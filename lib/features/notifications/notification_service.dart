import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';

import '../../firebase_options.dart';
import '../profile/taxonomy.dart';

/// Free, server-less notifications: the phone itself checks for changes about once an hour
/// (Android decides the exact time, so alerts can arrive a little late) and when the app opens.
///
/// It tells the job seeker when a recruiter views / shortlists / moves / rejects an application made
/// on CareerMate, and when new jobs arrive in their chosen categories.

const _taskName = 'careermate-check';

@pragma('vm:entry-point')
void notificationCallbackDispatcher() {
  Workmanager().executeTask((task, input) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      }
      await NotificationService.instance.init(requestPermission: false);
      await NotificationService.instance.checkNow();
    } catch (e) {
      debugPrint('Background check failed: $e');
    }
    return true;
  });
}

class AppNotification {
  AppNotification({required this.id, required this.kind, required this.title, required this.body, required this.at, this.read = false, this.route});

  final String id;

  /// viewed | shortlisted | interview | rejected | jobs
  final String kind;
  final String title;
  final String body;
  final DateTime at;
  bool read;
  final String? route;

  Map<String, dynamic> toJson() =>
      {'id': id, 'kind': kind, 'title': title, 'body': body, 'at': at.toIso8601String(), 'read': read, 'route': route};

  factory AppNotification.fromJson(Map<String, dynamic> m) => AppNotification(
        id: m['id'] as String? ?? '',
        kind: m['kind'] as String? ?? 'jobs',
        title: m['title'] as String? ?? '',
        body: m['body'] as String? ?? '',
        at: DateTime.tryParse(m['at'] as String? ?? '') ?? DateTime.now(),
        read: m['read'] as bool? ?? false,
        route: m['route'] as String?,
      );
}

class NotifSettings {
  const NotifSettings({this.applications = true, this.newJobs = true, this.quietHours = true});
  final bool applications;
  final bool newJobs;
  final bool quietHours;

  Map<String, dynamic> toJson() => {'applications': applications, 'newJobs': newJobs, 'quietHours': quietHours};
  factory NotifSettings.fromJson(Map<String, dynamic>? m) => NotifSettings(
        applications: m?['applications'] as bool? ?? true,
        newJobs: m?['newJobs'] as bool? ?? true,
        quietHours: m?['quietHours'] as bool? ?? true,
      );
  NotifSettings copyWith({bool? applications, bool? newJobs, bool? quietHours}) => NotifSettings(
        applications: applications ?? this.applications,
        newJobs: newJobs ?? this.newJobs,
        quietHours: quietHours ?? this.quietHours,
      );
}

/// One application's progress, for the timeline in the notification centre.
class AppProgress {
  AppProgress({required this.jobId, required this.title, required this.company, required this.status, this.appliedAt, this.viewedAt, this.updatedAt});
  final String jobId;
  final String title;
  final String company;
  final String status;
  final DateTime? appliedAt;
  final DateTime? viewedAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'jobId': jobId,
        'title': title,
        'company': company,
        'status': status,
        'appliedAt': appliedAt?.toIso8601String(),
        'viewedAt': viewedAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };
  factory AppProgress.fromJson(Map<String, dynamic> m) => AppProgress(
        jobId: m['jobId'] as String? ?? '',
        title: m['title'] as String? ?? '',
        company: m['company'] as String? ?? '',
        status: m['status'] as String? ?? 'new',
        appliedAt: DateTime.tryParse(m['appliedAt'] as String? ?? ''),
        viewedAt: DateTime.tryParse(m['viewedAt'] as String? ?? ''),
        updatedAt: DateTime.tryParse(m['updatedAt'] as String? ?? ''),
      );
}

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Bumped whenever the stored list changes, so open screens refresh.
  final changes = ValueNotifier<int>(0);

  /// Route to open after the user taps a notification.
  final pendingRoute = ValueNotifier<String?>(null);

  static const _channel = AndroidNotificationDetails(
    'careermate_updates',
    'Job updates',
    channelDescription: 'Application progress and new jobs for you',
    importance: Importance.high,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
  );

  Future<void> init({bool requestPermission = true}) async {
    if (kIsWeb || !Platform.isAndroid) return;
    if (!_ready) {
      await _plugin.initialize(
        const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
        onDidReceiveNotificationResponse: (r) => pendingRoute.value = r.payload ?? '/notifications',
      );
      _ready = true;
    }
    if (requestPermission) {
      await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        pendingRoute.value = launch!.notificationResponse?.payload ?? '/notifications';
      }
    }
  }

  /// Starts the hourly background check (Android may run it a little later to save battery).
  Future<void> startBackgroundChecks() async {
    if (kIsWeb || !Platform.isAndroid) return;
    await Workmanager().initialize(notificationCallbackDispatcher);
    await Workmanager().registerPeriodicTask(
      _taskName,
      _taskName,
      frequency: const Duration(hours: 1),
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  Future<void> stopBackgroundChecks() async {
    if (kIsWeb || !Platform.isAndroid) return;
    await Workmanager().cancelByUniqueName(_taskName);
  }

  // ------------------------------------------------------------------ local state file

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/notifications.json');
  }

  Future<Map<String, dynamic>> _load() async {
    try {
      final f = await _file();
      if (await f.exists()) return Map<String, dynamic>.from(jsonDecode(await f.readAsString()) as Map);
    } catch (_) {}
    return {};
  }

  Future<void> _save(Map<String, dynamic> s) async {
    final f = await _file();
    await f.writeAsString(jsonEncode(s));
    changes.value++;
  }

  Future<List<AppNotification>> items() async {
    final s = await _load();
    return [for (final m in (s['items'] as List? ?? const [])) AppNotification.fromJson(Map<String, dynamic>.from(m as Map))];
  }

  Future<List<AppProgress>> progress() async {
    final s = await _load();
    final list = [for (final m in (s['progress'] as List? ?? const [])) AppProgress.fromJson(Map<String, dynamic>.from(m as Map))];
    list.sort((a, b) => (b.updatedAt ?? b.appliedAt ?? DateTime(2000)).compareTo(a.updatedAt ?? a.appliedAt ?? DateTime(2000)));
    return list;
  }

  Future<NotifSettings> settings() async => NotifSettings.fromJson((await _load())['settings'] as Map<String, dynamic>?);

  Future<void> saveSettings(NotifSettings v) async {
    final s = await _load();
    s['settings'] = v.toJson();
    await _save(s);
  }

  Future<int> unreadCount() async => (await items()).where((n) => !n.read).length;

  Future<void> markAllRead() async {
    final s = await _load();
    for (final m in (s['items'] as List? ?? const [])) {
      (m as Map)['read'] = true;
    }
    await _save(s);
  }

  /// Clears everything (used on sign-out and account deletion).
  Future<void> clear() async {
    try {
      final f = await _file();
      if (await f.exists()) await f.delete();
      changes.value++;
    } catch (_) {}
  }

  // ------------------------------------------------------------------ the check

  bool _running = false;

  Future<void> checkNow() async {
    if (_running) return;
    _running = true;
    try {
      final user = FirebaseAuth.instance.currentUser ??
          await FirebaseAuth.instance.authStateChanges().first.timeout(const Duration(seconds: 10), onTimeout: () => null);
      if (user == null) return;
      final db = FirebaseFirestore.instance;
      final s = await _load();
      if (s['uid'] != user.uid) {
        // Different account on this phone: start fresh.
        s
          ..clear()
          ..['uid'] = user.uid;
      }
      final settings = NotifSettings.fromJson(s['settings'] as Map<String, dynamic>?);
      final fresh = <AppNotification>[];
      await _checkApplications(db, user.uid, s, settings, fresh);
      await _checkNewJobs(db, user.uid, s, settings, fresh);

      final items = [for (final m in (s['items'] as List? ?? const [])) Map<String, dynamic>.from(m as Map)];
      items.insertAll(0, fresh.map((n) => n.toJson()));
      s['items'] = items.take(60).toList();
      s['lastCheck'] = DateTime.now().toIso8601String();
      await _save(s);

      final quiet = settings.quietHours && (DateTime.now().hour >= 22 || DateTime.now().hour < 8);
      if (!quiet) {
        for (final n in fresh.take(4)) {
          await _show(n);
        }
      } else if (fresh.isNotEmpty) {
        // Show the held updates the next time a check runs outside quiet hours.
        s['held'] = [...(s['held'] as List? ?? const []), ...fresh.map((n) => n.toJson())];
        await _save(s);
      }
      if (!quiet && (s['held'] as List? ?? const []).isNotEmpty) {
        final held = [for (final m in s['held'] as List) AppNotification.fromJson(Map<String, dynamic>.from(m as Map))];
        s.remove('held');
        await _save(s);
        if (held.length == 1) {
          await _show(held.first);
        } else {
          await _show(AppNotification(
            id: 'held-${DateTime.now().millisecondsSinceEpoch}',
            kind: 'jobs',
            title: '${held.length} updates while you were away',
            body: held.take(2).map((h) => h.title).join(' · '),
            at: DateTime.now(),
            route: '/notifications',
          ));
        }
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _show(AppNotification n) async {
    if (!_ready) return;
    await _plugin.show(
      n.id.hashCode & 0x7fffffff,
      n.title,
      n.body,
      const NotificationDetails(android: _channel),
      payload: n.route ?? '/notifications',
    );
  }

  static const _statusText = {
    'shortlisted': ('You’re shortlisted!', 'shortlisted you for'),
    'interview': ('Interview stage', 'moved you to the interview stage for'),
    'rejected': ('Application update', 'decided not to move forward with your application for'),
  };

  Future<void> _checkApplications(FirebaseFirestore db, String uid, Map<String, dynamic> s, NotifSettings settings, List<AppNotification> out) async {
    final mine = await db.collection('users').doc(uid).collection('applications').where('source', isEqualTo: 'careermate').get();
    final known = Map<String, dynamic>.from(s['apps'] as Map? ?? {});
    final firstRun = !s.containsKey('apps');
    final progress = <Map<String, dynamic>>[];
    for (final a in mine.docs.take(40)) {
      final jobId = a.id;
      try {
        final job = await db.collection('posted_jobs').doc(jobId).get();
        final app = await db.collection('posted_jobs').doc(jobId).collection('applications').doc(uid).get();
        if (!app.exists) continue;
        final jm = job.data() ?? {};
        final m = app.data()!;
        final title = jm['title'] as String? ?? 'a job';
        final company = jm['company'] as String? ?? 'The recruiter';
        final status = m['status'] as String? ?? 'new';
        final viewed = m['viewedAt'] != null || status != 'new';
        progress.add(AppProgress(
          jobId: jobId,
          title: title,
          company: company,
          status: status,
          appliedAt: (m['appliedAt'] as Timestamp?)?.toDate(),
          viewedAt: (m['viewedAt'] as Timestamp?)?.toDate(),
          updatedAt: (m['updatedAt'] as Timestamp?)?.toDate(),
        ).toJson());

        final before = Map<String, dynamic>.from(known[jobId] as Map? ?? {});
        known[jobId] = {'status': status, 'viewed': viewed};
        if (firstRun || !settings.applications || before.isEmpty) continue;
        final now = DateTime.now();
        if (status != before['status'] && _statusText.containsKey(status)) {
          final t = _statusText[status]!;
          out.add(AppNotification(
            id: 'app-$jobId-$status',
            kind: status,
            title: t.$1,
            body: '$company ${t.$2} $title.${status == 'shortlisted' ? ' Get ready for the next step.' : status == 'interview' ? ' Check your email for details.' : ''}',
            at: now,
            route: '/notifications',
          ));
        } else if (viewed && before['viewed'] != true) {
          out.add(AppNotification(
            id: 'app-$jobId-viewed',
            kind: 'viewed',
            title: 'HR viewed your application',
            body: '$company opened your profile for $title.',
            at: now,
            route: '/notifications',
          ));
        }
      } catch (_) {
        // Job deleted or offline: skip.
      }
    }
    s['apps'] = known;
    s['progress'] = progress;
  }

  Future<void> _checkNewJobs(FirebaseFirestore db, String uid, Map<String, dynamic> s, NotifSettings settings, List<AppNotification> out) async {
    final prof = await db.collection('users').doc(uid).collection('profile').doc('main').get();
    final subs = List<String>.from(prof.data()?['subCategoryIds'] as List? ?? const []).take(10).toList();
    if (subs.isEmpty) return;
    final seen = Map<String, dynamic>.from(s['seenJobs'] as Map? ?? {});
    final allSeen = <String>{for (final v in seen.values) ...List<String>.from(v as List)};
    final newBySub = <String, List<Map>>{};
    for (final sub in subs) {
      try {
        final d = await db.collection('jobs_index').doc(sub).get();
        final jobs = (d.data()?['jobs'] as List? ?? const []).cast<Map>();
        final ids = [for (final j in jobs) '${j['id']}'];
        if (seen.containsKey(sub)) {
          final fresh = jobs.where((j) => !allSeen.contains('${j['id']}')).toList();
          if (fresh.isNotEmpty) newBySub[sub] = fresh;
        }
        seen[sub] = ids;
        allSeen.addAll(ids);
      } catch (_) {}
    }
    // CareerMate jobs posted by recruiters in the same categories.
    try {
      final posted = await db.collection('posted_jobs').where('subIds', arrayContainsAny: subs).limit(50).get();
      final known = List<String>.from(s['seenPosted'] as List? ?? const []);
      final live = posted.docs.where((d) => d.data()['status'] == 'live').toList();
      if (s.containsKey('seenPosted')) {
        for (final d in live.where((d) => !known.contains(d.id))) {
          final m = d.data();
          final sub = subs.firstWhere((x) => List<String>.from(m['subIds'] as List? ?? const []).contains(x), orElse: () => subs.first);
          (newBySub[sub] ??= []).insert(0, {'id': d.id, 'title': m['title'], 'company': m['company'], 'location': m['city'] ?? m['location']});
        }
      }
      s['seenPosted'] = live.map((d) => d.id).toList();
    } catch (_) {}
    s['seenJobs'] = seen;
    if (!settings.newJobs || newBySub.isEmpty) return;

    // One notification per category group (e.g. "Accounts & Finance").
    final byCat = <String, List<Map>>{};
    for (final e in newBySub.entries) {
      final cat = categoryOfSub(e.key)?.name ?? subCategoryById(e.key)?.name ?? 'your categories';
      (byCat[cat] ??= []).addAll(e.value);
    }
    final day = DateTime.now().toIso8601String().substring(0, 13);
    for (final e in byCat.entries) {
      final list = e.value;
      final first = list.first;
      final where = '${first['location'] ?? ''}'.split(',').first.trim();
      final more = list.length > 1 ? ' and ${list.length - 1} more' : '';
      out.add(AppNotification(
        id: 'jobs-${e.key}-$day',
        kind: 'jobs',
        title: list.length == 1 ? 'New ${e.key} job for you' : '${list.length} new ${e.key} jobs',
        body: '${first['title']}${(first['company'] ?? '').toString().isEmpty ? '' : ' at ${first['company']}'}'
            '${where.isEmpty ? '' : ' ($where)'}$more.',
        at: DateTime.now(),
        route: '/jobs',
      ));
    }
  }
}
