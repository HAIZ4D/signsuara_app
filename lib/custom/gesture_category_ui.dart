import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'custom_gesture.dart';

/// How a category looks (README "Custom gestures"): its icon, its colour on white (icons only), the
/// colour that fills it when chosen and the text on that fill (contrast 4.5:1 or more), and a hint.
({IconData icon, Color ink, Color fill, Color onFill, String hint}) categoryLook(GestureCategory category) =>
    switch (category) {
      GestureCategory.religious => (
          icon: Icons.auto_stories_rounded,
          ink: AppColors.onYellowInk,
          fill: AppColors.yellow,
          onFill: AppColors.onYellow,
          hint: 'Faith, prayer, holy days',
        ),
      GestureCategory.science => (
          icon: Icons.science_rounded,
          ink: AppColors.turqDeep,
          fill: AppColors.turqDeep,
          onFill: AppColors.onDark,
          hint: 'Science, health, medicine',
        ),
      GestureCategory.technical => (
          icon: Icons.build_rounded,
          ink: AppColors.blue,
          fill: AppColors.blue,
          onFill: AppColors.onDark,
          hint: 'Tools, computers, work',
        ),
      GestureCategory.personal => (
          icon: Icons.person_rounded,
          ink: AppColors.royal,
          fill: AppColors.royal,
          onFill: AppColors.onDark,
          hint: 'Names, family, daily life',
        ),
    };

/// The four categories, two by two; the chosen one is filled with its colour and ticked.
class CategoryPicker extends StatelessWidget {
  const CategoryPicker({super.key, required this.selected, required this.onSelect});

  final GestureCategory selected;
  final ValueChanged<GestureCategory> onSelect;

  @override
  Widget build(BuildContext context) {
    Widget option(GestureCategory category) => Expanded(
          child: _Option(category: category, selected: category == selected, onTap: () => onSelect(category)),
        );
    return Column(children: [
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          option(GestureCategory.religious),
          const SizedBox(width: 10),
          option(GestureCategory.science),
        ]),
      ),
      const SizedBox(height: 10),
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          option(GestureCategory.technical),
          const SizedBox(width: 10),
          option(GestureCategory.personal),
        ]),
      ),
    ]);
  }
}

class _Option extends StatelessWidget {
  const _Option({required this.category, required this.selected, required this.onTap});

  final GestureCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final look = categoryLook(category);
    final fg = selected ? look.onFill : AppColors.ink;
    final soft = selected ? look.onFill : AppColors.inkSoft;
    return Semantics(
      button: true,
      selected: selected,
      label: '${category.label}: ${look.hint}',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: AppMotion.reduced(context) ? Duration.zero : AppMotion.fast,
        curve: AppMotion.outCurve,
        decoration: BoxDecoration(
          color: selected ? look.fill : AppColors.surface2,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: selected ? look.fill : AppColors.line, width: 1.5),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(look.icon, size: 20, color: selected ? look.onFill : look.ink),
                    const Spacer(),
                    if (selected) Icon(Icons.check_circle_rounded, size: 18, color: look.onFill),
                  ]),
                  const SizedBox(height: AppSpace.s),
                  Text(category.label, style: AppText.strong.copyWith(color: fg, fontSize: 14.5)),
                  const SizedBox(height: 2),
                  Text(look.hint, style: AppText.small.copyWith(color: soft)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Change category": the picker in a sheet; the new category, or null when nothing changed.
Future<GestureCategory?> showCategorySheet(BuildContext context, CustomGesture gesture) =>
    showModalBottomSheet<GestureCategory>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true, // as tall as it needs (big text), scrolling if the screen is short
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpace.xl, 0, AppSpace.xl, AppSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Category for "${gesture.malay}"', style: AppText.section),
              const SizedBox(height: AppSpace.xs),
              Text('Only for finding it again: recognition stays the same.',
                  style: AppText.small.copyWith(color: AppColors.inkSoft)),
              const SizedBox(height: AppSpace.l),
              CategoryPicker(
                selected: gesture.category,
                onSelect: (category) => Navigator.pop(context, category == gesture.category ? null : category),
              ),
            ],
          ),
        ),
      ),
    );
