import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// The three Deaf-flag colours as a thin strip (turquoise · yellow · blue).
class FlagStrip extends StatelessWidget {
  const FlagStrip({super.key, this.width = 30, this.height = 5, this.gap = 7});

  final double width;
  final double height;
  final double gap;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, c) in [AppColors.turq, AppColors.yellow, AppColors.blue600].indexed) ...[
            if (i > 0) SizedBox(width: gap),
            Container(
              width: width,
              height: height,
              decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(height)),
            ),
          ],
        ],
      );
}

/// Stylised hand: 5 finger sensors joined to a palm node (design: HandSensor).
/// Each finger node lights up as much as that finger is bent ([bends], 0..1, thumb → pinky).
class HandSensor extends StatelessWidget {
  const HandSensor({super.key, required this.bends, this.active = true, this.size = 58});

  final List<double> bends;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size * 230 / 192,
        child: CustomPaint(painter: _HandPainter(bends, active)),
      );
}

class _HandPainter extends CustomPainter {
  _HandPainter(this.bends, this.active);

  final List<double> bends;
  final bool active;
  static const _tips = [Offset(38, 70), Offset(66, 36), Offset(96, 28), Offset(126, 38), Offset(154, 74)];
  static const _palm = Offset(96, 150);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 192, size.height / 230);
    final glow = Paint()
      ..shader = RadialGradient(colors: [
        AppColors.turqBright.withValues(alpha: active ? 0.35 : 0.12),
        AppColors.turqBright.withValues(alpha: 0),
      ]).createShader(Rect.fromCenter(center: _palm, width: 148, height: 124));
    canvas.drawOval(Rect.fromCenter(center: _palm, width: 148, height: 124), glow);
    canvas.drawCircle(
      _palm,
      16,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = AppColors.onDark.withValues(alpha: 0.25),
    );
    canvas.drawCircle(_palm, 7, Paint()..color = active ? AppColors.yellow : AppColors.offline);

    for (var i = 0; i < 5; i++) {
      final lit = active ? bends[i] : 0.0;
      canvas.drawLine(
        _tips[i],
        _palm,
        Paint()
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = Color.lerp(AppColors.onDark.withValues(alpha: 0.12), AppColors.turqBright.withValues(alpha: 0.7), lit)!,
      );
      canvas.drawCircle(
        _tips[i],
        lerpDouble(6, 9, lit)!,
        Paint()..color = Color.lerp(AppColors.onDark.withValues(alpha: 0.18), AppColors.turqBright, lit)!,
      );
    }
  }

  @override
  bool shouldRepaint(_HandPainter old) => old.active != active || !_same(old.bends, bends);

  static bool _same(List<double> a, List<double> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
