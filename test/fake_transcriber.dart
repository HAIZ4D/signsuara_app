import 'package:signsuara_app/speech/sign_words.dart';
import 'package:signsuara_app/speech/transcriber.dart';

/// The microphone in tests: [say] words while it listens, then [finish] (Android stops and says
/// "done") or [fail] with Android's error code.
class FakeTranscriber extends Transcriber {
  var listens = 0;
  var stops = 0;

  @override
  Future<void> listen(
    SpeechLanguage language, {
    Duration listenFor = const Duration(seconds: 30),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    listens++;
    problem = null;
    lastError = null;
    text = '';
    listening = true;
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    stops++;
    if (!listening) return;
    listening = false;
    notifyListeners();
  }

  void say(String words) {
    text = words;
    notifyListeners();
  }

  void finish() {
    listening = false;
    notifyListeners();
    finished++;
    notifyListeners();
  }

  void fail(String code) {
    listening = false;
    lastError = code;
    problem = sttErrorText(code) ?? problem;
    notifyListeners();
  }
}
