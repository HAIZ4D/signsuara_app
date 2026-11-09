import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../ui/finger_bend.dart';
import '../ui/widgets/finger_bars.dart';
import 'sign_targets.dart';

/// Sign Quest's live finger meter (README "Learn"): the glove's five fingers as bars, a yellow line
/// where each should be for the sign, green when a finger is in place. The ring around them fills
/// while at least 4 fingers are in place, and closes when the glove accepts the sign. It only
/// guides: the glove's recogniser decides. Fed 25 times a second; only this card redraws.
class FingerMeter extends StatelessWidget {
  const FingerMeter({super.key, required this.row, required this.hold, required this.target});

  final ValueListenable<List<double>?> row; // the latest glove row
  final ValueListenable<double> hold; // 0..1, the ring
  final List<double>? target; // raw flex values for the sign; null = no guide yet

  /// Fingers in place out of 5, or null without a row or a guide.
  static int? inPlace(List<double>? row, List<double>? target) =>
      row == null || target == null ? null : fingerMatches(row, target).where((m) => m).length;

  @override
  Widget build(BuildContext context) {
    final target = this.target;
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(AppSpace.m),
        decoration: BoxDecoration(
          gradient: AppGradients.night,
          borderRadius: BorderRadius.circular(22),
          boxShadow: AppShadows.card,
        ),
        child: ValueListenableBuilder<List<double>?>(
          valueListenable: row,
          builder: (context, row, _) {
            final count = inPlace(row, target);
            return Row(children: [
              SizedBox.square(
                dimension: 150,
                child: Stack(children: [
                  Positioned.fill(
                    child: ValueListenableBuilder<double>(
                      valueListenable: hold,
                      builder: (context, hold, _) => Semantics(
                        label: hold >= 1 ? 'Sign accepted' : '',
                        child: CustomPaint(painter: _HoldRing(hold)),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 30, 24, 26), // the bars stay inside the ring
                    child: FingerBars(
                      bends: fingerBend(row),
                      height: double.infinity,
                      targets: target == null ? null : fingerBend(target),
                      matches: row == null || target == null ? null : fingerMatches(row, target),
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('YOUR FINGERS', style: AppText.eyebrow.copyWith(color: AppColors.yellow)),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      row == null
                          ? 'Waiting for the glove…'
                          : count == null
                              ? 'Live from the glove'
                              : '$count of 5 in place',
                      style: AppText.strong.copyWith(color: AppColors.onDark),
                    ),
                    const SizedBox(height: AppSpace.xxs),
                    Text(
                      target == null
                          ? 'No finger guide for this sign yet: watch the signer.'
                          : 'Move each bar to its yellow line. Green = in place.',
                      style: AppText.small.copyWith(color: AppColors.onDarkSoft),
                    ),
                  ],
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}

/// The ring: a faint track, and an arc from the top that grows with [value] (green when full).
class _HoldRing extends CustomPainter {
  _HoldRing(this.value);

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    const width = 6.0;
    final rect = (Offset.zero & size).deflate(width / 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = AppColors.glassBorder;
    canvas.drawArc(rect, 0, 2 * pi, false, track);
    if (value <= 0) return;
    canvas.drawArc(
      rect,
      -pi / 2,
      2 * pi * value.clamp(0.0, 1.0),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..color = value >= 1 ? AppColors.live : AppColors.yellow,
    );
  }

  @override
  bool shouldRepaint(_HoldRing old) => old.value != value;
}
