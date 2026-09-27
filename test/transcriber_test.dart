import 'package:flutter_test/flutter_test.dart';
import 'package:signsuara_app/speech/transcriber.dart';

void main() {
  test('common Android speech errors get a plain explanation', () {
    expect(sttErrorText('error_no_match'), contains("Didn't catch that"));
    expect(sttErrorText('error_speech_timeout'), contains("Didn't catch that"));
    expect(sttErrorText('error_network'), contains('internet'));
    expect(sttErrorText('error_network_timeout'), contains('internet'));
    expect(sttErrorText('error_permission'), contains('Microphone permission'));
    expect(sttErrorText('error_language_unavailable'), contains('language is not available'));
  });

  test('an unknown error still gives a message with its code', () {
    expect(sttErrorText('error_unknown (99)'), contains('error_unknown (99)'));
  });
}
