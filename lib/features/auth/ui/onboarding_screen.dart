import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_config.dart';
import '../../../core/providers.dart';
import '../../../router/app_router.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';

class _Page {
  const _Page(this.title, this.body, this.icon, this.chip, this.tone);
  final String title;
  final String body;
  final IconData icon;
  final String chip;
  final ChipTone tone;
}

const _pages = [
  _Page(AppConfig.tagline,
      'Upload your CV and get a clear readiness score with fixes you can act on — no invented skills, ever.',
      Icons.description_outlined, 'CV readiness · explained', ChipTone.positive),
  _Page('Genuine jobs, last 30 days',
      'See jobs that match your skills and location, and why you match. Every listing shows its source.',
      Icons.travel_explore_rounded, 'Official source checks', ChipTone.info),
  _Page('Track every application',
      'Follow-ups, interviews and offers in one place, so nothing slips.',
      Icons.view_kanban_outlined, 'Reminders that help', ChipTone.warning),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> with SingleTickerProviderStateMixin {
  final _pager = PageController();
  late final AnimationController _orbit = AnimationController(vsync: this, duration: const Duration(seconds: 24))..repeat();
  int _page = 0;

  @override
  void dispose() {
    _pager.dispose();
    _orbit.dispose();
    super.dispose();
  }

  Future<void> _finish(String route) async {
    await ref.read(onboardingProvider.notifier).complete();
    if (mounted) context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final p = _pages[_page];
    final last = _page == _pages.length - 1;
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _finish(Routes.login),
              child: const Text('Skip', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
            ),
          ),
          Expanded(
            child: Center(
              child: AnimatedBuilder(
                animation: _orbit,
                builder: (context, _) => _OrbitHero(t: _orbit.value, page: p),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
            ),
            child: SafeArea(
              top: false,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: List.generate(_pages.length, (i) {
                  return AnimatedContainer(
                    duration: AppMotion.medium,
                    curve: AppMotion.curve,
                    margin: const EdgeInsets.only(right: 6),
                    width: i == _page ? 28 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page ? AppColors.blue : AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                })),
                const SizedBox(height: 18),
                SizedBox(
                  height: 150,
                  child: PageView.builder(
                    controller: _pager,
                    itemCount: _pages.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (context, i) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_pages[i].title, style: AppTheme.display(context, size: 28)),
                      const SizedBox(height: 10),
                      Text(_pages[i].body,
                          style: TextStyle(fontSize: 15, height: 1.5, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72))),
                    ]),
                  ),
                ),
                const SizedBox(height: 14),
                LoadingButton(
                  label: last ? 'Get started' : 'Next',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () => last
                      ? _finish(Routes.register)
                      : _pager.nextPage(duration: AppMotion.medium, curve: AppMotion.curve),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => _finish(Routes.login),
                  child: const Text('I already have an account'),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Logo with rings and orbiting dots, plus a floating chip for the current page.
class _OrbitHero extends StatelessWidget {
  const _OrbitHero({required this.t, required this.page});
  final double t;
  final _Page page;

  @override
  Widget build(BuildContext context) {
    final a = t * 2 * math.pi;
    Widget dot(double radius, double angle, double size, Color c) => Transform.translate(
          offset: Offset(math.cos(angle) * radius, math.sin(angle) * radius),
          child: Container(width: size, height: size, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        );
    Widget ring(double d) => Container(
          width: d,
          height: d,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.14))),
        );

    return SizedBox(
      width: 300,
      height: 300,
      child: Stack(alignment: Alignment.center, children: [
        ring(280),
        ring(200),
        dot(140, a, 12, const Color(0xFF4ADE80)),
        dot(140, a + 2.4, 9, const Color(0xFFFBBF24)),
        dot(100, -a * 1.6, 10, const Color(0xFF8FB0FF)),
        const BrandLogo(size: 104),
        Positioned(
          bottom: 18,
          child: AnimatedSwitcher(
            duration: AppMotion.medium,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(anim), child: child),
            ),
            child: Container(
              key: ValueKey(page.chip),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 10))],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(page.icon, size: 18, color: AppColors.blue),
                const SizedBox(width: 8),
                Text(page.chip, style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w800, fontSize: 13)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
