import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_services.dart';
import '../signer/sign_clips.dart';
import '../signer/sign_player.dart';
import '../theme/app_theme.dart';
import '../ui/widgets/gradient_button.dart';
import 'eja_nama.dart';
import 'learn_ui.dart';
import 'read_fingers_screen.dart';

/// Eja Nama (README "Learn"): type a name and the avatar fingerspells it, the letter she is making
/// lit up. Below it: Baca Jari, the game of reading her fingers.
class EjaNamaScreen extends StatefulWidget {
  const EjaNamaScreen({super.key, required this.services, this.openClip = openAssetClip});

  final AppServices services;
  final ClipOpener openClip; // tests give made-up clips

  @override
  State<EjaNamaScreen> createState() => _EjaNamaScreenState();
}

class _EjaNamaScreenState extends State<EjaNamaScreen> {
  late final _player = SignPlayer(open: widget.openClip);
  // Signed in: the user's first name is ready to spell.
  late final _name = TextEditingController(
      text: widget.services.account.signedIn ? widget.services.userName.trim().split(RegExp(r'\s+')).first : '');
  List<String> _words = const [];
  List<(String, (int, int)?)> _plan = const [];
  String? _note;

  @override
  void initState() {
    super.initState();
    // She is there from the start (a wave hello, or standing ready), not an empty stage.
    final ids = widget.services.signer.library.ids;
    if (ids.contains(LearnClips.wave)) {
      _player.play(const [LearnClips.wave]);
    } else if (ids.contains(SignClipLibrary.rest)) {
      _player.play(const [SignClipLibrary.rest]);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _name.dispose();
    super.dispose();
  }

  void _spell() {
    FocusScope.of(context).unfocus(); // the keyboard away: the avatar in full view
    final (:words, :dropped) = spellWords(_name.text);
    final plan = spellPlan(widget.services.signer.library, words);
    setState(() {
      _words = plan == null ? const [] : words;
      _plan = plan ?? const [];
      _note = words.isEmpty
          ? 'Type a name with the letters A–Z.'
          : plan == null
              ? 'Some letters have no clip in the app yet.'
              : (dropped ? 'Only the letters A–Z are spelled.' : null);
    });
    if (_plan.isNotEmpty) _player.play([for (final (clip, _) in _plan) clip]);
  }

  void _playBacaJari() {
    final words = bacaJariRound(widget.services.signer.library);
    if (words == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Baca Jari needs the letter clips, and they are not in the app yet.')));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ReadFingersScreen(services: widget.services, words: words, openClip: widget.openClip),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final stage = (MediaQuery.sizeOf(context).height * 0.42).clamp(220.0, 360.0);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.xs, AppSpace.gutter, AppSpace.xxl),
            children: [
              Row(children: [
                IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
                ),
                const SizedBox(width: AppSpace.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Eja Nama', style: AppText.section),
                      Text('Any name, fingerspelled letter by letter',
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.small.copyWith(color: AppColors.inkSoft)),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: AppSpace.s),
              SizedBox(
                height: stage,
                child: LearnStage(player: _player, actions: [
                  StageButton(icon: Icons.replay_rounded, label: 'Spell it again', onTap: _plan.isEmpty ? null : _player.replay),
                  StageButton(
                    icon: Icons.slow_motion_video_rounded,
                    label: 'Slower signing',
                    selected: _player.speed < 1,
                    onTap: () => setState(() => _player.speed = _player.speed < 1 ? 1 : 0.5),
                  ),
                ]),
              ),
              const SizedBox(height: AppSpace.m),
              _Letters(player: _player, words: _words, plan: _plan),
              if (_note case final note?)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.xs),
                  child: Text(note, textAlign: TextAlign.center, style: AppText.small.copyWith(color: AppColors.wrongInk)),
                ),
              const SizedBox(height: AppSpace.m),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: false,
                onSubmitted: (_) => _spell(),
                style: AppText.strong.copyWith(color: AppColors.ink, fontSize: 17),
                decoration: InputDecoration(
                  hintText: 'Type a name',
                  prefixIcon: const Icon(Icons.badge_outlined),
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
              GradientButton(label: 'Spell it', icon: Icons.sign_language_rounded, onTap: _spell),
              const SizedBox(height: AppSpace.l),
              _BacaJariCard(onPlay: _playBacaJari),
            ],
          ),
        ),
      ),
    );
  }
}

enum _TileLook { coming, now, shown }

/// The name's letters; the one she is making now is yellow, the ones already made are dark.
class _Letters extends StatelessWidget {
  const _Letters({required this.player, required this.words, required this.plan});

  final SignPlayer player;
  final List<String> words;
  final List<(String, (int, int)?)> plan;

  @override
  Widget build(BuildContext context) {
    if (words.isEmpty) {
      return SizedBox(
        height: 44,
        child: Center(
          child: Text('Type a name, then tap Spell it.', style: AppText.small.copyWith(color: AppColors.inkSoft)),
        ),
      );
    }
    return Semantics(
      label: 'Spelling ${words.join(' ').toUpperCase()}',
      excludeSemantics: true,
      child: SizedBox(
        height: 44,
        child: ListenableBuilder(
          listenable: player,
          builder: (context, _) {
            final at = player.index; // the clip playing now; plan.length once finished
            final now = at >= 0 && at < plan.length ? plan[at].$2 : null;
            _TileLook look((int, int) letter) {
              if (letter == now) return _TileLook.now;
              final place = plan.indexWhere((p) => p.$2 == letter);
              return place < at ? _TileLook.shown : _TileLook.coming;
            }

            return Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final (w, word) in words.indexed) ...[
                    if (w > 0) const SizedBox(width: 14),
                    for (final (i, char) in word.split('').indexed) _Tile(char.toUpperCase(), look((w, i))),
                  ],
                ]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.letter, this.look);

  final String letter;
  final _TileLook look;

  @override
  Widget build(BuildContext context) {
    final (fill, ink) = switch (look) {
      _TileLook.now => (AppColors.yellow, AppColors.onYellow),
      _TileLook.shown => (AppColors.surface, AppColors.ink),
      _TileLook.coming => (AppColors.surface2, AppColors.inkFaint),
    };
    return AnimatedContainer(
      duration: AppMotion.quick,
      width: 32,
      height: 42,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: look == _TileLook.now ? AppColors.yellow : AppColors.line),
      ),
      child: Text(letter, style: AppText.section.copyWith(color: ink, fontSize: 18)),
    );
  }
}

/// The way into Baca Jari.
class _BacaJariCard extends StatelessWidget {
  const _BacaJariCard({required this.onPlay});

  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Play Baca Jari: she fingerspells a word, you type it',
        excludeSemantics: true,
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), boxShadow: AppShadows.card),
          child: Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              onTap: onPlay,
              borderRadius: BorderRadius.circular(22),
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.l),
                child: Row(children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: AppColors.turqWash, borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.keyboard_alt_outlined, color: AppColors.turqInk),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Baca Jari', style: AppText.section),
                        const SizedBox(height: 2),
                        Text('She fingerspells a word, you type it. $bacaJariLength words, +10 XP each.',
                            style: AppText.small.copyWith(color: AppColors.inkSoft, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpace.s),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(color: AppColors.turqWash, shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow_rounded, color: AppColors.turqInk),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
}
