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
import '../../cv/cv_repository.dart';
import '../../notifications/notification_service.dart';
import '../../profile/profile_repository.dart';
import '../../profile/taxonomy.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final cv = ref.watch(currentCvProvider);
    final hasCv = cv.value != null;
    final profile = ref.watch(profileProvider).value;
    final name = (user?.displayName?.trim().isNotEmpty ?? false) ? user!.displayName!.trim().split(' ').first : 'there';
    final needsVerify = user != null && !user.emailVerified && user.providerData.any((p) => p.providerId == 'password');

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: RefreshIndicator(
              onRefresh: () => FirebaseAuth.instance.currentUser?.reload() ?? Future.value(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                children: [
                  FadeSlideIn(child: _Header(name: name, photo: user?.photoURL)),
                  const SizedBox(height: 16),
                  if (needsVerify) ...[
                    const FadeSlideIn(index: 1, child: _VerifyBanner()),
                    const SizedBox(height: 14),
                  ],
                  FadeSlideIn(
                    index: 2,
                    child: AnimatedSwitcher(
                      duration: AppMotion.medium,
                      child: cv.isLoading
                          ? const _LoadingCard(key: ValueKey('l'))
                          : profile != null && profile.atsScore != null
                              ? _ProfileCard(key: const ValueKey('pr'), profile: profile)
                              : hasCv
                              ? _CvReadyCard(key: const ValueKey('cv'), record: cv.value!)
                              : const _UploadPromptCard(key: ValueKey('up')),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeSlideIn(index: 3, child: const _Tools()),
                  const SizedBox(height: 20),
                  FadeSlideIn(index: 3, child: Text('Your next steps', style: AppTheme.display(context, size: 17))),
                  const SizedBox(height: 10),
                  FadeSlideIn(
                    index: 4,
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Column(children: [
                        const _Step(done: true, title: 'Create your account', subtitle: 'Done'),
                        _Step(done: hasCv, title: 'Upload your CV', subtitle: hasCv ? 'Done' : 'PDF or DOCX, up to 5 MB', onTap: () => context.go(Routes.cv)),
                        _Step(
                          done: profile != null,
                          title: 'Confirm your details & job categories',
                          subtitle: profile != null ? 'Done · tap to edit' : 'Takes a minute after uploading',
                          onTap: hasCv ? () => context.push(Routes.cvReview) : null,
                        ),
                        _Step(
                          done: false,
                          title: 'See jobs that match you',
                          subtitle: profile != null ? 'From company career sites, last 30 days' : 'After you confirm your categories',
                          onTap: profile != null ? () => context.go(Routes.jobs) : null,
                          last: true,
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tools extends StatelessWidget {
  const _Tools();

  @override
  Widget build(BuildContext context) {
    final tools = [
      ('🚀', '30-day plan', 'Daily tasks & streak', Routes.plan, const [Color(0xFF1E3A8A), Color(0xFF312E81)]),
      ('🛡️', 'Skill tests', 'Earn badges', Routes.skills, const [Color(0xFF14532D), Color(0xFF166534)]),
      ('⚖️', 'Compare offers', 'In-hand, bond, notice', Routes.offers, const [Color(0xFF4C1D95), Color(0xFF6D28D9)]),
      ('📄', 'CV maker', '40 templates', Routes.cvMaker, const [Color(0xFF0E7490), Color(0xFF0F766E)]),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.75,
      children: [
        for (final t in tools)
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => context.push(t.$4),
            child: Ink(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(gradient: LinearGradient(colors: t.$5), borderRadius: BorderRadius.circular(18)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(t.$1, style: const TextStyle(fontSize: 22)),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.$2, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14.5)),
                  Text(t.$3, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFDCE4F7), fontSize: 11.5)),
                ]),
              ]),
            ),
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name, this.photo});
  final String name;
  final String? photo;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greet = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
    return Row(children: [
      CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.navy,
        foregroundImage: photo != null ? NetworkImage(photo!) : null,
        child: Text(name.characters.first.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(greet, style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600, fontSize: 13)),
          Text(name, style: AppTheme.display(context, size: 19)),
        ]),
      ),
      ValueListenableBuilder<int>(
        valueListenable: NotificationService.instance.changes,
        builder: (context, _, _) => FutureBuilder<int>(
          future: NotificationService.instance.unreadCount(),
          builder: (context, snap) => IconButton.filledTonal(
            tooltip: 'Notifications',
            onPressed: () => context.push(Routes.notifications),
            icon: Badge(
              isLabelVisible: (snap.data ?? 0) > 0,
              label: Text('${snap.data ?? 0}'),
              child: const Icon(Icons.notifications_none_rounded),
            ),
          ),
        ),
      ),
      const SizedBox(width: 6),
      IconButton.filledTonal(
        tooltip: 'Settings',
        onPressed: () => context.push(Routes.settings),
        icon: const Icon(Icons.settings_outlined),
      ),
    ]);
  }
}

class _VerifyBanner extends ConsumerWidget {
  const _VerifyBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.amberTint, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(children: [
        const Icon(Icons.mark_email_unread_outlined, color: AppColors.amberText),
        const SizedBox(width: 10),
        const Expanded(
          child: Text('Please verify your email. Pull down to refresh after you click the link.',
              style: TextStyle(color: AppColors.amberText, fontWeight: FontWeight.w700, fontSize: 13)),
        ),
        TextButton(
          onPressed: () async {
            try {
              await ref.read(authRepositoryProvider).resendVerificationEmail();
              if (context.mounted) showMessage(context, 'Verification email sent again.');
            } on AuthFailure catch (e) {
              if (context.mounted) showMessage(context, e.message, error: true);
            }
          },
          child: const Text('Resend'),
        ),
      ]),
    );
  }
}

class _UploadPromptCard extends StatelessWidget {
  const _UploadPromptCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [BoxShadow(color: AppColors.navy.withValues(alpha: 0.25), blurRadius: 36, offset: const Offset(0, 18))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _PulsingIcon(),
        const SizedBox(height: 16),
        Text('Start with your CV', style: AppTheme.display(context, size: 21, color: Colors.white)),
        const SizedBox(height: 6),
        const Text('Upload it once. We read it to find jobs that match your skills, experience and location.',
            style: TextStyle(color: Color(0xFFC9D3EA), height: 1.5)),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => context.go(Routes.cv),
          icon: const Icon(Icons.upload_file_rounded),
          label: const Text('Upload CV'),
        ),
      ]),
    );
  }
}

class _PulsingIcon extends StatefulWidget {
  const _PulsingIcon();
  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(alignment: Alignment.center, children: [
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Transform.scale(
            scale: 1 + _c.value * 0.6,
            child: Opacity(
              opacity: (1 - _c.value) * 0.5,
              child: Container(decoration: BoxDecoration(color: AppColors.blue, borderRadius: BorderRadius.circular(18))),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(color: AppColors.blue, borderRadius: BorderRadius.circular(18)),
          child: const Center(child: Icon(Icons.description_outlined, color: Colors.white, size: 28)),
        ),
      ]),
    );
  }
}

class _CvReadyCard extends StatelessWidget {
  const _CvReadyCard({super.key, required this.record});
  final CvRecord record;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.go(Routes.cv),
      padding: const EdgeInsets.all(18),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: AppColors.greenTint, borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.task_alt_rounded, color: AppColors.greenText, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('CV uploaded', style: AppTheme.display(context, size: 16)),
            const SizedBox(height: 2),
            Text(record.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 8),
            const StatusChip('Analysis arrives in the next build step', tone: ChipTone.info),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
      ]),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({super.key});
  @override
  Widget build(BuildContext context) =>
      const AppCard(child: SizedBox(height: 120, child: Center(child: CircularProgressIndicator())));
}

class _Step extends StatelessWidget {
  const _Step({required this.done, required this.title, required this.subtitle, this.onTap, this.soon = false, this.last = false});
  final bool done;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool soon;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: AppColors.line))),
        child: Row(children: [
          AnimatedContainer(
            duration: AppMotion.medium,
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? AppColors.green : Colors.transparent,
              border: Border.all(color: done ? AppColors.green : AppColors.border, width: 2),
            ),
            child: done ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: soon ? AppColors.textMuted : null)),
              Text(subtitle, style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
            ]),
          ),
          if (onTap != null && !done) const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ]),
      ),
    );
  }
}


class _ProfileCard extends StatelessWidget {
  const _ProfileCard({super.key, required this.profile});
  final CareerProfile profile;

  @override
  Widget build(BuildContext context) {
    final main = profile.categoryId == null ? null : categoryById(profile.categoryId!);
    final subs = profile.subCategoryIds.map(subCategoryById).whereType<SubCategory>().take(3).toList();
    final score = profile.atsScore ?? 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [BoxShadow(color: AppColors.navy.withValues(alpha: 0.25), blurRadius: 36, offset: const Offset(0, 18))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ScoreRing(
            value: score,
            size: 108,
            color: score >= 75 ? const Color(0xFF4ADE80) : score >= 50 ? const Color(0xFF8FB0FF) : const Color(0xFFFBBF24),
            track: Colors.white.withValues(alpha: 0.12),
            label: 'out of 100',
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('CV READINESS (ESTIMATE)', style: TextStyle(color: Color(0xFFA9B6D6), fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: .5)),
              const SizedBox(height: 6),
              Text(main?.name ?? 'Categories not set', style: AppTheme.display(context, size: 17, color: Colors.white)),
              const SizedBox(height: 10),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 14)),
                onPressed: () => context.push(Routes.atsReport),
                child: const Text('View report'),
              ),
            ]),
          ),
        ]),
        if (subs.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in subs)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Text(s.name, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
          ]),
        ],
      ]),
    );
  }
}
