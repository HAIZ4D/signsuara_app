import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_services.dart';
import '../listen/listen_note.dart';
import '../listen/listen_session.dart';
import '../signer/sign_player_view.dart';
import '../signer/sign_translator.dart';
import '../signer/signer.dart';
import '../speech/sign_words.dart';
import '../theme/app_theme.dart';
import '../ui/widgets/glass_chip.dart';
import '../ui/widgets/gradient_button.dart';
import '../ui/widgets/motion.dart';
import '../ui/widgets/note_kind_icon.dart';
import '../ui/widgets/notice.dart';

/// Listen (design: hearing.jsx): long listening, like a meeting, a class, a program or a
/// consultation. The words show live, the signer signs each sentence, and the whole session is kept
/// as a note (README "Listen and Notes"). Separate from Chat, which is for daily talk.
class HearingScreen extends StatefulWidget {
  const HearingScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<HearingScreen> createState() => _HearingScreenState();
}

class _HearingScreenState extends State<HearingScreen> {
  var _large = false; // bigger text on the stage, easier to read from further away

  AppServices get s => widget.services;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light, // the hero behind the status bar is dark
      child: ColoredBox(
        color: AppColors.bg,
        child: ListenableBuilder(
          listenable: s.changes,
          builder: (context, _) {
            final session = s.listenSession;
            final listening = session.state == ListenState.listening;
            final language = session.active ? session.language : s.speaker.language;
            final lines = session.lines;
            final latest = lines.isEmpty ? '' : lines.last.text;
            // With sign clips the signer signs each finished sentence; without, the words show big
            // (live while they are being heard).
            final stageText = s.signer.hasClips || session.live.isEmpty || !listening ? latest : session.live;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Head(
                  language: language,
                  onSwitch: session.active ? () => _languageFixed(context) : () => s.setLanguage(_other(language)),
                ),
                if (session.problem case final problem?)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                    child: Notice(message: problem),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                    child: _Stage(text: stageText, listening: listening, large: _large, signer: s.signer),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                  child: _SessionCard(lines: lines, live: listening ? session.live : '', state: session.state),
                ),
                _Foot(
                  state: session.state,
                  startedAt: session.startedAt,
                  large: _large,
                  onMic: switch (session.state) {
                    ListenState.idle => s.startListening,
                    ListenState.listening => session.pause,
                    ListenState.paused => session.resume,
                  },
                  onStop: session.active ? () => _stop(context) : null,
                  onToggleSize: () => setState(() => _large = !_large),
                ),
                SizedBox(height: AppSpace.navClearance(context) - AppSpace.s),
              ],
            );
          },
        ),
      ),
    );
  }

  void _languageFixed(BuildContext context) => ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('The language can be changed after you stop listening.')));

  /// Stop: the session is saved as it is; the sheet then names it (or throws it away).
  Future<void> _stop(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final note = await s.listenSession.stop();
    if (!context.mounted) return;
    if (note == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Nothing was heard, so nothing was saved.')));
      return;
    }
    final decision = await showModalBottomSheet<_Decision>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SaveSheet(note: note),
    );
    if (decision == null) {
      messenger.showSnackBar(SnackBar(content: Text('Saved as "${note.title}".')));
    } else if (decision.discard) {
      await s.listenSession.discard(note);
      messenger.showSnackBar(const SnackBar(content: Text('The recording was thrown away.')));
    } else {
      final kept = await s.listenSession.keep(note, kind: decision.kind, title: decision.title);
      messenger.showSnackBar(SnackBar(content: Text('Saved "${kept.title}".')));
    }
  }

  static SpeechLanguage _other(SpeechLanguage l) =>
      l == SpeechLanguage.malay ? SpeechLanguage.english : SpeechLanguage.malay;
}

/// The title on the dark hero. The hero reaches [overlap] below the title, behind the top of the
/// light stage, so the stage floats over its edge like the cards on Home and Gestures.
class _Head extends StatelessWidget {
  const _Head({required this.language, required this.onSwitch});

  static const overlap = 124.0;

  final SpeechLanguage language;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) => Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(left: 0, right: 0, top: 0, bottom: -overlap, child: RepaintBoundary(child: _HeroBackdrop())),
          Padding(
            padding: EdgeInsets.fromLTRB(24, MediaQuery.paddingOf(context).top + AppSpace.s, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const ExcludeSemantics(child: Icon(Icons.volume_up_rounded, size: 14, color: AppColors.yellow)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('HEARING MODE',
                        overflow: TextOverflow.ellipsis,
                        style: AppText.eyebrow.copyWith(color: AppColors.yellow, fontSize: 12)),
                  ),
                  GlassChip(
                    icon: Icons.language_rounded,
                    label: '${language.displayName} → text',
                    tooltip: 'Listen for ${language == SpeechLanguage.malay ? 'English' : 'Malay'} instead',
                    onTap: onSwitch,
                  ),
                ]),
                const SizedBox(height: AppSpace.xs),
                Text("Speak, and they'll see it", style: AppText.screenTitle.copyWith(fontSize: 22)),
              ],
            ),
          ),
        ],
      );
}

/// The dark-blue hero with drifting colour blobs and round bottom corners (as on the other tabs).
class _HeroBackdrop extends StatelessWidget {
  const _HeroBackdrop();

  @override
  Widget build(BuildContext context) => const ClipRRect(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppRadius.hero)),
        child: DecoratedBox(decoration: BoxDecoration(gradient: AppGradients.deep), child: Aurora()),
      );
}

/// The signer's space (design: .hm-stage). With sign clips in the app, the avatar signs the words
/// and they show below it, the word being signed highlighted. Without clips: the words, big,
/// with how they will be signed as chips.
class _Stage extends StatelessWidget {
  const _Stage({required this.text, required this.listening, required this.large, required this.signer});

  final String text;
  final bool listening;
  final bool large;
  final Signer signer;

  @override
  Widget build(BuildContext context) {
    final empty = text.trim().isEmpty;
    final avatar = signer.hasClips; // it signs each sentence, also while the next one is heard
    final ours = signer.sentence == text; // the signer is on these words
    // Words still being heard (no clips: shown live) are not turned into signs until they are final.
    final signs = ours
        ? signer.steps
        : (listening && !avatar ? const <SignStep>[] : signer.translator.translate(text));
    final current = ours ? signer.currentStep : null;
    final live = avatar ? signer.signing : listening;

    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), boxShadow: AppShadows.pop),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: [
            // Turning brand-colour border, 2 px wide.
            Positioned.fill(
              child: RepaintBoundary(
                child: Spin(
                  child: Transform.scale(
                    scale: 1.6,
                    child: const DecoratedBox(decoration: BoxDecoration(gradient: AppGradients.stageBorder)),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    decoration: const BoxDecoration(gradient: AppGradients.studio),
                    child: Stack(
                      children: [
                        // A light studio: a turquoise spotlight on the signer, a warm glow from below.
                        const Positioned.fill(
                          child: DecoratedBox(decoration: BoxDecoration(gradient: AppGradients.spotlight)),
                        ),
                        const Positioned.fill(
                          child: DecoratedBox(decoration: BoxDecoration(gradient: AppGradients.stageWarm)),
                        ),
                        const Positioned(
                          top: 22,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: RepaintBoundary(child: Spin(period: Duration(seconds: 40), child: _Halo(size: 236))),
                          ),
                        ),
                        if (avatar)
                          Positioned.fill(
                            child: Padding(
                              // the top chip and buttons sit in the empty corners beside the head
                              padding: const EdgeInsets.fromLTRB(12, 30, 12, 16),
                              child: LayoutBuilder(
                                builder: (context, box) => Column(
                                  children: [
                                    // the signer gets all the room the words don't need; her clip is
                                    // cut at the skirt, so its bottom edge fades into the stage
                                    Expanded(
                                      child: ExcludeSemantics(
                                        child: ShaderMask(
                                          blendMode: BlendMode.dstIn,
                                          shaderCallback: AppGradients.avatarFade.createShader,
                                          child: SignPlayerView(player: signer.player),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: AppSpace.s),
                                    ConstrainedBox(
                                      // long words take at most a third; on a short screen they give way
                                      constraints: BoxConstraints(maxHeight: box.maxHeight / 3),
                                      child: empty
                                          ? Text('Tap Start listening. The signer signs what they say.',
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppText.body.copyWith(color: AppColors.inkSoft, fontSize: 14))
                                          : _SignedSentence(
                                              text: text,
                                              steps: signs,
                                              current: current,
                                              signed: ours ? signer.isSigned : (_) => false,
                                              large: large,
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else
                          Positioned.fill(
                            child: Center(
                              child: SingleChildScrollView(
                                reverse: true,
                                padding: const EdgeInsets.fromLTRB(22, 48, 22, 24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Semantics(
                                      liveRegion: true,
                                      child: AnimatedDefaultTextStyle(
                                        duration: AppMotion.fast,
                                        style: empty
                                            ? AppText.body.copyWith(color: AppColors.inkSoft, fontSize: 15)
                                            : AppText.heroTitle
                                                .copyWith(color: AppColors.ink, fontSize: large ? 36 : 27, height: 1.3),
                                        child: Text(
                                            empty
                                                ? (listening
                                                    ? 'Listening…'
                                                    : 'Tap Start listening.\nTheir words show up here, big and clear.')
                                                : text,
                                            textAlign: TextAlign.center),
                                      ),
                                    ),
                                    if (signs.isNotEmpty) ...[
                                      const SizedBox(height: AppSpace.l),
                                      _SignChips(signs: signs),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          top: 12,
                          left: 12,
                          child: _StageChip(
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              PulseDot(color: live ? AppColors.live : AppColors.offline, active: live),
                              const SizedBox(width: 7),
                              Text(signer.hasClips ? 'BIM signer' : 'BIM signer · coming soon',
                                  style: AppText.label.copyWith(color: AppColors.inkSoft, fontSize: 11.5)),
                            ]),
                          ),
                        ),
                        if (avatar)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Row(children: [
                              _StageButton(
                                icon: Icons.replay_rounded,
                                label: 'Sign it again',
                                onTap: ours && signer.canReplay ? signer.replay : null,
                              ),
                              _StageButton(
                                icon: Icons.slow_motion_video_rounded,
                                label: 'Slower signing',
                                selected: signer.slow,
                                onTap: signer.toggleSlow,
                              ),
                            ]),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The words under the signer; the word being signed now is highlighted (design: .hm-chunk.active).
/// Words the avatar can't sign yet (no clip) are grey, with a note saying so.
class _SignedSentence extends StatelessWidget {
  const _SignedSentence({
    required this.text,
    required this.steps,
    required this.current,
    required this.signed,
    required this.large,
  });

  final String text;
  final List<SignStep> steps;
  final int? current;
  final bool Function(int step) signed;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    var at = 0;
    var unsigned = false;
    for (final (i, step) in steps.indexed) {
      if (step.start > at) spans.add(TextSpan(text: text.substring(at, step.start)));
      if (!signed(i)) unsigned = true;
      spans.add(TextSpan(
        text: text.substring(step.start, step.end),
        style: i == current
            ? const TextStyle(color: AppColors.onYellow, backgroundColor: AppColors.yellow)
            : (signed(i) ? null : const TextStyle(color: AppColors.inkFaint)), // large text: 3:1 is enough
      ));
      at = step.end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return Semantics(
      liveRegion: true,
      label: text,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text.rich(
              TextSpan(
                  style: AppText.heroTitle.copyWith(color: AppColors.ink, fontSize: large ? 26 : 20, height: 1.35),
                  children: spans),
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (unsigned)
            Flexible(
              child: Text('Grey words have no sign clip yet.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.small.copyWith(color: AppColors.inkSoft, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

/// A small round button on the stage (replay, slower).
class _StageButton extends StatelessWidget {
  const _StageButton({required this.icon, required this.label, required this.onTap, this.selected = false});

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
              dimension: 48, // the tap area; the circle drawn inside is 40
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
                  child: Icon(icon,
                      size: 18,
                      color: selected ? AppColors.onDark : (onTap == null ? AppColors.inkFaint : AppColors.ink)),
                ),
              ),
            ),
          ),
        ),
      );
}

/// The words as signs (glosses): turquoise = a sign from the dictionary, outlined with "abc" =
/// fingerspelled letter by letter (no sign for it).
class _SignChips extends StatelessWidget {
  const _SignChips({required this.signs});

  final List<SignStep> signs;

  @override
  Widget build(BuildContext context) {
    final summary = [for (final s in signs) s.spelled ? 'spelled ${s.label.replaceAll('·', ' ')}' : s.label];
    return Semantics(
      label: 'In signs: ${summary.join(', ')}',
      excludeSemantics: true,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final step in signs)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: step.spelled ? AppColors.line : AppColors.turq),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (step.spelled) ...[
                    const Icon(Icons.abc_rounded, size: 18, color: AppColors.inkSoft),
                    const SizedBox(width: 4),
                  ],
                  Text(step.label,
                      style: AppText.eyebrow.copyWith(
                        fontFamily: AppFonts.display,
                        fontSize: 12,
                        letterSpacing: 0.8,
                        color: step.spelled ? AppColors.inkSoft : AppColors.turqDeep,
                      )),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.line),
        ),
        child: child,
      );
}

/// Dashed circle behind the stage text (design: .hm-halo).
class _Halo extends StatelessWidget {
  const _Halo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(dimension: size, child: CustomPaint(painter: _HaloPainter()));
}

class _HaloPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final dash = Paint()
      ..color = AppColors.haloDash
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const n = 48;
    for (var i = 0; i < n; i++) {
      final a = i * 2 * pi / n;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), a, pi / n, false, dash);
    }
    canvas.drawCircle(
      c,
      r - 22,
      Paint()
        ..color = AppColors.haloRing
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_HaloPainter old) => false;
}

/// This session's sentences (design: .hm-card), the newest at the bottom, and the words being heard
/// right now under them.
class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.lines, required this.live, required this.state});

  final List<NoteLine> lines;
  final String live;
  final ListenState state;

  @override
  Widget build(BuildContext context) {
    final listening = state == ListenState.listening;
    final title = state != ListenState.idle ? 'THIS SESSION' : (lines.isEmpty ? 'WHAT THEY SAID' : 'LAST SESSION');
    return Container(
      height: 120,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const ExcludeSemantics(child: Icon(Icons.subject_rounded, size: 15, color: AppColors.turq)),
            const SizedBox(width: 6),
            Text(title, style: AppText.eyebrow.copyWith(color: AppColors.inkSoft)),
            const Spacer(),
            if (listening) ...[
              const PulseDot(color: AppColors.yellow),
              const SizedBox(width: 6),
              Text('Listening', style: AppText.eyebrow.copyWith(color: AppColors.onYellowInk, letterSpacing: 0)),
            ] else if (lines.isNotEmpty)
              Text('${lines.length} ${lines.length == 1 ? 'sentence' : 'sentences'}',
                  style: AppText.small.copyWith(color: AppColors.inkSoft)),
          ]),
          const SizedBox(height: 6),
          Expanded(
            child: lines.isEmpty && live.isEmpty
                ? (listening // the wave below says it is listening
                    ? const SizedBox.shrink()
                    : Text(
                        'Listen to a meeting, a class or a consultation. Every sentence is kept as a note.',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body.copyWith(color: AppColors.inkSoft, fontSize: 13),
                      ))
                : ListView(
                    reverse: true,
                    padding: EdgeInsets.zero,
                    children: [
                      if (live.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(live,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.strong.copyWith(color: AppColors.inkSoft, fontStyle: FontStyle.italic)),
                        ),
                      for (final line in lines.reversed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(line.text,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.strong.copyWith(color: AppColors.ink)),
                        ),
                    ],
                  ),
          ),
          if (listening && live.isEmpty) const Waveform(color: AppColors.turq, bars: 34, height: 18),
        ],
      ),
    );
  }
}

class _Foot extends StatelessWidget {
  const _Foot({
    required this.state,
    required this.startedAt,
    required this.large,
    required this.onMic,
    required this.onStop,
    required this.onToggleSize,
  });

  final ListenState state;
  final DateTime? startedAt;
  final bool large;
  final VoidCallback onMic;
  final VoidCallback? onStop; // null when there is no session to stop
  final VoidCallback onToggleSize;

  @override
  Widget build(BuildContext context) {
    final label = AppText.label.copyWith(color: AppColors.inkSoft, fontSize: 12);
    return Padding(
      padding: const EdgeInsets.fromLTRB(34, 12, 34, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _SideButton(
            tooltip: large ? 'Normal text size' : 'Bigger text',
            selected: large,
            onTap: onToggleSize,
            child: Text('Aa', style: AppText.label.copyWith(color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: 14)),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MicButton(state: state, onTap: onMic),
                const SizedBox(height: 6),
                ExcludeSemantics(
                  // The mic button already says this to screen readers; don't read it twice.
                  child: state == ListenState.idle || startedAt == null
                      ? Text('Start listening', style: label, maxLines: 1, overflow: TextOverflow.ellipsis)
                      : _Elapsed(prefix: state == ListenState.listening ? 'Listening' : 'Paused', since: startedAt!, style: label),
                ),
              ],
            ),
          ),
          _SideButton(
            tooltip: 'Stop and save',
            onTap: onStop,
            child: const Icon(Icons.stop_rounded, color: AppColors.ink, size: 22),
          ),
        ],
      ),
    );
  }
}

/// "Listening · 12:05": how long the session has been going, ticking every second.
class _Elapsed extends StatefulWidget {
  const _Elapsed({required this.prefix, required this.since, required this.style});

  final String prefix;
  final DateTime since;
  final TextStyle style;

  @override
  State<_Elapsed> createState() => _ElapsedState();
}

class _ElapsedState extends State<_Elapsed> {
  late final Timer _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));

  @override
  void initState() {
    super.initState();
    _tick; // starts it
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = DateTime.now().difference(widget.since);
    String two(int n) => n.toString().padLeft(2, '0');
    final time = d.inHours > 0
        ? '${d.inHours}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}'
        : '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
    return Text('${widget.prefix} · $time', style: widget.style, maxLines: 1, overflow: TextOverflow.ellipsis);
  }
}

class _SideButton extends StatelessWidget {
  const _SideButton({required this.tooltip, required this.child, this.onTap, this.selected = false});

  final String tooltip;
  final Widget child;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Tooltip(
          message: tooltip,
          child: Opacity(
            opacity: onTap == null ? 0.35 : 1,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(16),
                child: Ink(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.turq.withValues(alpha: 0.14) : AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: selected ? AppColors.turq : AppColors.line),
                  ),
                  child: Center(child: child),
                ),
              ),
            ),
          ),
        ),
      );
}

/// Big yellow button with a turning ring while listening (design: .reply-ptt): Start, Pause, Continue.
class _MicButton extends StatelessWidget {
  const _MicButton({required this.state, required this.onTap});

  final ListenState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final listening = state == ListenState.listening;
    final (icon, label) = switch (state) {
      ListenState.idle => (Icons.mic_rounded, 'Start listening'),
      ListenState.listening => (Icons.pause_rounded, 'Pause listening'),
      ListenState.paused => (Icons.mic_rounded, 'Continue listening'),
    };
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox.square(
          dimension: 86,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (listening)
                Spin(
                  period: const Duration(seconds: 3),
                  child: SizedBox.square(dimension: 86, child: CustomPaint(painter: _RingPainter())),
                ),
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  gradient: AppGradients.sun,
                  shape: BoxShape.circle,
                  boxShadow: [
                    ...AppShadows.sunGlow,
                    BoxShadow(color: AppColors.yellow.withValues(alpha: 0.1), spreadRadius: 8),
                  ],
                ),
                child: Icon(icon, size: 30, color: AppColors.onYellow),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawCircle(
      size.center(Offset.zero),
      size.width / 2 - 2,
      Paint()
        ..shader = AppGradients.micRing.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => false;
}

/// What the save sheet decided: keep the note as [kind] with [title], or throw it away.
class _Decision {
  const _Decision.keep(this.kind, this.title) : discard = false;
  const _Decision.discard()
      : kind = NoteKind.other,
        title = '',
        discard = true;

  final NoteKind kind;
  final String title;
  final bool discard;
}

/// After Stop: what was it (meeting, class...) and its title. Closing the sheet keeps the note as it is.
class _SaveSheet extends StatefulWidget {
  const _SaveSheet({required this.note});

  final ListenNote note;

  @override
  State<_SaveSheet> createState() => _SaveSheetState();
}

class _SaveSheetState extends State<_SaveSheet> {
  var _kind = NoteKind.meeting;
  late final _title = TextEditingController(text: ListenSession.defaultTitle(_kind, widget.note.startedAt));
  var _edited = false; // a typed title is not replaced when the kind changes

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _pick(NoteKind kind) => setState(() {
        _kind = kind;
        if (!_edited) _title.text = ListenSession.defaultTitle(kind, widget.note.startedAt);
      });

  Future<void> _discard() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Throw this recording away?'),
        content: const Text('Everything heard in this session will be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep it')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Throw away')),
        ],
      ),
    );
    if (sure == true && mounted) Navigator.pop(context, const _Decision.discard());
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final minutes = note.duration.inMinutes;
    final eyebrow = AppText.eyebrow.copyWith(color: AppColors.inkSoft);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(AppRadius.pill)),
                  ),
                ),
                const SizedBox(height: AppSpace.l),
                Text('Save this listening', style: AppText.section.copyWith(fontSize: 20)),
                const SizedBox(height: AppSpace.xs),
                Text(
                    '${note.lines.length} ${note.lines.length == 1 ? 'sentence' : 'sentences'} · '
                    '${minutes < 1 ? 'under a minute' : '$minutes min'}',
                    style: AppText.body.copyWith(color: AppColors.inkSoft)),
                const SizedBox(height: AppSpace.xl),
                Text('WHAT WAS IT?', style: eyebrow),
                const SizedBox(height: AppSpace.s),
                Wrap(
                  spacing: AppSpace.s,
                  runSpacing: AppSpace.s,
                  children: [
                    for (final kind in NoteKind.values)
                      _KindChip(kind: kind, selected: kind == _kind, onTap: () => _pick(kind)),
                  ],
                ),
                const SizedBox(height: AppSpace.xl),
                Text('TITLE', style: eyebrow),
                const SizedBox(height: AppSpace.s),
                TextField(
                  controller: _title,
                  onChanged: (_) => _edited = true,
                  textCapitalization: TextCapitalization.sentences,
                  style: AppText.strong.copyWith(color: AppColors.ink),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surface2,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.xl),
                GradientButton(
                  label: 'Save note',
                  icon: Icons.bookmark_added_rounded,
                  onTap: () => Navigator.pop(context, _Decision.keep(_kind, _title.text)),
                ),
                const SizedBox(height: AppSpace.s),
                TextButton(
                  onPressed: _discard,
                  child: Text('Throw it away', style: AppText.label.copyWith(color: AppColors.inkSoft, fontSize: 14)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One kind to choose in the save sheet.
class _KindChip extends StatelessWidget {
  const _KindChip({required this.kind, required this.selected, required this.onTap});

  final NoteKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: kind.label,
        excludeSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: selected ? AppGradients.turq : null,
                color: selected ? null : AppColors.surface2,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                boxShadow: selected ? AppShadows.turqTile : null,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(noteKindIcon(kind), size: 17, color: selected ? AppColors.onDark : AppColors.turqDeep),
                const SizedBox(width: 7),
                Text(kind.label,
                    style: AppText.label.copyWith(color: selected ? AppColors.onDark : AppColors.ink, fontSize: 13.5)),
              ]),
            ),
          ),
        ),
      );
}
