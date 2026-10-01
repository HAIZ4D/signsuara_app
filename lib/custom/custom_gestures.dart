import 'package:flutter/foundation.dart';

import '../app_storage.dart';
import '../speech/sign_words.dart';
import 'custom_gesture.dart';
import 'custom_matcher.dart';

/// The user's custom gestures (saved on the phone) and a matcher that is always up to date.
class CustomGestures extends ChangeNotifier {
  AppStorage? _storage;
  List<CustomGesture> _all = const [];
  CustomGestureMatcher _matcher = CustomGestureMatcher(const []);

  List<CustomGesture> get all => _all;
  CustomGestureMatcher get matcher => _matcher;

  void load(AppStorage storage) {
    _storage = storage;
    _all = storage.loadGestures();
    _changed();
  }

  Future<void> add(CustomGesture gesture) => _save([..._all, gesture]);

  Future<void> remove(String id) => _save([for (final g in _all) if (g.id != id) g]);

  /// Saves a changed gesture (its category) in the same place in the list.
  Future<void> update(CustomGesture gesture) => _save([for (final g in _all) g.id == gesture.id ? gesture : g]);

  /// Words for a custom label (`custom:<id>`), or null when it is not a custom gesture.
  SignWords? customWords(String label) {
    for (final g in _all) {
      if (g.label == label) return g.words;
    }
    return null;
  }

  Future<void> _save(List<CustomGesture> gestures) async {
    _all = List.unmodifiable(gestures);
    _changed();
    await _storage?.saveGestures(_all);
  }

  void _changed() {
    _matcher = CustomGestureMatcher(_all);
    notifyListeners();
  }
}
