/// Central, changeable settings for the app.
///
/// Branding can be changed here (or at build time with --dart-define)
/// without touching the rest of the code.
class AppConfig {
  AppConfig._();

  /// App name shown everywhere. Override with:
  /// flutter run --dart-define=APP_NAME=MyName
  static const appName = String.fromEnvironment('APP_NAME', defaultValue: 'CareerMate');

  static const tagline = 'Your AI career copilot';

  /// Optional: the "Web client ID" from Firebase → Authentication →
  /// Google → Web SDK configuration. Only needed if Google sign-in on
  /// Android says "serverClientId must be provided".
  static const googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  /// Upload the original CV file to Cloud Storage.
  /// Cloud Storage needs the Firebase Blaze plan (a card must be linked,
  /// but small usage stays inside the no-cost limit).
  /// Set to false to keep the original file only on the phone and save
  /// just the file details in the database.
  static const uploadCvToCloud = bool.fromEnvironment('UPLOAD_CV_TO_CLOUD', defaultValue: true);

  /// Largest CV file accepted, in bytes (5 MB).
  static const maxCvBytes = 5 * 1024 * 1024;

  static const allowedCvExtensions = ['pdf', 'docx'];
}
