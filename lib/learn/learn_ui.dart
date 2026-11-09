import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../signer/sign_clips.dart';
import '../signer/sign_player.dart';
import '../signer/sign_player_view.dart';
import '../theme/app_theme.dart';
import '../ui/widgets/baked_gradients.dart';
import 'learn_progress.dart';

/// The avatar's reaction clips (optional: every game works without them; README "Learn").
abstract final class LearnClips {
  static const wave = 'wave', cheer = 'cheer', tryAgain = 'try_again';
  static const reactions = {wave, cheer, tryAgain};
}

/// What the avatar plays to show sign [id]. A letter clip starts and ends with the hand up where
/// letters are signed, so the hand rises to it first and comes down after (as in Listen,
/// SignClipLibrary.plan) when those clips exist.
List<String> clipsToShow(SignClipLibrary library, String id) {
  final spelling = id.startsWith('letter_') || id.startsWith('number_');
  final wrap = library.ids.contains(SignClipLibrary.spellIn) && library.ids.contains(SignClipLibrary.spellOut);
  return spelling && wrap ? [SignClipLibrary.spellIn, id, SignClipLibrary.spellOut] : [id];
}

/// A game's top bar: leave, its name, which question or sign, the combo and this round's XP.
class GameTopBar extends StatelessWidget {
  const GameTopBar({
    super.key,
    required this.title,
    required this.step,
    required this.combo,
    required this.xp,
    required this.reduced,
  });

  final String title;
  final String step; // "Question 3 of 10"
  final int combo;
  final int xp;
  final bool reduced;

  @override
  Widget build(BuildContext context) {
    Widget comboChip = GamePill(
      icon: Icons.local_fire_department_rounded,
      text: 'Combo x$combo',
      fill: AppColors.yellow,
      ink: AppColors.onYellow,
    );
    if (!reduced) {
      comboChip = comboChip.animate(key: ValueKey(combo)).scaleXY(begin: 0.6, end: 1, duration: 400.ms, curve: Curves.elasticOut);
    }
    return Row(
      children: [
        IconButton(
          tooltip: 'Leave the game',
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.close_rounded, color: AppColors.ink),
        ),
        const SizedBox(width: AppSpace.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.section),
              Text(step, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.small.copyWith(color: AppColors.inkSoft)),
            ],
          ),
        ),
        if (combo >= 2) ...[comboChip, const SizedBox(width: 6)],
        GamePill(icon: Icons.bolt_rounded, text: '$xp XP', fill: AppColors.yellowWash, ink: AppColors.onYellow),
      ],
    );
  }
}

class GamePill extends StatelessWidget {
  const GamePill({super.key, required this.icon, required this.text, required this.fill, required this.ink});

  final IconData icon;
  final String text;
  final Color fill;
  final Color ink;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
        decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: ink),
          const SizedBox(width: 4),
          Text(text, style: AppText.label.copyWith(color: ink)),
        ]),
      );
}

/// One dot per question or sign: green = right, red = wrong, turquoise = now, grey = to come. The
/// words in the top bar ("Question n of m") say the same without colour.
class ProgressDots extends StatelessWidget {
  const ProgressDots({super.key, required this.total, required this.results, required this.at});

  final int total;
  final List<bool> results;
  final int at;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.s, AppSpace.xs, AppSpace.s, AppSpace.xs),
          child: Row(children: [
            for (var i = 0; i < total; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  height: 5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    color: i < results.length
                        ? (results[i] ? AppColors.right : AppColors.danger)
                        : (i == at ? AppColors.turq : AppColors.line),
                  ),
                ),
              ),
            ],
          ]),
        ),
      );
}

/// The time left, as a shrinking bar and in seconds (red for the last 3). [clock] runs over the
/// whole time; its controller must use AnimationBehavior.preserve (see QuizScreen).
class TimeBar extends StatelessWidget {
  const TimeBar({super.key, required this.clock});

  final AnimationController clock;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.s, AppSpace.xs, AppSpace.s, 0),
        child: AnimatedBuilder(
          animation: clock,
          builder: (context, _) {
            final left = 1 - clock.value;
            final seconds = (clock.duration!.inMilliseconds * left / 1000).ceil();
            final hurry = seconds <= 3;
            final colour = hurry ? AppColors.danger : AppColors.turq;
            return Row(children: [
              Icon(Icons.timer_outlined, size: 16, color: colour),
              const SizedBox(width: 6),
              Expanded(
                child: LinearProgressIndicator(
                  value: left,
                  minHeight: 8,
                  color: colour,
                  backgroundColor: AppColors.line,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              const SizedBox(width: AppSpace.s),
              SizedBox(
                width: 28,
                child: Text('${seconds}s',
                    textAlign: TextAlign.end,
                    style: AppText.label.copyWith(color: hurry ? AppColors.wrongInk : AppColors.inkSoft)),
              ),
            ]);
          },
        ),
      );
}

/// The light "studio" with the avatar (the same look as the Listen stage). Needs a bounded size.
class LearnStage extends StatelessWidget {
  const LearnStage({super.key, required this.player, this.actions = const []});

  final SignPlayer player;
  final List<Widget> actions; // small round buttons in the top right corner

  static const _corners = BorderRadius.all(Radius.circular(AppRadius.lg));

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(borderRadius: _corners, boxShadow: AppShadows.card),
        child: Stack(
          children: [
            const Positioned.fill(
              child: BakedGradients(
                layers: [AppGradients.studio, AppGradients.spotlight, AppGradients.stageWarm],
                borderRadius: _corners,
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.m, AppSpace.l, AppSpace.m, AppSpace.xs),
                child: ExcludeSemantics(child: SignPlayerView(player: player)),
              ),
            ),
            if (actions.isNotEmpty) Positioned(top: 4, right: 4, child: Row(children: actions)),
          ],
        ),
      );
}

/// A small round button on the stage (sign again, slower), with a 48 dp tap area.
class StageButton extends StatelessWidget {
  const StageButton({super.key, required this.icon, required this.label, required this.onTap, this.selected = false});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        enabled: onTap != null,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox.square(
              dimension: 48,
              child: Center(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? AppColors.turq : AppColors.surface,
                    border: Border.all(color: selected ? AppColors.turq : AppColors.line),
                    boxShadow: AppShadows.blueTile,
                  ),
                  child: Icon(icon, size: 18, color: selected ? AppColors.onDark : AppColors.ink),
                ),
              ),
            ),
          ),
        ),
      );
}

/// Round see-through back button on the dark headers.
class GlassBackButton extends StatelessWidget {
  const GlassBackButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(Icons.arrow_back_rounded, size: 21, color: AppColors.onDark),
        style: IconButton.styleFrom(
          backgroundColor: AppColors.glass,
          side: const BorderSide(color: AppColors.glassBorder),
          fixedSize: const Size.square(44),
        ),
      );
}

/// How far into the current level ([LearnProgress.xpInLevel]), as a rounded bar.
class XpBar extends StatelessWidget {
  const XpBar({super.key, required this.progress, this.color = AppColors.yellow, this.track = AppColors.glass, this.height = 8});

  final LearnProgress progress;
  final Color color;
  final Color track;
  final double height;

  @override
  Widget build(BuildContext context) => LinearProgressIndicator(
        value: progress.xpInLevel / LearnProgress.xpPerLevel,
        minHeight: height,
        color: color,
        backgroundColor: track,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      );
}

/// "Level 2 ........ 40 / 100 XP"; both sides shrink (with …) rather than overflow on big text.
class LevelLine extends StatelessWidget {
  const LevelLine({super.key, required this.learn, required this.level, required this.xp});

  final LearnProgress learn;
  final TextStyle level;
  final TextStyle xp;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text('Level ${learn.level}', maxLines: 1, overflow: TextOverflow.ellipsis, style: level)),
        const SizedBox(width: AppSpace.s),
        Flexible(
          child: Text('${learn.xpInLevel} / ${LearnProgress.xpPerLevel} XP',
              maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end, style: xp),
        ),
      ]);
}

IconData badgeIcon(LearnBadge badge) => switch (badge) {
      LearnBadge.firstSign => Icons.back_hand_rounded,
      LearnBadge.alphabetMaster => Icons.abc_rounded,
      LearnBadge.studyBuddy => Icons.menu_book_rounded,
      LearnBadge.streak7 => Icons.local_fire_department_rounded,
    };

/// A round progress ring with something in the middle (the hub's level and today's goal). It fills
/// up when it first appears and when [value] changes (at once when motion is reduced).
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    required this.child,
    this.size = 52,
    this.width = 5,
    this.color = AppColors.yellow,
    this.track = AppColors.glassBorder,
  });

  final double value; // 0..1
  final Widget child;
  final double size;
  final double width;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
        duration: AppMotion.reduced(context) ? Duration.zero : const Duration(milliseconds: 900),
        curve: AppMotion.outCurve,
        builder: (context, v, child) => CustomPaint(painter: _Ring(v, color, track, width), child: child),
        child: SizedBox.square(dimension: size, child: Center(child: child)),
      );
}

class _Ring extends CustomPainter {
  _Ring(this.value, this.color, this.track, this.width);

  final double value;
  final Color color;
  final Color track;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(width / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    if (track.a > 0) canvas.drawArc(rect, 0, 2 * pi, false, paint..color = track);
    if (value > 0) canvas.drawArc(rect, -pi / 2, 2 * pi * value, false, paint..color = color);
  }

  @override
  bool shouldRepaint(_Ring old) => old.value != value || old.color != color || old.track != track || old.width != width;
}

/// A ring that pings out from a round button every 1.8 s while something waits to be done (the sign
/// of the day not watched yet). Still when motion is reduced. Only this ring redraws.
class PingRing extends StatefulWidget {
  const PingRing({super.key, required this.child, required this.color, this.active = true});

  final Widget child;
  final Color color;
  final bool active;

  @override
  State<PingRing> createState() => _PingRingState();
}

class _PingRingState extends State<PingRing> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(PingRing old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() => widget.active && !AppMotion.reduced(context) ? _c.repeat() : _c.reset();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final t = Curves.easeOut.transform(_c.value);
                  return Opacity(
                    opacity: _c.isAnimating ? (1 - t) * 0.6 : 0,
                    child: Transform.scale(
                      scale: 1 + 0.55 * t,
                      child: DecoratedBox(
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: widget.color, width: 2)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          widget.child,
        ],
      );
}

/// A badge: a gold circle once unlocked, grey with a lock before; [progress] (0..1) draws how close
/// a locked one is as a turquoise ring around it.
class BadgeMark extends StatelessWidget {
  const BadgeMark({super.key, required this.badge, required this.unlocked, this.size = 56, this.progress});

  final LearnBadge badge;
  final bool unlocked;
  final double size;
  final double? progress;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: unlocked ? AppGradients.sun : null,
                color: unlocked ? null : AppColors.surface2,
                border: unlocked ? null : Border.all(color: AppColors.line, width: 1.5),
                boxShadow: unlocked ? AppShadows.sunGlow : null,
              ),
              child: Center(
                child: Icon(badgeIcon(badge), size: size * 0.48, color: unlocked ? AppColors.onYellow : AppColors.inkFaint),
              ),
            ),
            if (!unlocked && (progress ?? 0) > 0)
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  // fills up like the hub's rings (at once when motion is reduced)
                  tween: Tween(begin: 0, end: progress!.clamp(0.0, 1.0)),
                  duration: AppMotion.reduced(context) ? Duration.zero : const Duration(milliseconds: 900),
                  curve: AppMotion.outCurve,
                  builder: (context, v, _) => CustomPaint(painter: _Ring(v, AppColors.turq, Colors.transparent, 3.5)),
                ),
              ),
            if (!unlocked)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Icon(Icons.lock_rounded, size: size * 0.22, color: AppColors.inkFaint),
                ),
              ),
          ],
        ),
      );
}
