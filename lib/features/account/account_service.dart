import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../auth/auth_repository.dart';
import '../cv/cv_repository.dart';
import '../cv/local_cv.dart';
import '../recruiter/posted_job.dart';

/// Permanent account deletion: CV files, database records, then the login.
class AccountService {
  AccountService(this._auth, this._db, this._cv, this._authRepo, this._recruiter, this._localCv);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final CvRepository _cv;
  final AuthRepository _authRepo;
  final RecruiterRepository _recruiter;
  final LocalCv _localCv;

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    // Firebase only allows deleting a login shortly after signing in.
    // Check first, so we never delete data and then fail on the login.
    final lastSignIn = user.metadata.lastSignInTime;
    if (lastSignIn == null || DateTime.now().difference(lastSignIn) > const Duration(minutes: 4)) {
      throw AuthFailure('For your security, please log out, log in again, and then delete your account.');
    }
    try {
      await _cv.deleteAll(user.uid);
      await _recruiter.deleteAllFor(user.uid);
      final profile = _db.collection('users').doc(user.uid).collection('profile');
      for (final d in (await profile.get()).docs) {
        await d.reference.delete();
      }
      for (final sub in ['applications', 'outreach']) {
        for (final d in (await _db.collection('users').doc(user.uid).collection(sub).get()).docs) {
          await d.reference.delete();
        }
      }
      try {
        await _localCv.delete();
      } catch (_) {}
      await _db.collection('users').doc(user.uid).delete();
      await user.delete();
      await _authRepo.signOut();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(AuthRepository.messageFor(e.code));
    }
  }
}

final accountServiceProvider = Provider<AccountService>((ref) => AccountService(
      ref.watch(firebaseAuthProvider),
      ref.watch(firestoreProvider),
      ref.watch(cvRepositoryProvider),
      ref.watch(authRepositoryProvider),
      ref.watch(recruiterRepositoryProvider),
      ref.watch(localCvProvider),
    ));
