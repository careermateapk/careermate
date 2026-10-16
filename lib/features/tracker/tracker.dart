import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../jobs/job_models.dart';

enum Stage { saved, applied, interview, offer, rejected }

extension StageText on Stage {
  String get label => switch (this) {
        Stage.saved => 'Saved',
        Stage.applied => 'Applied',
        Stage.interview => 'Interview',
        Stage.offer => 'Offer',
        Stage.rejected => 'Closed',
      };
}

/// One job the user is following. Stored in users/{uid}/tracker/{id}.
class TrackedJob {
  TrackedJob({
    required this.id,
    required this.title,
    required this.company,
    this.location = '',
    this.url = '',
    this.contactEmail = '',
    this.stage = Stage.saved,
    this.savedAt,
    this.appliedAt,
    this.followUpAt,
    this.interviewAt,
    this.notes = '',
    this.source = 'manual',
    this.recruiterStatus,
  });

  final String id;
  String title, company, location, url, contactEmail, notes, source;
  Stage stage;
  DateTime? savedAt, appliedAt, followUpAt, interviewAt;

  /// Live status set by a recruiter for jobs applied on CareerMate.
  String? recruiterStatus;

  bool get fromCareerMate => source == 'careermate';
  bool get followUpDue => stage == Stage.applied && followUpAt != null && !followUpAt!.isAfter(DateTime.now());

  Map<String, dynamic> toMap() => {
        'title': title,
        'company': company,
        'location': location,
        'url': url,
        'contactEmail': contactEmail,
        'stage': stage.name,
        'savedAt': savedAt == null ? null : Timestamp.fromDate(savedAt!),
        'appliedAt': appliedAt == null ? null : Timestamp.fromDate(appliedAt!),
        'followUpAt': followUpAt == null ? null : Timestamp.fromDate(followUpAt!),
        'interviewAt': interviewAt == null ? null : Timestamp.fromDate(interviewAt!),
        'notes': notes,
        'source': source,
      };

  static DateTime? _d(Object? v) => v is Timestamp ? v.toDate() : null;

  factory TrackedJob.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return TrackedJob(
      id: d.id,
      title: m['title'] as String? ?? '',
      company: m['company'] as String? ?? '',
      location: m['location'] as String? ?? '',
      url: m['url'] as String? ?? '',
      contactEmail: m['contactEmail'] as String? ?? '',
      stage: Stage.values.firstWhere((s) => s.name == m['stage'], orElse: () => Stage.saved),
      savedAt: _d(m['savedAt']),
      appliedAt: _d(m['appliedAt']),
      followUpAt: _d(m['followUpAt']),
      interviewAt: _d(m['interviewAt']),
      notes: m['notes'] as String? ?? '',
      source: m['source'] as String? ?? 'manual',
    );
  }

  factory TrackedJob.fromJob(JobItem j, {Stage stage = Stage.saved}) {
    final now = DateTime.now();
    return TrackedJob(
      id: j.isCareerMate ? j.postedJobId! : j.id,
      title: j.title,
      company: j.company,
      location: j.location,
      url: j.url,
      contactEmail: j.contactEmail,
      stage: stage,
      savedAt: now,
      appliedAt: stage == Stage.applied ? now : null,
      followUpAt: stage == Stage.applied ? now.add(const Duration(days: 7)) : null,
      source: j.isCareerMate ? 'careermate' : 'job',
    );
  }
}

class TrackerRepository {
  TrackerRepository(this._db, this._uid);
  final FirebaseFirestore _db;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('users').doc(_uid).collection('tracker');

  Future<void> save(TrackedJob t) => _col.doc(t.id).set(t.toMap(), SetOptions(merge: true));
  Future<void> delete(String id) => _col.doc(id).delete();
  Future<bool> has(String id) async => (await _col.doc(id).get()).exists;

  Future<void> setStage(TrackedJob t, Stage s) {
    final now = DateTime.now();
    t.stage = s;
    if (s == Stage.applied) {
      t.appliedAt ??= now;
      t.followUpAt ??= now.add(const Duration(days: 7));
    }
    return save(t);
  }

  /// Everything the user is following: their own list, plus CareerMate applications and emails sent to HR.
  Stream<List<TrackedJob>> watch() => _col.snapshots().asyncMap((snap) async {
        final byId = {for (final d in snap.docs) d.id: TrackedJob.fromDoc(d)};
        try {
          final apps = await _db.collection('users').doc(_uid).collection('applications').get();
          for (final a in apps.docs) {
            final jobId = a.id;
            final job = await _db.collection('posted_jobs').doc(jobId).get();
            final app = await _db.collection('posted_jobs').doc(jobId).collection('applications').doc(_uid).get();
            final jm = job.data() ?? {};
            final status = app.data()?['status'] as String? ?? 'new';
            final t = byId[jobId] ??
                TrackedJob(
                  id: jobId,
                  title: jm['title'] as String? ?? 'Job',
                  company: jm['company'] as String? ?? '',
                  location: jm['city'] as String? ?? '',
                  stage: Stage.applied,
                  appliedAt: (a.data()['appliedAt'] as Timestamp?)?.toDate(),
                  source: 'careermate',
                );
            t.source = 'careermate';
            t.recruiterStatus = status;
            if (status == 'interview' && t.stage.index < Stage.interview.index) t.stage = Stage.interview;
            if (status == 'rejected') t.stage = Stage.rejected;
            byId[jobId] = t;
          }
        } catch (_) {}
        try {
          final out = await _db.collection('users').doc(_uid).collection('outreach').get();
          for (final o in out.docs) {
            if (byId.containsKey(o.id)) continue;
            final m = o.data();
            final at = (m['emailedAt'] as Timestamp?)?.toDate();
            byId[o.id] = TrackedJob(
              id: o.id,
              title: m['jobTitle'] as String? ?? 'Job',
              company: m['company'] as String? ?? '',
              url: m['url'] as String? ?? '',
              contactEmail: m['to'] as String? ?? '',
              stage: Stage.applied,
              appliedAt: at,
              followUpAt: at?.add(const Duration(days: 7)),
              source: 'email',
            );
          }
        } catch (_) {}
        final list = byId.values.toList()
          ..sort((a, b) => (b.appliedAt ?? b.savedAt ?? DateTime(2000)).compareTo(a.appliedAt ?? a.savedAt ?? DateTime(2000)));
        return list;
      });
}

final trackerRepositoryProvider = Provider<TrackerRepository?>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  return uid == null ? null : TrackerRepository(ref.watch(firestoreProvider), uid);
});

final trackerProvider = StreamProvider<List<TrackedJob>>((ref) {
  final repo = ref.watch(trackerRepositoryProvider);
  return repo == null ? Stream.value(const []) : repo.watch();
});
