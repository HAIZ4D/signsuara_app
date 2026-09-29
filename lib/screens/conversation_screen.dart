import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_services.dart';
import '../glove/glove_session.dart';
import '../signer/sign_player_view.dart';
import '../signer/signer.dart';
import '../speech/sign_words.dart';
import '../theme/app_theme.dart';
import '../ui/finger_bend.dart';
import '../ui/widgets/brand.dart';
import '../ui/widgets/chat_bubble.dart';
import '../ui/widgets/finger_bars.dart';
import '../ui/widgets/glass_chip.dart';
import '../ui/widgets/glove_card.dart';
import '../ui/widgets/hero_panel.dart';
import '../ui/widgets/motion.dart';
import '../ui/widgets/notice.dart';

/// Live two-way conversation (design: screens-v2.jsx LiveScreen): my signs and their speech as
/// chat bubbles, with the glove's live finger sensors and a "They speak" turn toggle.
class ConversationScreen extends StatelessWidget {
  const ConversationScreen({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ListenableBuilder(
        listenable: services.changes,
        builder: (context, _) {
          final listening = services.transcriber.listening;
          final connected = services.session.link == GloveLink.connected;
          return Column(
            children: [
              _Hero(services: services, listening: listening, connected: connected),
              Expanded(child: _Chat(services: services, listening: listening, connected: connected)),
              _Dock(services: services, listening: listening, connected: connected),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------- hero

class _Hero extends StatelessWidget {
  const _Hero({required this.services, required this.listening, required this.connected});

  final AppServices services;
  final bool listening;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final language = services.speaker.language;
    final other = language == SpeechLanguage.malay ? SpeechLanguage.english : SpeechLanguage.malay;
    final live = connected || listening;
    return HeroPanel(
      bottomPadding: AppSpace.l,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      PulseDot(color: live ? AppColors.recDot : AppColors.offline, active: live),
                      const SizedBox(width: 6),
                      Text(live ? 'LIVE' : 'GLOVE OFF',
                          style: AppText.eyebrow.copyWith(color: live ? AppColors.recText : AppColors.onDarkSoft)),
                    ]),
                    const SizedBox(height: 2),
                    Text('Conversation', style: AppText.screenTitle),
                  ],
                ),
              ),
              GlassChip(
                icon: Icons.language_rounded,
                label: language.displayName,
                tooltip: 'Speak in ${other.displayName} instead',
                onTap: () => services.setLanguage(other),
              ),
              if (services.log.messages.isNotEmpty) ...[
                const SizedBox(width: AppSpace.s),
                GlassChip(
                  icon: Icons.delete_sweep_rounded,
                  tooltip: 'Clear conversation',
                  onTap: services.log.clear,
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Person(
                  initial: services.userName.isEmpty ? 'Y' : services.userName[0].toUpperCase(),
                  name: 'You',
                  status: listening ? 'Watching' : (connected ? 'Signing' : 'Glove off'),
                  on: !listening && connected,
                  me: true,
                ),
              ),
              const SizedBox(width: AppSpace.s),
              FlowDots(color: listening ? AppColors.yellow : AppColors.turqBright, reverse: listening),
              const SizedBox(width: AppSpace.s),
              Expanded(
                child: _Person(
                  initial: 'T',
                  name: 'Them',
                  status: listening ? 'Speaking' : 'Listening',
                  on: listening,
                  me: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "You" / "Them" card; lights up (turquoise for me, yellow for them) when that side is active.
class _Person extends StatelessWidget {
  const _Person({required this.initial, required this.name, required this.status, required this.on, required this.me});

  final String initial;
  final String name;
  final String status;
  final bool on;
  final bool me;

  @override
  Widget build(BuildContext context) {
    final accent = me ? AppColors.turqBright : AppColors.yellow;
    final avatar = Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: me ? AppGradients.turq : AppGradients.sun,
        borderRadius: BorderRadius.circular(AppSpace.m),
      ),
      child: Text(initial,
          style: AppText.strong.copyWith(
              fontFamily: AppFonts.display, fontSize: 14, color: me ? AppColors.onDark : AppColors.onYellow)),
    );
    final text = Column(
      crossAxisAlignment: me ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text(name, style: AppText.strong.copyWith(color: AppColors.onDark, fontSize: 13.5)),
        Text(status, style: AppText.small.copyWith(color: on ? AppColors.onDark : AppColors.onDarkSoft, fontSize: 11)),
      ],
    );
    return Semantics(
      label: '$name: $status',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: AppMotion.medium,
        curve: AppMotion.outCurve,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: on ? accent.withValues(alpha: 0.14) : AppColors.glass,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: on ? accent.withValues(alpha: 0.8) : AppColors.glass, width: 1.5),
          boxShadow: on ? [BoxShadow(color: accent.withValues(alpha: 0.6), blurRadius: 22, spreadRadius: -4)] : null,
        ),
        child: Row(
          mainAxisAlignment: me ? MainAxisAlignment.start : MainAxisAlignment.end,
          children: me
              ? [avatar, const SizedBox(width: 9), Flexible(child: text)]
              : [Flexible(child: text), const SizedBox(width: 9), avatar],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- chat

class _Chat extends StatelessWidget {
  const _Chat({required this.services, required this.listening, required this.connected});

  final AppServices services;
  final bool listening;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final language = services.speaker.language;
    final messages = services.log.messages;
    final notices = [
      if (connected && !services.session.motionSensorOk)
        const Notice(message: 'Motion sensor disconnected', color: AppColors.danger),
      if (services.speaker.problem != null) Notice(message: services.speaker.problem!),
      if (!listening && services.transcriber.problem != null) Notice(message: services.transcriber.problem!),
    ];
    // Newest at the bottom: build in reading order, show in a reversed list (sticks to the bottom).
    final items = <Widget>[
      const Center(child: DayChip('Today')),
      if (messages.isEmpty && !listening) const _EmptyChat(),
      for (final m in messages)
        if (m.label case final label?)
          ChatBubble.signed(
            key: ObjectKey(m),
            words: services.words(label),
            language: language,
            onRepeat: () => services.speaker.say(label),
          )
        else
          ChatBubble.heard(
            key: ObjectKey(m),
            text: m.text,
            onRepeat: services.signer.hasClips ? () => services.signer.signAgain(m.text) : null,
          ),
      if (listening) _DraftBubble(text: services.transcriber.text),
    ];
    return Column(
      children: [
        if (notices.isNotEmpty)
          Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 0), child: Column(children: notices)),
        Expanded(
          child: ListView(
            reverse: true,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            children: items.reversed.toList(),
          ),
        ),
      ],
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 30),
        child: Column(
          children: [
            const Icon(Icons.waving_hand_rounded, size: 34, color: AppColors.turq),
            const SizedBox(height: 10),
            Text(
              'Sign with your glove and your words appear here, spoken aloud.\n'
              'When the other person talks, tap "They speak".',
              textAlign: TextAlign.center,
              style: AppText.body.copyWith(color: AppColors.inkFaint),
            ),
          ],
        ),
      );
}

/// Their words appearing live while the mic listens.
class _DraftBubble extends StatelessWidget {
  const _DraftBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Semantics(
            liveRegion: true,
            label: text.isEmpty ? 'Listening' : 'They are saying: $text',
            excludeSemantics: true,
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
              padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                boxShadow: AppShadows.card,
                border: Border.all(color: AppColors.yellow, width: 1.5),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(22),
                  topRight: Radius.circular(22),
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(22),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const PulseDot(color: AppColors.yellow),
                    const SizedBox(width: 6),
                    Text('LISTENING', style: AppText.eyebrow.copyWith(fontSize: 10.5, color: AppColors.onYellowInk)),
                  ]),
                  const SizedBox(height: 5),
                  Text(text.isEmpty ? '…' : text,
                      style: AppText.strong.copyWith(color: AppColors.ink, fontWeight: FontWeight.w600, height: 1.4)),
                ],
              ),
            ),
          ),
        ),
      );
}

// ---------------------------------------------------------------- dock

class _Dock extends StatelessWidget {
  const _Dock({required this.services, required this.listening, required this.connected});

  final AppServices services;
  final bool listening;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(14, 6, 14, AppSpace.navClearance(context)),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: AppGradients.deep,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppShadows.dock,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TurnToggle(
            listening: listening,
            onYouSign: () => listening ? services.talk() : null, // talk() stops the mic
            onTheySpeak: () => listening ? null : services.talk(), // talk() starts the mic
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: AppMotion.reduced(context) ? Duration.zero : AppMotion.medium,
            switchInCurve: AppMotion.outCurve,
            child: listening
                ? const _ListeningStage(key: ValueKey('stage'))
                : services.signer.hasClips && services.signer.signing
                    ? _SigningStage(key: const ValueKey('signing'), signer: services.signer)
                    : _SensorRow(key: const ValueKey('sensors'), services: services, connected: connected),
          ),
        ],
      ),
    );
  }
}

/// "You sign | They speak" with a sliding highlight (design: .cv-turn).
class _TurnToggle extends StatelessWidget {
  const _TurnToggle({required this.listening, required this.onYouSign, required this.onTheySpeak});

  final bool listening;
  final VoidCallback onYouSign;
  final VoidCallback onTheySpeak;

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.reduced(context) ? Duration.zero : AppMotion.slow;
    Widget half(String label, IconData icon, bool on, Color onColor, VoidCallback tap) => Expanded(
          child: Semantics(
            button: true,
            selected: on,
            label: label,
            excludeSemantics: true,
            child: InkWell(
              onTap: tap,
              customBorder: const StadiumBorder(),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(icon, size: 15, color: on ? onColor : AppColors.onDarkFaint),
                  const SizedBox(width: 6),
                  Text(label, style: AppText.label.copyWith(fontWeight: FontWeight.w800, color: on ? onColor : AppColors.onDarkFaint)),
                ]),
              ),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: AppColors.glass, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedAlign(
              duration: duration,
              curve: AppMotion.navCurve,
              alignment: listening ? Alignment.centerRight : Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                child: AnimatedContainer(
                  duration: duration,
                  decoration: BoxDecoration(
                    gradient: listening ? AppGradients.sun : AppGradients.turq,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    boxShadow: listening ? AppShadows.sunGlow : AppShadows.turqTile,
                  ),
                ),
              ),
            ),
          ),
          Row(children: [
            half('You sign', Icons.waving_hand_rounded, !listening, AppColors.onDark, onYouSign),
            half('They speak', Icons.mic_rounded, listening, AppColors.onYellow, onTheySpeak),
          ]),
        ],
      ),
    );
  }
}

/// My turn: the hand visual + live finger bars (or how to connect the glove).
class _SensorRow extends StatelessWidget {
  const _SensorRow({super.key, required this.services, required this.connected});

  final AppServices services;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final session = services.session;
    final bends = fingerBend(session.lastRow);
    return Row(
      children: [
        Container(
          width: 76,
          height: 76,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.well, borderRadius: BorderRadius.circular(22)),
          child: HandSensor(bends: bends, active: connected, size: 62),
        ),
        const SizedBox(width: AppSpace.m),
        Expanded(
          child: connected
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FingerBars(bends: bends),
                    const SizedBox(height: 6),
                    Text('Reading all five finger sensors',
                        style: AppText.small.copyWith(color: AppColors.onDarkSoft, fontSize: 11.5)),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Glove not connected', style: AppText.strong.copyWith(color: AppColors.onDark, fontSize: 14)),
                          Text(session.status,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.small.copyWith(color: AppColors.onDarkSoft, fontSize: 11.5)),
                        ],
                      ),
                    ),
                    GloveActionButton(link: session.link, ble: services.ble),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Their turn: space reserved for the future BIM signer avatar.
/// After they speak: the avatar signs their words, then the finger sensors come back.
class _SigningStage extends StatelessWidget {
  const _SigningStage({super.key, required this.signer});

  final Signer signer;

  @override
  Widget build(BuildContext context) {
    final current = signer.currentStep;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 190,
        decoration: const BoxDecoration(gradient: AppGradients.stage),
        foregroundDecoration: const BoxDecoration(gradient: AppGradients.stageGlow),
        child: Stack(
          children: [
            Positioned.fill(
              top: 8,
              bottom: 40,
              child: ExcludeSemantics(child: SignPlayerView(player: signer.player)),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.chipOnStage,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const PulseDot(color: AppColors.live),
                  const SizedBox(width: 7),
                  Text('BIM signer', style: AppText.label.copyWith(color: AppColors.onDarkSoft, fontSize: 11.5)),
                ]),
              ),
            ),
            if (current != null)
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Center(
                  child: Semantics(
                    liveRegion: true,
                    label: 'Signing: ${signer.steps[current].text}',
                    excludeSemantics: true,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: AppGradients.sun,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        boxShadow: AppShadows.sunGlow,
                      ),
                      child: Text(signer.steps[current].label,
                          style: AppText.eyebrow.copyWith(
                              color: AppColors.onYellow, fontFamily: AppFonts.display, fontSize: 12, letterSpacing: 1)),
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

class _ListeningStage extends StatelessWidget {
  const _ListeningStage({super.key});

  @override
  Widget build(BuildContext context) {
    Widget chip(Widget child) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.chipOnStage,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: child,
        );
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 120,
        decoration: const BoxDecoration(gradient: AppGradients.stage),
        foregroundDecoration: const BoxDecoration(gradient: AppGradients.stageGlow),
        child: Stack(
          children: [
            Positioned(
              top: 10,
              left: 10,
              child: chip(Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.accessibility_new_rounded, size: 13, color: AppColors.onDarkSoft),
                const SizedBox(width: 6),
                Text('BIM signer · coming soon', style: AppText.label.copyWith(color: AppColors.onDarkSoft, fontSize: 11.5)),
              ])),
            ),
            const Positioned(
              left: 14,
              right: 14,
              top: 44,
              child: Waveform(color: AppColors.yellow, bars: 30, height: 34),
            ),
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Center(
                child: chip(Text('LISTENING…',
                    style: AppText.eyebrow.copyWith(color: AppColors.onDark, fontFamily: AppFonts.display, fontSize: 12))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
