import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Fades and slides a child up after an optional delay.
/// Use increasing [index] values for a staggered entrance.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0, this.offset = 18});

  final Widget child;
  final int index;
  final double offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: AppMotion.medium + const Duration(milliseconds: 150));
  late final Animation<double> _t = CurvedAnimation(parent: _c, curve: AppMotion.curve);

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 70 * widget.index), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(offset: Offset(0, widget.offset * (1 - _t.value)), child: child),
      ),
    );
  }
}

/// Rounded white surface used for most content blocks.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color, this.onTap});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? Theme.of(context).colorScheme.surface;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

enum ChipTone { positive, info, warning, risk, neutral }

/// Small coloured label, e.g. "Official source confirmed".
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.tone = ChipTone.neutral});

  final String label;
  final ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      ChipTone.positive => (AppColors.greenTint, AppColors.greenText),
      ChipTone.info => (AppColors.blueTint, AppColors.blueDark),
      ChipTone.warning => (AppColors.amberTint, AppColors.amberText),
      ChipTone.risk => (AppColors.redTint, AppColors.redText),
      ChipTone.neutral => (AppColors.surface, AppColors.textBody),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

/// App logo: rounded blue square with a briefcase + tick.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'brand-logo',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.blue,
          borderRadius: BorderRadius.circular(size * 0.3),
          boxShadow: [BoxShadow(color: AppColors.blue.withValues(alpha: 0.45), blurRadius: size * 0.5, offset: Offset(0, size * 0.18))],
        ),
        child: Icon(Icons.work_history_rounded, color: Colors.white, size: size * 0.52),
      ),
    );
  }
}

/// Circular score that animates from 0 to [value] (0–100).
class ScoreRing extends StatelessWidget {
  const ScoreRing({super.key, required this.value, this.size = 110, this.color = AppColors.green, this.track, this.label});

  final int value;
  final double size;
  final Color color;
  final Color? track;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final onColor = Theme.of(context).colorScheme.onSurface;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value / 100),
      duration: const Duration(milliseconds: 1400),
      curve: AppMotion.curve,
      builder: (context, t, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(t, color, track ?? onColor.withValues(alpha: 0.1)),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${(t * 100).round()}', style: AppTheme.display(context, size: size * 0.28)),
              if (label != null)
                Text(label!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: onColor.withValues(alpha: 0.6))),
            ]),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.t, this.color, this.track);
  final double t;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.085;
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    canvas.drawArc(r, 0, math.pi * 2, false, Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke);
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * t, false, Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.t != t || old.color != color;
}

/// A filled button that shows a spinner while [loading].
class LoadingButton extends StatelessWidget {
  const LoadingButton({super.key, required this.label, required this.onPressed, this.loading = false, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      child: AnimatedSwitcher(
        duration: AppMotion.fast,
        child: loading
            ? const SizedBox(key: ValueKey('l'), width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white))
            : Row(key: const ValueKey('t'), mainAxisSize: MainAxisSize.min, children: [
                Text(label),
                if (icon != null) ...[const SizedBox(width: 8), Icon(icon, size: 18)],
              ]),
      ),
    );
  }
}

/// Shows a short message at the bottom of the screen.
void showMessage(BuildContext context, String text, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? AppColors.red : AppColors.navy,
    ));
}
