import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signsuara_app/speech/sign_words.dart';
import 'package:signsuara_app/speech/speaker.dart';

// Catches what Speaker sends to the phone's voice engine, so no phone is needed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final spoken = <String>[];

  setUp(() {
    spoken.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (call) async {
      if (call.method == 'speak') {
        final args = call.arguments; // plain text, or {"text": ...} on Android
        spoken.add(args is Map ? args['text'] as String : args as String);
      }
      return 1;
    });
  });

  test('speaks the word in the chosen language', () async {
    final speaker = Speaker();
    await speaker.say('TerimaKasih');
    speaker.language = SpeechLanguage.english;
    await speaker.say('Saya');
    expect(spoken, ['Terima kasih', 'Me']);
  });

  test('custom gestures are spoken with their own phrase', () async {
    final speaker = Speaker()
      ..lookup = (label) => label == 'custom:1' ? const SignWords('Saya lapar', 'I am hungry') : wordsFor(label);
    await speaker.say('custom:1');
    speaker.language = SpeechLanguage.english;
    await speaker.say('custom:1');
    await speaker.say('Nama');
    expect(spoken, ['Saya lapar', 'I am hungry', 'Name']);
  });

  test('silent while the mic is listening (muted), and never says Rest', () async {
    final speaker = Speaker()..muted = true;
    await speaker.say('Saya');
    speaker.muted = false;
    await speaker.say('Rest');
    expect(spoken, isEmpty);

    await speaker.say('Nama');
    expect(spoken, ['Nama']);
  });
}
