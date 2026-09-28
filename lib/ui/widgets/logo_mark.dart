import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// The SignSuara mark (design: LogoMark): two arcs forming an "S" conversation loop —
/// turquoise = speaking, yellow = listening. [progress] 0 → 1 draws the arcs and pops the dots.
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 56, this.progress = 1});

  final double size;
  final double progress;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _LogoPainter(progress)),
      );
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.progress);

  final double progress;

  // Timeline (0..1): arc 1 draws 0.15-0.55, arc 2 0.3-0.7, dot 1 pops 0.6-0.8, dot 2 0.7-0.9.
  double _phase(double from, double to) => ((progress - from) / (to - from)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 64);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(2, 2, 60, 60), const Radius.circular(18)),
      Paint()..color = AppColors.blue,
    );

    final upper = Path()
      ..moveTo(44, 22)
      ..arcToPoint(const Offset(20, 26), radius: const Radius.circular(13), clockwise: false);
    final lower = Path()
      ..moveTo(20, 42)
      ..arcToPoint(const Offset(44, 38), radius: const Radius.circular(13), clockwise: false);

    _drawArc(canvas, upper, _phase(0.15, 0.55), AppGradients.turq);
    _drawArc(canvas, lower, _phase(0.3, 0.7), AppGradients.sun);

    final d1 = Curves.easeOutBack.transform(_phase(0.6, 0.8));
    final d2 = Curves.easeOutBack.transform(_phase(0.7, 0.9));
    if (d1 > 0) canvas.drawCircle(const Offset(20, 26), 4.2 * d1, Paint()..color = AppColors.turqBright);
    if (d2 > 0) canvas.drawCircle(const Offset(44, 38), 4.2 * d2, Paint()..color = AppColors.yellow);
  }

  void _drawArc(Canvas canvas, Path path, double t, Gradient gradient) {
    if (t <= 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..shader = gradient.createShader(const Rect.fromLTWH(14, 14, 36, 36));
    for (final PathMetric m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * t), paint);
    }
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.progress != progress;
}
