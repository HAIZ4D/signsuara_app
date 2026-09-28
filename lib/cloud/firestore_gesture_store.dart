import 'package:cloud_firestore/cloud_firestore.dart';

import '../custom/custom_gesture.dart';
import '../custom/gesture_store.dart';

/// A signed-in user's custom-gesture backup in Firestore: users/{uid}/gestures/{id}
/// (fields: README "Firebase setup").
class FirestoreGestureStore implements GestureStore {
  FirestoreGestureStore(String uid)
      : _gestures = FirebaseFirestore.instance.collection('users').doc(uid).collection('gestures');

  final CollectionReference<Map<String, dynamic>> _gestures;

  @override
  Future<List<CustomGesture>> loadAll() async => [
        for (final doc in (await _gestures.get()).docs)
          if (gestureFromBackup(doc.id, doc.data()) case final gesture?) gesture,
      ];

  @override
  Future<void> save(CustomGesture gesture) => _gestures.doc(gesture.id).set(gestureToBackup(gesture));

  @override
  Future<void> delete(String id) => _gestures.doc(id).delete();
}
