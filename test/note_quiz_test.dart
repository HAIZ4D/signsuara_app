import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signsuara_app/app_storage.dart';
import 'package:signsuara_app/learn/note_quiz.dart';
import 'package:signsuara_app/listen/listen_note.dart';
import 'package:signsuara_app/speech/sign_words.dart';

import 'fake_auth_backend.dart';

ListenNote _note(List<String> lines, {SpeechLanguage language = SpeechLanguage.malay}) {
  final start = DateTime(2026, 11, 8, 9);
  return ListenNote(
    id: 'n1',
    kind: NoteKind.lesson,
    title: 'Biology',
    language: language,
    startedAt: start,
    endedAt: start.add(const Duration(minutes: 30)),
    lines: [for (final (i, text) in lines.indexed) NoteLine(text, start.add(Duration(minutes: i)))],
  );
}

Map<String, Object?> _q(String question, List<Object?> options, Object? answer, [String? explain]) =>
    {'question': question, 'options': options, 'answer': answer, if (explain != null) 'explain': explain};

void main() {
  test("Gemini's answer: only well-formed questions are kept, answers shuffled, the right one still right", () {
    final json = jsonEncode({
      'questions': [
        _q('What do plants need?', ['Sunlight', 'Salt', 'Plastic', 'Noise'], 0, 'The teacher said plants need sunlight.'),
        _q('Three answers', ['a', 'b', 'c'], 0),
        _q('An empty answer', ['a', ' ', 'c', 'd'], 1),
        _q('Answer out of range', ['a', 'b', 'c', 'd'], 4),
        _q('Answer as text', ['a', 'b', 'c', 'd'], '1'),
        _q('   ', ['a', 'b', 'c', 'd'], 1),
        _q('Twice the same answer', ['a', 'a', 'c', 'd'], 1),
        'not a question',
        _q('When is the test?', [' Monday ', 'Friday', 'Sunday', 'Never'], 1, '  '),
      ],
    });
    for (var seed = 0; seed < 10; seed++) {
      final quiz = quizFromGemini(json, random: Random(seed));
      expect([for (final q in quiz) q.question], ['What do plants need?', 'When is the test?']);
      expect(quiz[0].correct.text, 'Sunlight');
      expect(quiz[0].explain, 'The teacher said plants need sunlight.');
      expect(quiz[1].correct.text, 'Friday');
      expect(quiz[1].options.map((o) => o.text), contains('Monday'), reason: 'trimmed');
      expect(quiz[1].explain, isNull, reason: 'a blank explanation is left out');
    }
    final firsts = {for (var seed = 0; seed < 20; seed++) quizFromGemini(json, random: Random(seed))[0].answer};
    expect(firsts.length, greaterThan(1), reason: 'the right answer is not always first');
    expect(quizFromGemini('not json'), isEmpty);
    expect(quizFromGemini(json, max: 1), hasLength(1));
  });

  test('5 questions, or 3 for a short note; the prompt is in the note language, with what was said', () {
    final short = _note(['Tumbuhan perlukan cahaya matahari.', 'Ujian pada hari Jumaat.']);
    final long = _note([for (var i = 0; i < 20; i++) 'Sentence number $i has some words in it'], language: SpeechLanguage.english);
    expect(quizLength(short), 3);
    expect(quizLength(long), 5);

    final prompt = quizPrompt(short);
    expect(prompt, contains('Bahasa Melayu'));
    expect(prompt, contains('exactly 3 questions'));
    expect(prompt, contains('a class called "Biology"'));
    expect(prompt, contains('[9:01 AM] Ujian pada hari Jumaat.'));
    expect(prompt, isNot(contains('Notes made from it earlier')));
    expect(quizPrompt(long), contains('English'));

    final summarised = quizPrompt(short.copyWith(summary: exampleSummary));
    expect(summarised, contains('Notes made from it earlier'));
    expect(summarised, contains(exampleSummary.overview));
  });

  test('a quiz is kept on the phone and comes back the same; damaged data gives none', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await AppStorage.open();
    expect(storage.loadQuiz('n1'), isNull);
    await storage.saveQuiz('n1', quizToMap(exampleQuiz()));

    final back = quizFromMap((await AppStorage.open()).loadQuiz('n1'))!;
    expect([for (final q in back) q.question], [for (final q in exampleQuiz()) q.question]);
    expect(back[0].correct.text, 'Twice a day');
    expect(back[1].explain, 'The next visit is on 8 October.');

    expect(quizFromMap({'questions': 'nope'}), isNull);
    expect(quizFromMap({'questions': []}), isNull);
    expect(quizFromMap({
      'questions': [
        {'question': 'q', 'options': ['a', 'b'], 'answer': 0},
      ],
    }), isNull, reason: 'not 4 answers');
    SharedPreferences.setMockInitialValues({'quiz_n1': 'not json'});
    expect((await AppStorage.open()).loadQuiz('n1'), isNull);
  });
}
