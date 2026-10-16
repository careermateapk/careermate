import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../router/app_router.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';
import '../../auth/auth_repository.dart';
import '../posted_job.dart';

class RecruiterHomeScreen extends ConsumerWidget {
  const RecruiterHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final doc = ref.watch(userDocProvider).value ?? const {};
    final jobsAsync = ref.watch(myPostedJobsProvider);
    final jobs = jobsAsync.value ?? const <PostedJob>[];
    final company = (doc['company'] as String?) ?? '';
    final name = (user?.displayName ?? '').trim().split(' ').first;
    final verified = user?.emailVerified ?? false;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: () async {
          // Reload so a just-verified email unlocks posting (refreshes the sign-in token too).
          final u = FirebaseAuth.instance.currentUser;
          await u?.reload();
          await u?.getIdToken(true);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 16, 20, 70),
              decoration: const BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    FadeSlideIn(
                      child: Row(children: [
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                          child: Text(company.isEmpty ? 'C' : company.characters.first.toUpperCase(),
                              style: AppTheme.display(context, size: 18, color: AppColors.navy)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Recruiter${company.isEmpty ? '' : ' · $company'}',
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Color(0xFFA9B6D6), fontSize: 12.5, fontWeight: FontWeight.w600)),
                            Text('Hi, ${name.isEmpty ? 'there' : name}', style: AppTheme.display(context, size: 19, color: Colors.white)),
                          ]),
                        ),
                        IconButton(
                          tooltip: 'Settings',
                          onPressed: () => context.push(Routes.settings),
                          icon: const Icon(Icons.settings_outlined, color: Colors.white),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    FadeSlideIn(index: 1, child: _VerifyStrip(verified: verified)),
                  ]),
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -52),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      FadeSlideIn(index: 2, child: _Stats(jobs: jobs)),
                      const SizedBox(height: 12),
                      FadeSlideIn(
                        index: 3,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(58)),
                          onPressed: verified
                              ? () => context.push(Routes.recruiterPost)
                              : () => showMessage(context, 'Verify your work email first. Tap "Resend" above, then pull down to refresh.', error: true),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Post a new job'),
                        ),
                      ),
                      const SizedBox(height: 18),
                      FadeSlideIn(index: 4, child: Text('Your jobs', style: AppTheme.display(context, size: 16))),
                      const SizedBox(height: 10),
                      if (jobsAsync.isLoading && jobs.isEmpty)
                        const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
                      else if (jobsAsync.hasError)
                        const AppCard(child: Text('Could not load your jobs. Check that the latest database rules are published, then pull down to refresh.'))
                      else if (jobs.isEmpty)
                        const AppCard(
                          child: Column(children: [
                            Icon(Icons.work_outline_rounded, size: 40, color: AppColors.blue),
                            SizedBox(height: 8),
                            Text('No jobs yet', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            SizedBox(height: 4),
                            Text('Post your first job. Matching job seekers will see it at the top of their list.',
                                textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
                          ]),
                        )
                      else
                        for (var i = 0; i < jobs.length; i++) ...[
                          FadeSlideIn(index: 5 + (i < 6 ? i : 6), child: _JobRow(job: jobs[i])),
                          const SizedBox(height: 10),
                        ],
                    ]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerifyStrip extends ConsumerWidget {
  const _VerifyStrip({required this.verified});
  final bool verified;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (verified) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFF4ADE80).withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
        child: const Row(children: [
          Icon(Icons.verified_user_rounded, color: Color(0xFF4ADE80), size: 18),
          SizedBox(width: 8),
          Text('Work email verified', style: TextStyle(color: Color(0xFFBBF7D0), fontWeight: FontWeight.w700, fontSize: 12.5)),
        ]),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
      decoration: BoxDecoration(color: const Color(0xFFFBBF24).withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        const Icon(Icons.mark_email_unread_outlined, color: Color(0xFFFBBF24), size: 18),
        const SizedBox(width: 8),
        const Expanded(
          child: Text('Verify your work email to post jobs. Then pull down to refresh.',
              style: TextStyle(color: Color(0xFFFDE68A), fontWeight: FontWeight.w700, fontSize: 12.5)),
        ),
        TextButton(
          onPressed: () async {
            try {
              await ref.read(authRepositoryProvider).resendVerificationEmail();
              if (context.mounted) showMessage(context, 'Verification email sent. Check your inbox and spam folder.');
            } on AuthFailure catch (e) {
              if (context.mounted) showMessage(context, e.message, error: true);
            }
          },
          child: const Text('Resend', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}

class _Stats extends ConsumerWidget {
  const _Stats({required this.jobs});
  final List<PostedJob> jobs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var applicants = 0, fresh = 0, shortlisted = 0;
    for (final j in jobs) {
      final apps = ref.watch(applicationsProvider(j.id)).value ?? const <Application>[];
      applicants += apps.length;
      fresh += apps.where((a) => a.status == 'new').length;
      shortlisted += apps.where((a) => a.status == 'shortlisted' || a.status == 'interview').length;
    }
    Widget tile(int n, String label, Color c) => Expanded(
          child: AppCard(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: n.toDouble()),
                duration: const Duration(milliseconds: 900),
                curve: AppMotion.curve,
                builder: (context, v, _) => Text('${v.round()}', style: AppTheme.display(context, size: 22, color: c)),
              ),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, fontWeight: FontWeight.w700)),
            ]),
          ),
        );
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Row(children: [
      tile(jobs.where((j) => j.isLive).length, 'Live jobs', onSurface),
      const SizedBox(width: 8),
      tile(applicants, 'Applicants', onSurface),
      const SizedBox(width: 8),
      tile(fresh, 'New', AppColors.blue),
      const SizedBox(width: 8),
      tile(shortlisted, 'Shortlisted', AppColors.green),
    ]);
  }
}

class _JobRow extends ConsumerWidget {
  const _JobRow({required this.job});
  final PostedJob job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apps = ref.watch(applicationsProvider(job.id)).value ?? const <Application>[];
    final fresh = apps.where((a) => a.status == 'new').length;
    final short = apps.where((a) => a.status == 'shortlisted' || a.status == 'interview').length;
    final (label, tone) = switch (job.status) {
      'live' => ('Live', ChipTone.positive),
      'closed' => ('Closed', ChipTone.neutral),
      _ => ('Draft', ChipTone.warning),
    };
    return AppCard(
      onTap: () => context.push(Routes.recruiterApplicants, extra: job),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(job.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 2),
              Text('${job.workMode == 'remote' ? 'Remote' : job.city} · ${job.workModeLabel} · ${job.experienceLabel}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
            ]),
          ),
          StatusChip(label, tone: tone),
        ]),
        if (apps.isNotEmpty) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Row(children: [
                Expanded(flex: fresh == 0 ? 1 : fresh * 10, child: Container(color: fresh == 0 ? AppColors.line : AppColors.blue)),
                const SizedBox(width: 3),
                Expanded(flex: short == 0 ? 1 : short * 10, child: Container(color: short == 0 ? AppColors.line : AppColors.green)),
                const SizedBox(width: 3),
                Expanded(flex: (apps.length - fresh - short).clamp(1, 1000).toInt() * 10, child: Container(color: AppColors.line)),
              ]),
            ),
          ),
        ],
        const SizedBox(height: 10),
        Row(children: [
          Text.rich(TextSpan(children: [
            TextSpan(text: '${apps.length}', style: const TextStyle(fontWeight: FontWeight.w800)),
            const TextSpan(text: ' applicants   '),
            TextSpan(text: '$fresh', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.blue)),
            const TextSpan(text: ' new   '),
            TextSpan(text: '$short', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.green)),
            const TextSpan(text: ' shortlisted'),
          ]), style: const TextStyle(fontSize: 12.5, color: AppColors.textBody)),
          const Spacer(),
          const Text('View →', style: TextStyle(color: AppColors.blue, fontWeight: FontWeight.w800, fontSize: 12.5)),
        ]),
      ]),
    );
  }
}
