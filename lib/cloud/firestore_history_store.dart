import 'package:cloud_firestore/cloud_firestore.dart';

import '../history/history_store.dart';
import '../history/saved_conversation.dart';

/// A signed-in user's conversations in Firestore: users/{uid}/conversations/{id}
/// (fields: README "Firebase setup"). Firestore keeps a copy on the phone, so saving works offline
/// and is sent when the internet is back.
class FirestoreHistoryStore implements HistoryStore {
  FirestoreHistoryStore(String uid)
      : _conversations = FirebaseFirestore.instance.collection('users').doc(uid).collection('conversations');

  final CollectionReference<Map<String, dynamic>> _conversations;

  @override
  Stream<List<SavedConversation>> watch({int limit = 50}) => _conversations
      .orderBy('updatedAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((snapshot) => [
            for (final doc in snapshot.docs)
              if (SavedConversation.fromMap(doc.id, doc.data(), time: (t) => (t as Timestamp).toDate())
                  case final conversation?)
                conversation,
          ]);

  @override
  Future<void> save(SavedConversation conversation) => _conversations.doc(conversation.id).set(conversation.toMap());

  @override
  Future<void> delete(String id) => _conversations.doc(id).delete();
}
