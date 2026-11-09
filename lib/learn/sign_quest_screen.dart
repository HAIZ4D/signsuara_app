import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../app/app_services.dart';
import '../glove/glove_session.dart';
import '../ml/gesture_classifier.dart';
import '../ml/signsuara_model.dart';
import '../signer/sign_player.dart';
import '../theme/app_theme.dart';
import '../ui/widgets/glove_card.dart';
import '../ui/widgets/gradient_button.dart';
import 'finger_meter.dart';
import 'learn_progress.dart';
import 'learn_ui.dart';
import 'results_screen.dart';
import 'sign_targets.dart';

/// Sign Quest (README "Learn"): the avatar shows a sign, you copy it with the glove. The glove's own
/// recogniser decides (the same model and rules as Chat). While the game is open, signs go only to
/// it: nothing is spoken by Chat or added to the conversation, and custom gestures are off.
class SignQuestScreen extends StatefulWidget {
  const SignQuestScreen({super.key, required this.services, required this.signs, this.openClip = openAssetClip});

  final AppServices services;
  final List<String> signs; // model labels, one per turn
  final ClipOpener openClip; // tests give made-up clips

  static const tries = 3;
  static const xpPerStar = 5;

  /// Time to make the sign, counted from the moment the glove can first answer ([warmUp]).
  static const signTime = Duration(seconds: 6);

  /// From an empty start the recogniser needs a full window (38 rows) and the same answer twice
  /// (5 rows apart) before it can accept anything: 45 rows at 25 a second = 1.8 s after "Go".
  static final warmUp = Duration(
      milliseconds: ((kWindowSize / GestureClassifier.predictEvery).ceil() + 1) * GestureClassifier.predictEvery * 40);

  /// Stars by how fast the glove accepted the sign, counted after [warmUp].
  static int starsFor(Duration time) => time < const Duration(seconds: 2)
      ? 3
      : time < const Duration(seconds: 4)
          ? 2
          : 1;

  @override
  State<SignQuestScreen> createState() => _SignQuestScreenState();
}

/// watch: the avatar shows the sign; countdown: 3-2-1; signing: the glove decides; right: done;
/// missed: time ran out (try again, or after the last try the next sign).
enum _Phase { watch, countdown, signing, right, missed }

class _SignQuestScreenState extends State<SignQuestScreen> with TickerProviderStateMixin {
  late final _player = SignPlayer(open: widget.openClip);
  // `preserve`: real seconds also when the phone's "remove animations" is on (see QuizScreen).
  late final _countdown = AnimationController(
      vsync: this, duration: const Duration(seconds: 3), animationBehavior: AnimationBehavior.preserve)
    ..addListener(_tickCountdown)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) _go();
    });
  var _shown = 0; // the countdown number last felt
  late final _clock = AnimationController(
      vsync: this,
      duration: SignQuestScreen.warmUp + SignQuestScreen.signTime,
      animationBehavior: AnimationBehavior.preserve)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) _timeUp();
    });
  final _row = ValueNotifier<List<double>?>(null); // the meter redraws from these, not the screen
  final _hold = ValueNotifier<double>(0);
  var _phase = _Phase.watch;
  var _at = 0;
  var _try = 1;
  var _combo = 0;
  final _stars = <int>[]; // one per finished sign
  String? _seen; // another sign the glove saw during this try
  var _link = GloveLink.disconnected;
  var _sensorDead = false;
  var _finishing = false;

  GloveSession get _session => widget.services.session;
  String get _label => widget.signs[_at];
  bool get _gloveReady => _link == GloveLink.connected && !_sensorDead;
  int get _xp => _stars.fold(0, (a, b) => a + b) * SignQuestScreen.xpPerStar;
  List<String> get _clips => clipsToShow(widget.services.signer.library, signClipFor(_label));

  @override
  void initState() {
    super.initState();
    widget.services
      ..gestureOverride = _onSign
      ..customGesturesOn = false;
    _session
      ..recognitionPaused = true // on again, with an empty window, at "Go"
      ..addRowListener(_onRow)
      ..addListener(_onGlove);
    _link = _session.link;
    _row.value = _session.lastRow;
    _show();
  }

  @override
  void dispose() {
    final services = widget.services;
    if (services.gestureOverride == _onSign) services.gestureOverride = null;
    services.customGesturesOn = true;
    _session
      ..recognitionPaused = false
      ..removeRowListener(_onRow)
      ..removeListener(_onGlove);
    _countdown.dispose();
    _clock.dispose();
    _player.dispose();
    _row.dispose();
    _hold.dispose();
    super.dispose();
  }

  void _show() {
    _phase = _Phase.watch;
    _seen = null;
    _hold.value = 0;
    _clock.value = 0;
    _player.play(_clips);
  }

  void _ready() {
    if (!_gloveReady) return;
    setState(() {
      _phase = _Phase.countdown;
      _seen = null;
    });
    _hold.value = 0;
    _clock.value = 0;
    _shown = 0;
    _countdown.forward(from: 0);
  }

  /// Each number of the countdown is also felt (a tick), so the eyes can stay on the hand.
  void _tickCountdown() {
    final n = 3 - min<int>(2, (_countdown.value * 3).floor());
    if (n == _shown || !_countdown.isAnimating) return;
    _shown = n;
    HapticFeedback.selectionClick();
  }

  void _retry() {
    if (!_gloveReady) return;
    _try++;
    _ready();
  }

  void _go() {
    if (_phase != _Phase.countdown) return;
    _session.recognitionPaused = false; // a fresh, empty window: nothing from before counts
    HapticFeedback.mediumImpact(); // "Go!", felt
    setState(() => _phase = _Phase.signing);
    _clock.forward(from: 0);
  }

  /// A sign accepted by the glove (only while the game is open).
  void _onSign(String label) {
    if (_phase != _Phase.signing || !mounted) return;
    if (label != _label) {
      setState(() => _seen = label); // passing through another sign on the way costs nothing
      return;
    }
    final stars = SignQuestScreen.starsFor(_clock.duration! * _clock.value - SignQuestScreen.warmUp);
    _clock.stop();
    _session.recognitionPaused = true;
    _hold.value = 1;
    setState(() {
      _phase = _Phase.right;
      _stars.add(stars);
      _combo++;
    });
    HapticFeedback.heavyImpact();
    widget.services.speaker.say(_label);
    if (widget.services.signer.library.ids.contains(LearnClips.cheer)) _player.play(const [LearnClips.cheer]);
  }

  void _timeUp() {
    if (_phase != _Phase.signing) return;
    _session.recognitionPaused = true;
    _hold.value = 0;
    setState(() {
      _phase = _Phase.missed;
      _combo = 0;
      if (_try >= SignQuestScreen.tries) _stars.add(0);
    });
    HapticFeedback.lightImpact();
    final reaction = widget.services.signer.library.ids.contains(LearnClips.tryAgain);
    _player.play([if (reaction) LearnClips.tryAgain, ..._clips]); // and the sign once more
  }

  void _onRow(List<double> row) {
    _row.value = row;
    final dead = GestureClassifier.isDeadRow(row);
    if (dead != _sensorDead) _gloveChanged(sensorDead: dead);
    if (_phase != _Phase.signing) return;
    final target = kSignFingerTargets[_label];
    final inPlace = target != null && fingerMatches(row, target).where((m) => m).length >= 4;
    // the ring fills in about the time the glove needs to answer, and empties twice as fast
    final step = 40 / SignQuestScreen.warmUp.inMilliseconds;
    _hold.value = (_hold.value + (inPlace ? step : -2 * step)).clamp(0.0, 0.95);
  }

  // The session tells about every row (25 a second): only a change of the connection matters here.
  void _onGlove() {
    if (_session.link != _link) _gloveChanged(link: _session.link);
  }

  /// A try that the glove can't follow (connection lost, motion sensor out) doesn't count.
  void _gloveChanged({GloveLink? link, bool? sensorDead}) {
    if (!mounted) return;
    setState(() {
      _link = link ?? _link;
      _sensorDead = sensorDead ?? _sensorDead;
      if (!_gloveReady && (_phase == _Phase.countdown || _phase == _Phase.signing)) {
        _countdown.stop();
        _clock.stop();
        _session.recognitionPaused = true;
        _phase = _Phase.watch;
        _hold.value = 0;
      }
    });
  }

  Future<void> _next() async {
    if (_at + 1 < widget.signs.length) {
      setState(() {
        _at++;
        _try = 1;
      });
      _show();
      return;
    }
    if (_finishing) return;
    _finishing = true;
    final w = widget;
    final stars = _stars.fold(0, (a, b) => a + b);
    final reward = await w.services.learn.finishRound(
      xp: stars * SignQuestScreen.xpPerStar,
      earned: [if (stars > 0) LearnBadge.firstSign],
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      builder: (_) => ResultsScreen(
        title: 'Sign Quest',
        right: stars,
        total: 3 * w.signs.length,
        unit: 'stars',
        reward: reward,
        progress: w.services.learn,
        playAgain: () => switch (signQuestRound(w.services.signer.library)) {
          final signs? => SignQuestScreen(services: w.services, signs: signs, openClip: w.openClip),
          null => null,
        },
      ),
    ));
  }

  /// The sign's words: a letter as "Huruf A" / "Letter A", else Malay / English.
  (String, String) get _words {
    if (_label.length == 1) return ('Huruf $_label', 'Letter $_label');
    final words = widget.services.words(_label);
    return (words.malay, words.english);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.reduced(context);
    final (malay, english) = _words;
    final last = _at + 1 == widget.signs.length;
    final out = _try >= SignQuestScreen.tries;
    final next = (last ? 'See results' : 'Next sign', last ? Icons.emoji_events_rounded : Icons.arrow_forward_rounded);
    final (label, icon, onTap) = switch (_phase) {
      _Phase.watch => ("I'm ready", Icons.back_hand_rounded, _gloveReady ? _ready : null),
      _Phase.countdown => ('Get ready…', Icons.hourglass_top_rounded, null),
      _Phase.signing => ('Sign it now', Icons.back_hand_rounded, null),
      _Phase.missed when !out => ('Try again', Icons.replay_rounded, _gloveReady ? _retry : null),
      _Phase.right || _Phase.missed => (next.$1, next.$2, _next),
    };
    Widget meter = FingerMeter(row: _row, hold: _hold, target: kSignFingerTargets[_label]);
    if (!reduced && _phase == _Phase.right) {
      meter = meter.animate(key: ValueKey('right$_at')).scaleXY(begin: 0.94, end: 1, duration: 400.ms, curve: Curves.elasticOut);
    } else if (!reduced && _phase == _Phase.missed) {
      meter = meter.animate(key: ValueKey('missed$_at-$_try')).shake(duration: 400.ms, hz: 5, offset: const Offset(6, 0));
    }
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
                  title: 'Sign Quest',
                  step: 'Sign ${_at + 1} of ${widget.signs.length} · try $_try of ${SignQuestScreen.tries}',
                  combo: _combo,
                  xp: _xp,
                  reduced: reduced,
                ),
                ProgressDots(total: widget.signs.length, results: [for (final s in _stars) s > 0], at: _at),
                TimeBar(clock: _clock),
                const SizedBox(height: AppSpace.m),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: LearnStage(player: _player, actions: [
                          StageButton(
                            icon: Icons.replay_rounded,
                            label: 'Show the sign again',
                            onTap: _phase == _Phase.watch || _phase == _Phase.missed ? () => _player.play(_clips) : null,
                          ),
                          StageButton(
                            icon: Icons.slow_motion_video_rounded,
                            label: 'Slower signing',
                            selected: _player.speed < 1,
                            onTap: () => setState(() => _player.speed = _player.speed < 1 ? 1 : 0.5),
                          ),
                        ]),
                      ),
                      Positioned(left: 10, bottom: 10, child: _SignName(malay: malay, english: english)),
                      if (_phase == _Phase.countdown)
                        Positioned.fill(child: Center(child: _Countdown(clock: _countdown, reduced: reduced))),
                      if (_phase == _Phase.right)
                        Positioned.fill(
                          child: Center(child: _Reward(key: ValueKey(_at), stars: _stars.last, word: malay, reduced: reduced)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.m),
                meter,
                const SizedBox(height: AppSpace.s),
                _status(),
                const SizedBox(height: AppSpace.s),
                GradientButton(label: label, icon: icon, onTap: onTap),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// What is happening, in words: the glove's state first, then the turn.
  Widget _status() {
    if (_link != GloveLink.connected) {
      return Row(children: [
        const Icon(Icons.bluetooth_disabled_rounded, size: 20, color: AppColors.wrongInk),
        const SizedBox(width: AppSpace.s),
        Expanded(child: Text('The glove is not connected.', style: AppText.strong.copyWith(color: AppColors.wrongInk))),
        GloveActionButton(link: _link, ble: widget.services.ble, onLight: true),
      ]);
    }
    final services = widget.services;
    final seen = _seen == null ? null : services.words(_seen!).shown(services.speaker.language);
    final (text, icon, colour) = _sensorDead
        ? ('Motion sensor disconnected. Check the glove.', Icons.sensors_off_rounded, AppColors.wrongInk)
        : switch (_phase) {
            _Phase.watch => ("Watch the signer, then tap I'm ready.", Icons.visibility_rounded, AppColors.inkSoft),
            _Phase.countdown => ('Get your hand ready…', Icons.hourglass_top_rounded, AppColors.inkSoft),
            _Phase.signing when seen != null => ('The glove sees $seen. Keep going!', Icons.back_hand_rounded, AppColors.turqInk),
            _Phase.signing => ('Sign it now!', Icons.back_hand_rounded, AppColors.turqInk),
            _Phase.right => ('Correct! +${_stars.last * SignQuestScreen.xpPerStar} XP', Icons.check_circle_rounded, AppColors.right),
            _Phase.missed when _try < SignQuestScreen.tries =>
              ("Time's up. Try ${_try + 1} of ${SignQuestScreen.tries} next.", Icons.timer_off_outlined, AppColors.wrongInk),
            _Phase.missed => ('Out of tries. On to the next sign.', Icons.timer_off_outlined, AppColors.wrongInk),
          };
    return Semantics(
      liveRegion: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(children: [
          Icon(icon, size: 20, color: colour),
          const SizedBox(width: AppSpace.s),
          Expanded(
            child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.strong.copyWith(color: colour)),
          ),
        ]),
      ),
    );
  }
}

/// The sign asked, on the stage: Malay big, English under it.
class _SignName extends StatelessWidget {
  const _SignName({required this.malay, required this.english});

  final String malay;
  final String english;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 16, 9),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('SIGN THIS', style: AppText.eyebrow.copyWith(color: AppColors.turqInk, fontSize: 10)),
            Text(malay.toUpperCase(), style: AppText.section.copyWith(fontSize: 19)),
            Text(english, style: AppText.small.copyWith(color: AppColors.inkSoft)),
          ],
        ),
      );
}

/// 3, 2, 1: one big number a second, each popping in.
class _Countdown extends StatelessWidget {
  const _Countdown({required this.clock, required this.reduced});

  final Animation<double> clock;
  final bool reduced;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: clock,
        builder: (context, _) {
          final n = 3 - min(2, (clock.value * 3).floor());
          Widget number = Container(
            width: 132,
            height: 132,
            alignment: Alignment.center,
            decoration: const BoxDecoration(gradient: AppGradients.sun, shape: BoxShape.circle, boxShadow: AppShadows.sunGlow),
            child: Text('$n', style: AppText.heroTitle.copyWith(fontSize: 68, height: 1, color: AppColors.onYellow)),
          );
          if (!reduced) {
            number = number
                .animate(key: ValueKey(n))
                .scaleXY(begin: 1.5, end: 1, duration: 300.ms, curve: Curves.easeOutBack)
                .fadeIn(duration: 150.ms);
          }
          return Semantics(liveRegion: true, label: 'Get ready, $n', excludeSemantics: true, child: number);
        },
      );
}

/// The stars won and the word, popping in one after the other.
class _Reward extends StatelessWidget {
  const _Reward({super.key, required this.stars, required this.word, required this.reduced});

  final int stars;
  final String word;
  final bool reduced;

  @override
  Widget build(BuildContext context) {
    Widget pop(Widget child, int i) => reduced
        ? child
        : child.animate(delay: (120 * i).ms).scaleXY(begin: 0, end: 1, duration: 400.ms, curve: Curves.elasticOut);
    return Semantics(
      liveRegion: true,
      label: '${word.toUpperCase()}. $stars of 3 stars',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(26, 16, 26, 18),
        decoration: BoxDecoration(
          gradient: AppGradients.night,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.pop,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < 3; i++)
                pop(
                  Icon(i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 42, color: i < stars ? AppColors.yellow : AppColors.onDarkFaint),
                  i,
                ),
            ]),
            const SizedBox(height: 6),
            pop(Text(word.toUpperCase(), style: AppText.heroTitle.copyWith(fontSize: 30)), 3),
            const SizedBox(height: 2),
            Text('+${stars * SignQuestScreen.xpPerStar} XP', style: AppText.strong.copyWith(color: AppColors.yellow)),
          ],
        ),
      ),
    );
  }
}
