import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../app_storage.dart';
import '../cloud/account.dart';
import '../custom/custom_gestures.dart';
import '../glove/glove_ble.dart';
import '../glove/glove_session.dart';
import '../history/conversation_history.dart';
import '../history/conversation_log.dart';
import '../speech/sign_words.dart';
import '../speech/speaker.dart';
import '../speech/transcriber.dart';

/// Everything the screens share: glove connection, recognition, speech in/out, custom gestures and
/// saved settings. Created once by the app shell, so every tab uses the SAME glove connection.
/// The wiring below was moved unchanged from the old single home page.
class AppServices {
  /// [account] null = a guest (tests). [log] can be given a test clock.
  AppServices({Account? account, ConversationLog? log})
      : account = account ?? Account(null),
        log = log ?? ConversationLog() {
    history = ConversationHistory(log: this.log, account: this.account, words: words);
    session.customMatch = (features) => gestures.matcher.match(features);
    speaker.lookup = words;
    session.addListener(_keepScreenOnWhileConnected);
    transcriber.addListener(_muteSpeakerWhileListening);
    transcriber.addListener(_logTranscript);
  }

  final Account account;
  final speaker = Speaker();
  final transcriber = Transcriber();
  final gestures = CustomGestures();
  final ConversationLog log;
  late final ConversationHistory history; // created at once: it must see the first message
  late final session = GloveSession(onGesture: _onGesture);
  late final ble = GloveBle(session);
  AppStorage? _storage;
  var _screenOn = false;

  /// Everything a screen may need to redraw for.
  Listenable get changes => Listenable.merge([session, speaker, transcriber, gestures, log, account, history]);

  /// A recognised sign: spoken (as before) and added to the conversation.
  void _onGesture(String label) {
    speaker.say(label);
    log.addSigned(label);
  }

  void _logTranscript() => log.transcript(listening: transcriber.listening, text: transcriber.text);

  /// The Google account's name, or "Guest".
  String get userName => account.name;

  Future<void> start() async {
    try {
      final storage = _storage = await AppStorage.open();
      speaker.language = storage.loadLanguage() ?? SpeechLanguage.malay;
      gestures.load(storage);
    } catch (_) {
      // Without storage the app still works; custom gestures just can't be saved.
    }
    await speaker.init();
  }

  /// Words for any label: a custom gesture's phrase, or the built-in speech map.
  SignWords words(String label) => gestures.customWords(label) ?? wordsFor(label);

  void setLanguage(SpeechLanguage language) {
    speaker.setLanguage(language);
    _storage?.saveLanguage(language);
  }

  void _muteSpeakerWhileListening() => speaker.muted = transcriber.listening;

  /// Mic button: start listening (silencing the phone first), or stop early.
  Future<void> talk() async {
    if (transcriber.listening) return transcriber.stop();
    speaker.muted = true;
    await speaker.stop();
    await transcriber.listen(speaker.language);
  }

  /// The screen stays on during a conversation (glove connected), normal otherwise.
  void _keepScreenOnWhileConnected() {
    final connected = session.link == GloveLink.connected;
    if (connected == _screenOn) return;
    _screenOn = connected;
    WakelockPlus.toggle(enable: connected);
  }

  void dispose() {
    if (_screenOn) WakelockPlus.disable();
    session.removeListener(_keepScreenOnWhileConnected);
    transcriber.removeListener(_muteSpeakerWhileListening);
    transcriber.removeListener(_logTranscript);
    if (transcriber.listening) transcriber.stop();
    ble.disconnect();
    session.dispose();
    speaker.dispose();
    transcriber.dispose();
    gestures.dispose();
    history.dispose();
    log.dispose();
  }
}
