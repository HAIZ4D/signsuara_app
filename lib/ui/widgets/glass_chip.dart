import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Small see-through pill button on the dark panels (language switch, clear, …).
class GlassChip extends StatelessWidget {
  const GlassChip({super.key, required this.icon, required this.tooltip, required this.onTap, this.label});

  final IconData icon;
  final String? label;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: Ink(
              padding: EdgeInsets.symmetric(horizontal: label == null ? 9 : 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.glass,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 15, color: AppColors.onDark),
                if (label != null) ...[
                  const SizedBox(width: 6),
                  Text(label!, style: AppText.label.copyWith(color: AppColors.onDark, fontSize: 12)),
                ],
              ]),
            ),
          ),
        ),
      );
}
