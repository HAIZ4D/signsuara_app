import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_services.dart';
import '../history/conversation_log.dart';
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

  @override
  State<HearingScreen> createState() => _HearingScreenState();
}

class _HearingScreenState extends State<HearingScreen> {
  var _large = false; // bigger text on the stage, easier to read from further away

  /// Quick replies the hearing person can tap instead of speaking: (Malay, English).
  static const _quick = [
    ('Sila tunggu', 'Please wait'),
    ('Terima kasih', 'Thank you'),
    ('Ya', 'Yes'),
    ('Tidak', 'No'),
  ];

  AppServices get s => widget.services;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppGradients.deep),
        child: Stack(
          children: [
            const Positioned.fill(child: Aurora()),
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
                        child: _Stage(text: current, listening: listening, large: _large),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                      child: _EarlierCard(lines: earlier, listening: listening),
                    ),
                    SizedBox(
                      height: 56,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                        children: [
                          for (final (ms, en) in _quick)
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

class _Head extends StatelessWidget {
  const _Head({required this.language, required this.onSwitch});

  final SpeechLanguage language;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(24, MediaQuery.paddingOf(context).top + AppSpace.s, 20, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.volume_up_rounded, size: 14, color: AppColors.yellow),
                    const SizedBox(width: 6),
                    Text('HEARING MODE', style: AppText.eyebrow.copyWith(color: AppColors.yellow, fontSize: 12)),
                  ]),
                  const SizedBox(height: 6),
                  Text("Speak, and they'll see it", style: AppText.screenTitle.copyWith(fontSize: 22)),
                ],
              ),
            ),
            GlassChip(
              icon: Icons.language_rounded,
              label: '${language.displayName} → text',
              tooltip: 'Listen for ${language == SpeechLanguage.malay ? 'English' : 'Malay'} instead',
              onTap: onSwitch,
            ),
          ],
        ),
      );
}

/// Where the signer will stand one day; now: the words, big (design: .hm-stage).
class _Stage extends StatelessWidget {
  const _Stage({required this.text, required this.listening, required this.large});

  final String text;
  final bool listening;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final empty = text.trim().isEmpty;
    final shown = empty
        ? (listening ? 'Listening…' : 'Tap the mic and talk.\nYour words show up here, big and clear.')
        : text;
    final (gloss, glossSun) = listening ? ('LISTENING…', false) : (empty ? ('READY', false) : ('SAID', true));

    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), boxShadow: AppShadows.turqGlow),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: [
            // Turning colour border, 1.5 px wide.
            Positioned.fill(
              child: Spin(
                child: Transform.scale(
                  scale: 1.6,
                  child: const DecoratedBox(decoration: BoxDecoration(gradient: AppGradients.stageBorder)),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(1.5),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28.5),
                  child: Container(
                    decoration: const BoxDecoration(gradient: AppGradients.stage),
                    foregroundDecoration: const BoxDecoration(gradient: AppGradients.stageGlow),
                    child: Stack(
                      children: [
                        const Positioned(
                          top: 18,
                          left: 0,
                          right: 0,
                          child: Center(child: Spin(period: Duration(seconds: 40), child: _Halo(size: 200))),
                        ),
                        Positioned.fill(
                          child: Center(
                            child: SingleChildScrollView(
                              reverse: true,
                              padding: const EdgeInsets.fromLTRB(22, 48, 22, 54),
                              child: Semantics(
                                liveRegion: true,
                                child: AnimatedDefaultTextStyle(
                                  duration: AppMotion.fast,
                                  style: empty
                                      ? AppText.body.copyWith(color: AppColors.onDarkSoft, fontSize: 15)
                                      : AppText.heroTitle.copyWith(fontSize: large ? 36 : 27, height: 1.3),
                                  child: Text(shown, textAlign: TextAlign.center),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 12,
                          left: 12,
                          child: _StageChip(
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              PulseDot(color: listening ? AppColors.live : AppColors.offline, active: listening),
                              const SizedBox(width: 7),
                              Text('BIM signer · coming soon',
                                  style: AppText.label.copyWith(color: AppColors.onDarkSoft, fontSize: 11.5)),
                            ]),
                          ),
                        ),
                        Positioned(
                          bottom: 14,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: AnimatedContainer(
                              duration: AppMotion.medium,
                              curve: AppMotion.springCurve,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: glossSun ? AppGradients.sun : null,
                                color: glossSun ? null : AppColors.chipOnStage,
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                                border: Border.all(color: glossSun ? AppColors.yellow : AppColors.glassBorder),
                                boxShadow: glossSun ? AppShadows.sunGlow : null,
                              ),
                              child: Text(gloss,
                                  style: AppText.eyebrow.copyWith(
                                    fontFamily: AppFonts.display,
                                    fontSize: 13,
                                    letterSpacing: 1,
                                    color: glossSun ? AppColors.onYellow : AppColors.onDarkSoft,
                                  )),
                            ),
                          ),
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

class _StageChip extends StatelessWidget {
  const _StageChip({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(color: AppColors.chipOnStage, borderRadius: BorderRadius.circular(AppRadius.pill)),
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
      ..color = AppColors.onDark.withValues(alpha: 0.14)
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
        ..color = AppColors.yellow.withValues(alpha: 0.16)
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
      height: 112,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('WHAT THEY SAID', style: AppText.eyebrow.copyWith(color: AppColors.onDarkFaint)),
            const Spacer(),
            if (listening) ...[
              const PulseDot(color: AppColors.yellow),
              const SizedBox(width: 6),
              Text('Transcribing', style: AppText.eyebrow.copyWith(color: AppColors.yellow, letterSpacing: 0)),
            ],
          ]),
          const SizedBox(height: 6),
          Expanded(
            child: lines.isEmpty
                ? Text(
                    'Earlier sentences are kept here. Quick replies below work without speaking.',
                    style: AppText.body.copyWith(color: AppColors.onDarkSoft, fontSize: 13),
                  )
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
                              style: AppText.strong.copyWith(color: AppColors.onDark.withValues(alpha: 0.75))),
                        ),
                    ],
                  ),
          ),
          if (listening) const Waveform(color: AppColors.yellow, bars: 34, height: 18),
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
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.glass,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Text(text, style: AppText.label.copyWith(color: AppColors.onDark, fontSize: 13)),
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
            child: Text('Aa', style: AppText.label.copyWith(color: AppColors.onDark, fontWeight: FontWeight.w800, fontSize: 14)),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MicButton(listening: listening, onTap: onTalk),
              const SizedBox(height: 6),
              ExcludeSemantics(
                // The mic button already says this to screen readers; don't read it twice.
                child: Text(listening ? 'Listening' : 'Tap to speak',
                    style: AppText.label.copyWith(color: AppColors.onDarkSoft, fontSize: 12)),
              ),
            ],
          ),
          _SideButton(
            tooltip: 'Clear conversation',
            onTap: canClear ? onClear : null,
            child: const Icon(Icons.delete_sweep_rounded, color: AppColors.onDark, size: 20),
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
                    color: selected ? AppColors.turq.withValues(alpha: 0.22) : AppColors.glass,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: selected ? AppColors.turqBright.withValues(alpha: 0.5) : AppColors.glassBorder),
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
