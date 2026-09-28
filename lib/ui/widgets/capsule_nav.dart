import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class NavItem {
  const NavItem(this.label, this.icon, {this.sun = false});

  final String label;
  final IconData icon;
  final bool sun; // yellow highlight (the centre Hearing tab)
}

/// Floating capsule tab bar with a sliding highlight (design: .capnav).
class CapsuleNav extends StatelessWidget {
  const CapsuleNav({super.key, required this.items, required this.current, required this.onTap});

  final List<NavItem> items;
  final int current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.reduced(context) ? Duration.zero : AppMotion.slow;
    return Container(
      height: AppSpace.navHeight,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        gradient: AppGradients.navCapsule,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.glassBorder),
        boxShadow: AppShadows.nav,
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth / items.length;
          final sun = items[current].sun;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: duration,
                curve: AppMotion.navCurve,
                left: w * current + 2,
                top: 0,
                bottom: 0,
                width: w - 4,
                child: AnimatedContainer(
                  duration: duration,
                  decoration: BoxDecoration(
                    gradient: sun ? AppGradients.navBlobSun : AppGradients.navBlobTurq,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    boxShadow: sun ? AppShadows.sunGlow : AppShadows.turqTile,
                  ),
                ),
              ),
              Row(
                children: [
                  for (final (i, item) in items.indexed)
                    Expanded(child: _NavButton(item: item, on: i == current, onTap: () => onTap(i))),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.on, required this.onTap});

  final NavItem item;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = !on
        ? AppColors.onDarkFaint
        : item.sun
            ? AppColors.onYellow
            : AppColors.onDark;
    return Semantics(
      button: true,
      selected: on,
      label: item.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: on ? 1.04 : 1,
              duration: AppMotion.medium,
              curve: AppMotion.springCurve,
              child: Icon(item.icon, size: 23, color: color),
            ),
            AnimatedSize(
              duration: AppMotion.fast,
              curve: AppMotion.outCurve,
              child: on
                  ? Padding(
                      padding: const EdgeInsets.only(top: AppSpace.xxs),
                      child: Text(item.label, maxLines: 1, style: AppText.tiny.copyWith(color: color)),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}
