import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'sign_words.dart';

/// Turns what the hearing person says into text: tap-to-talk, one sentence per tap.
/// The only file that uses speech_to_text. Android uses Google's speech service (usually online).
class Transcriber extends ChangeNotifier {
  final _stt = SpeechToText();

  bool listening = false;
  String text = ''; // what was heard; updates live while listening
  String? problem; // shown instead of the text when listening failed
  String? lastError; // Android's code for the last failure (e.g. error_no_match), null after a new start

  /// How many listens have finished: counted when Android says "done", which comes after the final
  /// words. A Listen session starts the next listen then.
  var finished = 0;

  /// One listen. By default one sentence (Chat); a Listen session asks for longer ones.
  Future<void> listen(
    SpeechLanguage language, {
    Duration listenFor = const Duration(seconds: 30),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    problem = null;
    lastError = null;
    try {
      if (!await _stt.initialize(onStatus: _onStatus, onError: _onError)) {
        problem = 'Speech recognition is not available. It needs the Google app and '
            'microphone permission.';
        return notifyListeners();
      }
      text = '';
      listening = true;
      notifyListeners();
      await _stt.listen(
        onResult: (result) {
          text = result.recognizedWords;
          notifyListeners();
        },
        listenOptions: SpeechListenOptions(
          localeId: language.locale,
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: true,
          listenFor: listenFor,
          pauseFor: pauseFor,
        ),
      );
    } catch (e) {
      listening = false;
      problem = 'Speech recognition error: $e';
      notifyListeners();
    }
  }

  Future<void> stop() => _stt.stop();

  void _onStatus(String status) {
    final done = status == SpeechToText.doneStatus;
    if (done) finished++;
    final now = status == SpeechToText.listeningStatus;
    if (now == listening && !done) return;
    listening = now;
    notifyListeners();
  }

  void _onError(SpeechRecognitionError error) {
    listening = false;
    lastError = error.errorMsg;
    problem = sttErrorText(error.errorMsg) ?? problem;
    notifyListeners();
  }
}

/// Plain-English text for Android's speech recognition error codes, or null when the code is no
/// real failure: many phones report error_client whenever a listen closes, even after the words
/// came through fine (README "Speech").
String? sttErrorText(String code) => switch (code) {
      'error_client' => null,
      'error_no_match' || 'error_speech_timeout' => "Didn't catch that. Tap the mic and try again.",
      'error_network' || 'error_network_timeout' || 'error_server' || 'error_server_disconnected' =>
        'Speech recognition needs internet. Check the connection and try again.',
      'error_permission' => 'Microphone permission is off. Allow it in phone Settings > Apps > SignSuara.',
      'error_language_not_supported' || 'error_language_unavailable' =>
        'This language is not available for speech recognition on this phone. '
            'Check Google app > Settings > Voice > Languages.',
      'error_busy' || 'error_too_many_requests' => 'Speech recognition is busy. Wait a moment and try again.',
      _ => 'Speech recognition error ($code). Try again.',
    };
