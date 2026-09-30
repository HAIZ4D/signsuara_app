import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../app_storage.dart';
import '../cloud/account.dart';
import '../custom/custom_gestures.dart';
import '../custom/gesture_backup.dart';
import '../glove/glove_ble.dart';
import '../glove/glove_session.dart';
import '../history/conversation_history.dart';
import '../history/conversation_log.dart';
import '../listen/listen_session.dart';
import '../listen/notes.dart';
import '../signer/signer.dart';
import '../speech/sign_words.dart';
import '../speech/speaker.dart';
import '../speech/transcriber.dart';

/// Everything the screens share: glove connection, recognition, speech in/out, custom gestures and
/// saved settings. Created once by the app shell, so every tab uses the SAME glove connection.
/// The wiring below was moved unchanged from the old single home page.
class AppServices {
  /// [account] null = a guest (tests). [log] can be given a test clock, [signer] test clips,
  /// [transcriber] a fake microphone.
  AppServices({Account? account, ConversationLog? log, Signer? signer, Transcriber? transcriber})
      : account = account ?? Account(null),
        log = log ?? ConversationLog(),
        signer = signer ?? Signer(),
        transcriber = transcriber ?? Transcriber() {
    history = ConversationHistory(log: this.log, account: this.account, words: words);
    backup = GestureBackup(gestures: gestures, account: this.account);
    listenSession = ListenSession(
      listen: (language) {
        _micForListen = true;
        return this.transcriber.listen(language, listenFor: _sessionListenFor, pauseFor: _sessionPauseFor);
      },
      stopListening: this.transcriber.stop,
      store: () => notes.store,
    );
    session.customMatch = (features) => gestures.matcher.match(features);
    speaker.lookup = words;
    session.addListener(_keepScreenOn);
    listenSession.addListener(_keepScreenOn);
    this.transcriber.addListener(_muteSpeakerWhileListening);
    listenSession.addListener(_muteSpeakerWhileListening);
    this.transcriber.addListener(_routeTranscript);
    this.log.addListener(_signLatestHeard);
    listenSession.addListener(_signLatestLine);
  }

  // One listen in a Listen session: long, and patient with pauses (it starts again after each).
  static const _sessionListenFor = Duration(seconds: 60);
  static const _sessionPauseFor = Duration(seconds: 5);

  final Account account;
  final speaker = Speaker();
  final Transcriber transcriber;
  final gestures = CustomGestures();
  final ConversationLog log;
  late final ConversationHistory history; // created at once: it must see the first message
  late final GestureBackup backup; // starts in start(), after the phone's gestures are loaded
  late final ListenSession listenSession; // Listen tab: meetings, classes... kept as notes
  late final notes = Notes(account: account); // the Notes tab: the account's, or the guest's
  final Signer signer; // signs what the hearing person said (README "Signer")
  late final session = GloveSession(onGesture: _onGesture);
  late final ble = GloveBle(session);
  AppStorage? _storage;
  var _screenOn = false;
  var _micForListen = false; // who started the current listen: a Listen session, or Chat

  /// Everything a screen may need to redraw for.
  Listenable get changes =>
      Listenable.merge([session, speaker, transcriber, gestures, log, account, history, backup, signer, listenSession, notes]);

  /// Chat's own listening (a Listen session uses the same microphone).
  bool get chatListening => transcriber.listening && !_micForListen;
  String? get chatProblem => _micForListen ? null : transcriber.problem;

  /// A recognised sign: spoken (as before) and added to the conversation.
  void _onGesture(String label) {
    speaker.say(label);
    log.addSigned(label);
  }

  /// The microphone's words go to whoever started the listen: never Listen's into the chat, even
  /// when Android sends the last words after listening stopped.
  void _routeTranscript() {
    final t = transcriber;
    if (_micForListen) {
      listenSession.heard(listening: t.listening, text: t.text, finished: t.finished, error: t.lastError, problem: t.problem);
    } else {
      log.transcript(listening: t.listening, text: t.text);
    }
  }

  /// Chat: the hearing person's latest finished words are signed.
  void _signLatestHeard() {
    if (chatListening) return;
    final heard = [for (final m in log.messages) if (m.side == Side.them) m.text];
    signer.show(heard.isEmpty ? '' : heard.last);
  }

  /// Listen: each new sentence is signed as soon as it is heard.
  void _signLatestLine() {
    final lines = listenSession.lines;
    if (lines.isNotEmpty) signer.show(lines.last.text);
  }

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
    backup.start();
    await speaker.init();
  }

  /// Words for any label: a custom gesture's phrase, or the built-in speech map.
  SignWords words(String label) => gestures.customWords(label) ?? wordsFor(label);

  void setLanguage(SpeechLanguage language) {
    speaker.setLanguage(language);
    _storage?.saveLanguage(language);
  }

  /// Silent while the mic listens, and for a whole Listen session (also between its listens), so
  /// the phone never hears its own voice.
  void _muteSpeakerWhileListening() => speaker.muted = transcriber.listening || listenSession.active;

  /// Chat's mic button: start listening (silencing the phone first), or stop early. Not while
  /// Listen is recording: it has the microphone.
  Future<void> talk() async {
    if (listenSession.active) return;
    if (transcriber.listening) return transcriber.stop();
    _micForListen = false;
    speaker.muted = true;
    await speaker.stop();
    await transcriber.listen(speaker.language);
  }

  /// Listen's Start button: a new session in the chosen language (the phone goes silent first).
  Future<void> startListening() async {
    if (listenSession.active) return;
    if (transcriber.listening) await transcriber.stop();
    speaker.muted = true;
    await speaker.stop();
    await listenSession.start(speaker.language);
  }

  /// The screen stays on while the glove is connected or Listen is recording, normal otherwise.
  void _keepScreenOn() {
    final on = session.link == GloveLink.connected || listenSession.active;
    if (on == _screenOn) return;
    _screenOn = on;
    _screenStaysOn(on);
  }

  /// Keeping the screen on is a nicety: if the phone refuses, the app goes on as normal.
  static void _screenStaysOn(bool on) {
    try {
      WakelockPlus.toggle(enable: on).catchError((Object e) => debugPrint('Screen-on not changed: $e'));
    } catch (e) {
      debugPrint('Screen-on not changed: $e');
    }
  }

  void dispose() {
    if (_screenOn) _screenStaysOn(false);
    session.removeListener(_keepScreenOn);
    listenSession.removeListener(_keepScreenOn);
    transcriber.removeListener(_muteSpeakerWhileListening);
    listenSession.removeListener(_muteSpeakerWhileListening);
    transcriber.removeListener(_routeTranscript);
    listenSession.removeListener(_signLatestLine);
    if (transcriber.listening) transcriber.stop();
    ble.disconnect();
    session.dispose();
    speaker.dispose();
    transcriber.dispose();
    gestures.dispose();
    history.dispose();
    backup.dispose();
    log.removeListener(_signLatestHeard);
    listenSession.dispose();
    notes.dispose();
    signer.dispose();
    log.dispose();
  }
}
