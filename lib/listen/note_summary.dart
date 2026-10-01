import 'dart:convert';

import '../speech/sign_words.dart';
import '../ui/time_label.dart';
import 'listen_note.dart';

/// A hard word that was said, explained simply.
class SummaryTerm {
  const SummaryTerm(this.term, this.meaning);

  final String term;
  final String meaning;
}

/// Gemini's notes about a Listen session (README "Listen and Notes"), in the session's language.
class NoteSummary {
  const NoteSummary({
    required this.overview,
    required this.keyPoints,
    required this.actions,
    required this.details,
    required this.terms,
    required this.madeAt,
    required this.model,
    this.done = const {},
  });

  final String overview; // what it was about, in 2 or 3 sentences
  final List<String> keyPoints;
  final List<String> actions; // what the listener is asked or advised to do
  final List<String> details; // dates, times, places, numbers, doses: exactly as said
  final List<SummaryTerm> terms; // hard words explained
  final DateTime madeAt;
  final String model;
  final Set<int> done; // the actions the reader ticked off (their places in [actions])

  /// The same notes, with [done] as the ticked-off actions.
  NoteSummary withDone(Set<int> done) => NoteSummary(
      overview: overview,
      keyPoints: keyPoints,
      actions: actions,
      details: details,
      terms: terms,
      madeAt: madeAt,
      model: model,
      done: done);

  Map<String, Object?> toMap() => {
        'overview': overview,
        'keyPoints': keyPoints,
        'actions': actions,
        'details': details,
        'terms': [
          for (final t in terms) {'term': t.term, 'meaning': t.meaning},
        ],
        'madeAt': madeAt,
        'model': model,
        if (done.isNotEmpty) 'done': done.toList()..sort(),
      };

  /// The opposite of [toMap]; damaged data gives null (the note is still shown, without it).
  static NoteSummary? fromMap(Object? map, {DateTime Function(Object? stored) time = _asDateTime}) {
    if (map is! Map) return null;
    try {
      return _read(map, madeAt: time(map['madeAt']), model: map['model'] as String);
    } catch (_) {
      return null;
    }
  }

  /// Gemini's JSON answer (the schema in lib/cloud/gemini_summarizer.dart); null when it can't be
  /// read, or says nothing.
  static NoteSummary? fromJson(String json, {required DateTime madeAt, required String model}) {
    try {
      final summary = _read(jsonDecode(json) as Map, madeAt: madeAt, model: model);
      return summary.overview.trim().isEmpty ? null : summary;
    } catch (_) {
      return null;
    }
  }

  static NoteSummary _read(Map map, {required DateTime madeAt, required String model}) {
    List<String> texts(Object? list) =>
        [for (final t in (list as List? ?? const [])) if ((t as String).trim().isNotEmpty) t.trim()];
    return NoteSummary(
      overview: (map['overview'] as String).trim(),
      keyPoints: texts(map['keyPoints']),
      actions: texts(map['actions']),
      details: texts(map['details']),
      terms: [
        for (final t in (map['terms'] as List? ?? const []).cast<Map>())
          if ((t['term'] as String).trim().isNotEmpty) SummaryTerm((t['term'] as String).trim(), (t['meaning'] as String).trim()),
      ],
      madeAt: madeAt,
      model: model,
      done: {for (final i in (map['done'] as List? ?? const [])) if (i is int) i}, // older notes have none
    );
  }

  static DateTime _asDateTime(Object? stored) => stored as DateTime;
}

/// Makes the notes for a Listen session: Gemini on the phone (lib/cloud/gemini_summarizer.dart),
/// a fake in tests.
abstract class Summarizer {
  /// Throws [SummaryFailure] (plain words for the screen) when it can't.
  Future<NoteSummary> summarize(ListenNote note);
}

/// Why no summary could be made, already in plain words.
class SummaryFailure implements Exception {
  const SummaryFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// What Gemini is asked (README "Listen and Notes"): simple words, only what was said, numbers kept
/// exact, in the language that was listened to.
String summaryPrompt(ListenNote note) {
  final language = note.language == SpeechLanguage.malay ? 'Bahasa Melayu' : 'English';
  final what = switch (note.kind) {
    NoteKind.meeting => 'a meeting',
    NoteKind.lesson => 'a class',
    NoteKind.consultation => 'a consultation (for example with a doctor)',
    NoteKind.program => 'a program or event',
    NoteKind.other => 'a talk',
  };
  return '''
You write clear notes for a Deaf person, who will read them in $language.
Below is what was said at $what called "${note.title}", sentence by sentence with the time.
It comes from speech recognition, so a few words may be wrong.

Write every part of the notes in $language, following these rules:
- Use short, simple sentences and everyday words.
- Only write what was said. Do not add facts, advice or guesses of your own. If something is unclear, say that it is unclear.
- Keep every number, date, time, place, amount and medicine dose exactly as it was said.
- overview: two or three sentences about what it was about.
- keyPoints: the main points, one short sentence each.
- actions: what the listener was asked or advised to do. Empty when there is nothing.
- details: important dates, times, places, numbers and doses. Empty when there are none.
- terms: difficult, technical, medical, scientific or religious words that were said, each with a simple meaning. Empty when there are none.

What was said:
${[for (final line in note.lines) '[${clockTime(line.at)}] ${line.text}'].join('\n')}
''';
}
