import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../app/app_services.dart';
import '../signer/sign_player.dart';
import '../theme/app_theme.dart';
import '../ui/widgets/hero_panel.dart';
import 'learn_progress.dart';
import 'learn_ui.dart';
import 'learn_units.dart';
import 'note_signs.dart';
import 'quiz_question.dart';
import 'quiz_screen.dart';
import 'sign_lesson_screen.dart';
import 'sign_quest_screen.dart';
import 'teka_isyarat.dart';

IconData unitIcon(LearnUnit unit) => switch (unit.id) {
      'kenali_diri' => Icons.waving_hand_rounded,
      'jawab_tanya' => Icons.question_answer_rounded,
      'berbual' => Icons.forum_rounded,
      'agama' => Icons.mosque_rounded,
      _ => Icons.abc_rounded, // the letters
    };

/// Opens unit [i] of [units]: its sheet with the steps (watch, quiz, practise), or, while it is
/// locked, which unit opens it.
void openUnit(BuildContext context, AppServices services, List<LearnUnit> units, int i,
    {ClipOpener openClip = openAssetClip}) {
  final learn = services.learn;
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar(); // an earlier "locked" message would cover the lesson's buttons
  if (!unitOpen(units, learn, i)) {
    messenger.showSnackBar(SnackBar(content: Text('Pass "${units[i - 1].title}" to open this unit.')));
    return;
  }
  final unit = units[i];
  final next = i + 1 < units.length ? units[i + 1] : null;
  final ids = unit.available(services.signer.library);
  final navigator = Navigator.of(context);

  /// A unit quiz's stars, and what they mean (shown on Results).
  String rate(int right, int total) {
    final stars = quizStars(right, total);
    final opensNext = stars >= 2 && learn.unitStars(unit.id) < 2 && next != null;
    learn.rateUnit(unit.id, stars);
    if (stars == 3) return opensNext ? 'Perfect: 3 stars! "${next.title}" is open now.' : 'Perfect: 3 stars for "${unit.title}"!';
    if (stars == 2) return opensNext ? 'Unit passed! "${next.title}" is open now.' : 'Unit passed. Get them all right for 3 stars.';
    return 'Get ${unitPassMark(total)} of $total right to pass this unit.';
  }

  void lesson() => navigator.push(MaterialPageRoute<void>(
        builder: (_) => SignLessonScreen(
          services: services,
          title: unit.title,
          subtitle: 'Unit ${i + 1}',
          ids: ids,
          onWatchedAll: () => learn.rateUnit(unit.id, 1),
          onQuizDone: rate,
          openClip: openClip,
        ),
      ));

  void quiz() {
    List<QuizQuestion>? round() => tekaIsyaratRound(services.signer.library, only: ids, length: min(10, ids.length));
    final questions = round();
    if (questions == null) return;
    navigator.push(MaterialPageRoute<void>(
      builder: (_) => QuizScreen(
        title: unit.title,
        questions: questions,
        progress: learn,
        timed: true,
        openClip: openClip,
        again: round,
        onFinished: rate,
      ),
    ));
  }

  final gloveSigns = gloveSignsAmong(ids);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (sheet) {
      final stars = learn.unitStars(unit.id);
      void go(VoidCallback open) {
        Navigator.pop(sheet);
        open();
      }

      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(AppSpace.gutter, 0, AppSpace.gutter, MediaQuery.paddingOf(sheet).bottom + AppSpace.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              _UnitBadge(unit: unit, look: stars >= 2 ? _Look.passed : _Look.current, size: 54),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('UNIT ${i + 1} · ${unit.english.toUpperCase()}',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.eyebrow.copyWith(color: AppColors.turqInk)),
                    Text(unit.title, style: AppText.section.copyWith(fontSize: 20)),
                  ],
                ),
              ),
              _Stars(stars: stars, size: 20),
            ]),
            const SizedBox(height: AppSpace.m),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final id in ids)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(AppRadius.pill)),
                  child: Text(signAnswer(id).text, style: AppText.label.copyWith(color: AppColors.ink)),
                ),
            ]),
            const SizedBox(height: AppSpace.l),
            _Step(
              number: 1,
              title: 'Watch the signs',
              detail: '${ids.length} signs, one by one',
              done: stars >= 1,
              onTap: () => go(lesson),
            ),
            _Step(
              number: 2,
              title: 'Quiz',
              detail: switch (stars) {
                3 => 'Perfect: 3 stars',
                2 => 'Passed. Get them all right for 3 stars',
                _ => 'Get ${(unitPassShare * 100).round()} % right to pass${next == null ? '' : ' and open the next unit'}',
              },
              done: stars >= 2,
              onTap: () => go(quiz),
            ),
            if (gloveSigns.isNotEmpty)
              _Step(
                number: 3,
                title: 'Practise with the glove',
                detail: 'Sign Quest · optional',
                done: false,
                onTap: () => go(() => navigator.push(MaterialPageRoute<void>(
                      builder: (_) => SignQuestScreen(services: services, signs: gloveSigns, openClip: openClip),
                    ))),
              ),
          ],
        ),
      );
    },
  );
}

/// One step of a unit: its number (a tick once done), what to do, and the way in.
class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title, required this.detail, required this.done, required this.onTap});

  final int number;
  final String title;
  final String detail;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '$title. $detail.${done ? ' Done.' : ''}',
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: done ? AppColors.right : AppColors.turqWash, shape: BoxShape.circle),
                child: done
                    ? const Icon(Icons.check_rounded, size: 20, color: AppColors.onDark)
                    : Text('$number', style: AppText.strong.copyWith(color: AppColors.turqInk)),
              ),
              const SizedBox(width: AppSpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.strong.copyWith(color: AppColors.ink)),
                    Text(detail, style: AppText.small.copyWith(color: AppColors.inkSoft)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
            ]),
          ),
        ),
      );
}

enum _Look { locked, current, open, passed }

_Look _lookOf(List<LearnUnit> units, LearnProgress learn, int i, int? current) {
  if (!unitOpen(units, learn, i)) return _Look.locked;
  if (learn.unitStars(units[i].id) >= 2) return i == current ? _Look.current : _Look.passed;
  return i == current ? _Look.current : _Look.open;
}

/// A unit's round mark: grey with a lock (locked), yellow (the one to do now), white (open),
/// turquoise (passed).
class _UnitBadge extends StatelessWidget {
  const _UnitBadge({required this.unit, required this.look, this.size = 76});

  final LearnUnit unit;
  final _Look look;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: switch (look) { _Look.current => AppGradients.sun, _Look.passed => AppGradients.turq, _ => null },
          color: switch (look) { _Look.locked => AppColors.surface2, _Look.open => AppColors.surface, _ => null },
          border: Border.all(
            color: look == _Look.current ? AppColors.onDark : AppColors.line,
            width: look == _Look.current ? 4 : 2,
          ),
          boxShadow: switch (look) {
            _Look.current => AppShadows.sunGlow,
            _Look.passed => AppShadows.turqTile,
            _ => AppShadows.card,
          },
        ),
        child: Icon(
          look == _Look.locked ? Icons.lock_rounded : unitIcon(unit),
          size: size * 0.44,
          color: switch (look) {
            _Look.locked => AppColors.inkFaint,
            _Look.current => AppColors.onYellow,
            _Look.passed => AppColors.onDark,
            _Look.open => AppColors.turqInk,
          },
        ),
      );
}

class _Stars extends StatelessWidget {
  const _Stars({required this.stars, this.size = 18});

  final int stars;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '$stars of 3 stars',
        excludeSemantics: true,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < 3; i++)
            Icon(i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                size: size, color: i < stars ? AppColors.onYellowInk : AppColors.inkFaint),
        ]),
      );
}

/// Learn's path (README "Learn"): the units in order on a winding dotted line. Passing a unit's quiz
/// opens the next one; each unit has up to 3 stars (watched, passed, perfect).
class LearnPathScreen extends StatelessWidget {
  const LearnPathScreen({super.key, required this.services, this.openClip = openAssetClip});

  final AppServices services;
  final ClipOpener openClip;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: AppColors.bg,
          body: ListenableBuilder(
            listenable: Listenable.merge([services.learn, services.signer]),
            builder: (context, _) {
              final learn = services.learn;
              final units = pathUnits(services.signer.library);
              final passed = unitsPassed(units, learn);
              return ListView(
                padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + AppSpace.xxl),
                children: [
                  HeroPanel(
                    bottomPadding: AppSpace.xxl,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const GlassBackButton(),
                        const SizedBox(height: AppSpace.s),
                        Text('YOUR PATH', style: AppText.eyebrow.copyWith(color: AppColors.yellow)),
                        const SizedBox(height: AppSpace.xs),
                        Text('Learning path', style: AppText.heroTitle),
                        const SizedBox(height: AppSpace.xs),
                        Text('$passed of ${units.length} units passed · pass a unit to open the next',
                            style: AppText.small.copyWith(color: AppColors.onDarkSoft, fontSize: 13)),
                        const SizedBox(height: AppSpace.m),
                        LinearProgressIndicator(
                          value: units.isEmpty ? 0 : passed / units.length,
                          minHeight: 8,
                          color: AppColors.yellow,
                          backgroundColor: AppColors.glass,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpace.xl),
                  if (units.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppSpace.xl),
                      child: Text('The units appear once the app has the sign clips.',
                          textAlign: TextAlign.center, style: AppText.body.copyWith(color: AppColors.inkSoft)),
                    )
                  else
                    _PathMap(
                      units: units,
                      learn: learn,
                      onOpen: (i) => openUnit(context, services, units, i, openClip: openClip),
                    ),
                ],
              );
            },
          ),
        ),
      );
}

/// The units zig-zagging down the page, joined by a dotted line (turquoise where it is passed).
class _PathMap extends StatelessWidget {
  const _PathMap({required this.units, required this.learn, required this.onOpen});

  final List<LearnUnit> units;
  final LearnProgress learn;
  final ValueChanged<int> onOpen;

  static const _row = 176.0; // height of one unit
  static const _badge = 76.0;
  static const _sway = [0.0, 0.62, 0.0, -0.62]; // where each unit sits: centre, right, centre, left

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final width = box.maxWidth;
        final reach = width / 2 - 90; // the badge and its words stay on the screen
        final current = currentUnit(units, learn);
        final centres = [
          for (var i = 0; i < units.length; i++) Offset(width / 2 + _sway[i % _sway.length] * reach, i * _row + _badge / 2),
        ];
        return SizedBox(
          height: units.length * _row,
          child: Stack(children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _Trail(centres, [for (final u in units) learn.unitStars(u.id) >= 2]),
              ),
            ),
            for (final (i, unit) in units.indexed)
              Positioned(
                left: centres[i].dx - 80,
                top: i * _row,
                width: 160,
                child: _UnitNode(
                  unit: unit,
                  number: i + 1,
                  look: _lookOf(units, learn, i, current),
                  stars: learn.unitStars(unit.id),
                  onTap: () => onOpen(i),
                ),
              ),
          ]),
        );
      });
}

class _UnitNode extends StatelessWidget {
  const _UnitNode({
    required this.unit,
    required this.number,
    required this.look,
    required this.stars,
    required this.onTap,
  });

  final LearnUnit unit;
  final int number;
  final _Look look;
  final int stars;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locked = look == _Look.locked;
    return Semantics(
      button: true,
      label: 'Unit $number, ${unit.title}, ${unit.english}. '
          '${switch (look) { _Look.locked => 'Locked', _Look.current => 'Next to do', _Look.open => 'Open', _Look.passed => 'Passed' }}. '
          '$stars of 3 stars.',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _UnitBadge(unit: unit, look: look),
            const SizedBox(height: 6),
            _Stars(stars: stars, size: 16),
            Text(unit.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppText.strong.copyWith(color: locked ? AppColors.inkFaint : AppColors.ink, fontSize: 14)),
            Text('Unit $number · ${unit.english}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppText.small.copyWith(color: AppColors.inkSoft, fontSize: 11.5)),
          ],
        ),
      ),
    );
  }
}

/// Dots from one unit to the next; turquoise after a passed unit, grey before.
class _Trail extends CustomPainter {
  _Trail(this.centres, this.passed, {this.gap = 46, this.reveal = 1});

  final List<Offset> centres;
  final List<bool> passed;
  final double gap; // no dots this close to a unit's centre (under its badge)
  final double reveal; // 0..1: how much of the trail is drawn yet (it draws itself in, left to right)

  @override
  void paint(Canvas canvas, Size size) {
    final segments = centres.length - 1;
    for (var i = 0; i < segments; i++) {
      final a = centres[i], b = centres[i + 1];
      final paint = Paint()..color = passed[i] ? AppColors.turq : AppColors.line;
      final length = (b - a).distance;
      for (var d = gap; d < length - gap; d += 12) {
        if ((i + d / length) / segments > reveal) return;
        canvas.drawCircle(Offset.lerp(a, b, d / length)!, 3, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_Trail old) =>
      old.gap != gap ||
      old.reveal != reveal ||
      old.centres.toString() != centres.toString() ||
      old.passed.toString() != passed.toString();
}

/// The yellow NEXT tag over the unit to do; it bobs gently like a marker on a game map.
class _NextTag extends StatelessWidget {
  const _NextTag({required this.bob});

  final bool bob;

  @override
  Widget build(BuildContext context) {
    final tag = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: AppColors.yellow, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Text('NEXT', style: AppText.tiny.copyWith(color: AppColors.onYellow)),
    );
    if (!bob) return tag;
    return RepaintBoundary(
      child: tag
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .moveY(begin: 0, end: -3, duration: 900.ms, curve: Curves.easeInOut),
    );
  }
}

/// The hub's view of the path: the unit to do next among its neighbours (up to 4) on a dotted line,
/// the next one marked NEXT; a tap opens a unit (or says which unit opens it).
class MiniPath extends StatelessWidget {
  const MiniPath({super.key, required this.services, this.openClip = openAssetClip});

  final AppServices services;
  final ClipOpener openClip;

  static const _badge = 52.0;
  static const _tag = 20.0; // room above the badges for the NEXT tag

  @override
  Widget build(BuildContext context) {
    final learn = services.learn;
    final units = pathUnits(services.signer.library);
    if (units.isEmpty) return const SizedBox.shrink();
    final current = currentUnit(units, learn);
    final start = max(0, min((current ?? units.length - 1) - 1, units.length - 4)); // the next one second from the left
    final shown = [for (var i = start; i < min(units.length, start + 4); i++) i];
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpace.xs, AppSpace.m, AppSpace.xs, AppSpace.m),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22), boxShadow: AppShadows.card),
      child: LayoutBuilder(builder: (context, box) {
        final cell = box.maxWidth / shown.length;
        final centres = [for (var k = 0; k < shown.length; k++) Offset(cell * (k + 0.5), _tag + _badge / 2)];
        final reduced = AppMotion.reduced(context);
        return Stack(children: [
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              // the trail draws itself from the first unit to the last when the hub opens
              tween: Tween(begin: reduced ? 1 : 0, end: 1),
              duration: reduced ? Duration.zero : const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, reveal, _) => CustomPaint(
                painter: _Trail(centres, [for (final i in shown) learn.unitStars(units[i].id) >= 2],
                    gap: _badge / 2 + 6, reveal: reveal),
              ),
            ),
          ),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final i in shown)
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Unit ${i + 1}, ${units[i].title}. ${learn.unitStars(units[i].id)} of 3 stars.'
                      '${i == current ? ' Next to do.' : unitOpen(units, learn, i) ? '' : ' Locked.'}',
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => openUnit(context, services, units, i, openClip: openClip),
                    child: Column(children: [
                      SizedBox(
                        height: _tag,
                        child: i == current ? _NextTag(bob: !reduced) : null,
                      ),
                      _UnitBadge(unit: units[i], look: _lookOf(units, learn, i, current), size: _badge),
                      const SizedBox(height: 4),
                      _Stars(stars: learn.unitStars(units[i].id), size: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Text(units[i].title,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.small.copyWith(
                                color: unitOpen(units, learn, i) ? AppColors.ink : AppColors.inkSoft, fontSize: 11.5)),
                      ),
                    ]),
                  ),
                ),
              ),
          ]),
        ]);
      }),
    );
  }
}
