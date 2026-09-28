import 'dart:async';

import 'saved_conversation.dart';

/// Where conversations are kept: Firestore for a signed-in account
/// (lib/cloud/firestore_history_store.dart), memory for a guest and in tests.
abstract class HistoryStore {
  /// The newest [limit] conversations (by last message), again after every change.
  Stream<List<SavedConversation>> watch({int limit = 50});

  /// Adds the conversation, or replaces it (same id) with its newer version.
  Future<void> save(SavedConversation conversation);

  Future<void> delete(String id);
}

/// Kept in memory only: a guest's conversations stay until the app closes.
class MemoryHistoryStore implements HistoryStore {
  final _all = <String, SavedConversation>{};
  final _changed = StreamController<void>.broadcast();

  List<SavedConversation> _newest(int limit) =>
      (_all.values.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt))).take(limit).toList();

  @override
  Stream<List<SavedConversation>> watch({int limit = 50}) async* {
    yield _newest(limit);
    await for (final _ in _changed.stream) {
      yield _newest(limit);
    }
  }

  @override
  Future<void> save(SavedConversation conversation) async {
    _all[conversation.id] = conversation;
    _changed.add(null);
  }

  @override
  Future<void> delete(String id) async {
    _all.remove(id);
    _changed.add(null);
  }
}
