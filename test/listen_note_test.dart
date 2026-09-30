import 'package:flutter_test/flutter_test.dart';
import 'package:signsuara_app/listen/listen_note.dart';
import 'package:signsuara_app/speech/sign_words.dart';

void main() {
  final note = ListenNote(
    id: 'n1',
    kind: NoteKind.consultation,
    title: 'Doctor · Today, 9:00 AM',
    language: SpeechLanguage.malay,
    startedAt: DateTime(2026, 10, 1, 9),
    endedAt: DateTime(2026, 10, 1, 9, 12),
    lines: [NoteLine('Makan ubat dua kali sehari', DateTime(2026, 10, 1, 9, 1))],
  );

  test('a note survives the database: kind, language, times and every line', () {
    final back = ListenNote.fromMap('n1', note.toMap())!;
    expect(back.kind, NoteKind.consultation);
    expect(back.title, note.title);
    expect(back.language, SpeechLanguage.malay);
    expect(back.duration, const Duration(minutes: 12));
    expect(back.lines.single.text, 'Makan ubat dua kali sehari');
    expect(back.lines.single.at, DateTime(2026, 10, 1, 9, 1));
  });

  test('damaged data is skipped, an unknown kind reads as Other', () {
    expect(ListenNote.fromMap('x', {'title': 'no lines'}), isNull);
    final odd = note.toMap()..['kind'] = 'party';
    expect(ListenNote.fromMap('n1', odd)!.kind, NoteKind.other);
  });
}
