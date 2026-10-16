import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'config/app_config.dart';
import 'core/providers.dart';
import 'features/notifications/notification_service.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class CareerMateApp extends ConsumerStatefulWidget {
  const CareerMateApp({super.key});

  @override
  ConsumerState<CareerMateApp> createState() => _CareerMateAppState();
}

class _CareerMateAppState extends ConsumerState<CareerMateApp> with WidgetsBindingObserver {
  final _notif = NotificationService.instance;
  String? _startedFor;
  String? _sharedText;
  StreamSubscription<List<SharedMediaFile>>? _shareSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notif.pendingRoute.addListener(_openPending);
    try {
      _shareSub = ReceiveSharingIntent.instance.getMediaStream().listen(_onShared, onError: (_) {});
      ReceiveSharingIntent.instance.getInitialMedia().then((v) {
        _onShared(v);
        ReceiveSharingIntent.instance.reset();
      }).catchError((_) {});
    } catch (_) {}
  }

  /// Text shared from another app (e.g. a LinkedIn job post).
  void _onShared(List<SharedMediaFile> files) {
    final parts = [
      for (final f in files)
        if (f.type == SharedMediaType.text || f.type == SharedMediaType.url) ...[f.path, f.message ?? ''],
    ].where((s) => s.trim().isNotEmpty).toSet();
    if (parts.isEmpty) return;
    _sharedText = parts.join('\n');
    _openShared();
  }

  void _openShared() {
    final text = _sharedText;
    if (text == null || _startedFor == null) return;
    _sharedText = null;
    ref.read(routerProvider).push('/share-job', extra: text);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notif.pendingRoute.removeListener(_openPending);
    _shareSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _startedFor != null) {
      _notif.checkNow().catchError((_) {});
    }
  }

  void _openPending() {
    final route = _notif.pendingRoute.value;
    if (route == null || _startedFor == null) return;
    _notif.pendingRoute.value = null;
    final router = ref.read(routerProvider);
    route == '/jobs' ? router.go(route) : router.push(route);
  }

  /// Starts notifications once a job seeker is signed in.
  Future<void> _start(String uid) async {
    if (_startedFor == uid) return;
    _startedFor = uid;
    try {
      await _notif.init();
      await _notif.startBackgroundChecks();
      await _notif.checkNow();
    } catch (_) {}
    _openPending();
    _openShared();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(userDocProvider, (_, next) {
      final uid = ref.read(authStateProvider).value?.uid;
      final doc = next.value;
      if (uid == null || doc == null) {
        _startedFor = null;
        return;
      }
      if (roleFrom(doc['role']) == UserRole.seeker) _start(uid);
    });
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
