import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../ui/widgets/hero_panel.dart';
import '../ui/widgets/motion.dart';

/// Learn tab: space reserved for Islamic learning (Hijaiyah letters, daily phrases, PAFA).
/// Not built yet: the model doesn't know these signs.
class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  static const _planned = [
    (Icons.translate_rounded, 'Hijaiyah letters', 'Alif, Ba, Ta and more'),
    (Icons.auto_awesome_rounded, 'Daily phrases', 'Alhamdulillah, SubhanAllah'),
    (Icons.menu_book_rounded, 'PAFA basics', 'Perkara Asas Fardhu Ain'),
  ];

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ListView(
        padding: EdgeInsets.only(bottom: AppSpace.navClearance(context)),
        children: [
          HeroPanel(
            bottomPadding: 40,
            child: FadeUp(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Pill(icon: Icons.auto_awesome_rounded, text: 'Islamic learning'),
                  const SizedBox(height: 10),
                  Text('Learn and sign the Arabic letters', style: AppText.heroTitle.copyWith(fontSize: 23)),
                  const SizedBox(height: AppSpace.m),
                  _Pill(icon: Icons.schedule_rounded, text: 'Coming soon'),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 10),
            child: Text(
              "Lessons are being prepared. They'll appear here in a future update.",
              style: AppText.body.copyWith(color: AppColors.inkSoft),
            ),
          ),
          for (final (i, (icon, title, subtitle)) in _planned.indexed)
            FadeUp(
              delay: Duration(milliseconds: 60 * i),
              child: Container(
                margin: const EdgeInsets.fromLTRB(AppSpace.gutter, 0, AppSpace.gutter, 10),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: AppShadows.card,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(16)),
                      child: Icon(icon, color: AppColors.inkFaint),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: AppText.strong.copyWith(color: AppColors.ink, fontSize: 14.5)),
                          Text(subtitle, style: AppText.small.copyWith(color: AppColors.inkFaint)),
                        ],
                      ),
                    ),
                    const Icon(Icons.lock_outline_rounded, color: AppColors.inkFaint, size: 20),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.yellow.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: AppColors.yellow),
          const SizedBox(width: 5),
          Text(text, style: AppText.eyebrow.copyWith(color: AppColors.yellow, letterSpacing: 0)),
        ]),
      );
}
