import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../profile/cv_parser.dart';
import '../../profile/profile_repository.dart';

/// Full-screen animated "scan" shown after a CV is read. Everything it shows
/// (skills, experience, education, city) comes from the CV that was just read.
class CvScanScreen extends StatefulWidget {
  const CvScanScreen({super.key, required this.profile, required this.fileName});
  final CareerProfile profile;
  final String fileName;

  static Future<void> show(BuildContext context, {required CareerProfile profile, required String fileName}) {
    return Navigator.of(context, rootNavigator: true).push(PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 450),
      reverseTransitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, _, _) => CvScanScreen(profile: profile, fileName: fileName),
      transitionsBuilder: (_, a, _, child) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween(begin: 1.06, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: child),
      ),
    ));
  }

  @override
  State<CvScanScreen> createState() => _CvScanScreenState();
}

class _CvScanScreenState extends State<CvScanScreen> with TickerProviderStateMixin {
  static const _total = Duration(milliseconds: 5600);
  late final AnimationController _time = AnimationController(vsync: this, duration: _total)..forward();
  late final AnimationController _loop = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
  late final List<String> _chips = _buildChips();

  static const _steps = [
    'Reading text',
    'Finding contact details',
    'Spotting your skills',
    'Measuring experience',
    'Matching job categories',
  ];

  List<String> _buildChips() {
    final p = widget.profile;
    final out = <String>[];
    final skills = p.skills.take(3).map(CvParser.prettySkill).toList();
    if (skills.length >= 2) {
      out.add('${skills[0]} · ${skills[1]}');
      if (skills.length > 2) out.add(skills[2]);
    } else {
      out.addAll(skills);
    }
    if (p.experienceYears >= 1) {
      final y = p.experienceYears % 1 == 0 ? p.experienceYears.toInt().toString() : p.experienceYears.toStringAsFixed(1);
      out.add('$y yrs exp');
    } else {
      out.add('Fresher');
    }
    if (p.education.isNotEmpty) out.add(p.education.first);
    if (p.location.trim().isNotEmpty) out.add(p.location.split(',').first.trim());
    if (p.titles.isNotEmpty) out.add(p.titles.first);
    return out.take(6).toList();
  }

  @override
  void initState() {
    super.initState();
    _time.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) Navigator.of(context).pop();
        });
      }
    });
  }

  @override
  void dispose() {
    _time.dispose();
    _loop.dispose();
    super.dispose();
  }

  // 0..1 progress of a window inside the timeline.
  double _win(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050C22),
      body: AnimatedBuilder(
        animation: Listenable.merge([_time, _loop]),
        builder: (context, _) {
          final t = _time.value;
          final pct = (Curves.easeInOutCubic.transform(_win(t, 0.05, 0.92)) * 100).round();
          final stepNow = (_win(t, 0.05, 0.95) * _steps.length).floor().clamp(0, _steps.length);
          return Stack(children: [
            Positioned.fill(child: CustomPaint(painter: _BackdropPainter(_loop.value, t))),
            SafeArea(
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFF22E39A),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: const Color(0xFF22E39A).withValues(alpha: 0.4 + 0.6 * _pulse()), blurRadius: 10)],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('AI SCAN IN PROGRESS',
                        style: TextStyle(color: Color(0xFF9FB4E8), fontWeight: FontWeight.w800, letterSpacing: 1.6, fontSize: 11.5)),
                    const Spacer(),
                    Flexible(
                      child: Text(widget.fileName,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF6E83B8), fontSize: 12)),
                    ),
                  ]),
                ),
                Expanded(
                  child: LayoutBuilder(builder: (context, c) {
                    final center = Offset(c.maxWidth / 2, c.maxHeight / 2);
                    return Stack(clipBehavior: Clip.none, children: [
                      Positioned.fill(child: CustomPaint(painter: _OrbitPainter(_loop.value, t, center))),
                      Positioned(
                        left: center.dx - 95,
                        top: center.dy - 125,
                        child: _CvCard(scan: _loop.value, t: t),
                      ),
                      for (var i = 0; i < _chips.length; i++) _chip(i, center, t, c.maxWidth),
                    ]);
                  }),
                ),
                _bottom(pct, stepNow),
              ]),
            ),
          ]);
        },
      ),
    );
  }

  double _pulse() => (math.sin(_loop.value * 2 * math.pi) + 1) / 2;

  Widget _chip(int i, Offset center, double t, double width) {
    final n = _chips.length;
    final start = 0.22 + i * (0.5 / math.max(n, 1));
    final p = Curves.easeOutBack.transform(_win(t, start, start + 0.14));
    if (p <= 0) return const SizedBox.shrink();
    // Spread chips around the card on an ellipse.
    final ang = -math.pi / 2 + (i + 0.5) * (2 * math.pi / n) + 0.35;
    final rx = math.min(width / 2 - 70, 150.0);
    const ry = 165.0;
    final target = center + Offset(math.cos(ang) * rx, math.sin(ang) * ry);
    final pos = Offset.lerp(center, target, p)!;
    final float = math.sin((_loop.value + i / n) * 2 * math.pi) * 4;
    const colors = [Color(0xFF22E39A), Color(0xFF6EA8FF), Color(0xFFFFC857), Color(0xFFB794FF), Color(0xFF5EEAD4), Color(0xFFFF8FA3)];
    final col = colors[i % colors.length];
    return Positioned(
      left: pos.dx,
      top: pos.dy + float,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: Opacity(
          opacity: p.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.6 + 0.4 * p,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 150),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF0E1A3D).withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: col.withValues(alpha: 0.7), width: 1.2),
                boxShadow: [BoxShadow(color: col.withValues(alpha: 0.35), blurRadius: 16)],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle_rounded, size: 13, color: col),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(_chips[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottom(int pct, int stepNow) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1636).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1F2E5C)),
      ),
      child: Row(children: [
        SizedBox(
          width: 76,
          height: 76,
          child: CustomPaint(
            painter: _RingPainter(pct / 100),
            child: Center(
              child: Text('$pct%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 19)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < _steps.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: i < stepNow
                        ? const Icon(Icons.check_circle_rounded, key: ValueKey('d'), size: 15, color: Color(0xFF22E39A))
                        : i == stepNow
                            ? const SizedBox(
                                key: ValueKey('a'),
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6EA8FF)),
                              )
                            : const Icon(Icons.radio_button_unchecked_rounded, key: ValueKey('w'), size: 15, color: Color(0xFF3A4A78)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_steps[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: i <= stepNow ? Colors.white : const Color(0xFF5A6A98),
                          fontWeight: i == stepNow ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 12.5,
                        )),
                  ),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _CvCard extends StatelessWidget {
  const _CvCard({required this.scan, required this.t});
  final double scan;
  final double t;

  @override
  Widget build(BuildContext context) {
    // Beam sweeps down and up.
    final y = (math.sin(scan * 2 * math.pi - math.pi / 2) + 1) / 2;
    return SizedBox(
      width: 190,
      height: 250,
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: const Color(0xFF2F6BFF).withValues(alpha: 0.45), blurRadius: 40, spreadRadius: 2)],
          ),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          child: CustomPaint(painter: _LinesPainter(y, t), size: Size.infinite),
        ),
        // Laser beam with a soft trail.
        Positioned(
          left: -10,
          right: -10,
          top: 6 + y * 232 - 30,
          child: IgnorePointer(
            child: Column(children: [
              Container(
                height: 30,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [const Color(0x0022E39A), const Color(0xFF22E39A).withValues(alpha: 0.28)],
                  ),
                ),
              ),
              Container(
                height: 3,
                decoration: BoxDecoration(
                  color: const Color(0xFF22E39A),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: const [
                    BoxShadow(color: Color(0xFF22E39A), blurRadius: 14, spreadRadius: 1),
                    BoxShadow(color: Color(0x8822E39A), blurRadius: 30, spreadRadius: 4),
                  ],
                ),
              ),
            ]),
          ),
        ),
        // Corner brackets.
        for (final a in const [Alignment.topLeft, Alignment.topRight, Alignment.bottomLeft, Alignment.bottomRight])
          Positioned.fill(
            child: Align(
              alignment: a,
              child: Transform.translate(
                offset: Offset(a.x * 12, a.y * 12),
                child: CustomPaint(size: const Size(22, 22), painter: _BracketPainter(a)),
              ),
            ),
          ),
      ]),
    );
  }
}

class _LinesPainter extends CustomPainter {
  _LinesPainter(this.beam, this.t);
  final double beam;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    // Avatar + name block
    final grey = Paint()..color = const Color(0xFFE6EAF2);
    final hit = Paint()..color = const Color(0xFF22E39A).withValues(alpha: 0.85);
    final found = Paint()..color = const Color(0xFF2F6BFF).withValues(alpha: 0.75);
    canvas.drawCircle(const Offset(16, 16), 16, t > 0.2 ? found : grey);
    canvas.drawRRect(RRect.fromLTRBR(40, 6, size.width * 0.85, 14, const Radius.circular(4)), t > 0.25 ? found : grey);
    canvas.drawRRect(RRect.fromLTRBR(40, 20, size.width * 0.6, 26, const Radius.circular(3)), grey);
    const widths = [1.0, 0.82, 0.94, 0.6, 1.0, 0.88, 0.7, 0.95, 0.5, 0.9, 0.76, 0.62];
    final beamY = beam * (size.height + 20) - 10;
    for (var i = 0; i < widths.length; i++) {
      final y = 46.0 + i * 15;
      if (y > size.height - 6) break;
      final near = (y - beamY).abs() < 10;
      // Lines become "found" progressively through the timeline.
      final done = t > 0.2 + i * 0.055;
      final isHeader = i == 0 || i == 5 || i == 9;
      final w = size.width * widths[i] * (isHeader ? 0.45 : 1);
      canvas.drawRRect(
        RRect.fromLTRBR(0, y, w, y + (isHeader ? 7 : 5), const Radius.circular(3)),
        near ? hit : (done && (isHeader || i.isEven) ? found : grey),
      );
    }
  }

  @override
  bool shouldRepaint(_LinesPainter o) => o.beam != beam || o.t != t;
}

class _BracketPainter extends CustomPainter {
  _BracketPainter(this.a);
  final Alignment a;
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = const Color(0xFF22E39A)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final x0 = a.x < 0 ? 0.0 : s.width, y0 = a.y < 0 ? 0.0 : s.height;
    final dx = a.x < 0 ? s.width : -s.width, dy = a.y < 0 ? s.height : -s.height;
    canvas.drawPath(Path()..moveTo(x0, y0 + dy)..lineTo(x0, y0)..lineTo(x0 + dx, y0), p);
  }

  @override
  bool shouldRepaint(_BracketPainter o) => false;
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter(this.loop, this.t, this.c);
  final double loop;
  final double t;
  final Offset c;

  @override
  void paint(Canvas canvas, Size size) {
    // Ripples
    for (var k = 0; k < 3; k++) {
      final ph = (loop + k / 3) % 1.0;
      final r = 130 + ph * 120;
      canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = const Color(0xFF2F6BFF).withValues(alpha: (1 - ph) * 0.35));
    }
    // Rotating dashed orbits
    void orbit(double r, double speed, Color col, int dashes) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = col;
      final rot = loop * 2 * math.pi * speed;
      for (var i = 0; i < dashes; i++) {
        final a0 = rot + i * 2 * math.pi / dashes;
        canvas.drawArc(Rect.fromCircle(center: c, radius: r), a0, math.pi / dashes, false, p);
      }
      final dot = c + Offset(math.cos(rot) * r, math.sin(rot) * r);
      canvas.drawCircle(dot, 4, Paint()..color = col.withValues(alpha: 1));
      canvas.drawCircle(dot, 10, Paint()..color = col.withValues(alpha: 0.25));
    }

    orbit(150, 0.5, const Color(0xFF6EA8FF).withValues(alpha: 0.55), 18);
    orbit(176, -0.3, const Color(0xFF22E39A).withValues(alpha: 0.4), 10);
  }

  @override
  bool shouldRepaint(_OrbitPainter o) => true;
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.loop, this.t);
  final double loop;
  final double t;
  static final _rnd = List.generate(46, (i) {
    final r = math.Random(i * 7919);
    return [r.nextDouble(), r.nextDouble(), r.nextDouble()];
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.15),
          radius: 0.95,
          colors: [Color(0xFF16307A), Color(0xFF0A1640), Color(0xFF050C22)],
          stops: [0, 0.5, 1],
        ).createShader(rect),
    );
    // Grid
    final grid = Paint()
      ..color = const Color(0xFF2F6BFF).withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    // Floating particles drifting upward
    for (final p in _rnd) {
      final y = ((p[1] - loop * (0.15 + p[2] * 0.25)) % 1.0) * size.height;
      final x = p[0] * size.width;
      canvas.drawCircle(Offset(x, y), 1 + p[2] * 1.8,
          Paint()..color = (p[2] > 0.5 ? const Color(0xFF22E39A) : const Color(0xFF6EA8FF)).withValues(alpha: 0.25 + p[2] * 0.4));
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter o) => true;
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v);
  final double v;
  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = s.width / 2 - 5;
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..color = const Color(0xFF1F2E5C));
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * v,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..shader = const SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: 3 * math.pi / 2,
          colors: [Color(0xFF6EA8FF), Color(0xFF22E39A), Color(0xFF6EA8FF)],
          transform: GradientRotation(-math.pi / 2),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.v != v;
}
