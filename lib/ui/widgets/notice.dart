import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// A coloured warning strip, e.g. "Motion sensor disconnected" or a missing voice.
class Notice extends StatelessWidget {
  const Notice({super.key, required this.message, this.color = AppColors.warning});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpace.s),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.m, vertical: 10),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.onDark, size: 20),
              const SizedBox(width: AppSpace.s),
              Expanded(
                child: Text(message, style: AppText.label.copyWith(color: AppColors.onDark, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      );
}
