import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'custom/custom_gesture.dart';
import 'speech/sign_words.dart';

/// Everything the app saves on the phone: the custom gestures and the BM/EN choice.
/// The only file that uses shared_preferences. Data is lost only if the app is uninstalled.
class AppStorage {
  AppStorage._(this._prefs);

  static Future<AppStorage> open() async => AppStorage._(await SharedPreferences.getInstance());

  static const _gesturesKey = 'custom_gestures';
  static const _languageKey = 'speech_language';
  static const _summaryNoticeKey = 'summary_notice_seen';

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
}
