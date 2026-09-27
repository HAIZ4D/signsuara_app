import 'package:flutter_test/flutter_test.dart';
import 'package:signsuara_app/ml/gesture_classifier.dart';
import 'package:signsuara_app/ml/signsuara_model.dart';
import 'package:signsuara_app/speech/sign_words.dart';

void main() {
  // Fails after training a new gesture until its words are added (the app itself won't crash).
  test('every gesture the model knows has words, except Rest', () {
    for (final label in kLabels.where((l) => l != GestureClassifier.restLabel)) {
      expect(kSignWords, contains(label),
          reason: 'Add "$label" to kSignWords in lib/speech/sign_words.dart');
    }
  });

  test('Saya: screen shows "I / Me", English voice says "Me"', () {
    final saya = wordsFor('Saya');
    expect(saya.shown(SpeechLanguage.english), 'I / Me');
    expect(saya.spoken(SpeechLanguage.english), 'Me');
    expect(saya.spoken(SpeechLanguage.malay), 'Saya');
  });

  test('TerimaKasih is spoken as two words', () {
    expect(wordsFor('TerimaKasih').spoken(SpeechLanguage.malay), 'Terima kasih');
    expect(wordsFor('TerimaKasih').spoken(SpeechLanguage.english), 'Thank you');
  });

  test('a label missing from the map falls back to its own text', () {
    for (final language in SpeechLanguage.values) {
      expect(wordsFor('Makan').shown(language), 'Makan');
      expect(wordsFor('Makan').spoken(language), 'Makan');
    }
  });
}
