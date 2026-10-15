# CareerMate

AI job search & career copilot — Flutter app for Android.

## How the app is built
There is no local setup. Every change pushed to `main` is built on GitHub:

1. **Actions** tab → "Build Android app" runs (about 10 minutes).
2. When it finishes, the APK appears under **Releases** (right side of the repo page) as `CareerMate build N`.
3. Open that release on your phone → tap `app-release.apk` → install.

The build uses a fixed signing key in `ci/debug.keystore` so the SHA-1 stays the same for Google sign-in.
This key is for testing only. A separate upload key (kept in GitHub Secrets) is needed before publishing on Play Store.

- Package name: `in.careermate.careermate`
- Test signing SHA-1: `31:B9:00:06:86:F3:CB:BF:EC:9A:AB:60:C8:6F:D2:46:AE:81:22:76`
- Test signing SHA-256: `A4:13:3A:58:0F:33:F2:80:DE:37:82:D8:81:87:58:3D:6A:1B:BA:87:22:37:3C:E3:F1:31:7E:F5:85:6F:27:BB`

## What works in this build (v0.1)
- Email/password sign-up, login, password reset, email verification
- Google sign-in
- Onboarding, home dashboard, bottom navigation
- CV upload (PDF/DOCX ≤ 5 MB) with file checks; replace; delete
- Light/dark theme, logout, permanent account deletion
- Firestore and Storage security rules in `firebase/` (owner-only access)

## Structure
```
lib/
  config/app_config.dart     app name, feature flags
  firebase_options.dart      Firebase connection values
  theme/                     design tokens + light/dark theme
  router/app_router.dart     routes + sign-in redirects
  core/providers.dart        Firebase + settings providers (Riverpod)
  features/auth/             login, register, reset, onboarding, Google sign-in
  features/cv/               CV validation, upload, upload screen
  features/home/             app shell, dashboard
  features/settings/         settings, account deletion
firebase/                    firestore.rules, storage.rules
test/                        unit tests
.github/workflows/           automatic Android build
```
