import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'custom/custom_gesture.dart';
import 'speech/sign_words.dart';

/// Everything the app saves on the phone: the custom gestures, the BM/EN choice and Learn progress.
/// The only file that uses shared_preferences. Data is lost only if the app is uninstalled.
class AppStorage {
  AppStorage._(this._prefs);

  static Future<AppStorage> open() async => AppStorage._(await SharedPreferences.getInstance());

  static const _gesturesKey = 'custom_gestures';
  static const _languageKey = 'speech_language';
  static const _summaryNoticeKey = 'summary_notice_seen';
  static const _learnKey = 'learn_progress';

  final SharedPreferences _prefs;

  List<CustomGesture> loadGestures() {
    try {
      final json = _prefs.getString(_gesturesKey);
      if (json == null) return [];
      return [for (final g in jsonDecode(json) as List) CustomGesture.fromJson(g as Map<String, dynamic>)];
    } catch (_) {
      return []; // damaged data must never stop the app from starting
    }
  }

  Future<void> saveGestures(List<CustomGesture> gestures) =>
      _prefs.setString(_gesturesKey, jsonEncode([for (final g in gestures) g.toJson()]));

  SpeechLanguage? loadLanguage() => SpeechLanguage.values.asNameMap()[_prefs.getString(_languageKey)];

  Future<void> saveLanguage(SpeechLanguage language) => _prefs.setString(_languageKey, language.name);

  /// True once the user has read (and accepted) what summaries send to Google.
  bool summaryNoticeSeen() => _prefs.getBool(_summaryNoticeKey) ?? false;

  Future<void> saveSummaryNoticeSeen() => _prefs.setBool(_summaryNoticeKey, true);

  /// Learn's XP, streak and badges (README "Learn"); nothing saved or damaged data → empty.
  Map<String, dynamic> loadLearnProgress() {
    try {
      final json = _prefs.getString(_learnKey);
      return json == null ? {} : jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> saveLearnProgress(Map<String, Object?> progress) => _prefs.setString(_learnKey, jsonEncode(progress));

  static String _quizKey(String noteId) => 'quiz_$noteId';

  /// The Gemini quiz kept for a note (README "Learn"); nothing saved or damaged data → null.
  Map<String, Object?>? loadQuiz(String noteId) {
    try {
      final json = _prefs.getString(_quizKey(noteId));
      return json == null ? null : jsonDecode(json) as Map<String, Object?>;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveQuiz(String noteId, Map<String, Object?> quiz) => _prefs.setString(_quizKey(noteId), jsonEncode(quiz));
}
