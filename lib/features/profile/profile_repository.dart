import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// The user's confirmed career profile (users/{uid}/profile/main).
class CareerProfile {
  CareerProfile({
    this.name = '',
    this.email = '',
    this.phone = '',
    this.location = '',
    this.links = const [],
    this.experienceYears = 0,
    this.skills = const [],
    this.titles = const [],
    this.education = const [],
    this.categoryId,
    this.subCategoryIds = const [],
    this.atsScore,
    this.atsParts = const {},
    this.atsIssues = const [],
    this.resumeFileName = '',
  });

  final String name;
  final String email;
  final String phone;
  final String location;
  final List<String> links;
  final double experienceYears;
  final List<String> skills; // lowercase keywords
  final List<String> titles;
  final List<String> education;
  final String? categoryId;
  final List<String> subCategoryIds;
  final int? atsScore;
  final Map<String, int> atsParts;

  /// Each: {severity: high|medium|low, title, detail, before?, after?}
  final List<Map<String, String>> atsIssues;
  final String resumeFileName;

  bool get isFresher => experienceYears < 1;

  CareerProfile copyWith({
    String? name,
    String? email,
    String? phone,
    String? location,
    double? experienceYears,
    List<String>? skills,
    List<String>? titles,
    List<String>? education,
    String? categoryId,
    List<String>? subCategoryIds,
    int? atsScore,
    Map<String, int>? atsParts,
    List<Map<String, String>>? atsIssues,
    String? resumeFileName,
  }) =>
      CareerProfile(
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        location: location ?? this.location,
        links: links,
        experienceYears: experienceYears ?? this.experienceYears,
        skills: skills ?? this.skills,
        titles: titles ?? this.titles,
        education: education ?? this.education,
        categoryId: categoryId ?? this.categoryId,
        subCategoryIds: subCategoryIds ?? this.subCategoryIds,
        atsScore: atsScore ?? this.atsScore,
        atsParts: atsParts ?? this.atsParts,
        atsIssues: atsIssues ?? this.atsIssues,
        resumeFileName: resumeFileName ?? this.resumeFileName,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'phone': phone,
        'location': location,
        'links': links,
        'experienceYears': experienceYears,
        'skills': skills,
        'titles': titles,
        'education': education,
        'categoryId': categoryId,
        'subCategoryIds': subCategoryIds,
        'atsScore': atsScore,
        'atsParts': atsParts,
        'atsIssues': atsIssues,
        'resumeFileName': resumeFileName,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory CareerProfile.fromMap(Map<String, dynamic> m) => CareerProfile(
        name: m['name'] as String? ?? '',
        email: m['email'] as String? ?? '',
        phone: m['phone'] as String? ?? '',
        location: m['location'] as String? ?? '',
        links: List<String>.from(m['links'] as List? ?? const []),
        experienceYears: (m['experienceYears'] as num?)?.toDouble() ?? 0,
        skills: List<String>.from(m['skills'] as List? ?? const []),
        titles: List<String>.from(m['titles'] as List? ?? const []),
        education: List<String>.from(m['education'] as List? ?? const []),
        categoryId: m['categoryId'] as String?,
        subCategoryIds: List<String>.from(m['subCategoryIds'] as List? ?? const []),
        atsScore: (m['atsScore'] as num?)?.toInt(),
        atsParts: (m['atsParts'] as Map?)?.map((k, v) => MapEntry(k as String, (v as num).toInt())) ?? const {},
        atsIssues: (m['atsIssues'] as List? ?? const [])
            .map((e) => (e as Map).map((k, v) => MapEntry(k as String, '$v')))
            .toList(),
        resumeFileName: m['resumeFileName'] as String? ?? '',
      );
}

class ProfileRepository {
  ProfileRepository(this._db);
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid).collection('profile').doc('main');

  Stream<CareerProfile?> watch(String uid) =>
      _doc(uid).snapshots().map((s) => s.exists ? CareerProfile.fromMap(s.data()!) : null);

  Future<void> save(String uid, CareerProfile p) => _doc(uid).set(p.toMap());

  Future<void> delete(String uid) => _doc(uid).delete();
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) => ProfileRepository(ref.watch(firestoreProvider)));

final profileProvider = StreamProvider<CareerProfile?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(profileRepositoryProvider).watch(user.uid);
});

/// The CV read in this session, waiting for the user to review it.
class CvDraft {
  CvDraft({required this.profile, required this.text, required this.fileName});
  final CareerProfile profile;
  final String text;
  final String fileName;
}

class CvDraftNotifier extends Notifier<CvDraft?> {
  @override
  CvDraft? build() => null;
  void set(CvDraft? d) => state = d;
}

final cvDraftProvider = NotifierProvider<CvDraftNotifier, CvDraft?>(CvDraftNotifier.new);
