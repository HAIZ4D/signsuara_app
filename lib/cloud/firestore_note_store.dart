import 'package:cloud_firestore/cloud_firestore.dart';

import '../listen/listen_note.dart';
import '../listen/note_store.dart';

/// A signed-in user's notes in Firestore: users/{uid}/notes/{id} (fields: README "Firebase setup").
/// Firestore keeps a copy on the phone, so saving works offline and is sent when the internet is back.
class FirestoreNoteStore implements NoteStore {
  FirestoreNoteStore(String uid) : _notes = FirebaseFirestore.instance.collection('users').doc(uid).collection('notes');

  final CollectionReference<Map<String, dynamic>> _notes;

  @override
  Stream<List<ListenNote>> watch({int limit = 100}) => _notes
      .orderBy('startedAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((snapshot) => [
            for (final doc in snapshot.docs)
              if (ListenNote.fromMap(doc.id, doc.data(), time: (t) => (t as Timestamp).toDate()) case final note?)
                note,
          ]);

  @override
  Future<void> save(ListenNote note) => _sent(_notes.doc(note.id).set(note.toMap()));

  @override
  Future<void> delete(String id) => _sent(_notes.doc(id).delete());

  // Firestore confirms a change only once the server has it, which offline means "when the internet is
  // back" (Stop's sheet or a summary would wait that long). The phone's copy has it at once (watch()
  // shows it), so wait for the server at most 2 s.
  static Future<void> _sent(Future<void> write) => write.timeout(const Duration(seconds: 2), onTimeout: () {});
}
