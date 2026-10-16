import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../jobs/job_models.dart';
import '../profile/category_matcher.dart';
import '../profile/cv_parser.dart';
import '../profile/taxonomy.dart';
import '../recruiter/posted_job.dart';

/// A job post someone saw (LinkedIn, WhatsApp…) and shared into CareerMate.
class SharedPost {
  SharedPost({
    required this.raw,
    required this.title,
    required this.location,
    required this.experience,
    required this.qualification,
    required this.email,
    required this.phone,
    required this.link,
    required this.source,
    required this.subIds,
    required this.skills,
  });

  final String raw;
  final String title;
  final String location;
  final String experience;
  final String qualification;
  final String email;
  final String phone;
  final String link;
  final String source;
  final List<String> subIds;
  final List<String> skills;

  String get domain => email.contains('@') ? email.split('@').last.toLowerCase() : '';
  bool get companyEmail => email.isNotEmpty && isCompanyEmail(email);

  /// Stable id so the same post shared twice becomes one job.
  String get id {
    final key = '${email.toLowerCase()}|${title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}';
    var h = 0x811c9dc5;
    for (final c in key.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0xffffffff;
    }
    return 'p${h.toRadixString(16)}${key.length}';
  }

  static SharedPost parse(String raw) {
    final text = raw.replaceAll('\r', '\n');
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final low = text.toLowerCase();

    String field(List<String> keys) {
      for (final l in lines) {
        final m = RegExp('^(?:${keys.join('|')})\\s*[:\\-–]\\s*(.+)\$', caseSensitive: false).firstMatch(l);
        if (m != null) return m.group(1)!.trim();
      }
      return '';
    }

    var title = field(['role', 'position', 'job title', 'designation', 'title', 'opening', 'post']);
    if (title.isEmpty) {
      final hiring = RegExp(r"(?:we['’]?re hiring|we are hiring|hiring|looking for|opening for|vacancy for)\s*(?:an?\s+)?[:\-–!]*\s*([A-Za-z][^\n.,!]{3,70})",
              caseSensitive: false)
          .firstMatch(text);
      title = hiring?.group(1)?.trim() ?? '';
    }
    title = title.replaceAll(RegExp(r'[*#|]+'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (title.length > 80) title = title.substring(0, 80);

    var location = field(['location', 'job location', 'city', 'work location', 'place']);
    if (location.isEmpty) {
      for (final c in CvParser.cities) {
        if (CvParser.containsWord(low, c)) {
          location = c.split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
          break;
        }
      }
    }
    var exp = field(['experience', 'exp', 'work experience']);
    if (exp.isEmpty) {
      exp = RegExp(r'(\d{1,2}\s*(?:-|–|to)\s*\d{1,2}|\d{1,2}\+?)\s*(?:years?|yrs?)', caseSensitive: false).firstMatch(text)?.group(0) ?? '';
    }
    final qual = field(['qualification', 'qualifications', 'education', 'eligibility']);
    final email = RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+').firstMatch(text)?.group(0)?.replaceFirst(RegExp(r'[.]+$'), '') ?? '';
    final phone = RegExp(r'(\+91[\s-]?)?[6-9]\d{4}[\s-]?\d{5}').firstMatch(text)?.group(0) ?? '';
    final link = RegExp(r'https?://\S+').firstMatch(text)?.group(0) ?? '';
    final source = low.contains('linkedin') ? 'LinkedIn' : low.contains('whatsapp') || link.contains('wa.me') ? 'WhatsApp' : 'a job post';

    final skills = <String>{};
    for (final c in jobCategories) {
      for (final s in c.subs) {
        for (final k in s.skills) {
          if (CvParser.containsWord(low, k)) skills.add(k);
        }
      }
    }
    final cat = const CategoryMatcher().match(skills: skills.toList(), titles: [title.toLowerCase(), low]);
    final subIds = cat.subs.where((s) => s.strength >= 50).take(4).map((s) => s.sub.id).toList();

    return SharedPost(
      raw: text.length > 4000 ? text.substring(0, 4000) : text,
      title: title,
      location: location,
      experience: exp,
      qualification: qual,
      email: email,
      phone: phone,
      link: link,
      source: source,
      subIds: subIds,
      skills: skills.toList(),
    );
  }
}

enum CheckResult { ok, warn, bad }

class PostCheck {
  const PostCheck(this.result, this.title, this.detail);
  final CheckResult result;
  final String title;
  final String detail;
}

const _consultancyWords = [
  'consultant', 'consultancy', 'consulting', 'placement', 'recruitment agency', 'staffing', 'for our client',
  'on behalf of', 'leading company', 'reputed company', 'leading delhi', 'leading mumbai', 'mnc client', 'hr solutions',
];

class CommunityRepository {
  CommunityRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('community_jobs');

  /// Runs the authenticity checks. Website check needs internet.
  Future<List<PostCheck>> check(SharedPost p) async {
    final out = <PostCheck>[];
    if (p.email.isEmpty) {
      out.add(const PostCheck(CheckResult.warn, 'No email to apply', 'The post has no email address. Apply only through the official company site.'));
    } else if (p.companyEmail) {
      out.add(PostCheck(CheckResult.ok, 'Real company email', '${p.email} — not Gmail/Yahoo'));
    } else {
      out.add(PostCheck(CheckResult.warn, 'Personal email', '${p.email} is a free email. Many genuine small firms use these, but be careful.'));
    }

    if (p.domain.isNotEmpty && p.companyEmail) {
      final ok = await _siteOpens(p.domain);
      out.add(ok
          ? PostCheck(CheckResult.ok, 'Company website exists', '${p.domain} opens and matches the email')
          : PostCheck(CheckResult.warn, 'Website not reachable', 'We could not open ${p.domain}. Check the company yourself.'));
    }

    final money = findMoneyAsk(p.raw);
    out.add(money == null
        ? const PostCheck(CheckResult.ok, 'No money asked', 'No fee, deposit or “registration charge”')
        : PostCheck(CheckResult.bad, 'Asks for money', 'Mentions “$money”. Genuine employers never charge to apply.'));

    final hasDetails = p.title.isNotEmpty && (p.location.isNotEmpty || p.experience.isNotEmpty);
    out.add(hasDetails
        ? const PostCheck(CheckResult.ok, 'Clear job details', 'Role and location or experience are stated')
        : const PostCheck(CheckResult.warn, 'Few details', 'The role, city or experience is missing. You can fill them in.'));

    final low = p.raw.toLowerCase();
    final agency = _consultancyWords.any(low.contains);
    if (agency) {
      out.add(const PostCheck(CheckResult.warn, 'Posted by a hiring consultancy', 'The actual employer is not named'));
    }

    try {
      final existing = await _col.doc(p.id).get();
      final reports = (existing.data()?['reports'] as num?)?.toInt() ?? 0;
      out.add(reports >= 2
          ? PostCheck(CheckResult.bad, 'Reported by other users', '$reports people reported this job as fake')
          : PostCheck(CheckResult.ok, existing.exists ? 'Already shared by others' : 'Not reported by other users',
              existing.exists ? 'Already on CareerMate · $reports reports' : '0 scam reports'));
    } catch (_) {}
    return out;
  }

  Future<bool> _siteOpens(String domain) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      for (final host in [domain, 'www.$domain']) {
        try {
          final req = await client.getUrl(Uri.https(host, '/')).timeout(const Duration(seconds: 8));
          req.followRedirects = true;
          final res = await req.close().timeout(const Duration(seconds: 8));
          await res.drain<void>();
          if (res.statusCode < 500) return true;
        } catch (_) {}
      }
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> exists(String id) async => (await _col.doc(id).get()).exists;

  Future<void> publish(SharedPost p, {required String uid, required int passed, required int total}) {
    return _col.doc(p.id).set({
      'title': p.title,
      'company': p.companyEmail ? _companyFromDomain(p.domain) : '',
      'location': p.location,
      'experience': p.experience,
      'qualification': p.qualification,
      'contactEmail': p.email,
      'link': p.link,
      'source': p.source,
      'description': p.raw,
      'skills': p.skills,
      'subIds': p.subIds,
      'checksPassed': passed,
      'checksTotal': total,
      'sharedBy': uid,
      'sharedAt': FieldValue.serverTimestamp(),
      'reports': 0,
      'reportedBy': <String>[],
    });
  }

  Future<void> report(String id, String uid) => _col.doc(id).update({
        'reports': FieldValue.increment(1),
        'reportedBy': FieldValue.arrayUnion([uid]),
      });

  Future<List<JobItem>> jobsFor(List<String> subIds) async {
    if (subIds.isEmpty) return const [];
    final since = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 30)));
    final s = await _col.where('subIds', arrayContainsAny: subIds.take(10).toList()).limit(100).get();
    return s.docs
        .where((d) => ((d.data()['reports'] as num?) ?? 0) < 3)
        .where((d) => (d.data()['sharedAt'] as Timestamp?)?.compareTo(since) != -1)
        .map(_toJob)
        .toList();
  }

  static String _companyFromDomain(String d) {
    final name = d.split('.').first;
    return name.isEmpty ? '' : name[0].toUpperCase() + name.substring(1);
  }

  static JobItem _toJob(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    final desc = m['description'] as String? ?? '';
    final at = (m['sharedAt'] as Timestamp?)?.toDate();
    return JobItem(
      id: 'cm_${d.id}',
      title: m['title'] as String? ?? 'Job',
      company: (m['company'] as String?)?.isNotEmpty == true ? m['company'] as String : 'Hiring company',
      location: m['location'] as String? ?? '',
      remote: (m['location'] as String? ?? '').toLowerCase().contains('remote'),
      url: m['link'] as String? ?? '',
      source: 'community',
      sourceName: 'Shared from ${m['source'] ?? 'a job post'}',
      official: false,
      postedAt: at,
      dateKind: 'shared',
      lastChecked: at,
      salaryMin: null,
      salaryMax: null,
      employmentType: null,
      snippet: desc.length > 400 ? desc.substring(0, 400) : desc,
      description: desc,
      skills: List<String>.from(m['skills'] as List? ?? const []),
      subIds: List<String>.from(m['subIds'] as List? ?? const []),
      scamFlags: [if (findMoneyAsk(desc) != null) findMoneyAsk(desc)!],
      contactEmail: m['contactEmail'] as String? ?? '',
      communityId: d.id,
      checksPassed: (m['checksPassed'] as num?)?.toInt() ?? 0,
      checksTotal: (m['checksTotal'] as num?)?.toInt() ?? 0,
      reports: (m['reports'] as num?)?.toInt() ?? 0,
    );
  }
}

final communityRepositoryProvider = Provider<CommunityRepository>((ref) => CommunityRepository(ref.watch(firestoreProvider)));
