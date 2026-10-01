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
import 'gesture_backup.dart';
import 'gesture_category_ui.dart';
import 'record_gesture_page.dart';

/// "My gestures" tab (README "Custom gestures"): your own signs as a small dictionary, sorted into
/// categories (tap one to show only those), and "Record a new gesture". Only real numbers.
class CustomGesturesPage extends StatefulWidget {
  const CustomGesturesPage({super.key, required this.gestures, required this.session, this.ble, this.backup});

  final CustomGestures gestures;
  final GloveSession session;
  final GloveBle? ble;
  final GestureBackup? backup; // null: no backup line (tests)

  @override
  State<CustomGesturesPage> createState() => _CustomGesturesPageState();
}

class _CustomGesturesPageState extends State<CustomGesturesPage> {
  GestureCategory? _category; // the filter; null = every category

  CustomGestures get gestures => widget.gestures;

  void _record([GestureCategory? category]) => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => RecordGesturePage(
          gestures: gestures,
          session: widget.session,
          ble: widget.ble,
          category: category ?? _category ?? GestureCategory.personal,
        ),
      ));

  // ⋮ on a gesture: its actions.
  Future<void> _more(CustomGesture g) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, AppSpace.s),
              child: Text(g.malay, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.section),
            ),
            ListTile(
              leading: Icon(categoryLook(g.category).icon, color: AppColors.turqDeep),
              title: Text('Change category', style: AppText.strong.copyWith(color: AppColors.ink)),
              subtitle: Text('Now: ${g.category.label}', style: AppText.small.copyWith(color: AppColors.inkSoft)),
              onTap: () => Navigator.pop(context, 'category'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              title: Text('Delete', style: AppText.strong.copyWith(color: AppColors.ink)),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'category':
        await _changeCategory(g);
      case 'delete':
        await _delete(g);
    }
  }

  Future<void> _changeCategory(CustomGesture g) async {
    final category = await showCategorySheet(context, g);
    if (category == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await gestures.update(g.copyWith(category: category));
    messenger.showSnackBar(SnackBar(content: Text('"${g.malay}" is now in ${category.label}.')));
  }

  Future<void> _delete(CustomGesture g) async {
    final backup = widget.backup;
    final messenger = ScaffoldMessenger.of(context);
    final delete = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Delete "${g.malay}"?'),
        content: Text(backup == null || backup.state == BackupState.off
            ? 'Its recordings are deleted too.'
            : 'Its recordings are deleted too, also from the backup in your account.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Delete')),
        ],
      ),
    );
    if (delete != true) return;
    await gestures.remove(g.id);
    messenger.showSnackBar(SnackBar(content: Text('"${g.malay}" was deleted.')));
  }

  @override
  Widget build(BuildContext context) {
    final builtIn = [for (final l in kLabels) if (l != GestureClassifier.restLabel) wordsFor(l).malay];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ListenableBuilder(
        listenable: Listenable.merge([gestures, widget.backup]),
        builder: (context, _) {
          final all = gestures.all;
          final counts = {for (final c in GestureCategory.values) c: all.where((g) => g.category == c).length};
          final shown = [for (final g in all) if (_category == null || g.category == _category) g];
          return ListView(
            padding: EdgeInsets.only(bottom: AppSpace.navClearance(context)),
            children: [
              _Hero(yours: all.length, builtIn: builtIn.length, onRecord: _record),
              _Categories(
                counts: counts,
                selected: _category,
                onSelect: (category) => setState(() => _category = category == _category ? null : category),
              ),
              _LibraryHeader(category: _category, count: shown.length, onShowAll: () => setState(() => _category = null)),
              if (widget.backup case final backup?)
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 0, AppSpace.gutter, AppSpace.m),
                  child: _BackupLine(backup: backup),
                ),
              if (shown.isEmpty && _category != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
                  child: _EmptyCategory(category: _category!, onRecord: () => _record(_category)),
                )
              else if (all.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
                  child: _EmptyLibrary(builtIn: builtIn),
                )
              else
                for (final (i, g) in shown.indexed)
                  FadeUp(
                    key: ValueKey(g.id),
                    delay: Duration(milliseconds: 40 * i.clamp(0, 6)),
                    child: _GestureEntry(gesture: g, onMore: () => _more(g)),
                  ),
              if (all.isNotEmpty) _BuiltIn(words: builtIn),
            ],
          );
        },
      ),
    );
  }
}

/// Icon and colour for a backup state (also used in Profile).
(IconData, Color) backupLook(BackupState state) => switch (state) {
      BackupState.off => (Icons.cloud_off_rounded, AppColors.inkFaint),
      BackupState.checking => (Icons.cloud_sync_rounded, AppColors.inkFaint),
      BackupState.done => (Icons.cloud_done_rounded, AppColors.turq),
      BackupState.failed => (Icons.cloud_off_rounded, AppColors.warning),
    };

/// Whether the custom gestures are backed up to the Google account, in plain words.
class _BackupLine extends StatelessWidget {
  const _BackupLine({required this.backup});

  final GestureBackup backup;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = backupLook(backup.state);
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: AppSpace.s),
          Expanded(child: Text(backup.summary, style: AppText.small.copyWith(color: AppColors.inkSoft))),
        ],
      ),
    );
  }
}

/// The dark header: what this tab is, real numbers, and "Record a new gesture" over its edge.
class _Hero extends StatelessWidget {
  const _Hero({required this.yours, required this.builtIn, required this.onRecord});

  static const _barHeight = 76.0;

  final int yours;
  final int builtIn;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: _barHeight / 2),
            child: HeroPanel(
              bottomPadding: _barHeight / 2 + 24,
              child: FadeUp(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const ExcludeSemantics(child: Icon(Icons.back_hand_rounded, size: 14, color: AppColors.yellow)),
                      const SizedBox(width: 6),
                      Text('GESTURES', style: AppText.eyebrow.copyWith(color: AppColors.yellow, fontSize: 12)),
                    ]),
                    const SizedBox(height: 6),
                    Text('My Gestures', style: AppText.heroTitle),
                    const SizedBox(height: 6),
                    Text('Your own signs, each with its own voice.', style: AppText.body.copyWith(color: AppColors.onDarkSoft)),
                    const SizedBox(height: 18),
                    IntrinsicHeight(
                      child: Row(children: [
                        Flexible(child: _Figure('$yours', 'Your signs', AppColors.turqBright)),
                        const VerticalDivider(color: AppColors.glassBorder, width: 36, thickness: 1),
                        Flexible(child: _Figure('$builtIn', 'Built-in signs', AppColors.yellow)),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: AppSpace.gutter,
            right: AppSpace.gutter,
            bottom: 0,
            height: _barHeight,
            child: _RecordBar(onTap: onRecord),
          ),
        ],
      );
}

/// A big number with its label (real data only).
class _Figure extends StatelessWidget {
  const _Figure(this.value, this.label, this.color);

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '$value $label',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: AppText.heroTitle.copyWith(fontSize: 32, height: 1.05, color: color)),
            Text(label, style: AppText.small.copyWith(color: AppColors.onDarkSoft)),
          ],
        ),
      );
}

/// "Record a new gesture": a white bar over the header's edge, with a live record dot.
class _RecordBar extends StatelessWidget {
  const _RecordBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FadeUp(
        delay: const Duration(milliseconds: 120),
        child: Semantics(
          button: true,
          label: 'Record a new gesture',
          excludeSemantics: true,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppShadows.pop,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(color: AppColors.blue, shape: BoxShape.circle),
                      child: const Center(child: PulseDot(color: AppColors.recDot, size: 13)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Record a new gesture', style: AppText.section.copyWith(fontSize: 16.5)),
                          Text('Sign it ${CustomGesture.recordingsNeeded} times, 3 seconds each',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.small.copyWith(color: AppColors.inkSoft)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_rounded, color: AppColors.ink),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}

/// The four categories with how many signs each has: a tap shows only those, a second tap all.
class _Categories extends StatelessWidget {
  const _Categories({required this.counts, required this.selected, required this.onSelect});

  final Map<GestureCategory, int> counts;
  final GestureCategory? selected;
  final ValueChanged<GestureCategory> onSelect;

  @override
  Widget build(BuildContext context) {
    Widget tile(GestureCategory category) => Expanded(
          child: _CategoryTile(
            category: category,
            count: counts[category] ?? 0,
            selected: selected == category,
            onTap: () => onSelect(category),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.xl, AppSpace.gutter, 0),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              tile(GestureCategory.religious),
              const SizedBox(width: AppSpace.m),
              tile(GestureCategory.science),
            ]),
          ),
          const SizedBox(height: AppSpace.m),
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              tile(GestureCategory.technical),
              const SizedBox(width: AppSpace.m),
              tile(GestureCategory.personal),
            ]),
          ),
        ],
      ),
    );
  }
}

/// One category: how many signs, its name and what goes in it, its icon large and faint in the
/// corner. Chosen: filled with its colour and ticked.
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.count, required this.selected, required this.onTap});

  final GestureCategory category;
  final int count;
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
      label: '${category.label}, $count ${count == 1 ? 'sign' : 'signs'}',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: AppMotion.reduced(context) ? Duration.zero : AppMotion.fast,
        curve: AppMotion.outCurve,
        decoration: BoxDecoration(
          color: selected ? look.fill : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.card,
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                Positioned(
                  right: -10,
                  bottom: -14,
                  child: Icon(
                    look.icon,
                    size: 76,
                    color: (selected ? look.onFill : look.ink).withValues(alpha: selected ? 0.22 : 0.12),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 14, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text('$count', style: AppText.heroTitle.copyWith(fontSize: 28, height: 1.1, color: fg)),
                        const Spacer(),
                        if (selected) Icon(Icons.check_circle_rounded, size: 20, color: look.onFill),
                      ]),
                      const SizedBox(height: 14),
                      Text(category.label, style: AppText.strong.copyWith(color: fg)),
                      const SizedBox(height: 2),
                      Text(look.hint, style: AppText.small.copyWith(color: soft)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "All signs · 3 saved", or one category's, with the way back to all.
class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({required this.category, required this.count, required this.onShowAll});

  final GestureCategory? category;
  final int count;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 12, 8),
        child: Row(children: [
          Expanded(
            child: Row(children: [
              Flexible(
                child: Semantics(
                  header: true,
                  child: Text(category == null ? 'All signs' : '${category!.label} signs',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.section),
                ),
              ),
              const SizedBox(width: 10),
              Text('$count saved', style: AppText.small.copyWith(color: AppColors.inkSoft)),
            ]),
          ),
          if (category != null)
            TextButton(
              onPressed: onShowAll,
              style: TextButton.styleFrom(foregroundColor: AppColors.turqInk),
              child: const Text('Show all'),
            ),
        ]),
      );
}

/// One gesture, like a dictionary entry: the phrase, its English, then its category and how it is
/// signed. ⋮ changes the category or deletes it.
class _GestureEntry extends StatelessWidget {
  const _GestureEntry({required this.gesture, required this.onMore});

  final CustomGesture gesture;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final look = categoryLook(gesture.category);
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpace.gutter, 0, AppSpace.gutter, AppSpace.m),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 36), // room for ⋮
                  child: Text(gesture.malay,
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.section.copyWith(fontSize: 18)),
                ),
                if (gesture.english.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 36),
                    child: Text(gesture.english,
                        maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.body.copyWith(color: AppColors.inkSoft)),
                  ),
                const SizedBox(height: AppSpace.m),
                const Divider(height: 1, color: AppColors.line),
                const SizedBox(height: 10),
                Wrap(
                  spacing: AppSpace.l,
                  runSpacing: 6,
                  children: [
                    _Fact(icon: look.icon, color: look.ink, text: gesture.category.label),
                    _Fact(
                      icon: gesture.moving ? Icons.swipe_rounded : Icons.back_hand_rounded,
                      color: AppColors.inkSoft,
                      text: gesture.moving ? 'Moving' : 'Still',
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              tooltip: 'More for ${gesture.malay}',
              icon: const Icon(Icons.more_vert_rounded, color: AppColors.inkSoft),
              onPressed: onMore,
            ),
          ),
        ],
      ),
    );
  }
}

/// A small fact with its icon ("Still"): a label, not a button.
class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        ExcludeSemantics(child: Icon(icon, size: 16, color: color)),
        const SizedBox(width: 6),
        Text(text, style: AppText.small.copyWith(color: AppColors.inkSoft, fontWeight: FontWeight.w700)),
      ]);
}

/// Before the first custom gesture: what they are for, and the signs the glove already knows.
class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.builtIn});

  final List<String> builtIn;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpace.xl),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(color: AppColors.turqWash, shape: BoxShape.circle),
              child: const Icon(Icons.back_hand_rounded, color: AppColors.turqInk, size: 26),
            ),
            const SizedBox(height: 14),
            Text('No custom gestures yet', style: AppText.section),
            const SizedBox(height: 6),
            Text(
              'Teach the glove a sign for a word you need: a prayer, a medicine, a technical word or a '
              'name. It speaks your phrase in Malay or English.',
              style: AppText.body.copyWith(color: AppColors.inkSoft),
            ),
            const SizedBox(height: AppSpace.m),
            Text(
              'The glove already knows ${builtIn.join(', ')}. Make yours clearly different.',
              style: AppText.small.copyWith(color: AppColors.inkSoft),
            ),
          ],
        ),
      );
}

/// A category with nothing in it yet, and the way to record one there.
class _EmptyCategory extends StatelessWidget {
  const _EmptyCategory({required this.category, required this.onRecord});

  final GestureCategory category;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    final look = categoryLook(category);
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.xl, AppSpace.xl, AppSpace.s),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(look.icon, color: look.ink, size: 28),
          const SizedBox(height: 10),
          Text('No ${category.label.toLowerCase()} signs yet', style: AppText.section),
          const SizedBox(height: AppSpace.xs),
          Text('${look.hint}: record a sign for a word you need.', style: AppText.body.copyWith(color: AppColors.inkSoft)),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRecord,
              icon: const Icon(Icons.fiber_manual_record_rounded, size: 16, color: AppColors.recDot),
              label: const Text('Record one'),
              style: TextButton.styleFrom(foregroundColor: AppColors.turqInk),
            ),
          ),
        ],
      ),
    );
  }
}

/// The signs the glove knows already (labels, not buttons): custom ones should look different.
class _BuiltIn extends StatelessWidget {
  const _BuiltIn({required this.words});

  final List<String> words;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, AppSpace.l, 22, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('BUILT INTO THE GLOVE', style: AppText.eyebrow.copyWith(color: AppColors.inkSoft)),
            const SizedBox(height: 10),
            Wrap(
              spacing: AppSpace.s,
              runSpacing: AppSpace.s,
              children: [
                for (final word in words)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: AppColors.line, width: 1.5),
                    ),
                    child: Text(word, style: AppText.small.copyWith(color: AppColors.ink)),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.s),
            Text('Make your own signs clearly different from these.',
                style: AppText.small.copyWith(color: AppColors.inkSoft)),
          ],
        ),
      );
}
