import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Full-width rounded button with a gradient (design: .btn-turq / .btn-yellow). Disabled when
/// [onTap] is null (faded, and screen readers are told it is disabled).
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.gradient = AppGradients.turq,
    this.shadow = AppShadows.turqTile,
    this.foreground = AppColors.onDark,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Gradient gradient;
  final List<BoxShadow> shadow;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.45,
        duration: AppMotion.fast,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: enabled ? shadow : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Ink(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(AppRadius.md)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[Icon(icon, size: 20, color: foreground), const SizedBox(width: 9)],
                    Flexible(
                      child: Text(label,
                          style: AppText.strong.copyWith(color: foreground, fontSize: 16), overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
