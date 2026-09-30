import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_services.dart';
import '../history/conversation_log.dart';
import '../signer/sign_player_view.dart';
import '../signer/sign_translator.dart';
import '../signer/signer.dart';
import '../speech/sign_words.dart';
import '../theme/app_theme.dart';
import '../ui/widgets/glass_chip.dart';
import '../ui/widgets/motion.dart';
import '../ui/widgets/notice.dart';

/// Hearing mode (design: hearing.jsx): the hearing person talks and the signer reads it big.
/// The stage is where the BIM signer avatar will go later; for now it shows the words.
class HearingScreen extends StatefulWidget {
  const HearingScreen({super.key, required this.services});

  final AppServices services;

  /// Quick replies the hearing person can tap instead of speaking: (Malay, English).
  /// Every word in them must have a sign (test/sign_translator_test.dart checks it).
  static const quickReplies = [
    ('Terima kasih', 'Thank you'),
    ('Ya', 'Yes'),
    ('Tidak', 'No'),
    ('Saya', 'Me'),
    ('Nama', 'Name'),
  ];

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
        child: Stack(
          children: [
            ListenableBuilder(
              listenable: s.changes,
              builder: (context, _) {
                final listening = s.transcriber.listening;
                final language = s.speaker.language;
                final heard = [for (final m in s.log.messages) if (m.side == Side.them) m.text];
                final current = listening ? s.transcriber.text : (heard.isEmpty ? '' : heard.last);
                final older = listening ? heard : heard.take(max(0, heard.length - 1)).toList();
                final earlier = older.length > 3 ? older.sublist(older.length - 3) : older;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Head(language: language, onSwitch: () => s.setLanguage(_other(language))),
                    if (!listening && s.transcriber.problem != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                        child: Notice(message: s.transcriber.problem!),
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                        child: _Stage(text: current, listening: listening, large: _large, signer: s.signer),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                      child: _EarlierCard(lines: earlier, listening: listening),
                    ),
                    SizedBox(
                      height: 58,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                        children: [
                          for (final (ms, en) in HearingScreen.quickReplies)
                            _QuickChip(
                              text: language == SpeechLanguage.malay ? ms : en,
                              onTap: () => s.log.addHeard(language == SpeechLanguage.malay ? ms : en),
                            ),
                        ],
                      ),
                    ),
                    _Foot(
                      listening: listening,
                      large: _large,
                      canClear: s.log.messages.isNotEmpty,
                      onTalk: s.talk,
                      onToggleSize: () => setState(() => _large = !_large),
                      onClear: s.log.clear,
                    ),
                    SizedBox(height: AppSpace.navClearance(context) - AppSpace.s),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
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
    final avatar = signer.hasClips && !listening;
    final ours = signer.sentence == text; // the signer is on these words
    final signs = listening ? const <SignStep>[] : (ours ? signer.steps : signer.translator.translate(text));
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
                                          ? Text('Tap the mic and talk. The signer signs it.',
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
                                                    : 'Tap the mic and talk.\nYour words show up here, big and clear.')
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

/// Their earlier sentences (design: .hm-card "What they said").
class _EarlierCard extends StatelessWidget {
  const _EarlierCard({required this.lines, required this.listening});

  final List<String> lines;
  final bool listening;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88, // kept low so the signer's stage gets the height
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
            const ExcludeSemantics(child: Icon(Icons.history_rounded, size: 15, color: AppColors.turq)),
            const SizedBox(width: 6),
            Text('WHAT THEY SAID', style: AppText.eyebrow.copyWith(color: AppColors.inkSoft)),
            const Spacer(),
            if (listening) ...[
              const PulseDot(color: AppColors.yellow),
              const SizedBox(width: 6),
              Text('Transcribing', style: AppText.eyebrow.copyWith(color: AppColors.onYellowInk, letterSpacing: 0)),
            ],
          ]),
          const SizedBox(height: 6),
          Expanded(
            child: lines.isEmpty
                ? (listening // the wave below says it is listening; the hint would not fit next to it
                    ? const SizedBox.shrink()
                    : Text(
                        'Earlier sentences are kept here. Quick replies below work without speaking.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body.copyWith(color: AppColors.inkSoft, fontSize: 13),
                      ))
                : ListView(
                    reverse: true,
                    padding: EdgeInsets.zero,
                    children: [
                      for (final line in lines.reversed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(line,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.strong.copyWith(color: AppColors.ink)),
                        ),
                    ],
                  ),
          ),
          if (listening) const Waveform(color: AppColors.turq, bars: 34, height: 18),
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: AppSpace.s),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            customBorder: const StadiumBorder(),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: AppColors.line),
              ),
              child: Text(text, style: AppText.label.copyWith(color: AppColors.ink, fontSize: 13)),
            ),
          ),
        ),
      );
}

class _Foot extends StatelessWidget {
  const _Foot({
    required this.listening,
    required this.large,
    required this.canClear,
    required this.onTalk,
    required this.onToggleSize,
    required this.onClear,
  });

  final bool listening;
  final bool large;
  final bool canClear;
  final VoidCallback onTalk;
  final VoidCallback onToggleSize;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
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
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MicButton(listening: listening, onTap: onTalk),
              const SizedBox(height: 6),
              ExcludeSemantics(
                // The mic button already says this to screen readers; don't read it twice.
                child: Text(listening ? 'Listening' : 'Tap to speak',
                    style: AppText.label.copyWith(color: AppColors.inkSoft, fontSize: 12)),
              ),
            ],
          ),
          _SideButton(
            tooltip: 'Clear conversation',
            onTap: canClear ? onClear : null,
            child: const Icon(Icons.delete_sweep_rounded, color: AppColors.ink, size: 20),
          ),
        ],
      ),
    );
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

/// Big yellow tap-to-talk button with a turning ring while listening (design: .reply-ptt).
class _MicButton extends StatelessWidget {
  const _MicButton({required this.listening, required this.onTap});

  final bool listening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: listening ? 'Stop listening' : 'Tap to speak',
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
                child: Icon(listening ? Icons.stop_rounded : Icons.mic_rounded, size: 30, color: AppColors.onYellow),
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
