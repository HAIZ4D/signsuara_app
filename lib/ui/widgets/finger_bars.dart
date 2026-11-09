import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Five vertical bars showing how bent each finger is right now (design: .cv-fingers).
/// [bends] come from the real glove (see fingerBend), 0 = straight, 1 = bent.
/// Learn's Sign Quest adds [targets] (where each finger should be, a yellow line) and [matches]
/// (green = in place, grey = not yet); without them the bars look as in Chat.
class FingerBars extends StatelessWidget {
  const FingerBars({super.key, required this.bends, this.height = 46, this.targets, this.matches});

  final List<double> bends;
  final double height;
  final List<double>? targets;
  final List<bool>? matches;

  static const _labels = ['T', 'I', 'M', 'R', 'P'];
  static const _names = ['thumb', 'index', 'middle', 'ring', 'pinky'];

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.reduced(context) ? Duration.zero : const Duration(milliseconds: 420);
    String state(int i) => switch (matches?[i]) { true => ', in place', false => ', not in place', null => '' };
    return Semantics(
      label: 'Finger sensors: ${[
        for (var i = 0; i < 5; i++) '${_names[i]} ${(bends[i] * 100).round()} percent bent${state(i)}'
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
                      child: Stack(
                        fit: StackFit.expand, // the bar's track fills its place, as before
                        children: [
                          Container(
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
                                  gradient: matches == null ? AppGradients.finger : null,
                                  color: switch (matches?[i]) { true => AppColors.live, false => AppColors.offline, null => null },
                                  borderRadius: BorderRadius.circular(7),
                                ),
                              ),
                            ),
                          ),
                          if (targets case final targets?)
                            Align(
                              alignment: Alignment(0, 1 - 2 * (0.06 + 0.94 * targets[i])),
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  color: AppColors.yellow,
                                  borderRadius: BorderRadius.circular(AppRadius.pill),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(_labels[i],
                        style: AppText.tiny.copyWith(color: matches?[i] == true ? AppColors.liveText : AppColors.onDarkFaint)),
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
