import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../ml/gesture_classifier.dart';
import 'sign_words.dart';

/// Speaks recognised gestures with the phone's text-to-speech voice.
/// The only file that uses flutter_tts.
class Speaker extends ChangeNotifier {
  // Google's engine has a Malay voice; Samsung's own engine may not.
  static const _googleEngine = 'com.google.android.tts';

  final _tts = FlutterTts();
  SpeechLanguage language = SpeechLanguage.malay;

  /// Shown on screen when the chosen voice can't be used, otherwise null.
  String? problem;

  /// True while the mic is listening: nothing is spoken, so the phone never transcribes itself.
  bool muted = false;

  /// Label -> words. The home page adds the custom gestures' phrases to the built-in map.
  SignWords Function(String label) lookup = wordsFor;

  Future<void> init() async {
    if (Platform.isAndroid) {
      try {
        final engines = List<String>.from(await _tts.getEngines as List);
        if (engines.contains(_googleEngine)) await _tts.setEngine(_googleEngine);
        await _tts.setQueueMode(1); // queue words instead of cutting the previous one off
      } catch (_) {
        // Keep the phone's default engine; setLanguage below reports if the voice is missing.
      }
    }
    await setLanguage(language);
  }

  Future<void> setLanguage(SpeechLanguage value) async {
    language = value;
    try {
      final available = await _tts.isLanguageAvailable(value.locale) == true;
      if (available) await _tts.setLanguage(value.locale);
      problem = available
          ? null
          : '${value.displayName} voice not installed. Phone Settings > Text-to-speech: '
              'choose "Speech Services by Google" and download ${value.displayName}.';
    } catch (e) {
      problem = 'Text-to-speech not available: $e';
    }
    notifyListeners();
  }

  /// Speaks the word for a model label in the chosen language. Rest is never spoken.
  Future<void> say(String label) async {
    if (muted || label == GestureClassifier.restLabel) return;
    try {
      await _tts.speak(lookup(label).spoken(language));
    } catch (_) {
      // A failed word must never stop recognition; the banner already explains voice problems.
    }
  }

  /// Stops the current word and drops any queued ones.
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
