import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../signer/sign_player.dart';
import '../theme/app_theme.dart';
import '../ui/widgets/gradient_button.dart';
import 'learn_progress.dart';
import 'learn_ui.dart';
import 'quiz_question.dart';
import 'results_screen.dart';

/// One quiz, question by question (README "Learn"): Teka Isyarat (the avatar signs, 10 s a
/// question) and, later, the Gemini quiz (text only). Every answer is shown with a colour AND an
/// icon AND a haptic; "Next" waits for a tap, so a wrong answer's replay can be watched.
class QuizScreen extends StatefulWidget {
  const QuizScreen({
    super.key,
    required this.title,
    required this.questions,
    required this.progress,
    this.timed = false,
    this.openClip = openAssetClip,
    this.again,
    this.badges = const [],
    this.onFinished,
  });

  static const timeLimit = Duration(seconds: 10);
  static const xpPerAnswer = 10;

  final String title;
  final List<QuizQuestion> questions;
  final LearnProgress progress;
  final bool timed;
  final ClipOpener openClip;

  /// Questions for "Play again" (a new round); null = no such button.
  final List<QuizQuestion>? Function()? again;

  /// Badges won by finishing this quiz (Study buddy for a Gemini quiz).
  final List<LearnBadge> badges;

  /// Told the score when the quiz is finished (a unit of the path keeps its stars); what it returns
  /// is shown on the Results screen ("Unit passed!").
  final String? Function(int right, int total)? onFinished;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

/// How an answer looks: not answered yet; the right one picked; the right one shown after a wrong
/// pick (or time up); the wrong one picked; the others.
enum _Look { idle, picked, shown, wrong, faded }

class _QuizScreenState extends State<QuizScreen> with SingleTickerProviderStateMixin {
  late final _player = SignPlayer(open: widget.openClip);
  // `preserve`: with "remove animations" on, Flutter runs normal animations 20 times faster;
  // the time to answer must stay 10 real seconds.
  late final _clock =
      AnimationController(vsync: this, duration: QuizScreen.timeLimit, animationBehavior: AnimationBehavior.preserve)
        ..addStatusListener((status) {
      if (status == AnimationStatus.completed) _answer(null); // time is up
    });
  var _at = 0;
  var _answered = false;
  int? _chosen;
  var _combo = 0;
  final _results = <bool>[]; // right or not, one per answered question
  var _finishing = false;

  QuizQuestion get _q => widget.questions[_at];
  int get _xp => _results.where((r) => r).length * QuizScreen.xpPerAnswer;

  @override
  void initState() {
    super.initState();
    _ask();
  }

  @override
  void dispose() {
    _clock.dispose();
    _player.dispose();
    super.dispose();
  }

  void _ask() {
    _answered = false;
    _chosen = null;
    if (_q.clips.isNotEmpty) _player.play(_q.clips);
    if (widget.timed) _clock.forward(from: 0);
  }

  void _answer(int? choice) {
    if (_answered) return;
    _clock.stop();
    final right = choice == _q.answer;
    setState(() {
      _answered = true;
      _chosen = choice;
      _combo = right ? _combo + 1 : 0;
      _results.add(right);
    });
    if (right) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.heavyImpact();
      if (_q.clips.isNotEmpty) _player.replay(); // once more, now knowing the answer
    }
  }

  Future<void> _next() async {
    if (_at + 1 < widget.questions.length) {
      setState(() => _at++);
      _ask();
      return;
    }
    if (_finishing) return;
    _finishing = true;
    final w = widget;
    final right = [for (final (i, q) in w.questions.indexed) if (_results[i]) q];
    final reward = await w.progress.finishRound(
      xp: _xp,
      letters: [for (final q in right) if (q.clipId?.startsWith('letter_') ?? false) q.clipId!.substring(7)],
      earned: w.badges,
    );
    final message = w.onFinished?.call(right.length, w.questions.length);
    if (!mounted) return;
    final again = w.again;
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      builder: (_) => ResultsScreen(
        title: w.title,
        right: right.length,
        total: w.questions.length,
        reward: reward,
        progress: w.progress,
        message: message,
        playAgain: again == null
            ? null
            : () => switch (again()) {
                  final questions? => QuizScreen(
                      title: w.title,
                      questions: questions,
                      progress: w.progress,
                      timed: w.timed,
                      openClip: w.openClip,
                      again: again,
                      badges: w.badges,
                      onFinished: w.onFinished,
                    ),
                  null => null,
                },
      ),
    ));
  }

  void _toggleSlow() => setState(() => _player.speed = _player.speed < 1 ? 1 : 0.5);

  @override
  Widget build(BuildContext context) {
    final q = _q;
    final reduced = AppMotion.reduced(context);
    final last = _at + 1 == widget.questions.length;
    final options = [
      for (final (i, option) in q.options.indexed)
        _OptionCard(
          key: ValueKey('$_at-$i'),
          option: option,
          look: !_answered
              ? _Look.idle
              : i == q.answer
                  ? (i == _chosen ? _Look.picked : _Look.shown)
                  : (i == _chosen ? _Look.wrong : _Look.faded),
          reduced: reduced,
          lines: q.clips.isEmpty ? 4 : 2, // a written answer can be longer than a sign's name
          onTap: _answered ? null : () => _answer(i),
        ),
    ];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.xs, AppSpace.gutter, AppSpace.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GameTopBar(
                  title: widget.title,
                  step: 'Question ${_at + 1} of ${widget.questions.length}',
                  combo: _combo,
                  xp: _xp,
                  reduced: reduced,
                ),
                ProgressDots(total: widget.questions.length, results: _results, at: _at),
                if (widget.timed) TimeBar(clock: _clock),
                const SizedBox(height: AppSpace.m),
                if (q.clips.isNotEmpty) ...[
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: LearnStage(player: _player, actions: [
                            StageButton(icon: Icons.replay_rounded, label: 'Sign it again', onTap: _player.replay),
                            StageButton(
                              icon: Icons.slow_motion_video_rounded,
                              label: 'Slower signing',
                              selected: _player.speed < 1,
                              onTap: _toggleSlow,
                            ),
                          ]),
                        ),
                        if (_answered && _chosen == q.answer && !reduced)
                          Positioned(left: 0, right: 0, bottom: AppSpace.l, child: Center(child: _XpFloat(key: ValueKey(_at)))),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpace.m),
                  Text(q.question, textAlign: TextAlign.center, style: AppText.section),
                  const SizedBox(height: AppSpace.m),
                  for (final row in const [0, 2]) // two rows of two answers
                    Padding(
                      padding: EdgeInsets.only(top: row == 0 ? 0 : 10),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: options[row]),
                            const SizedBox(width: 10),
                            Expanded(child: options[row + 1]),
                          ],
                        ),
                      ),
                    ),
                ] else
                  Expanded(
                    child: ListView(children: [
                      Text(q.question, style: AppText.section.copyWith(fontSize: 20, height: 1.35)),
                      const SizedBox(height: AppSpace.l),
                      for (final option in options) Padding(padding: const EdgeInsets.only(bottom: 10), child: option),
                    ]),
                  ),
                const SizedBox(height: AppSpace.m),
                _Feedback(question: q, answered: _answered, chosen: _chosen),
                const SizedBox(height: AppSpace.s),
                GradientButton(
                  label: last ? 'See results' : 'Next',
                  icon: last ? Icons.emoji_events_rounded : Icons.arrow_forward_rounded,
                  onTap: _answered ? _next : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    super.key,
    required this.option,
    required this.look,
    required this.reduced,
    required this.lines,
    required this.onTap,
  });

  final int lines; // most lines of the answer's text

  final QuizOption option;
  final _Look look;
  final bool reduced;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (fill, edge, ink, icon) = switch (look) {
      _Look.idle => (AppColors.surface, AppColors.line, AppColors.ink, null),
      _Look.picked => (AppColors.right, AppColors.right, AppColors.onDark, Icons.check_circle_rounded),
      _Look.shown => (AppColors.rightWash, AppColors.right, AppColors.right, Icons.check_circle_rounded),
      _Look.wrong => (AppColors.wrongWash, AppColors.danger, AppColors.wrongInk, Icons.cancel_rounded),
      _Look.faded => (AppColors.surface, AppColors.line, AppColors.inkFaint, null),
    };
    final state = switch (look) {
      _Look.picked => ', right',
      _Look.shown => ', the right answer',
      _Look.wrong => ', wrong',
      _ => '',
    };
    final glow = look == _Look.picked || look == _Look.shown;
    final Widget card = Semantics(
      button: true,
      enabled: onTap != null,
      label: '${option.text}${option.detail == null ? '' : ', ${option.detail}'}$state',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: edge, width: look == _Look.idle || look == _Look.faded ? 1.5 : 2),
          boxShadow: glow ? AppShadows.rightGlow : AppShadows.card,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.m, vertical: 10),
              child: Row(children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(option.text,
                          maxLines: lines,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.strong.copyWith(color: ink, fontSize: 15.5)),
                      if (option.detail case final detail?)
                        Text(detail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.small.copyWith(color: look == _Look.idle ? AppColors.inkSoft : ink)),
                    ],
                  ),
                ),
                if (icon != null) ...[const SizedBox(width: 6), Icon(icon, size: 22, color: ink)],
              ]),
            ),
          ),
        ),
      ),
    );
    if (reduced) return card;
    return switch (look) {
      _Look.picked => card.animate().scaleXY(begin: 0.92, end: 1, duration: 400.ms, curve: Curves.elasticOut),
      _Look.wrong => card.animate().shake(duration: 400.ms, hz: 5, offset: const Offset(6, 0)),
      _Look.shown => card.animate().scaleXY(begin: 0.96, end: 1, duration: 300.ms, curve: AppMotion.springCurve),
      _ => card,
    };
  }
}

/// What happened, in words (the colours and icons say it too): a hint before answering, then
/// right / wrong / time up with the right answer, and the question's explanation if it has one.
class _Feedback extends StatelessWidget {
  const _Feedback({required this.question, required this.answered, required this.chosen});

  final QuizQuestion question;
  final bool answered;
  final int? chosen;

  @override
  Widget build(BuildContext context) {
    final answer = question.correct.text;
    final (text, icon, colour) = !answered
        ? (question.clips.isEmpty ? 'Pick an answer.' : 'Watch the signer, then pick the meaning.', Icons.touch_app_outlined, AppColors.inkSoft)
        : chosen == question.answer
            ? ('Correct! +${QuizScreen.xpPerAnswer} XP', Icons.check_circle_rounded, AppColors.right)
            : chosen == null
                ? ("Time's up. It's $answer.", Icons.timer_off_outlined, AppColors.wrongInk)
                : ("Not quite. It's $answer.", Icons.cancel_rounded, AppColors.wrongInk);
    return Semantics(
      liveRegion: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 20, color: colour),
              const SizedBox(width: AppSpace.s),
              Expanded(child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.strong.copyWith(color: colour))),
            ]),
            if (answered && question.explain != null)
              Padding(
                padding: const EdgeInsets.only(left: 28, top: 2),
                child: Text(question.explain!, style: AppText.body.copyWith(color: AppColors.inkSoft)),
              ),
          ],
        ),
      ),
    );
  }
}

/// "+10 XP" floating up from the stage after a right answer (left out when motion is reduced; the
/// words under the answers say it anyway).
class _XpFloat extends StatelessWidget {
  const _XpFloat({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            gradient: AppGradients.sun,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: AppShadows.sunGlow,
          ),
          child: Text('+${QuizScreen.xpPerAnswer} XP', style: AppText.strong.copyWith(color: AppColors.onYellow)),
        )
            .animate()
            .moveY(begin: 0, end: -40, duration: 700.ms, curve: Curves.easeOut)
            .fadeOut(delay: 400.ms, duration: 300.ms),
      );
}
