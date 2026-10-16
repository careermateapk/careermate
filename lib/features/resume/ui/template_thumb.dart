import 'package:flutter/material.dart';

import '../templates.dart';

/// Small drawing of a template's layout, used in the gallery (fast; the real PDF is shown in the preview).
class TemplateThumb extends StatelessWidget {
  const TemplateThumb({super.key, required this.t, this.color});
  final ResumeTemplate t;
  final int? color;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.75,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        child: CustomPaint(painter: _ThumbPainter(t, Color(color ?? t.color))),
      ),
    );
  }
}

class _ThumbPainter extends CustomPainter {
  _ThumbPainter(this.t, this.c);
  final ResumeTemplate t;
  final Color c;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final grey = Paint()..color = const Color(0xFFDCE1EA);
    final dark = Paint()..color = const Color(0xFF1F2937);
    final acc = Paint()..color = c;
    final tint = Paint()..color = c.withValues(alpha: 0.12);
    final white = Paint()..color = Colors.white.withValues(alpha: 0.75);

    void bar(double x, double y, double bw, double bh, Paint p) =>
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, bw, bh), Radius.circular(bh / 2)), p);
    void para(double x, double y, double bw, int n, {Paint? p}) {
      for (var i = 0; i < n; i++) {
        bar(x, y + i * h * 0.028, bw * (i % 3 == 2 ? 0.7 : (i.isEven ? 1 : 0.88)), h * 0.012, p ?? grey);
      }
    }

    void section(double x, double y, double bw, int n, {Paint? head, Paint? p}) {
      if (t.layout == ResumeLayout.boxed) {
        canvas.drawRect(Rect.fromLTWH(x, y, bw * 0.45, h * 0.03), acc);
      } else {
        bar(x, y, bw * 0.35, h * 0.018, head ?? acc);
      }
      para(x, y + h * 0.045, bw, n, p: p);
    }

    switch (t.layout) {
      case ResumeLayout.sidebarLeft:
      case ResumeLayout.sidebarRight:
        final left = t.layout == ResumeLayout.sidebarLeft;
        final sx = left ? 0.0 : w * 0.64;
        canvas.drawRect(Rect.fromLTWH(sx, 0, w * 0.36, h), acc);
        final mx = left ? w * 0.42 : w * 0.06;
        final px = sx + w * 0.05;
        if (t.initialsBadge) canvas.drawCircle(Offset(sx + w * 0.18, h * 0.1), w * 0.07, white);
        section(px, h * (t.initialsBadge ? 0.2 : 0.07), w * 0.26, 4, head: white, p: white);
        section(px, h * 0.42, w * 0.26, 6, head: white, p: white);
        bar(mx, h * 0.06, w * 0.45, h * 0.03, dark);
        bar(mx, h * 0.105, w * 0.3, h * 0.016, acc);
        section(mx, h * 0.17, w * 0.52, 3);
        section(mx, h * 0.33, w * 0.52, 9);
        section(mx, h * 0.68, w * 0.52, 5);
      case ResumeLayout.split:
        canvas.drawRect(Rect.fromLTWH(w * 0.66, 0, w * 0.34, h), tint);
        canvas.drawRect(Rect.fromLTWH(w * 0.66, 0, w * 0.012, h), acc);
        bar(w * 0.07, h * 0.06, w * 0.42, h * 0.035, acc);
        bar(w * 0.07, h * 0.11, w * 0.28, h * 0.016, grey);
        section(w * 0.07, h * 0.18, w * 0.53, 3);
        section(w * 0.07, h * 0.34, w * 0.53, 10);
        section(w * 0.71, h * 0.07, w * 0.24, 4);
        section(w * 0.71, h * 0.3, w * 0.24, 7);
        section(w * 0.71, h * 0.62, w * 0.24, 4);
      case ResumeLayout.headerBand:
        canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.19), acc);
        final cx = t.centered ? w * 0.27 : w * (t.initialsBadge ? 0.26 : 0.08);
        if (t.initialsBadge) canvas.drawCircle(Offset(w * 0.14, h * 0.095), w * 0.07, white);
        bar(cx, h * 0.06, w * 0.46, h * 0.032, white);
        bar(cx, h * 0.115, w * 0.32, h * 0.016, white);
        section(w * 0.08, h * 0.25, w * 0.84, 3);
        section(w * 0.08, h * 0.4, w * 0.84, 8);
        section(w * 0.08, h * 0.7, w * 0.38, 4);
        section(w * 0.54, h * 0.7, w * 0.38, 4);
      default:
        final center = t.centered || t.layout == ResumeLayout.classic;
        final nx = center ? w * 0.25 : w * (t.initialsBadge ? 0.24 : 0.08);
        if (t.initialsBadge) canvas.drawCircle(Offset(w * 0.13, h * 0.08), w * 0.06, acc);
        bar(nx, h * 0.05, w * 0.5, h * 0.032, t.layout == ResumeLayout.minimal ? dark : acc);
        bar(center ? w * 0.2 : nx, h * 0.1, w * 0.6, h * 0.013, grey);
        if (t.layout == ResumeLayout.classic) canvas.drawRect(Rect.fromLTWH(w * 0.08, h * 0.135, w * 0.84, h * 0.006), acc);
        if (t.layout == ResumeLayout.timeline) {
          canvas.drawRect(Rect.fromLTWH(w * 0.1, h * 0.34, w * 0.008, h * 0.4), acc);
          for (var i = 0; i < 4; i++) {
            canvas.drawCircle(Offset(w * 0.104, h * (0.36 + i * 0.1)), w * 0.018, acc);
          }
          section(w * 0.08, h * 0.17, w * 0.84, 3);
          for (var i = 0; i < 4; i++) {
            para(w * 0.16, h * (0.35 + i * 0.1), w * 0.76, 3);
          }
          section(w * 0.08, h * 0.79, w * 0.84, 3);
        } else {
          section(w * 0.08, h * 0.17, w * 0.84, 3);
          section(w * 0.08, h * 0.32, w * 0.84, 10);
          section(w * 0.08, h * 0.67, w * 0.84, 3);
          section(w * 0.08, h * 0.82, w * 0.84, 3);
        }
    }
  }

  @override
  bool shouldRepaint(_ThumbPainter o) => o.c != c || o.t.id != t.id;
}
