import '../speech/sign_words.dart';
import 'note_summary.dart';

/// What was listened to; chosen when a Listen session is saved.
enum NoteKind {
  meeting('Meeting'),
  lesson('Class'),
  consultation('Consultation'),
  program('Program'),
  other('Other');

  const NoteKind(this.label);

  final String label;

  /// The kind saved as [name]; anything unknown is [other].
  static NoteKind named(Object? name) => values.firstWhere((k) => k.name == name, orElse: () => other);
}

/// One sentence heard during a Listen session.
class NoteLine {
  const NoteLine(this.text, this.at);

  final String text;
  final DateTime at;
}

/// A Listen session kept as a note (README "Listen and Notes"): everything heard, sentence by
/// sentence, from Start to Stop.
class ListenNote {
  const ListenNote({
    required this.id,
    required this.kind,
    required this.title,
    required this.language,
    required this.startedAt,
    required this.endedAt,
    required this.lines,
    this.summary,
  });

  final String id;
  final NoteKind kind;
  final String title;
  final SpeechLanguage language; // what was listened for
  final DateTime startedAt;
  final DateTime endedAt;
  final List<NoteLine> lines;
  final NoteSummary? summary; // made by Gemini when the user asks (README "Listen and Notes")

  Duration get duration => endedAt.difference(startedAt);

  ListenNote copyWith({NoteKind? kind, String? title, DateTime? endedAt, List<NoteLine>? lines, NoteSummary? summary}) =>
      ListenNote(
        id: id,
        kind: kind ?? this.kind,
        title: title ?? this.title,
        language: language,
        startedAt: startedAt,
        endedAt: endedAt ?? this.endedAt,
        lines: lines ?? this.lines,
        summary: summary ?? this.summary,
      );

  /// For the database (README "Firebase setup"). Times stay DateTime: Firestore stores them as
  /// timestamps.
  Map<String, Object?> toMap() => {
        'kind': kind.name,
        'title': title,
        'language': language.name,
        'startedAt': startedAt,
        'endedAt': endedAt,
        'lines': [
          for (final line in lines) {'text': line.text, 'at': line.at},
        ],
        if (summary case final summary?) 'summary': summary.toMap(),
      };

  /// The opposite of [toMap]. [time] turns a stored time back into a DateTime (Firestore gives
  /// timestamps). Damaged data gives null: skipped, never a crash.
  static ListenNote? fromMap(String id, Map<String, Object?> map,
      {DateTime Function(Object? stored) time = _asDateTime}) {
    try {
      return ListenNote(
        id: id,
        kind: NoteKind.named(map['kind']),
        title: map['title'] as String,
        language: SpeechLanguage.values.byName(map['language'] as String),
        startedAt: time(map['startedAt']),
        endedAt: time(map['endedAt']),
        lines: [
          for (final line in (map['lines'] as List).cast<Map<Object?, Object?>>())
            NoteLine(line['text'] as String, time(line['at'])),
        ],
        summary: NoteSummary.fromMap(map['summary'], time: time),
      );
    } catch (_) {
      return null;
    }
  }

  static DateTime _asDateTime(Object? stored) => stored as DateTime;
}
