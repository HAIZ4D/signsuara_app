import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'baked_gradients.dart';
import 'motion.dart';

/// Dark-blue header panel with drifting colour blobs and round bottom corners (design: .hx-hero).
class HeroPanel extends StatelessWidget {
  const HeroPanel({super.key, required this.child, this.bottomPadding = 64, this.backdrop});

  final Widget child;
  final double bottomPadding;
  final Widget? backdrop; // over the colour blobs, under the content (Home's evening stars)

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppRadius.hero)),
      child: Stack(
        children: [
          // The dark-blue colour is painted once (a big gradient costs this kind of graphics chip
          // a few ms in every frame; README "Smoothness").
          const Positioned.fill(child: BakedGradients(layers: [AppGradients.deep])),
          const Positioned.fill(child: Aurora()),
          if (backdrop case final backdrop?) Positioned.fill(child: backdrop),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpace.xl,
              MediaQuery.paddingOf(context).top + AppSpace.s,
              AppSpace.xl,
              bottomPadding,
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// "Section title ........ action" row above a list (design: .hx-sec).
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 12, 6),
        child: Row(
          children: [
            Expanded(child: Text(title, style: AppText.section)),
            if (action != null)
              TextButton(
                onPressed: onAction,
                child: Text(action!, style: AppText.label.copyWith(color: AppColors.turq, fontWeight: FontWeight.w800)),
              ),
          ],
        ),
      );
}
