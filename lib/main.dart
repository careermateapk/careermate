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
  // Draw something right away, then get ready in the background. If a step hangs or fails,
  // the screen says which one instead of staying on the logo forever.
  runApp(const BootApp());
}

class BootApp extends StatefulWidget {
  const BootApp({super.key});
  @override
  State<BootApp> createState() => _BootAppState();
}

class _BootAppState extends State<BootApp> {
  Widget? _app;
  String? _error;
  String _step = 'Starting';

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<T> _run<T>(String step, Future<T> Function() f, {int seconds = 20}) {
    if (mounted) setState(() => _step = step);
    return f().timeout(Duration(seconds: seconds), onTimeout: () => throw Exception('$step took too long'));
  }

  Future<void> _boot() async {
    try {
      try {
        await _run('Connecting', () => Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform), seconds: 30);
      } catch (e) {
        setState(() => _app = SetupErrorApp(message: e.toString()));
        return;
      }

      // On-phone notifications (no server). Permission is asked after a job seeker signs in.
      try {
        await _run('Notifications', () => NotificationService.instance.init(requestPermission: false), seconds: 8);
      } catch (_) {}

      // Needed before reading PDFs with the document API (CV text extraction).
      try {
        pdfrxFlutterInitialize();
      } catch (_) {}

      if (!kIsWeb) {
        try {
          await _run('Google sign-in', () => GoogleSignIn.instance.initialize(
                serverClientId: AppConfig.googleWebClientId.isEmpty ? null : AppConfig.googleWebClientId,
              ), seconds: 10);
        } catch (_) {}
      }

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
      final prefs = await _run('Settings', () => SharedPreferencesWithCache.create(
            cacheOptions: const SharedPreferencesWithCacheOptions(allowList: PrefKeys.all),
          ));

      if (!mounted) return;
      setState(() => _app = ProviderScope(
            overrides: [prefsProvider.overrideWithValue(prefs)],
            child: const CareerMateApp(),
          ));
    } catch (e) {
      if (mounted) setState(() => _error = '$_step: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_app != null) return _app!;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0B1328),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _error == null
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('CareerMate', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 20),
                    const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
                    const SizedBox(height: 12),
                    Text(_step, style: const TextStyle(color: Color(0xFF8A96B8), fontSize: 12)),
                  ])
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xFFFBBF24), size: 40),
                    const SizedBox(height: 12),
                    const Text('App could not start', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFC9D3EA), fontSize: 12.5)),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        setState(() => _error = null);
                        _boot();
                      },
                      child: const Text('Try again'),
                    ),
                  ]),
          ),
        ),
      ),
    );
  }
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
