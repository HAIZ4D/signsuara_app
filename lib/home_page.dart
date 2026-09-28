import 'package:flutter/material.dart';

import 'app/app_services.dart';
import 'custom/custom_gestures.dart';
import 'custom/custom_gestures_page.dart';
import 'glove/glove_ble.dart';
import 'glove/glove_session.dart';
import 'speech/sign_words.dart';
import 'speech/speaker.dart';
import 'speech/transcriber.dart';

/// The old single-screen UI. TEMPORARY: shown in the Conversation and Hearing tabs until the
/// redesigned screens replace it (redesign steps 2 and 3). Uses the shared [AppServices].
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.services});

  final AppServices services;

  Speaker get speaker => services.speaker;
  Transcriber get transcriber => services.transcriber;
  CustomGestures get gestures => services.gestures;
  GloveSession get session => services.session;
  GloveBle get ble => services.ble;
  SignWords _words(String label) => services.words(label);
  void _setLanguage(SpeechLanguage language) => services.setLanguage(language);
  Future<void> _talk() => services.talk();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: services.changes,
      builder: (context, _) {
        final text = Theme.of(context).textTheme;
        final colors = Theme.of(context).colorScheme;
        final language = speaker.language;
        final other = language == SpeechLanguage.malay ? SpeechLanguage.english : SpeechLanguage.malay;
        final last = session.announced.lastOrNull;
        final sentence = session.announced.reversed.take(12).toList().reversed;

        return Scaffold(
          appBar: AppBar(
            title: const Text('SignSuara'),
            actions: [
              IconButton(
                tooltip: 'My gestures',
                icon: const Icon(Icons.back_hand_outlined),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => CustomGesturesPage(gestures: gestures, session: session))),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SegmentedButton<SpeechLanguage>(
                  segments: [
                    for (final l in SpeechLanguage.values) ButtonSegment(value: l, label: Text(l.short)),
                  ],
                  selected: {language},
                  showSelectedIcon: false,
                  onSelectionChanged: (choice) => _setLanguage(choice.first),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ConnectionBar(session: session, ble: ble),
                  if (!session.motionSensorOk) _Banner('Motion sensor disconnected', colors.error),
                  if (speaker.problem != null) _Banner(speaker.problem!, Colors.orange.shade800),
                  Expanded(
                    flex: 3,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: last == null ? null : () => speaker.say(last),
                      child: Center(
                        child: last == null
                            ? Text('Sign something…', style: text.headlineSmall?.copyWith(color: colors.outline))
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_words(last).shown(language),
                                      textAlign: TextAlign.center, style: text.displayLarge),
                                  Text(_words(last).shown(other),
                                      style: text.titleLarge?.copyWith(color: colors.outline)),
                                  const SizedBox(height: 12),
                                  Text('tap to repeat', style: text.labelSmall?.copyWith(color: colors.outline)),
                                ],
                              ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(sentence.map((l) => _words(l).shown(language)).join('  '),
                            style: text.titleMedium),
                      ),
                      IconButton(
                        tooltip: 'Clear',
                        onPressed: session.announced.isEmpty ? null : session.clearAnnounced,
                        icon: const Icon(Icons.clear_all),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    flex: 2,
                    child: _HeardCard(transcriber: transcriber, language: language, onTalk: _talk),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Now: ${session.current == null ? '—' : _words(session.current!).malay} · rows ${session.rows} · '
                    'dropped ${session.dropped} · broken ${session.badPackets}',
                    style: text.labelSmall?.copyWith(color: colors.outline),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ConnectionBar extends StatelessWidget {
  const _ConnectionBar({required this.session, required this.ble});

  final GloveSession session;
  final GloveBle ble;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(switch (session.link) {
                GloveLink.connected => Icons.bluetooth_connected,
                GloveLink.busy => Icons.bluetooth_searching,
                GloveLink.disconnected => Icons.bluetooth_disabled,
              }),
              const SizedBox(width: 12),
              Expanded(child: Text(session.status)),
              switch (session.link) {
                GloveLink.connected => OutlinedButton(onPressed: ble.disconnect, child: const Text('Disconnect')),
                GloveLink.busy => const FilledButton(onPressed: null, child: Text('Wait…')),
                GloveLink.disconnected => FilledButton(onPressed: ble.connect, child: const Text('Connect')),
              },
            ],
          ),
        ),
      );
}

/// What the hearing person said, big enough for the signer to read, plus the mic button.
class _HeardCard extends StatelessWidget {
  const _HeardCard({required this.transcriber, required this.language, required this.onTalk});

  final Transcriber transcriber;
  final SpeechLanguage language;
  final VoidCallback onTalk;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final listening = transcriber.listening;
    final problem = transcriber.problem;
    final heard = transcriber.text;

    return Card(
      color: colors.secondaryContainer,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('They said', style: text.labelLarge)),
                FloatingActionButton.extended(
                  heroTag: null,
                  onPressed: onTalk,
                  backgroundColor: listening ? colors.error : null,
                  foregroundColor: listening ? colors.onError : null,
                  icon: Icon(listening ? Icons.stop : Icons.mic),
                  label: Text(listening ? 'Stop' : 'Tap to talk'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                reverse: true, // keep the newest words visible
                child: Text(
                  problem ??
                      (heard.isNotEmpty
                          ? heard
                          : listening
                              ? 'Listening…'
                              : 'Tap the mic, then speak ${language.displayName}.'),
                  style: problem != null
                      ? text.titleMedium?.copyWith(color: colors.error)
                      : heard.isNotEmpty
                          ? text.headlineMedium
                          : text.titleMedium?.copyWith(color: colors.outline),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner(this.message, this.color);

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Material(
          color: color,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(message,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      );
}
