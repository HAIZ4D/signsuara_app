import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_services.dart';
import '../signer/sign_player.dart';
import '../theme/app_theme.dart';
import '../ui/widgets/gradient_button.dart';
import 'eja_nama.dart';
import 'learn_ui.dart';
import 'results_screen.dart';

/// Baca Jari, "read the fingers" (README "Learn"): the avatar fingerspells a short Malay word, you
/// type it. The blanks say how many letters; "Spell it again" and "Slower" are free to use. After
/// each answer its English is shown. +10 XP a word; its letters count for Alphabet master.
class ReadFingersScreen extends StatefulWidget {
  const ReadFingersScreen({super.key, required this.services, required this.words, this.openClip = openAssetClip});

  final AppServices services;
  final List<(String, String)> words; // (Malay word, English)
  final ClipOpener openClip;

  static const xpPerWord = 10;

  @override
  State<ReadFingersScreen> createState() => _ReadFingersScreenState();
}

class _ReadFingersScreenState extends State<ReadFingersScreen> {
  late final _player = SignPlayer(open: widget.openClip);
  final _typed = TextEditingController();
  final _focus = FocusNode();
  var _at = 0;
  var _answered = false;
  var _combo = 0;
  final _results = <bool>[];
  var _finishing = false;

  (String, String) get _word => widget.words[_at];
  int get _xp => _results.where((r) => r).length * ReadFingersScreen.xpPerWord;

  @override
  void initState() {
    super.initState();
    _show();
  }

  @override
  void dispose() {
    _player.dispose();
    _typed.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _show() {
    _answered = false;
    _typed.clear();
    final plan = spellPlan(widget.services.signer.library, [_word.$1]);
    if (plan != null) _player.play([for (final (clip, _) in plan) clip]);
  }

  void _check() {
    if (_answered || _typed.text.trim().isEmpty) return;
    final right = sameWord(_typed.text, _word.$1);
    _focus.unfocus();
    setState(() {
      _answered = true;
      _results.add(right);
      _combo = right ? _combo + 1 : 0;
    });
    if (right) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.heavyImpact();
      _player.replay(); // watch it once more, knowing the word
    }
  }

  Future<void> _next() async {
    if (_at + 1 < widget.words.length) {
      setState(() => _at++);
      _show();
      return;
    }
    if (_finishing) return;
    _finishing = true;
    final w = widget;
    final read = [for (final (i, (word, _)) in w.words.indexed) if (_results[i]) word];
    final reward = await w.services.learn.finishRound(
      xp: _xp,
      letters: {for (final word in read) ...word.split('')},
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      builder: (_) => ResultsScreen(
        title: 'Baca Jari',
        right: read.length,
        total: w.words.length,
        reward: reward,
        progress: w.services.learn,
        playAgain: () => switch (bacaJariRound(w.services.signer.library)) {
          final words? => ReadFingersScreen(services: w.services, words: words, openClip: w.openClip),
          null => null,
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.reduced(context);
    final (word, english) = _word;
    final right = _answered && _results.last;
    final last = _at + 1 == widget.words.length;
    final (text, icon, colour) = !_answered
        ? ('Watch her fingers, then type the word.', Icons.visibility_rounded, AppColors.inkSoft)
        : right
            ? ('Correct! ${word.toUpperCase()} means "$english". +${ReadFingersScreen.xpPerWord} XP',
                Icons.check_circle_rounded, AppColors.right)
            : ('Not quite. It was ${word.toUpperCase()} ("$english").', Icons.cancel_rounded, AppColors.wrongInk);
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
                  title: 'Baca Jari',
                  step: 'Word ${_at + 1} of ${widget.words.length}',
                  combo: _combo,
                  xp: _xp,
                  reduced: reduced,
                ),
                ProgressDots(total: widget.words.length, results: _results, at: _at),
                const SizedBox(height: AppSpace.m),
                Expanded(
                  child: LearnStage(player: _player, actions: [
                    StageButton(icon: Icons.replay_rounded, label: 'Spell it again', onTap: _player.replay),
                    StageButton(
                      icon: Icons.slow_motion_video_rounded,
                      label: 'Slower signing',
                      selected: _player.speed < 1,
                      onTap: () => setState(() => _player.speed = _player.speed < 1 ? 1 : 0.5),
                    ),
                  ]),
                ),
                const SizedBox(height: AppSpace.m),
                _Blanks(word: word, answered: _answered, right: right),
                const SizedBox(height: AppSpace.s),
                TextField(
                  controller: _typed,
                  focusNode: _focus,
                  enabled: !_answered,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  autocorrect: false,
                  enableSuggestions: false,
                  onSubmitted: (_) => _check(),
                  style: AppText.strong.copyWith(color: AppColors.ink, fontSize: 18, letterSpacing: 2),
                  decoration: InputDecoration(
                    hintText: 'Type the word you saw',
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(color: AppColors.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(color: AppColors.line),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.s),
                Semantics(
                  liveRegion: true,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 40),
                    child: Row(children: [
                      Icon(icon, size: 20, color: colour),
                      const SizedBox(width: AppSpace.s),
                      Expanded(
                        child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.strong.copyWith(color: colour)),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: AppSpace.s),
                GradientButton(
                  label: !_answered ? 'Check' : (last ? 'See results' : 'Next'),
                  icon: !_answered ? Icons.check_rounded : (last ? Icons.emoji_events_rounded : Icons.arrow_forward_rounded),
                  onTap: _answered ? _next : _check,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One box per letter: empty before answering (how many letters), the word after it (green when
/// read right, red when not).
class _Blanks extends StatelessWidget {
  const _Blanks({required this.word, required this.answered, required this.right});

  final String word;
  final bool answered;
  final bool right;

  @override
  Widget build(BuildContext context) {
    final (fill, edge, ink) = !answered
        ? (AppColors.surface, AppColors.line, AppColors.ink)
        : right
            ? (AppColors.rightWash, AppColors.right, AppColors.right)
            : (AppColors.wrongWash, AppColors.danger, AppColors.wrongInk);
    return Semantics(
      label: answered ? 'The word: ${word.toUpperCase()}' : '${word.length} letters',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final char in word.split(''))
            Container(
              width: 34,
              height: 40,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: edge, width: answered ? 2 : 1.5),
              ),
              child: Text(answered ? char.toUpperCase() : '', style: AppText.section.copyWith(color: ink, fontSize: 18)),
            ),
          const SizedBox(width: AppSpace.s),
          Flexible(
            child: Text('${word.length} letters',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.small.copyWith(color: AppColors.inkSoft)),
          ),
        ],
      ),
    );
  }
}
