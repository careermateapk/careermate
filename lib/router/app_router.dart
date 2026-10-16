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
import '../features/jobs/job_models.dart';
import '../features/jobs/ui/job_detail_screen.dart';
import '../features/jobs/ui/jobs_screen.dart';
import '../features/jobs/ui/sources_screen.dart';
import '../features/community/ui/share_job_screen.dart';
import '../features/resume/ui/resume_screens.dart';
import '../features/notifications/ui/notifications_screen.dart';
import '../features/home/ui/dashboard_screen.dart';
import '../features/home/ui/home_shell.dart';
import '../features/outreach/ui/email_compose_screen.dart';
import '../features/profile/ui/ats_report_screen.dart';
import '../features/recruiter/posted_job.dart';
import '../features/recruiter/ui/applicants_screen.dart';
import '../features/recruiter/ui/post_job_screen.dart';
import '../features/recruiter/ui/recruiter_home_screen.dart';
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
  static const jobDetail = '/job';
  static const emailRecruiter = '/email';
  static const recruiterHome = '/r';
  static const recruiterPost = '/r/post';
  static const recruiterApplicants = '/r/applicants';
  static const sources = '/sources';
  static const notifications = '/notifications';
  static const shareJob = '/share-job';
  static const cvMaker = '/cv-maker';
  static const cvMakerEdit = '/cv-maker/edit';
  static const cvMakerFinal = '/cv-maker/final';

  static const _public = {onboarding, login, register, forgot};
}

/// Re-runs the router's redirect whenever sign-in or onboarding changes.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
    ref.listen(onboardingProvider, (_, _) => notifyListeners());
    ref.listen(userDocProvider, (_, _) => notifyListeners());
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
      final userDoc = ref.read(userDocProvider);
      if (userDoc.isLoading && !userDoc.hasValue) return loc == Routes.splash ? null : Routes.splash;
      final isRecruiter = roleFrom(userDoc.value?['role']) == UserRole.recruiter;
      final home = isRecruiter ? Routes.recruiterHome : Routes.home;

      if (loc == Routes.splash || Routes._public.contains(loc)) return home;
      if (loc == Routes.settings) return null;
      final inRecruiterArea = loc == Routes.recruiterHome || loc.startsWith('${Routes.recruiterHome}/');
      if (isRecruiter && !inRecruiterArea) return Routes.recruiterHome;
      if (!isRecruiter && inRecruiterArea) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.onboarding, builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: Routes.register, builder: (_, _) => const RegisterScreen()),
      GoRoute(path: Routes.forgot, builder: (_, _) => const ForgotPasswordScreen()),
      GoRoute(path: Routes.settings, builder: (_, _) => const SettingsScreen()),
      GoRoute(path: Routes.sources, builder: (_, _) => const SourcesScreen()),
      GoRoute(path: Routes.notifications, builder: (_, _) => const NotificationsScreen()),
      GoRoute(path: Routes.cvMaker, builder: (_, _) => const ResumeGalleryScreen()),
      GoRoute(path: Routes.cvMakerEdit, builder: (_, _) => const ResumeEditorScreen()),
      GoRoute(path: Routes.cvMakerFinal, builder: (_, _) => const ResumeFinalScreen()),
      GoRoute(path: Routes.shareJob, builder: (_, s) => ShareJobScreen(text: s.extra as String? ?? '')),
      GoRoute(path: Routes.cvReview, builder: (_, _) => const CvReviewScreen()),
      GoRoute(path: Routes.cvCategories, builder: (_, _) => const CategoriesScreen()),
      GoRoute(path: Routes.atsReport, builder: (_, _) => const AtsReportScreen()),
      GoRoute(
        path: Routes.emailRecruiter,
        redirect: (_, state) => state.extra is EmailDraftArgs ? null : Routes.jobs,
        builder: (_, state) => EmailComposeScreen(args: state.extra! as EmailDraftArgs),
      ),
      GoRoute(path: Routes.recruiterHome, builder: (_, _) => const RecruiterHomeScreen()),
      GoRoute(
        path: Routes.recruiterPost,
        builder: (_, state) => PostJobScreen(existing: state.extra is PostedJob ? state.extra! as PostedJob : null),
      ),
      GoRoute(
        path: Routes.recruiterApplicants,
        redirect: (_, state) => state.extra is PostedJob ? null : Routes.recruiterHome,
        builder: (_, state) => ApplicantsScreen(job: state.extra! as PostedJob),
      ),
      GoRoute(
        path: Routes.jobDetail,
        redirect: (_, state) => state.extra is JobMatch ? null : Routes.jobs,
        builder: (_, state) => JobDetailScreen(match: state.extra! as JobMatch),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: Routes.home, builder: (_, _) => const DashboardScreen())]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.jobs, builder: (_, _) => const JobsScreen()),
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
