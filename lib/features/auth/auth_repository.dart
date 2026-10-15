import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show ValueNotifier, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/providers.dart';

/// A sign-in problem with a message that is safe to show to the user.
class AuthFailure implements Exception {
  AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Thrown when the user closes the Google account picker. Not an error.
class AuthCancelled implements Exception {
  AuthCancelled([this.detail = '']);
  final String detail;
}

/// Email/password and Google sign-in only (both free on Firebase).
class AuthRepository {
  AuthRepository(this._auth, this._db, this._busy);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final ValueNotifier<bool> _busy;

  User? get currentUser => _auth.currentUser;

  Future<void> signInWithEmail(String email, String password) async {
    await _guard(() => _auth.signInWithEmailAndPassword(email: email.trim(), password: password));
  }

  Future<void> register({required String name, required String email, required String password}) async {
    await _guard(() async {
      final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
      final user = cred.user!;
      await user.updateDisplayName(name.trim());
      await _saveProfile(user, provider: 'password', name: name.trim());
      // Verification mail is free; the app still works before verifying.
      await user.sendEmailVerification();
      await user.reload();
    });
  }

  Future<void> sendPasswordReset(String email) async {
    await _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));
  }

  Future<void> resendVerificationEmail() async {
    await _guard(() async => _auth.currentUser?.sendEmailVerification());
  }

  /// [allowNewAccount] is false on the login page: a Google email that has
  /// no CareerMate account yet is not signed up there.
  Future<void> signInWithGoogle({bool allowNewAccount = true}) async {
    _busy.value = true;
    try {
      await _signInWithGoogle(allowNewAccount);
    } finally {
      _busy.value = false;
    }
  }

  Future<void> _signInWithGoogle(bool allowNewAccount) async {
    await _guard(() async {
      UserCredential cred;
      if (kIsWeb) {
        cred = await _auth.signInWithPopup(GoogleAuthProvider());
      } else {
        final GoogleSignInAccount account;
        try {
          account = await GoogleSignIn.instance.authenticate();
        } on GoogleSignInException catch (e) {
          final detail = e.description ?? '';
          if (e.code == GoogleSignInExceptionCode.canceled) throw AuthCancelled(detail);
          throw AuthFailure('Google sign-in failed (${e.code.name})${detail.isEmpty ? '' : ': $detail'}');
        }
        final idToken = account.authentication.idToken;
        if (idToken == null) throw AuthFailure('Google did not return a sign-in token. Please try again.');
        cred = await _auth.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
      }
      final user = cred.user!;
      final isNew = cred.additionalUserInfo?.isNewUser ?? false;
      if (isNew && !allowNewAccount) {
        // Undo the account Firebase just created, then ask the user to sign up.
        try {
          await user.delete();
        } catch (_) {}
        await signOut();
        throw AuthFailure('No account found for ${user.email ?? 'this Google account'}. Please create an account first.');
      }
      if (isNew) {
        await _saveProfile(user, provider: 'google', name: user.displayName ?? '');
      }
    });
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Not signed in with Google — nothing to do.
      }
    }
    await _auth.signOut();
  }

  Future<void> _saveProfile(User user, {required String provider, required String name}) {
    return _db.collection('users').doc(user.uid).set({
      'displayName': name,
      'email': user.email,
      'authProvider': provider,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(messageFor(e.code));
    }
  }

  /// Turns Firebase error codes into plain messages.
  static String messageFor(String code) => switch (code) {
        'invalid-credential' || 'wrong-password' || 'user-not-found' => 'Email or password is incorrect.',
        'invalid-email' => 'Please enter a valid email address.',
        'email-already-in-use' => 'An account already exists with this email. Try logging in.',
        'weak-password' => 'Password is too weak. Use at least 8 characters.',
        'user-disabled' => 'This account has been disabled.',
        'too-many-requests' => 'Too many attempts. Please wait a few minutes and try again.',
        'network-request-failed' => 'No internet connection. Please check your network.',
        'requires-recent-login' => 'For your security, please log out and log in again, then retry.',
        'popup-closed-by-user' || 'cancelled-popup-request' => 'Sign-in window was closed.',
        'account-exists-with-different-credential' =>
          'This email is already registered with a different sign-in method.',
        'operation-not-allowed' => 'This sign-in method is not enabled in Firebase yet (guide step 5).',
        _ => 'Something went wrong ($code). Please try again.',
      };
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(firebaseAuthProvider), ref.watch(firestoreProvider), ref.watch(authFlowBusyProvider)),
);
