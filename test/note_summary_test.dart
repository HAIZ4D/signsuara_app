import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:signsuara_app/listen/listen_note.dart';
import 'package:signsuara_app/listen/note_summary.dart';
import 'package:signsuara_app/speech/sign_words.dart';

void main() {
  final madeAt = DateTime(2026, 10, 1, 10);
  final note = ListenNote(
    id: 'n1',
    kind: NoteKind.consultation,
    title: 'Klinik',
    language: SpeechLanguage.malay,
    startedAt: DateTime(2026, 10, 1, 9),
    endedAt: DateTime(2026, 10, 1, 9, 10),
    lines: [
      NoteLine('Makan antibiotik ini dua kali sehari', DateTime(2026, 10, 1, 9, 1)),
      NoteLine('Datang semula pada 8 Oktober', DateTime(2026, 10, 1, 9, 5)),
    ],
  );
  String answer(Map<String, Object?> json) => jsonEncode(json);
  final good = {
    'overview': 'Doktor menerangkan ubat baharu.',
    'keyPoints': ['Ubat ini untuk batuk.', '  '],
    'actions': ['Makan ubat dua kali sehari.'],
    'details': ['2 kali sehari', '8 Oktober'],
    'terms': [
      {'term': 'Antibiotik', 'meaning': 'Ubat yang membunuh kuman.'},
    ],
  };

  test("Gemini's answer is read: blank points dropped, every part kept", () {
    final s = NoteSummary.fromJson(answer(good), madeAt: madeAt, model: 'm')!;
    expect(s.overview, 'Doktor menerangkan ubat baharu.');
    expect(s.keyPoints, ['Ubat ini untuk batuk.']);
    expect(s.actions, ['Makan ubat dua kali sehari.']);
    expect(s.details, ['2 kali sehari', '8 Oktober']);
    expect(s.terms.single.term, 'Antibiotik');
    expect(s.terms.single.meaning, 'Ubat yang membunuh kuman.');
  });

  test('an answer that cannot be used gives null (the screen then says so)', () {
    expect(NoteSummary.fromJson('not json', madeAt: madeAt, model: 'm'), isNull);
    expect(NoteSummary.fromJson(answer({...good, 'overview': '  '}), madeAt: madeAt, model: 'm'), isNull);
    expect(NoteSummary.fromJson(answer({'keyPoints': []}), madeAt: madeAt, model: 'm'), isNull);
    expect(NoteSummary.fromJson(answer({'overview': 'Only this.'}), madeAt: madeAt, model: 'm')!.keyPoints, isEmpty,
        reason: 'missing lists are just empty');
  });

  test('the summary is kept in the note; a damaged one does not lose the note', () {
    final summary = NoteSummary.fromJson(answer(good), madeAt: madeAt, model: 'gemini-x')!;
    final back = ListenNote.fromMap('n1', note.copyWith(summary: summary).toMap())!;
    expect(back.summary!.overview, summary.overview);
    expect(back.summary!.terms.single.term, 'Antibiotik');
    expect(back.summary!.madeAt, madeAt);
    expect(back.summary!.model, 'gemini-x');
    expect(ListenNote.fromMap('n1', note.toMap())!.summary, isNull);

    final damaged = note.toMap()..['summary'] = {'overview': 3};
    final kept = ListenNote.fromMap('n1', damaged)!;
    expect(kept.summary, isNull);
    expect(kept.lines, hasLength(2));
  });

  test('ticks on the to-do list are kept with the notes; older notes have none', () {
    final summary = NoteSummary.fromJson(answer(good), madeAt: madeAt, model: 'm')!;
    expect(summary.done, isEmpty);
    expect(note.copyWith(summary: summary).toMap()['summary'], isNot(contains('done')), reason: 'nothing stored before a tick');
    final back = ListenNote.fromMap('n1', note.copyWith(summary: summary.withDone({0})).toMap())!;
    expect(back.summary!.done, {0});
    expect(back.summary!.actions, summary.actions);
  });

  test("Gemini is asked for simple words in the note's language, only what was said, numbers exact", () {
    final prompt = summaryPrompt(note);
    expect(prompt, contains('read them in Bahasa Melayu'));
    expect(prompt, contains('a consultation'));
    expect(prompt, contains('"Klinik"'));
    expect(prompt, contains('[9:01 AM] Makan antibiotik ini dua kali sehari'));
    expect(prompt, contains('[9:05 AM] Datang semula pada 8 Oktober'));
    expect(prompt, contains('Only write what was said'));
    expect(prompt, contains('exactly as it was said'));
    final english = ListenNote.fromMap('n2', {...note.toMap(), 'language': 'english', 'kind': 'lesson'})!;
    expect(summaryPrompt(english), contains('read them in English'));
    expect(summaryPrompt(english), contains('a class'));
  });
}
