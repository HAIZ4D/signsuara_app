import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_theme.dart';
import '../ui/widgets/gradient_button.dart';
import '../ui/widgets/hero_panel.dart';
import 'learn_progress.dart';
import 'learn_ui.dart';

/// After a round (README "Learn"): the score, the XP counting up, level, streak and new badges.
class ResultsScreen extends StatelessWidget {
  const ResultsScreen({
    super.key,
    required this.title,
    required this.right,
    required this.total,
    required this.reward,
    required this.progress,
    this.unit = 'right',
    this.playAgain,
    this.message,
  });

  final String title;
  final int right;
  final int total;
  final String unit; // what is counted: answers "right", or "stars"
  final RoundReward reward;
  final LearnProgress progress;
  final Widget? Function()? playAgain; // the next round's screen; null = no "Play again"
  final String? message; // what the round meant, e.g. for a unit of the path ("Unit passed!")

  String get _cheer => right == total
      ? 'Perfect score!'
      : right * 10 >= total * 7
          ? 'Great work!'
          : right * 10 >= total * 4
              ? 'Good try!'
              : 'Keep practising!';

  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.reduced(context);
    final streak = progress.streak;
    Widget popIn(Widget badge) =>
        reduced ? badge : badge.animate().scaleXY(begin: 0.4, end: 1, duration: 400.ms, curve: Curves.elasticOut);
    final best = right == total || reward.levelUp;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: _Celebration(
          confetti: best,
          buzz: best || reward.badges.isNotEmpty,
          child: ListView(
          padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + AppSpace.xxl),
          children: [
            HeroPanel(
              bottomPadding: AppSpace.xxl + AppSpace.s,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title.toUpperCase(), style: AppText.eyebrow.copyWith(color: AppColors.yellow)),
                  const SizedBox(height: 6),
                  Text(_cheer, style: AppText.heroTitle),
                  const SizedBox(height: AppSpace.l),
                  Semantics(
                    label: '$right of $total $unit',
                    excludeSemantics: true,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('$right', style: AppText.heroTitle.copyWith(fontSize: 64, height: 1)),
                        Text(' / $total', style: AppText.heroTitle.copyWith(fontSize: 26, color: AppColors.onDarkSoft)),
                        const SizedBox(width: 10),
                        Flexible(child: Text(unit, style: AppText.label.copyWith(color: AppColors.onDarkSoft, fontSize: 14))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.l, AppSpace.gutter, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (message case final message?) ...[
                    Semantics(
                      liveRegion: true,
                      child: Container(
                        padding: const EdgeInsets.all(AppSpace.l),
                        decoration: BoxDecoration(color: AppColors.yellowWash, borderRadius: BorderRadius.circular(22)),
                        child: Row(children: [
                          const Icon(Icons.route_rounded, color: AppColors.onYellowInk),
                          const SizedBox(width: AppSpace.m),
                          Expanded(child: Text(message, style: AppText.strong.copyWith(color: AppColors.onYellow))),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(gradient: AppGradients.sun, shape: BoxShape.circle),
                            child: const Icon(Icons.bolt_rounded, color: AppColors.onYellow),
                          ),
                          const SizedBox(width: AppSpace.m),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TweenAnimationBuilder<int>(
                                  tween: IntTween(begin: 0, end: reward.xp),
                                  duration: reduced ? Duration.zero : const Duration(milliseconds: 900),
                                  curve: AppMotion.outCurve,
                                  builder: (context, xp, _) => Text('+$xp XP',
                                      semanticsLabel: '${reward.xp} XP earned',
                                      style: AppText.heroTitle.copyWith(color: AppColors.ink, fontSize: 28)),
                                ),
                                Text('earned this round', style: AppText.small.copyWith(color: AppColors.inkSoft)),
                              ],
                            ),
                          ),
                        ]),
                        const SizedBox(height: AppSpace.l),
                        LevelLine(
                          learn: progress,
                          level: AppText.strong.copyWith(color: AppColors.ink),
                          xp: AppText.small.copyWith(color: AppColors.inkSoft),
                        ),
                        const SizedBox(height: 6),
                        XpBar(progress: progress, track: AppColors.surface2),
                        if (reward.levelUp) ...[
                          const SizedBox(height: AppSpace.m),
                          Text('Level up! You reached level ${progress.level}.',
                              style: AppText.strong.copyWith(color: AppColors.turqInk)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _Card(
                    child: Row(children: [
                      const Icon(Icons.local_fire_department_rounded, color: AppColors.onYellowInk, size: 30),
                      const SizedBox(width: AppSpace.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(streak == 1 ? '1-day streak' : '$streak-day streak',
                                style: AppText.strong.copyWith(color: AppColors.ink)),
                            Text('Play again tomorrow to keep it going.',
                                style: AppText.small.copyWith(color: AppColors.inkSoft)),
                          ],
                        ),
                      ),
                    ]),
                  ),
                  if (reward.badges.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(reward.badges.length == 1 ? 'New badge' : 'New badges', style: AppText.section),
                          for (final badge in reward.badges)
                            Padding(
                              padding: const EdgeInsets.only(top: AppSpace.m),
                              child: Row(children: [
                                popIn(BadgeMark(badge: badge, unlocked: true, size: 48)),
                                const SizedBox(width: AppSpace.m),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(badge.title, style: AppText.strong.copyWith(color: AppColors.ink)),
                                      Text(badge.how, style: AppText.small.copyWith(color: AppColors.inkSoft)),
                                    ],
                                  ),
                                ),
                              ]),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpace.xl),
                  if (playAgain case final playAgain?)
                    GradientButton(
                      label: 'Play again',
                      icon: Icons.replay_rounded,
                      onTap: () {
                        final next = playAgain();
                        if (next != null) Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => next));
                      },
                    ),
                  const SizedBox(height: AppSpace.s),
                  TextButton(
                    onPressed: () => Navigator.maybePop(context),
                    style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    child: Text('Back to Learn', style: AppText.strong.copyWith(color: AppColors.turqInk)),
                  ),
                ],
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

/// A perfect score or a new level: a second of confetti in the Deaf Flag colours (none when the
/// phone asks for less motion). Anything worth celebrating (also a new badge) buzzes once.
class _Celebration extends StatefulWidget {
  const _Celebration({required this.confetti, required this.buzz, required this.child});

  final bool confetti;
  final bool buzz;
  final Widget child;

  @override
  State<_Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<_Celebration> {
  final _confetti = ConfettiController(duration: const Duration(seconds: 1));
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.buzz) HapticFeedback.mediumImpact();
    if (widget.confetti && !AppMotion.reduced(context)) _confetti.play();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Positioned.fill(child: widget.child),
          if (widget.confetti && !AppMotion.reduced(context))
            Align(
              alignment: const Alignment(0, -0.75),
              child: IgnorePointer(
                child: ConfettiWidget(
                  confettiController: _confetti,
                  blastDirectionality: BlastDirectionality.explosive,
                  numberOfParticles: 16,
                  emissionFrequency: 0.06,
                  minBlastForce: 8,
                  maxBlastForce: 24,
                  gravity: 0.25,
                  minimumSize: const Size(10, 6),
                  maximumSize: const Size(16, 9),
                  colors: const [AppColors.turqBright, AppColors.yellow, AppColors.royal, AppColors.onDark],
                ),
              ),
            ),
        ],
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpace.l),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          boxShadow: AppShadows.card,
        ),
        child: child,
      );
}
