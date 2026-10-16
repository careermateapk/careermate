import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../profile/cv_parser.dart';
import '../profile/profile_repository.dart';
import '../recruiter/posted_job.dart';
import '../community/job_post.dart';

/// One job from the collector (jobs_index/{subCategoryId}.jobs[]).
class JobItem {
  JobItem({
    required this.id,
    required this.title,
    required this.company,
    required this.location,
    required this.remote,
    required this.url,
    required this.source,
    required this.sourceName,
    required this.official,
    required this.postedAt,
    required this.dateKind,
    required this.lastChecked,
    required this.salaryMin,
    required this.salaryMax,
    required this.employmentType,
    required this.snippet,
    required this.skills,
    required this.subIds,
    required this.scamFlags,
    this.description = '',
    this.postedJobId,
    this.contactEmail = '',
    this.communityId,
    this.checksPassed = 0,
    this.checksTotal = 0,
    this.reports = 0,
  });

  final String id;

  /// Longer description when the source gives one (falls back to [snippet]).
  final String description;
  String get fullText => description.length > snippet.length ? description : snippet;
  final String title;
  final String company;
  final String location;
  final bool remote;
  final String url;
  final String source;
  final String sourceName;
  final bool official;
  final DateTime? postedAt;

  /// published | updated | unknown
  final String dateKind;
  final DateTime? lastChecked;
  final num? salaryMin;
  final num? salaryMax;
  final String? employmentType;
  final String snippet;
  final List<String> skills;
  final List<String> subIds;
  final List<String> scamFlags;

  /// Set for jobs posted by recruiters on CareerMate.
  final String? postedJobId;

  /// Recruiter email for CareerMate jobs (empty for collected jobs).
  final String contactEmail;

  bool get isAdzuna => source == 'adzuna';
  bool get isCareerMate => postedJobId != null;

  /// Shared into CareerMate by a user from LinkedIn/WhatsApp, after checks.
  final String? communityId;
  final int checksPassed;
  final int checksTotal;
  final int reports;
  bool get isCommunity => communityId != null;

  int? get ageDays => postedAt == null ? null : DateTime.now().difference(postedAt!).inDays;

  bool get looksFresherFriendly {
    final t = title.toLowerCase();
    return RegExp(r'\b(intern|internship|fresher|freshers|trainee|graduate|junior|entry level|apprentice)\b').hasMatch(t);
  }

  static DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

  factory JobItem.fromMap(Map<String, dynamic> m) => JobItem(
        id: m['id'] as String? ?? '',
        title: m['title'] as String? ?? '',
        company: m['company'] as String? ?? '',
        location: m['location'] as String? ?? '',
        remote: m['remote'] as bool? ?? false,
        url: m['url'] as String? ?? '',
        source: m['source'] as String? ?? '',
        sourceName: m['sourceName'] as String? ?? '',
        official: m['official'] as bool? ?? false,
        postedAt: _date(m['postedAt']),
        dateKind: m['dateKind'] as String? ?? 'unknown',
        lastChecked: _date(m['lastChecked']),
        salaryMin: m['salaryMin'] as num?,
        salaryMax: m['salaryMax'] as num?,
        employmentType: m['employmentType'] as String?,
        snippet: m['snippet'] as String? ?? '',
        description: m['description'] as String? ?? '',
        skills: List<String>.from(m['skills'] as List? ?? const []),
        subIds: List<String>.from(m['subIds'] as List? ?? const []),
        scamFlags: List<String>.from(m['scamFlags'] as List? ?? const []),
      );
}

enum Recommendation { apply, review, deprioritise }

/// How well a job fits the user's confirmed profile, with reasons.
/// Weights: skills 50, category 25, location 15, freshness 10 (total 100).
class JobMatch {
  JobMatch(this.job, this.score, this.matchedSkills, this.missingSkills, this.reasons, this.concerns);
  final JobItem job;
  final int score;
  final List<String> matchedSkills;

  /// Skills the job mentions that are not shown in the CV (not "you lack them").
  final List<String> missingSkills;
  final List<String> reasons;
  final List<String> concerns;

  Recommendation get recommendation => job.scamFlags.isNotEmpty
      ? Recommendation.deprioritise
      : score >= 70
          ? Recommendation.apply
          : score >= 50
              ? Recommendation.review
              : Recommendation.deprioritise;

  static JobMatch of(JobItem job, CareerProfile p) {
    final mine = p.skills.map((s) => s.toLowerCase()).toSet();
    final matched = job.skills.where(mine.contains).toList();
    final missing = job.skills.where((s) => !mine.contains(s)).toList();
    final reasons = <String>[];
    final concerns = <String>[];

    // Skills (50)
    final denom = job.skills.isEmpty ? 3 : job.skills.length.clamp(3, 8);
    final skillPts = (50 * (matched.length / denom).clamp(0, 1)).round();
    if (matched.isNotEmpty) {
      reasons.add('Your CV shows ${matched.length} of the skills this job mentions: ${matched.take(4).map(CvParser.prettySkill).join(', ')}.');
    }
    if (job.skills.isNotEmpty && matched.isEmpty) concerns.add('None of the skills this job mentions appear in your CV.');

    // Category (25)
    final catHit = job.subIds.any(p.subCategoryIds.contains);
    final catPts = catHit ? 25 : 0;
    if (catHit) reasons.add('It is in one of your chosen job categories.');

    // Location (15)
    int locPts;
    final city = p.location.toLowerCase().trim();
    final loc = job.location.toLowerCase();
    if (job.remote) {
      locPts = 15;
      reasons.add('Remote job — you can work from your city.');
    } else if (city.isNotEmpty && loc.contains(city)) {
      locPts = 15;
      reasons.add('Located in your city, ${p.location}.');
    } else {
      locPts = 6;
      concerns.add(city.isEmpty ? 'Add your city to your profile to check location fit.' : 'This job is not in ${p.location}. You may need to relocate.');
    }

    // Freshness (10)
    final age = job.ageDays;
    final freshPts = age == null ? 3 : age <= 7 ? 10 : age <= 14 ? 7 : 4;
    if (age == null) concerns.add('The publish date is not known.');

    if (job.scamFlags.isNotEmpty) concerns.insert(0, 'Mentions "${job.scamFlags.first}". Genuine employers do not charge you to apply.');
    if (p.isFresher && !job.looksFresherFriendly && RegExp(r'\b(senior|lead|principal|manager|head|staff)\b').hasMatch(job.title.toLowerCase())) {
      concerns.add('The title suggests a senior role.');
    }

    final total = (skillPts + catPts + locPts + freshPts).clamp(0, 100).toInt();
    return JobMatch(job, total, matched, missing, reasons, concerns);
  }
}

class JobsData {
  JobsData(this.jobs, this.updatedAt);
  final List<JobItem> jobs;
  final DateTime? updatedAt;
}

/// Jobs for the user's chosen sub-categories (one document each), merged and de-duplicated.
final jobsProvider = FutureProvider.autoDispose<JobsData>((ref) async {
  final profile = ref.watch(profileProvider).value;
  if (profile == null || profile.subCategoryIds.isEmpty) return JobsData(const [], null);
  final db = ref.watch(firestoreProvider);
  final docs = await Future.wait(profile.subCategoryIds.take(10).map((id) => db.collection('jobs_index').doc(id).get()));
  final byId = <String, JobItem>{};
  DateTime? updated;
  for (final d in docs) {
    final data = d.data();
    if (data == null) continue;
    final u = DateTime.tryParse(data['updatedAt'] as String? ?? '')?.toLocal();
    if (u != null && (updated == null || u.isAfter(updated))) updated = u;
    for (final raw in (data['jobs'] as List? ?? const [])) {
      final j = JobItem.fromMap(Map<String, dynamic>.from(raw as Map));
      byId[j.id] = j;
    }
  }
  // Jobs shared by users (LinkedIn/WhatsApp posts) that passed the checks.
  try {
    for (final c in await ref.watch(communityRepositoryProvider).jobsFor(profile.subCategoryIds)) {
      byId[c.id] = c;
    }
  } catch (_) {}
  // Jobs posted by recruiters on CareerMate come first in the list.
  try {
    final posted = await ref.watch(recruiterRepositoryProvider).liveJobsFor(profile.subCategoryIds);
    for (final p in posted) {
      byId[p.toJobItem().id] = p.toJobItem();
    }
  } catch (_) {
    // Rules not updated yet or offline: show collected jobs only.
  }
  return JobsData(byId.values.toList(), updated);
});
