import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'core/providers.dart';
import 'features/notifications/notification_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    runApp(SetupErrorApp(message: e.toString()));
    return;
  }

  // On-phone notifications (no server). Permission is asked after a job seeker signs in.
  try {
    await NotificationService.instance.init(requestPermission: false);
  } catch (_) {}

  // Needed before reading PDFs with the document API (CV text extraction).
  pdfrxFlutterInitialize();

  if (!kIsWeb) {
    await GoogleSignIn.instance.initialize(
      serverClientId: AppConfig.googleWebClientId.isEmpty ? null : AppConfig.googleWebClientId,
    );
  }

  // Instead of a blank grey screen, show what went wrong (helps us fix it from a screenshot).
  ErrorWidget.builder = (details) => Material(
        color: const Color(0xFF0B1328),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFFBBF24), size: 40),
              const SizedBox(height: 12),
              const Text('Something went wrong on this screen',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('Go back and try again. If it happens again, send a screenshot of this message.',
                  style: TextStyle(color: Color(0xFFC9D3EA), fontSize: 13.5)),
              const SizedBox(height: 12),
              Text(details.exceptionAsString(),
                  maxLines: 6, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF8A96B8), fontSize: 11.5)),
            ]),
          ),
        ),
      );

  final prefs = await SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(allowList: PrefKeys.all),
  );

  runApp(ProviderScope(
    overrides: [prefsProvider.overrideWithValue(prefs)],
    child: const CareerMateApp(),
  ));
}

/// Shown instead of the app when Firebase is not set up yet.
class SetupErrorApp extends StatelessWidget {
  const SetupErrorApp({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.build_circle_outlined, size: 48, color: Color(0xFFD97706)),
              const SizedBox(height: 16),
              const Text('Firebase setup needed', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('Follow SETUP_GUIDE.md, step 6 (flutterfire configure), then run the app again.'),
              const SizedBox(height: 16),
              Text(message, style: const TextStyle(color: Colors.black54, fontSize: 12)),
            ]),
          ),
        ),
      ),
    );
  }
}
