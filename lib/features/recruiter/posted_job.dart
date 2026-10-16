import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../jobs/job_models.dart';
import '../profile/profile_repository.dart';

/// A job posted by a recruiter on CareerMate (posted_jobs/{id}).
class PostedJob {
  PostedJob({
    required this.id,
    required this.recruiterUid,
    required this.company,
    required this.contactEmail,
    required this.title,
    required this.catId,
    required this.subIds,
    required this.workMode,
    required this.city,
    required this.expMin,
    required this.expMax,
    required this.salaryMinLakh,
    required this.salaryMaxLakh,
    required this.skills,
    required this.description,
    required this.status,
    this.createdAt,
  });

  final String id;
  final String recruiterUid;
  final String company;
  final String contactEmail;
  final String title;
  final String? catId;
  final List<String> subIds;

  /// onsite | hybrid | remote
  final String workMode;
  final String city;
  final int expMin;
  final int expMax;
  final double? salaryMinLakh;
  final double? salaryMaxLakh;
  final List<String> skills; // lowercase keywords
  final String description;

  /// live | draft | closed
  final String status;
  final DateTime? createdAt;

  bool get isLive => status == 'live';

  String get workModeLabel => switch (workMode) { 'remote' => 'Remote', 'hybrid' => 'Hybrid', _ => 'On-site' };

  String get experienceLabel =>
      expMax <= 0 ? 'Fresher' : (expMin == expMax ? '$expMin yrs' : '$expMin–$expMax yrs');

  Map<String, dynamic> toMap() => {
        'recruiterUid': recruiterUid,
        'company': company,
        'contactEmail': contactEmail,
        'title': title,
        'catId': catId,
        'subIds': subIds,
        'workMode': workMode,
        'city': city,
        'expMin': expMin,
        'expMax': expMax,
        'salaryMinLakh': salaryMinLakh,
        'salaryMaxLakh': salaryMaxLakh,
        'skills': skills,
        'description': description,
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory PostedJob.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return PostedJob(
      id: d.id,
      recruiterUid: m['recruiterUid'] as String? ?? '',
      company: m['company'] as String? ?? '',
      contactEmail: m['contactEmail'] as String? ?? '',
      title: m['title'] as String? ?? '',
      catId: m['catId'] as String?,
      subIds: List<String>.from(m['subIds'] as List? ?? const []),
      workMode: m['workMode'] as String? ?? 'onsite',
      city: m['city'] as String? ?? '',
      expMin: (m['expMin'] as num?)?.toInt() ?? 0,
      expMax: (m['expMax'] as num?)?.toInt() ?? 0,
      salaryMinLakh: (m['salaryMinLakh'] as num?)?.toDouble(),
      salaryMaxLakh: (m['salaryMaxLakh'] as num?)?.toDouble(),
      skills: List<String>.from(m['skills'] as List? ?? const []),
      description: m['description'] as String? ?? '',
      status: m['status'] as String? ?? 'draft',
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Shown in the job seeker's list alongside collected jobs.
  JobItem toJobItem() => JobItem(
        id: 'cm_$id',
        title: title,
        company: company,
        location: workMode == 'remote' ? 'Remote, India' : city,
        remote: workMode == 'remote',
        url: '',
        source: 'careermate',
        sourceName: 'CareerMate',
        official: true,
        postedAt: createdAt,
        dateKind: 'published',
        lastChecked: DateTime.now(),
        salaryMin: salaryMinLakh == null ? null : salaryMinLakh! * 100000,
        salaryMax: salaryMaxLakh == null ? null : salaryMaxLakh! * 100000,
        employmentType: '$workModeLabel · $experienceLabel',
        snippet: description.length > 400 ? description.substring(0, 400) : description,
        skills: skills,
        subIds: subIds,
        scamFlags: const [],
        postedJobId: id,
        contactEmail: contactEmail,
      );
}

/// A job seeker's application (posted_jobs/{jobId}/applications/{seekerUid}).
class Application {
  Application({
    required this.seekerUid,
    required this.name,
    required this.email,
    required this.phone,
    required this.location,
    required this.experienceYears,
    required this.skills,
    required this.titles,
    required this.education,
    required this.score,
    required this.status,
    required this.cvEmailed,
    this.appliedAt,
    this.viewedAt,
  });

  final String seekerUid;
  final String name;
  final String email;
  final String phone;
  final String location;
  final double experienceYears;
  final List<String> skills;
  final List<String> titles;
  final List<String> education;
  final int score;

  /// new | shortlisted | interview | rejected
  final String status;
  final bool cvEmailed;
  final DateTime? viewedAt;
  final DateTime? appliedAt;

  factory Application.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Application(
      seekerUid: d.id,
      name: m['name'] as String? ?? '',
      email: m['email'] as String? ?? '',
      phone: m['phone'] as String? ?? '',
      location: m['location'] as String? ?? '',
      experienceYears: (m['experienceYears'] as num?)?.toDouble() ?? 0,
      skills: List<String>.from(m['skills'] as List? ?? const []),
      titles: List<String>.from(m['titles'] as List? ?? const []),
      education: List<String>.from(m['education'] as List? ?? const []),
      score: (m['score'] as num?)?.toInt() ?? 0,
      status: m['status'] as String? ?? 'new',
      cvEmailed: m['cvEmailed'] as bool? ?? false,
      appliedAt: (m['appliedAt'] as Timestamp?)?.toDate(),
      viewedAt: (m['viewedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Words that mean a job asks candidates for money.
const moneyAskWords = [
  'registration fee', 'security deposit', 'pay to apply', 'processing fee', 'refundable deposit', 'training fee',
  'joining fee', 'kit charges', 'send money', 'upi payment', 'deposit amount',
];

String? findMoneyAsk(String text) {
  final t = text.toLowerCase();
  for (final w in moneyAskWords) {
    if (t.contains(w) && !t.contains('no $w') && !t.contains('without $w')) return w;
  }
  return null;
}

class RecruiterRepository {
  RecruiterRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _jobs => _db.collection('posted_jobs');

  Stream<List<PostedJob>> watchMine(String uid) => _jobs.where('recruiterUid', isEqualTo: uid).snapshots().map((s) {
        final list = s.docs.map(PostedJob.fromDoc).toList();
        list.sort((a, b) => (b.createdAt ?? DateTime(2100)).compareTo(a.createdAt ?? DateTime(2100)));
        return list;
      });

  Future<String> save(PostedJob job) async {
    if (job.id.isEmpty) {
      final ref = await _jobs.add({...job.toMap(), 'createdAt': FieldValue.serverTimestamp()});
      return ref.id;
    }
    await _jobs.doc(job.id).update(job.toMap());
    return job.id;
  }

  Future<void> setStatus(String jobId, String status) =>
      _jobs.doc(jobId).update({'status': status, 'updatedAt': FieldValue.serverTimestamp()});

  Future<void> delete(String jobId) async {
    final apps = await _jobs.doc(jobId).collection('applications').get();
    for (final a in apps.docs) {
      await a.reference.delete();
    }
    await _jobs.doc(jobId).delete();
  }

  Stream<List<Application>> watchApplications(String jobId) =>
      _jobs.doc(jobId).collection('applications').snapshots().map((s) {
        final list = s.docs.map(Application.fromDoc).toList();
        list.sort((a, b) => b.score.compareTo(a.score));
        return list;
      });

  Future<void> setApplicationStatus(String jobId, String seekerUid, String status) => _jobs
      .doc(jobId)
      .collection('applications')
      .doc(seekerUid)
      .update({'status': status, 'updatedAt': FieldValue.serverTimestamp()});

  /// Records the first time the recruiter opens an application, so the candidate is told "HR viewed".
  Future<void> markViewed(String jobId, String seekerUid) => _jobs
      .doc(jobId)
      .collection('applications')
      .doc(seekerUid)
      .update({'viewedAt': FieldValue.serverTimestamp()});

  /// Live CareerMate jobs in any of [subIds] (max 10, Firestore limit).
  Future<List<PostedJob>> liveJobsFor(List<String> subIds) async {
    if (subIds.isEmpty) return const [];
    final s = await _jobs.where('subIds', arrayContainsAny: subIds.take(10).toList()).limit(100).get();
    return s.docs.map(PostedJob.fromDoc).where((j) => j.isLive).toList();
  }

  Future<bool> hasApplied(String jobId, String uid) async =>
      (await _jobs.doc(jobId).collection('applications').doc(uid).get()).exists;

  /// Saves the application with the seeker's confirmed profile details.
  Future<void> apply({
    required String jobId,
    required String uid,
    required CareerProfile profile,
    required int score,
    required bool cvEmailed,
  }) async {
    await _jobs.doc(jobId).collection('applications').doc(uid).set({
      'name': profile.name,
      'email': profile.email,
      'phone': profile.phone,
      'location': profile.location,
      'experienceYears': profile.experienceYears,
      'skills': profile.skills,
      'titles': profile.titles,
      'education': profile.education,
      'score': score,
      'status': 'new',
      'cvEmailed': cvEmailed,
      'appliedAt': FieldValue.serverTimestamp(),
    });
    await _db.collection('users').doc(uid).collection('applications').doc(jobId).set({
      'jobId': jobId,
      'source': 'careermate',
      'appliedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Removes every job (and its applications) posted by [uid]. Used on account deletion.
  Future<void> deleteAllFor(String uid) async {
    final mine = await _jobs.where('recruiterUid', isEqualTo: uid).get();
    for (final d in mine.docs) {
      await delete(d.id);
    }
  }
}

final recruiterRepositoryProvider = Provider<RecruiterRepository>((ref) => RecruiterRepository(ref.watch(firestoreProvider)));

final myPostedJobsProvider = StreamProvider<List<PostedJob>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const []);
  return ref.watch(recruiterRepositoryProvider).watchMine(user.uid);
});

final applicationsProvider = StreamProvider.family<List<Application>, String>(
  (ref, jobId) => ref.watch(recruiterRepositoryProvider).watchApplications(jobId),
);
