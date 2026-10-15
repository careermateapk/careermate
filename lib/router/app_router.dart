import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers.dart';
import '../features/auth/ui/forgot_password_screen.dart';
import '../features/auth/ui/login_screen.dart';
import '../features/auth/ui/onboarding_screen.dart';
import '../features/auth/ui/register_screen.dart';
import '../features/auth/ui/splash_screen.dart';
import '../features/cv/ui/cv_upload_screen.dart';
import '../features/home/ui/coming_soon_screen.dart';
import '../features/home/ui/dashboard_screen.dart';
import '../features/home/ui/home_shell.dart';
import '../features/profile/ui/ats_report_screen.dart';
import '../features/profile/ui/categories_screen.dart';
import '../features/profile/ui/cv_review_screen.dart';
import '../features/settings/ui/settings_screen.dart';

class Routes {
  static const splash = '/splash';
  static const onboarding = '/welcome';
  static const login = '/login';
  static const register = '/register';
  static const forgot = '/forgot-password';
  static const home = '/home';
  static const jobs = '/jobs';
  static const cv = '/cv';
  static const tracker = '/tracker';
  static const prep = '/prep';
  static const settings = '/settings';
  static const cvReview = '/cv-review';
  static const cvCategories = '/cv-categories';
  static const atsReport = '/cv-report';

  static const _public = {onboarding, login, register, forgot};
}

/// Re-runs the router's redirect whenever sign-in or onboarding changes.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
    ref.listen(onboardingProvider, (_, _) => notifyListeners());
    _busy = ref.read(authFlowBusyProvider)..addListener(notifyListeners);
  }

  late final ValueNotifier<bool> _busy;

  @override
  void dispose() {
    _busy.removeListener(notifyListeners);
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final onboarded = ref.read(onboardingProvider);
      final loc = state.matchedLocation;
      if (ref.read(authFlowBusyProvider).value) return null;

      if (auth.isLoading && !auth.hasValue) return loc == Routes.splash ? null : Routes.splash;

      final signedIn = auth.value != null;
      if (!signedIn) {
        if (Routes._public.contains(loc)) return null;
        return onboarded ? Routes.login : Routes.onboarding;
      }
      if (loc == Routes.splash || Routes._public.contains(loc)) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.onboarding, builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: Routes.register, builder: (_, _) => const RegisterScreen()),
      GoRoute(path: Routes.forgot, builder: (_, _) => const ForgotPasswordScreen()),
      GoRoute(path: Routes.settings, builder: (_, _) => const SettingsScreen()),
      GoRoute(path: Routes.cvReview, builder: (_, _) => const CvReviewScreen()),
      GoRoute(path: Routes.cvCategories, builder: (_, _) => const CategoriesScreen()),
      GoRoute(path: Routes.atsReport, builder: (_, _) => const AtsReportScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: Routes.home, builder: (_, _) => const DashboardScreen())]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.jobs,
              builder: (_, _) => const ComingSoonScreen(
                title: 'Find jobs',
                icon: Icons.work_outline_rounded,
                message: 'Job search with match scores is the next build step.',
              ),
            ),
          ]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.cv, builder: (_, _) => const CvUploadScreen())]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.tracker,
              builder: (_, _) => const ComingSoonScreen(
                title: 'Applications',
                icon: Icons.view_kanban_outlined,
                message: 'Your application tracker is coming in Phase 1.',
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.prep,
              builder: (_, _) => const ComingSoonScreen(
                title: 'Interview prep',
                icon: Icons.chat_bubble_outline_rounded,
                message: 'Mock interviews arrive in Phase 2.',
              ),
            ),
          ]),
        ],
      ),
    ],
  );
});
