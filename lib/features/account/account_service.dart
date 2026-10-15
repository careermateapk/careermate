import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../auth/auth_repository.dart';
import '../cv/cv_repository.dart';

/// Permanent account deletion: CV files, database records, then the login.
class AccountService {
  AccountService(this._auth, this._db, this._cv, this._authRepo);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final CvRepository _cv;
  final AuthRepository _authRepo;

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
    ));
