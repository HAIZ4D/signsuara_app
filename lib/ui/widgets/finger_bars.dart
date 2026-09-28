import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Five vertical bars showing how bent each finger is right now (design: .cv-fingers).
/// [bends] come from the real glove (see fingerBend), 0 = straight, 1 = bent.
class FingerBars extends StatelessWidget {
  const FingerBars({super.key, required this.bends, this.height = 46});

  final List<double> bends;
  final double height;

  static const _labels = ['T', 'I', 'M', 'R', 'P'];
  static const _names = ['thumb', 'index', 'middle', 'ring', 'pinky'];

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.reduced(context) ? Duration.zero : const Duration(milliseconds: 420);
    return Semantics(
      label: 'Finger sensors: ${[
        for (var i = 0; i < 5; i++) '${_names[i]} ${(bends[i] * 100).round()} percent bent'
      ].join(', ')}',
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            for (var i = 0; i < 5; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(color: AppColors.glass, borderRadius: BorderRadius.circular(7)),
                        alignment: Alignment.bottomCenter,
                        child: AnimatedFractionallySizedBox(
                          duration: duration,
                          curve: const Cubic(0.34, 1.3, 0.5, 1),
                          heightFactor: 0.06 + 0.94 * bends[i],
                          widthFactor: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: AppGradients.finger,
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(_labels[i], style: AppText.tiny.copyWith(color: AppColors.onDarkFaint)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
