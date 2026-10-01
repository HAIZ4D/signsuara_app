import 'dart:async';

import 'package:flutter/foundation.dart';

import '../cloud/account.dart';
import 'listen_note.dart';
import 'note_store.dart';
import 'note_summary.dart';

/// The Listen notes for the Notes tab and Home, newest first. Signed in: the account's (kept);
/// guest: in memory, kept until the app closes.
class Notes extends ChangeNotifier {
  Notes({required this.account}) {
    account.addListener(_useStore);
    _useStore();
  }

  final Account account;
  final _guest = MemoryNoteStore();
  NoteStore? _watched;
  StreamSubscription<List<ListenNote>>? _watching;
  List<ListenNote> _all = const [];

  /// The newest notes (up to 100).
  List<ListenNote> get all => _all;

  /// True when notes are kept after the app closes (signed in).
  bool get kept => account.signedIn;

  /// Where notes are saved right now.
  NoteStore get store => account.notes ?? _guest;

  /// The note with [id] as it is now (e.g. after an edit), or null when it was deleted.
  ListenNote? byId(String id) => _all.where((n) => n.id == id).firstOrNull;

  void _useStore() {
    final store = this.store;
    if (identical(store, _watched)) return;
    _watched = store;
    _watching?.cancel();
    _all = const [];
    _watching = store.watch().listen((list) {
      _all = list;
      notifyListeners();
    }, onError: (Object e) => debugPrint('Notes not loaded: $e'));
    notifyListeners();
  }

  Future<void> save(ListenNote note) => store.save(note);

  /// Asks Gemini for [note]'s summary and keeps it in the note. Throws [SummaryFailure].
  Future<ListenNote> summarize(ListenNote note) async {
    final summarizer = account.summarizer;
    if (summarizer == null) throw const SummaryFailure('Summaries are not available: the app could not reach Firebase.');
    final summary = await summarizer.summarize(note);
    // Gemini takes a while: keep an edit made meanwhile, and don't bring back a deleted note.
    final latest = byId(note.id);
    if (latest == null) return note.copyWith(summary: summary);
    final done = latest.copyWith(summary: summary);
    await save(done);
    return done;
  }

  Future<void> delete(String id) => store.delete(id);

  @override
  void dispose() {
    account.removeListener(_useStore);
    _watching?.cancel();
    super.dispose();
  }
}
