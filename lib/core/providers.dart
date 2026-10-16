import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shared preferences, created in main() and injected with an override.
final prefsProvider = Provider<SharedPreferencesWithCache>(
  (ref) => throw UnimplementedError('prefsProvider must be overridden in main()'),
);

/// True while a sign-in is being checked (e.g. Google sign-in on the login
/// page for an email with no account). The router waits instead of jumping.
final authFlowBusyProvider = Provider<ValueNotifier<bool>>((ref) {
  final n = ValueNotifier(false);
  ref.onDispose(n.dispose);
  return n;
});

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
final storageProvider = Provider<FirebaseStorage>((ref) => FirebaseStorage.instance);

/// The signed-in user, or null. Updates on sign-in, sign-out and profile reloads.
final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(firebaseAuthProvider).userChanges(),
);

class PrefKeys {
  static const onboardingDone = 'onboarding_done';
  static const themeMode = 'theme_mode';
  static const localCvPath = 'local_cv_path';
  static const localCvName = 'local_cv_name';
  static const all = {onboardingDone, themeMode, localCvPath, localCvName};
}

enum UserRole { seeker, recruiter }

UserRole roleFrom(Object? v) => v == 'recruiter' ? UserRole.recruiter : UserRole.seeker;

/// The signed-in user's account document (users/{uid}): role, company details.
final userDocProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(firestoreProvider).collection('users').doc(user.uid).snapshots().map((s) => s.data());
});

/// Email domains anyone can sign up for. Recruiters must use a company email.
const freeEmailDomains = {
  'gmail.com', 'googlemail.com', 'yahoo.com', 'yahoo.co.in', 'yahoo.in', 'ymail.com', 'rediffmail.com',
  'outlook.com', 'hotmail.com', 'live.com', 'msn.com', 'icloud.com', 'me.com', 'aol.com', 'proton.me',
  'protonmail.com', 'zoho.com', 'zohomail.in', 'gmx.com', 'mail.com', 'yandex.com', 'tutanota.com',
};

/// Personal emails allowed to act as recruiters, only for testing the app.
const testRecruiterEmails = {'ksuraj.th@gmail.com'};

bool isCompanyEmail(String email) {
  if (testRecruiterEmails.contains(email.trim().toLowerCase())) return true;
  final at = email.trim().toLowerCase().split('@');
  return at.length == 2 && at[1].contains('.') && !freeEmailDomains.contains(at[1]);
}

/// Whether the user has finished the intro screens on this device.
class OnboardingNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(prefsProvider).getBool(PrefKeys.onboardingDone) ?? false;

  Future<void> complete() async {
    await ref.read(prefsProvider).setBool(PrefKeys.onboardingDone, true);
    state = true;
  }
}

final onboardingProvider = NotifierProvider<OnboardingNotifier, bool>(OnboardingNotifier.new);

/// Light / dark / system theme, remembered on this device.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final saved = ref.watch(prefsProvider).getString(PrefKeys.themeMode);
    return ThemeMode.values.firstWhere((m) => m.name == saved, orElse: () => ThemeMode.system);
  }

  Future<void> set(ThemeMode mode) async {
    await ref.read(prefsProvider).setString(PrefKeys.themeMode, mode.name);
    state = mode;
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
