import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../app/app_services.dart';
import '../glove/glove_session.dart';
import '../signer/sign_clips.dart';
import '../signer/sign_player.dart';
import '../signer/sign_player_view.dart';
import '../theme/app_theme.dart';
import '../ui/time_label.dart';
import '../ui/widgets/hero_panel.dart';
import '../ui/widgets/motion.dart';
import 'eja_nama_screen.dart';
import 'gemini_quiz_screen.dart';
import 'learn_path_screen.dart';
import 'learn_progress.dart';
import 'learn_ui.dart';
import 'learn_units.dart';
import 'note_lesson_screen.dart';
import 'quiz_question.dart';
import 'quiz_screen.dart';
import 'sign_lesson_screen.dart';
import 'sign_quest_screen.dart';
import 'sign_targets.dart';
import 'teka_isyarat.dart';

/// Learn mode's hub (README "Learn"), opened from Home, built like a game's home: Cikgu Suara (the
/// avatar) says hello and suggests one thing to do, the level / today / streak counters, the sign
/// of the day, the next units of the path, the games as a grid of tiles, and the badges with how
/// close each one is. Only real progress is shown (kept on the phone).
class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key, required this.services, this.openClip = openAssetClip});

  final AppServices services;
  final ClipOpener openClip; // tests give made-up clips

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  late final _player = SignPlayer(open: widget.openClip); // its own: Chat and Listen keep theirs
  var _greeted = false;
  late var _link = _services.session.link;

  AppServices get _services => widget.services;

  @override
  void initState() {
    super.initState();
    _services.signer.addListener(_greet);
    _services.session.addListener(_onGlove);
    _greet();
  }

  @override
  void dispose() {
    _services.signer.removeListener(_greet);
    _services.session.removeListener(_onGlove);
    _player.dispose();
    super.dispose();
  }

  // The session tells about every glove row (25 a second); the hub only cares about the connection.
  void _onGlove() {
    final link = _services.session.link;
    if (link != _link && mounted) setState(() => _link = link);
  }

  /// The avatar waves hello (or just stands there, without a wave clip) once the clip list is known.
  void _greet() {
    final ids = _services.signer.library.ids;
    if (_greeted || ids.isEmpty) return;
    _greeted = true;
    _player.play([ids.contains(LearnClips.wave) ? LearnClips.wave : SignClipLibrary.rest]);
  }

  var _pokes = 0;

  /// A tap on Cikgu Suara: she waves again (cheers every other time, when the app has that clip),
  /// with a light buzz.
  void _poke() {
    final ids = _services.signer.library.ids;
    final clips = [LearnClips.wave, LearnClips.cheer].where(ids.contains).toList();
    if (clips.isEmpty) return;
    HapticFeedback.selectionClick();
    _player.play([clips[_pokes++ % clips.length]]);
  }

  void _say(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  void _open(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  void _playTekaIsyarat() {
    List<QuizQuestion>? round() => tekaIsyaratRound(_services.signer.library);
    final questions = round();
    if (questions == null) return _say('Teka Isyarat needs at least 4 sign clips in the app, and they are not there yet.');
    _open(QuizScreen(
      title: 'Teka Isyarat',
      questions: questions,
      progress: _services.learn,
      timed: true,
      openClip: widget.openClip,
      again: round,
    ));
  }

  void _playSignQuest() {
    if (_link != GloveLink.connected) return _say('Connect the glove on Home first: Sign Quest reads your hand.');
    final signs = signQuestRound(_services.signer.library);
    if (signs == null) return _say("Sign Quest needs the signer's clips of the glove's signs, and they are not in the app yet.");
    _open(SignQuestScreen(services: _services, signs: signs, openClip: widget.openClip));
  }

  void _watchSignOfTheDay(String id) => _open(SignLessonScreen(
        services: _services,
        title: 'Sign of the day',
        subtitle: longDate(DateTime.now()),
        ids: [id],
        onWatchedAll: _services.learn.watchSignOfTheDay,
        openClip: widget.openClip,
      ));

  /// What Cikgu Suara suggests now (one thing): the tip, its button, and what that opens.
  (String, String?, VoidCallback?) _suggestion(String? sign, List<LearnUnit> units, int? current) {
    final learn = _services.learn;
    if (sign != null && !learn.watchedSignToday) {
      final gloss = signAnswer(sign).text;
      final keep = learn.streak > 0 && !learn.playedToday;
      return (
        keep ? 'Keep your ${learn.streak}-day streak! Today\'s sign is $gloss.' : 'Today\'s sign is $gloss. Want to see it?',
        'Show me',
        () => _watchSignOfTheDay(sign),
      );
    }
    if (current != null && learn.unitStars(units[current].id) < 2) {
      return (
        'Next up: unit ${current + 1}, ${units[current].title}.',
        'Continue',
        () => openUnit(context, _services, units, current, openClip: widget.openClip),
      );
    }
    if (learn.xpToday < LearnProgress.dailyGoal) {
      return ('${LearnProgress.dailyGoal - learn.xpToday} XP more for today\'s goal.', 'Play Teka Isyarat', _playTekaIsyarat);
    }
    return ('Today\'s goal is done. Hebat! See you tomorrow.', null, null);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: ListenableBuilder(
          listenable: Listenable.merge([_services.learn, _services.signer, _services.notes]),
          builder: (context, _) {
            final learn = _services.learn;
            final library = _services.signer.library;
            final sign = signOfTheDay(library, DateTime.now());
            final units = pathUnits(library);
            final current = currentUnit(units, learn);
            final (tip, action, onAction) = _suggestion(sign, units, current);
            final name = _services.account.signedIn ? _services.userName.trim().split(RegExp(r'\s+')).first : null;
            Widget rise(int i, Widget child) =>
                FadeUp(delay: Duration(milliseconds: 60 * i), child: child); // staggered, < 400 ms in all
            return ListView(
              padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + AppSpace.xxl),
              children: [
                HeroPanel(
                  bottomPadding: AppSpace.xl,
                  child: _Hero(
                    learn: learn,
                    player: _player,
                    avatar: _services.signer.hasClips,
                    greeting: name == null ? 'Jom belajar!' : 'Jom belajar, $name!',
                    tip: tip,
                    action: action,
                    onAction: onAction,
                    onAvatar: _poke,
                  ),
                ),
                if (sign != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.l, AppSpace.gutter, 0),
                    child: rise(1, _SignOfTheDay(id: sign, watched: learn.watchedSignToday, onTap: () => _watchSignOfTheDay(sign))),
                  ),
                if (units.isNotEmpty) ...[
                  SectionHeader(
                    title: 'Your path',
                    action: 'See all',
                    onAction: () => _open(LearnPathScreen(services: _services, openClip: widget.openClip)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
                    child: rise(2, MiniPath(services: _services, openClip: widget.openClip)),
                  ),
                ],
                const SectionHeader(title: 'Play'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
                  child: _PlayGrid(state: this), // its tiles pop in one by one
                ),
                const SectionHeader(title: 'Badges'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
                  child: rise(4, _BadgeShelf(learn: learn)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The dark top: back and the title; Cikgu Suara's speech bubble beside her; the three counters.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.learn,
    required this.player,
    required this.avatar,
    required this.greeting,
    required this.tip,
    required this.action,
    required this.onAction,
    required this.onAvatar,
  });

  final LearnProgress learn;
  final SignPlayer player;
  final bool avatar;
  final String greeting;
  final String tip;
  final String? action;
  final VoidCallback? onAction;
  final VoidCallback onAvatar; // a tap on her: she waves again

  @override
  Widget build(BuildContext context) {
    final bubble = _Bubble(greeting: greeting, tip: tip, action: action, onAction: onAction, tail: avatar);
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const GlassBackButton(),
            const SizedBox(width: AppSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('LEARN MODE', style: AppText.eyebrow.copyWith(color: AppColors.yellow)),
                  Text('Learn BIM', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.screenTitle.copyWith(fontSize: 22)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: AppSpace.m),
          Row(children: [
            Expanded(
              // she "speaks": the bubble pops out from her side just after she starts to wave,
              // and again whenever her tip changes
              child: AppMotion.reduced(context)
                  ? bubble
                  : bubble
                      .animate(key: ValueKey(tip))
                      .fadeIn(delay: 250.ms, duration: 200.ms)
                      .scaleXY(begin: 0.85, end: 1, delay: 250.ms, duration: 350.ms, curve: AppMotion.springCurve, alignment: Alignment.centerRight),
            ),
            if (avatar) ...[
              const SizedBox(width: 14),
              Semantics(
                button: true,
                label: 'Cikgu Suara. Tap to say hi.',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: onAvatar,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 124,
                    height: 176,
                    child: Stack(children: [
                      const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: AppGradients.avatarGlow))),
                      Positioned.fill(child: SignPlayerView(player: player)),
                    ]),
                  ),
                ),
              ),
            ],
          ]),
          const SizedBox(height: AppSpace.m),
          _Counters(learn: learn),
        ],
      );
  }
}

/// Cikgu Suara's speech bubble: hello, one tip, and a button to do it. Its tail points at her.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.greeting, required this.tip, required this.action, required this.onAction, required this.tail});

  final String greeting;
  final String tip;
  final String? action;
  final VoidCallback? onAction;
  final bool tail;

  @override
  Widget build(BuildContext context) => Semantics(
        button: onAction != null,
        label: 'Cikgu Suara: $greeting $tip${action == null ? '' : ' $action.'}',
        excludeSemantics: true,
        child: CustomPaint(
          painter: tail ? _BubbleTail() : null,
          child: Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(greeting, style: AppText.strong.copyWith(color: AppColors.ink, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(tip, style: AppText.body.copyWith(color: AppColors.inkSoft, fontSize: 13.5, height: 1.4)),
                    if (action case final action?) ...[
                      const SizedBox(height: AppSpace.s),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Flexible(
                          child: Text(action, style: AppText.label.copyWith(color: AppColors.turqInk, fontWeight: FontWeight.w800, fontSize: 13.5)),
                        ),
                        const SizedBox(width: 4),
                        // the arrow nudges twice, inviting the tap, then stays still
                        AppMotion.reduced(context)
                            ? const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.turqInk)
                            : const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.turqInk)
                                .animate() // delays inside the effects: no timer is left behind
                                .moveX(delay: 900.ms, begin: 0, end: 4, duration: 260.ms, curve: Curves.easeInOut)
                                .then()
                                .moveX(begin: 0, end: -4, duration: 260.ms, curve: Curves.easeInOut)
                                .then()
                                .moveX(begin: 0, end: 4, duration: 260.ms, curve: Curves.easeInOut)
                                .then()
                                .moveX(begin: 0, end: -4, duration: 260.ms, curve: Curves.easeInOut),
                      ]),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

/// The little point on the bubble's right side, towards the avatar.
class _BubbleTail extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * 0.5;
    canvas.drawPath(
      Path()
        ..moveTo(size.width - 1, y - 9)
        ..lineTo(size.width + 10, y)
        ..lineTo(size.width - 1, y + 9)
        ..close(),
      Paint()..color = AppColors.surface,
    );
  }

  @override
  bool shouldRepaint(_BubbleTail old) => false;
}

/// Level (ring = XP in this level), today (ring = today's XP of the daily goal), and the streak.
class _Counters extends StatelessWidget {
  const _Counters({required this.learn});

  final LearnProgress learn;

  @override
  Widget build(BuildContext context) {
    final today = learn.xpToday;
    final done = today >= LearnProgress.dailyGoal;
    final streak = learn.streak;
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpace.s, AppSpace.m, AppSpace.s, AppSpace.m),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: _Counter(
            label: 'Level ${learn.level}, ${learn.xpInLevel} of ${LearnProgress.xpPerLevel} XP to the next level',
            mark: ProgressRing(
              value: learn.xpInLevel / LearnProgress.xpPerLevel,
              child: Text('${learn.level}', style: AppText.section.copyWith(color: AppColors.onDark, fontSize: 18)),
            ),
            title: 'Level ${learn.level}',
            detail: '${learn.xpInLevel} / ${LearnProgress.xpPerLevel} XP',
          ),
        ),
        Expanded(
          child: _Counter(
            label: 'Today: $today of ${LearnProgress.dailyGoal} XP${done ? ', goal done' : ''}',
            mark: ProgressRing(
              value: today / LearnProgress.dailyGoal,
              color: AppColors.turqBright,
              child: Icon(done ? Icons.check_rounded : Icons.bolt_rounded, size: 22, color: AppColors.onDark),
            ),
            title: 'Today',
            detail: '$today / ${LearnProgress.dailyGoal} XP',
          ),
        ),
        Expanded(
          child: _Counter(
            label: streak == 0 ? 'No streak yet' : '$streak-day streak${learn.playedToday ? '' : ', play today to keep it'}',
            mark: _ignite(context, streak, Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: streak > 0 ? AppColors.yellow : AppColors.glass,
                border: Border.all(color: streak > 0 ? AppColors.yellow : AppColors.glassBorder, width: 2),
              ),
              child: Icon(Icons.local_fire_department_rounded, size: 26, color: streak > 0 ? AppColors.onYellow : AppColors.onDarkFaint),
            )),
            title: streak == 0 ? 'No streak' : '$streak-day streak',
            detail: streak == 0 ? 'Play to start' : (learn.playedToday ? 'Played today' : 'Play today'),
          ),
        ),
      ]),
    );
  }
}

/// A kept streak's flame lights up with a little pop (and a tilt) as the hub opens, and again when
/// the streak grows.
Widget _ignite(BuildContext context, int streak, Widget flame) => streak == 0 || AppMotion.reduced(context)
    ? flame
    : flame
        .animate(key: ValueKey(streak))
        .scaleXY(begin: 0.6, end: 1, delay: 400.ms, duration: 400.ms, curve: AppMotion.springCurve)
        .rotate(begin: -0.04, end: 0, delay: 400.ms, duration: 400.ms, curve: AppMotion.springCurve); // turns: ~14°

class _Counter extends StatelessWidget {
  const _Counter({required this.label, required this.mark, required this.title, required this.detail});

  final String label; // for screen readers
  final Widget mark;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        excludeSemantics: true,
        child: Column(children: [
          mark,
          const SizedBox(height: 6),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.strong.copyWith(color: AppColors.onDark, fontSize: 13)),
          Text(detail,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.small.copyWith(color: AppColors.onDarkSoft, fontSize: 11.5)),
        ]),
      );
}

/// Today's sign: the date, the sign and its English; ticked once watched (+5 XP, once a day).
class _SignOfTheDay extends StatelessWidget {
  const _SignOfTheDay({required this.id, required this.watched, required this.onTap});

  final String id;
  final bool watched;
  final VoidCallback onTap;

  static const _months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final name = signAnswer(id);
    return Semantics(
      button: true,
      label: 'Sign of the day: ${name.text}${name.detail == null ? '' : ', ${name.detail}'}. '
          '${watched ? 'Watched today.' : 'Watch it for ${LearnProgress.signOfTheDayXp} XP.'}',
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), boxShadow: AppShadows.card),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Container(
                  width: 58,
                  height: 64,
                  decoration: BoxDecoration(color: AppColors.yellow, borderRadius: BorderRadius.circular(16)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(_months[now.month - 1], style: AppText.tiny.copyWith(color: AppColors.onYellow, fontSize: 11)),
                    Text('${now.day}', style: AppText.section.copyWith(color: AppColors.onYellow, fontSize: 24, height: 1.1)),
                  ]),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SIGN OF THE DAY', style: AppText.eyebrow.copyWith(color: AppColors.turqInk)),
                      Text(name.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.section.copyWith(fontSize: 19)),
                      if (name.detail case final english?)
                        Text(english, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.small.copyWith(color: AppColors.inkSoft)),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.s),
                watched
                    ? _popIn(
                        context,
                        Container(
                          padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
                          decoration: BoxDecoration(color: AppColors.rightWash, borderRadius: BorderRadius.circular(AppRadius.pill)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.check_rounded, size: 16, color: AppColors.right),
                            const SizedBox(width: 4),
                            Text('Watched', style: AppText.label.copyWith(color: AppColors.right)),
                          ]),
                        ),
                      )
                    // a soft ring pings out of the button until today's sign is watched
                    : PingRing(
                        color: AppColors.turq,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(color: AppColors.turqWash, shape: BoxShape.circle),
                          child: const Icon(Icons.play_arrow_rounded, color: AppColors.turqInk),
                        ),
                      ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Something new pops in with a small bounce (the "Watched" tick, an unlocked badge).
Widget _popIn(BuildContext context, Widget child, {Duration delay = Duration.zero}) => AppMotion.reduced(context)
    ? child
    : child
        .animate()
        .scaleXY(delay: delay, begin: 0.6, end: 1, duration: 400.ms, curve: AppMotion.springCurve)
        .rotate(delay: delay, begin: -0.025, end: 0, duration: 400.ms, curve: AppMotion.springCurve); // turns: ~9°

/// The games as a grid of solid-coloured tiles of two sizes (a "bento" grid): Teka Isyarat big,
/// Eja Nama and Sign Quest beside it, then Gemini Quiz and the signs from your notes.
class _PlayGrid extends StatelessWidget {
  const _PlayGrid({required this.state});

  final _LearnScreenState state;

  @override
  Widget build(BuildContext context) {
    final services = state._services;
    final library = services.signer.library;
    final connected = state._link == GloveLink.connected;
    final notes = services.notes.all;
    final withSigns = notes.where((n) => heardSigns(services, n).isNotEmpty).length;
    const gap = 10.0;
    return LayoutBuilder(builder: (context, box) {
      final wide = (box.maxWidth - gap) * 0.58;
      final narrow = box.maxWidth - gap - wide;
      return Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: wide,
            child: _PlayTile(
              height: 210,
              order: 0,
              icon: Icons.visibility_rounded,
              title: 'Teka Isyarat',
              detail: 'Guess the sign she makes',
              meta: '${tekaIsyaratPool(library).length} signs',
              fill: AppColors.turqDeep,
              ink: AppColors.onDark,
              onTap: state._playTekaIsyarat,
            ),
          ),
          const SizedBox(width: gap),
          SizedBox(
            width: narrow,
            child: Column(children: [
              _PlayTile(
                height: 100,
                order: 1,
                icon: Icons.sign_language_rounded,
                title: 'Eja Nama',
                detail: 'Spell any name',
                fill: AppColors.yellow,
                ink: AppColors.onYellow,
                onTap: () => state._open(EjaNamaScreen(services: services, openClip: state.widget.openClip)),
              ),
              const SizedBox(height: gap),
              _PlayTile(
                height: 100,
                order: 2,
                icon: connected ? Icons.back_hand_rounded : Icons.bluetooth_disabled_rounded,
                title: 'Sign Quest',
                detail: connected ? 'Use the glove' : 'Glove is off',
                fill: AppColors.blue,
                ink: AppColors.onDark,
                onTap: state._playSignQuest,
              ),
            ]),
          ),
        ]),
        const SizedBox(height: gap),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: narrow,
            child: _PlayTile(
              height: 118,
              order: 3,
              icon: Icons.auto_awesome_rounded,
              title: 'Gemini Quiz',
              detail: 'Quiz from notes',
              fill: AppColors.royal,
              ink: AppColors.onDark,
              onTap: () => pickNoteForQuiz(context, services),
            ),
          ),
          const SizedBox(width: gap),
          SizedBox(
            width: wide,
            child: _PlayTile(
              height: 118,
              order: 4,
              icon: Icons.sticky_note_2_rounded,
              title: 'Signs in your notes',
              detail: 'Signs that were said',
              meta: switch (withSigns) { 0 => 'Record one in Listen', 1 => '1 note with signs', final n => '$n notes with signs' },
              fill: AppColors.surface,
              ink: AppColors.ink,
              accent: AppColors.turqInk,
              onTap: () => pickNoteForLesson(context, services, openClip: state.widget.openClip),
            ),
          ),
        ]),
      ]);
    });
  }
}

/// One game tile: a solid colour, its icon in a soft circle (and big and faint in the corner), the
/// name, what you do, and a real detail. The tiles pop in one after another; pressed, a tile sinks
/// a little and springs back when let go.
class _PlayTile extends StatefulWidget {
  const _PlayTile({
    required this.height,
    required this.order,
    required this.icon,
    required this.title,
    required this.detail,
    required this.fill,
    required this.ink,
    required this.onTap,
    this.meta,
    this.accent,
  });

  final double height;
  final int order; // its place in the pop-in cascade
  final IconData icon;
  final String title;
  final String detail;
  final String? meta;
  final Color fill;
  final Color ink; // text on [fill]
  final Color? accent; // the icon's colour on a white tile
  final VoidCallback onTap;

  @override
  State<_PlayTile> createState() => _PlayTileState();
}

class _PlayTileState extends State<_PlayTile> {
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final iconColour = w.accent ?? w.ink;
    final big = w.height > 150;
    // Bigger text (the phone's setting) gets a taller tile, so the words never spill out.
    final grow = max(1.0, MediaQuery.textScalerOf(context).scale(16) / 16);
    final reduced = AppMotion.reduced(context);
    final Widget tile = Semantics(
      button: true,
      label: '${w.title}. ${w.detail}.${w.meta == null ? '' : ' ${w.meta}.'}',
      excludeSemantics: true,
      child: AnimatedScale(
        // down quickly, back up with a small spring
        scale: _pressed ? 0.96 : 1,
        duration: _pressed ? AppMotion.quick : const Duration(milliseconds: 260),
        curve: _pressed ? Curves.easeOut : AppMotion.springCurve,
        child: Container(
          height: w.height * grow,
          width: double.infinity, // fills its place in the grid, whatever its words
          decoration: BoxDecoration(
            color: w.fill,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppShadows.card,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: w.onTap,
              onHighlightChanged: (on) => setState(() => _pressed = on),
              borderRadius: BorderRadius.circular(24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(children: [
                  // the big tile's icon fills its empty top corner; on the small ones it sits low
                  Positioned(
                    right: big ? -24 : -14,
                    top: big ? -18 : null,
                    bottom: big ? null : -16,
                    child: Icon(w.icon, size: w.height * (big ? 0.66 : 0.74), color: iconColour.withValues(alpha: big ? 0.16 : 0.12)),
                  ),
                  Padding(
                    padding: EdgeInsets.all(big ? 16 : 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: big ? 44 : 34,
                          height: big ? 44 : 34,
                          decoration: BoxDecoration(color: iconColour.withValues(alpha: 0.16), shape: BoxShape.circle),
                          child: Icon(w.icon, size: big ? 24 : 19, color: iconColour),
                        ),
                        const Spacer(),
                        Text(w.title,
                            maxLines: big ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.section.copyWith(color: w.ink, fontSize: big ? 21 : 15.5, height: 1.15)),
                        Text(w.detail,
                            maxLines: big ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.small.copyWith(color: w.ink.withValues(alpha: 0.85), fontSize: 12)),
                        if (w.meta case final meta?)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(meta,
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.label.copyWith(color: iconColour, fontSize: 12)),
                          ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
    if (reduced) return tile;
    // the tiles pop in one after another, 50 ms apart (a quick cascade, all in within 0.6 s)
    final delay = (150 + 50 * w.order).ms;
    return tile
        .animate()
        .fadeIn(delay: delay, duration: 200.ms)
        .scaleXY(delay: delay, begin: 0.9, end: 1, duration: 360.ms, curve: AppMotion.springCurve);
  }
}

/// The badges, each with how close it is: "7/26 letters", "3/7 days", or the game that gives it.
class _BadgeShelf extends StatelessWidget {
  const _BadgeShelf({required this.learn});

  final LearnProgress learn;

  @override
  Widget build(BuildContext context) {
    final letters = learn.lettersRight.length;
    final days = learn.streak.clamp(0, 7);
    (String, double?) progress(LearnBadge badge) => learn.has(badge)
        ? ('Unlocked', null)
        : switch (badge) {
            LearnBadge.firstSign => ('In Sign Quest', null),
            LearnBadge.alphabetMaster => ('$letters/26 letters', letters / 26),
            LearnBadge.studyBuddy => ('In Gemini Quiz', null),
            LearnBadge.streak7 => ('$days/7 days', days / 7),
          };
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpace.s, AppSpace.l, AppSpace.s, AppSpace.m),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22), boxShadow: AppShadows.card),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final badge in LearnBadge.values)
            Expanded(
              child: Tooltip(
                message: badge.how,
                child: Semantics(
                  label: '${badge.title}, ${learn.has(badge) ? 'unlocked' : 'locked, ${progress(badge).$1}'}. ${badge.how}.',
                  excludeSemantics: true,
                  child: Column(children: [
                    learn.has(badge)
                        ? _popIn(context, BadgeMark(badge: badge, unlocked: true, size: 52), delay: 350.ms)
                        : BadgeMark(badge: badge, unlocked: false, size: 52, progress: progress(badge).$2),
                    const SizedBox(height: AppSpace.s),
                    Text(badge.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: AppText.small.copyWith(color: learn.has(badge) ? AppColors.ink : AppColors.inkSoft, fontSize: 11.5)),
                    Text(progress(badge).$1,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.small.copyWith(
                            color: learn.has(badge) ? AppColors.right : AppColors.turqInk, fontSize: 10.5, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
