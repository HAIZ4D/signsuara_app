import 'dart:async';

import 'listen_note.dart';

/// Where notes are kept: Firestore for a signed-in account (lib/cloud/firestore_note_store.dart),
/// memory for a guest and in tests.
abstract class NoteStore {
  /// The newest [limit] notes (by start time), again after every change.
  Stream<List<ListenNote>> watch({int limit = 100});

  /// Adds the note, or replaces it (same id) with its newer version.
  Future<void> save(ListenNote note);

  Future<void> delete(String id);
}

/// Kept in memory only: a guest's notes stay until the app closes.
class MemoryNoteStore implements NoteStore {
  final _all = <String, ListenNote>{};
  final _changed = StreamController<void>.broadcast();

  List<ListenNote> _newest(int limit) =>
      (_all.values.toList()..sort((a, b) => b.startedAt.compareTo(a.startedAt))).take(limit).toList();

  @override
  Stream<List<ListenNote>> watch({int limit = 100}) {
    // Listens for changes at once, so a note saved right after watch() is never missed.
    StreamSubscription<void>? changes;
    late final StreamController<List<ListenNote>> out;
    out = StreamController(
      onListen: () {
        out.add(_newest(limit));
        changes = _changed.stream.listen((_) => out.add(_newest(limit)));
      },
      onCancel: () {
        changes?.cancel(); // not waited for: nothing depends on it
      },
    );
    return out.stream;
  }

  @override
  Future<void> save(ListenNote note) async {
    _all[note.id] = note;
    _changed.add(null);
  }

  @override
  Future<void> delete(String id) async {
    _all.remove(id);
    _changed.add(null);
  }
}
