import 'dart:convert';

import 'custom_gesture.dart';

/// Where a signed-in user's custom gestures are backed up: Firestore on the phone
/// (lib/cloud/firestore_gesture_store.dart), a fake in tests.
abstract class GestureStore {
  Future<List<CustomGesture>> loadAll();

  Future<void> save(CustomGesture gesture);

  Future<void> delete(String id);
}

/// For the database (README "Firebase setup"): readable fields, and the raw recordings as one
/// JSON text, because Firestore can't store lists inside lists.
Map<String, Object?> gestureToBackup(CustomGesture gesture) => {
      'malay': gesture.malay,
      'english': gesture.english,
      'moving': gesture.moving,
      'category': gesture.category.name,
      'recordings': jsonEncode(gesture.recordings),
      'savedAt': DateTime.now(),
    };

/// The opposite of [gestureToBackup], through the same JSON the phone uses. Null when damaged.
CustomGesture? gestureFromBackup(String id, Map<String, Object?> backup) {
  try {
    return CustomGesture.fromJson({
      'id': id,
      'malay': backup['malay'],
      'english': backup['english'],
      'moving': backup['moving'],
      'category': backup['category'], // missing in older backups: Personal
      'recordings': jsonDecode(backup['recordings'] as String),
    });
  } catch (_) {
    return null;
  }
}
