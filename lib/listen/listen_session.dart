import 'dart:async';

import 'package:flutter/foundation.dart';

import '../speech/sign_words.dart';
import '../speech/transcriber.dart';
import '../ui/time_label.dart';
import 'listen_note.dart';
import 'note_store.dart';

enum ListenState { idle, listening, paused }

/// A Listen session (README "Listen and Notes"): the phone listens on and on (a meeting, a class,
/// a consultation) until Stop. Android's recogniser stops after every pause, so the session starts
/// it again after each sentence. Every finished sentence becomes a line of the session's note,
/// which is saved while it runs (a closed app loses little) and when it stops.
class ListenSession extends ChangeNotifier {
  ListenSession({
    required this.listen,
    required this.stopListening,
    required this.store,
    DateTime Function()? clock,
    this.restartDelay = const Duration(milliseconds: 250),
  }) : _clock = clock ?? DateTime.now;

  /// Starts one listen; the session calls it again after every sentence.
  final Future<void> Function(SpeechLanguage language) listen;
  final Future<void> Function() stopListening;

  /// Where the note is kept: the account's notes, or the guest's.
  final NoteStore Function() store;
  final Duration restartDelay;
  final DateTime Function() _clock;

  /// Quiet moments, not failures: listening just starts again.
  static const _silence = {'error_no_match', 'error_speech_timeout', 'error_client'};
  static const _busy = {'error_busy', 'error_too_many_requests'};
  static const _saveEvery = 3; // lines

  var state = ListenState.idle;
  var language = SpeechLanguage.malay;
  DateTime? startedAt;
  String live = ''; // the words being heard right now
  String? problem; // why it paused, in plain words
  final _lines = <NoteLine>[];
  String? _id;
  var _taken = false; // this listen's words are already a line
  var _starting = false; // a listen was asked for, and is not running yet
  var _finishedSeen = -1; // the transcriber's count of finished listens, -1 = not known yet
  String? _errorSeen;
  Timer? _restart;
  var _unsaved = 0;

  bool get active => state != ListenState.idle;
  List<NoteLine> get lines => List.unmodifiable(_lines);

  /// "Meeting · Today, 10:05 AM"
  static String defaultTitle(NoteKind kind, DateTime startedAt) => '${kind.label} · ${dayAndTime(startedAt)}';

  /// Start: a new session.
  Future<void> start(SpeechLanguage language) async {
    if (active) return;
    this.language = language;
    final now = startedAt = _clock();
    _id = '${now.microsecondsSinceEpoch}';
    _lines.clear();
    live = '';
    problem = null;
    _unsaved = 0;
    _finishedSeen = -1;
    state = ListenState.listening;
    notifyListeners();
    await _listen();
  }

  /// Pause: stops listening but keeps the session (a break in a class, say).
  Future<void> pause() async {
    if (state != ListenState.listening) return;
    _cancelRestart();
    _takeLine(live);
    state = ListenState.paused;
    notifyListeners();
    _save();
    await stopListening();
  }

  /// Continue: listens again after a pause or a problem.
  Future<void> resume() async {
    if (state != ListenState.paused) return;
    problem = null;
    state = ListenState.listening;
    notifyListeners();
    await _listen();
  }

  /// Stop: ends the session and saves it. The note, or null when nothing was heard (nothing kept).
  Future<ListenNote?> stop() async {
    if (!active) return null;
    final wasListening = state == ListenState.listening;
    _cancelRestart();
    _takeLine(live);
    state = ListenState.idle;
    live = '';
    final note = _note();
    notifyListeners();
    if (wasListening) await stopListening();
    if (note != null) await _saveNote(note);
    return note;
  }

  /// Keeps [note] as [kind] with [title] (chosen after Stop; empty = the default title).
  Future<ListenNote> keep(ListenNote note, {required NoteKind kind, required String title}) async {
    final kept = note.copyWith(kind: kind, title: title.trim().isEmpty ? defaultTitle(kind, note.startedAt) : title.trim());
    await _saveNote(kept);
    return kept;
  }

  /// Throws the recording away.
  Future<void> discard(ListenNote note) => store().delete(note.id);

  /// Call whenever the transcriber changes (AppServices does, while this session owns the mic).
  void heard({required bool listening, required String text, required int finished, String? error, String? problem}) {
    if (state != ListenState.listening) return; // after Pause or Stop, late words are not used
    if (_finishedSeen < 0) _finishedSeen = finished;
    if (_starting) {
      // Until the new listen runs, the text (and a late "done") still belong to the one before.
      if (!listening) {
        _finishedSeen = finished;
        if (error != null && error != _errorSeen) {
          _errorSeen = error;
          _afterError(error);
        } else if (error == null && problem != null) {
          _pauseFor(problem); // it could not start at all (no Google app, no permission)
        }
        return;
      }
      _starting = false;
    }
    if (!_taken && text != live) {
      live = text;
      notifyListeners();
    }
    if (finished > _finishedSeen) {
      // Android said "done": the final words are in. Keep them and listen again.
      _finishedSeen = finished;
      _takeLine(text);
      _restartSoon();
    } else if (error != null && error != _errorSeen) {
      _errorSeen = error;
      _takeLine(text);
      _afterError(error);
    } else if (!listening && _restart == null) {
      _restartSoon(const Duration(seconds: 2)); // in case Android never says "done"
    }
  }

  void _afterError(String error) {
    if (_silence.contains(error)) {
      _restartSoon();
    } else if (_busy.contains(error)) {
      _restartSoon(const Duration(seconds: 1));
    } else {
      _pauseFor(sttErrorText(error) ?? 'Listening stopped. Tap Continue to go on.');
    }
  }

  Future<void> _listen() async {
    _taken = false;
    _starting = true;
    _errorSeen = null;
    live = '';
    await listen(language);
  }

  void _restartSoon([Duration? after]) {
    _restart?.cancel();
    _restart = Timer(after ?? restartDelay, () {
      _restart = null;
      if (state != ListenState.listening) return;
      _takeLine(live);
      _listen();
    });
  }

  void _cancelRestart() {
    _restart?.cancel();
    _restart = null;
  }

  void _pauseFor(String message) {
    _cancelRestart();
    state = ListenState.paused;
    problem = message;
    live = '';
    notifyListeners();
    _save();
  }

  void _takeLine(String text) {
    final words = text.trim();
    if (_taken || words.isEmpty) return;
    _taken = true;
    _lines.add(NoteLine(words, _clock()));
    live = '';
    notifyListeners();
    if (++_unsaved >= _saveEvery) _save();
  }

  ListenNote? _note() {
    final id = _id, started = startedAt;
    if (id == null || started == null || _lines.isEmpty) return null;
    return ListenNote(
      id: id,
      kind: NoteKind.other,
      title: defaultTitle(NoteKind.other, started),
      language: language,
      startedAt: started,
      endedAt: _clock(),
      lines: List.of(_lines),
    );
  }

  void _save() {
    final note = _note();
    if (note != null) _saveNote(note);
  }

  Future<void> _saveNote(ListenNote note) {
    _unsaved = 0;
    return store().save(note).catchError((Object e) => debugPrint('Note not saved: $e'));
  }

  @override
  void dispose() {
    _cancelRestart();
    super.dispose();
  }
}
