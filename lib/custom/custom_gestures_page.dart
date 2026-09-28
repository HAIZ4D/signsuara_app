import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../glove/glove_ble.dart';
import '../glove/glove_session.dart';
import '../ml/gesture_classifier.dart';
import '../ml/signsuara_model.dart';
import '../speech/sign_words.dart';
import '../theme/app_theme.dart';
import '../ui/widgets/hero_panel.dart';
import '../ui/widgets/motion.dart';
import 'custom_gesture.dart';
import 'custom_gestures.dart';
import 'record_gesture_page.dart';

/// "My gestures" tab (design: screens-v2.jsx GesturesScreen): the custom gestures, with delete
/// and "Record a new gesture". Only real numbers (no invented uses/accuracy).
class CustomGesturesPage extends StatelessWidget {
  const CustomGesturesPage({super.key, required this.gestures, required this.session, this.ble});

  final CustomGestures gestures;
  final GloveSession session;
  final GloveBle? ble;

  static const _ctaHeight = 82.0;

  @override
  Widget build(BuildContext context) {
    final builtInLabels = [for (final l in kLabels) if (l != GestureClassifier.restLabel) l];
    final builtIn = [for (final l in builtInLabels) wordsFor(l).malay].join(', ');
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ListenableBuilder(
        listenable: gestures,
        builder: (context, _) {
          final all = gestures.all;
          return ListView(
            padding: EdgeInsets.only(bottom: AppSpace.navClearance(context)),
            children: [
              Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: _ctaHeight - 36),
                    child: HeroPanel(
                      bottomPadding: 60,
                      child: FadeUp(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('My Gestures', style: AppText.heroTitle),
                            const SizedBox(height: 6),
                            Text('Teach the glove your own signs and give each one a voice.',
                                style: AppText.body.copyWith(color: AppColors.onDarkSoft)),
                            const SizedBox(height: AppSpace.l),
                            Row(children: [
                              Expanded(child: _Stat('${all.length}', 'Custom signs', AppColors.turqBright)),
                              const SizedBox(width: AppSpace.s),
                              Expanded(child: _Stat('${builtInLabels.length}', 'Built-in signs', AppColors.yellow)),
                              const SizedBox(width: AppSpace.s),
                              const Expanded(child: _Stat('2', 'Languages', AppColors.onDark)),
                            ]),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: AppSpace.gutter,
                    right: AppSpace.gutter,
                    bottom: 0,
                    height: _ctaHeight,
                    child: _RecordCta(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => RecordGesturePage(gestures: gestures, session: session, ble: ble),
                      )),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
                child: Row(children: [
                  Text('Your library', style: AppText.label.copyWith(color: AppColors.inkFaint)),
                  const Spacer(),
                  Text('${all.length} saved', style: AppText.label.copyWith(color: AppColors.inkFaint)),
                ]),
              ),
              if (all.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
                  child: _EmptyLibrary(builtIn: builtIn),
                ),
              for (final (i, g) in all.indexed)
                FadeUp(
                  key: ValueKey(g.id),
                  delay: Duration(milliseconds: 50 * i.clamp(0, 6)),
                  child: _GestureItem(gesture: g, index: i, onDelete: () => _confirmDelete(context, g)),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, CustomGesture g) async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Delete "${g.malay}"?'),
        content: const Text('Its recordings are deleted too.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Delete')),
        ],
      ),
    );
    if (delete == true) await gestures.remove(g.id);
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label, this.color);

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.m, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.glass,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: AppText.cardTitle.copyWith(fontSize: 20, color: color)),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.small.copyWith(color: AppColors.onDarkSoft, fontSize: 11)),
          ],
        ),
      );
}

/// Yellow "Record a new gesture" card overlapping the hero (design: .gx-cta).
class _RecordCta extends StatelessWidget {
  const _RecordCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FadeUp(
      delay: const Duration(milliseconds: 150),
      child: Semantics(
        button: true,
        label: 'Record a new gesture',
        excludeSemantics: true,
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(26), boxShadow: AppShadows.sunCta),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Material(
              type: MaterialType.transparency,
              child: Ink(
                decoration: const BoxDecoration(gradient: AppGradients.sunCta),
                child: InkWell(
                  onTap: onTap,
                  child: Stack(
                    children: [
                      const Positioned.fill(child: ShineSweep(strength: 0.45)),
                      Padding(
                        padding: const EdgeInsets.all(AppSpace.l),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(color: AppColors.blue, borderRadius: BorderRadius.circular(17)),
                              child: const Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(Icons.add_rounded, color: AppColors.onDark, size: 26),
                                  Positioned(top: 8, right: 8, child: PulseDot(color: AppColors.recDot, size: 8)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Record a new gesture',
                                      style: AppText.cardTitle.copyWith(fontSize: 16.5, color: AppColors.onYellow)),
                                  Text('Sign it ${CustomGesture.recordingsNeeded} times to train',
                                      style: AppText.small.copyWith(
                                          color: AppColors.onYellow.withValues(alpha: 0.8), fontSize: 12.5)),
                                ],
                              ),
                            ),
                            const Icon(Icons.auto_awesome_rounded, color: AppColors.onYellow, size: 22),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.builtIn});

  final String builtIn;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpace.l),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(15)),
              child: const Icon(Icons.back_hand_outlined, color: AppColors.turq),
            ),
            const SizedBox(width: AppSpace.m),
            Expanded(
              child: Text(
                'No custom gestures yet. Tap "Record a new gesture" to teach one. '
                'Make it clearly different from the built-in signs ($builtIn).',
                style: AppText.body.copyWith(color: AppColors.inkSoft, fontSize: 13.5),
              ),
            ),
          ],
        ),
      );
}

/// One saved gesture (design: .g-item).
class _GestureItem extends StatelessWidget {
  const _GestureItem({required this.gesture, required this.index, required this.onDelete});

  final CustomGesture gesture;
  final int index;
  final VoidCallback onDelete;

  static const _accents = [AppColors.turq, AppColors.yellow, AppColors.blue600];

  @override
  Widget build(BuildContext context) {
    final accent = _accents[index % _accents.length];
    final ink = accent == AppColors.yellow ? AppColors.onYellowInk : accent;
    final kind = gesture.moving ? 'Moving' : 'Still';
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpace.gutter, 0, AppSpace.gutter, AppSpace.m),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(18)),
            child: Icon(gesture.moving ? Icons.swipe_rounded : Icons.back_hand_rounded, color: ink, size: 30),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(gesture.malay,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.strong.copyWith(color: AppColors.ink)),
                const SizedBox(height: 8),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: accent.withValues(alpha: 0.4), width: 1.5),
                    ),
                    child: Text(kind, style: AppText.small.copyWith(color: ink, fontSize: 11.5, fontWeight: FontWeight.w800)),
                  ),
                  if (gesture.english.isNotEmpty) ...[
                    const SizedBox(width: 9),
                    Flexible(
                      child: Text(gesture.english,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.small.copyWith(color: AppColors.inkFaint)),
                    ),
                  ],
                ]),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: onDelete,
            style: IconButton.styleFrom(
              side: const BorderSide(color: AppColors.line),
              foregroundColor: AppColors.inkFaint,
            ),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}
