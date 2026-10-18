import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

class SkillResult {
  SkillResult({required this.testId, required this.score, required this.total, required this.passed, this.passedAt, this.attemptedAt});
  final String testId;
  final int score;
  final int total;
  final bool passed;
  final DateTime? passedAt;
  final DateTime? attemptedAt;

  int get percent => total == 0 ? 0 : (score * 100 / total).round();

  /// A new attempt is allowed 7 days after the last one.
  DateTime? get nextTry => attemptedAt?.add(const Duration(days: 7));
  bool get canRetry => nextTry == null || DateTime.now().isAfter(nextTry!);

  factory SkillResult.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return SkillResult(
      testId: d.id,
      score: (m['score'] as num?)?.toInt() ?? 0,
      total: (m['total'] as num?)?.toInt() ?? 10,
      passed: m['passed'] as bool? ?? false,
      passedAt: (m['passedAt'] as Timestamp?)?.toDate(),
      attemptedAt: (m['attemptedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class SkillRepository {
  SkillRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid) => _db.collection('users').doc(uid).collection('badges');

  Stream<Map<String, SkillResult>> watch(String uid) =>
      _col(uid).snapshots().map((s) => {for (final d in s.docs) d.id: SkillResult.fromDoc(d)});

  /// Keeps the best passing result; always records the attempt time.
  Future<void> save(String uid, String testId, int score, int total, bool passed) async {
    final ref = _col(uid).doc(testId);
    final old = await ref.get();
    final prev = old.exists ? SkillResult.fromDoc(old) : null;
    final keepOld = prev != null && prev.passed && (!passed || prev.score >= score);
    await ref.set({
      if (!keepOld) ...{
        'score': score,
        'total': total,
        'passed': passed,
        if (passed) 'passedAt': FieldValue.serverTimestamp(),
      },
      'attemptedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Short labels (e.g. "Tally Prime 80%") for passed tests, used on applications.
  Future<List<String>> badgeLabels(String uid, String Function(String id) name) async {
    final s = await _col(uid).get();
    return [
      for (final d in s.docs)
        if (d.data()['passed'] == true) '${name(d.id)} ${SkillResult.fromDoc(d).percent}%',
    ];
  }
}

final skillRepositoryProvider = Provider<SkillRepository>((ref) => SkillRepository(ref.watch(firestoreProvider)));

final myBadgesProvider = StreamProvider<Map<String, SkillResult>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(const {});
  return ref.watch(skillRepositoryProvider).watch(uid);
});
