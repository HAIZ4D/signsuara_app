import 'dart:convert';
import 'dart:math';

import '../listen/listen_note.dart';
import '../speech/sign_words.dart';
import '../ui/time_label.dart';
import 'quiz_question.dart';

/// Gemini Quiz (README "Learn"): a short quiz made from a Listen note. Gemini on the phone
/// (lib/cloud/gemini_quiz_maker.dart), a fake in tests.
abstract class QuizMaker {
  /// The checked questions (see [quizFromGemini]). Throws [QuizFailure] (plain words for the
  /// screen) when it can't.
  Future<List<QuizQuestion>> makeQuiz(ListenNote note);
}

/// Why no quiz could be made, already in plain words.
class QuizFailure implements Exception {
  const QuizFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 5 questions; 3 for a short note (under 80 words), where 5 would repeat themselves.
int quizLength(ListenNote note) {
  final words = note.lines.fold(0, (n, line) => n + line.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length);
  return words < 80 ? 3 : 5;
}

/// What Gemini is asked (written like summaryPrompt): for a Deaf learner, in the note's language,
/// only from what was said (and the note's Gemini summary, if it has one), 4 answers, no tricks.
String quizPrompt(ListenNote note) {
  final language = note.language == SpeechLanguage.malay ? 'Bahasa Melayu' : 'English';
  final what = switch (note.kind) {
    NoteKind.meeting => 'a meeting',
    NoteKind.lesson => 'a class',
    NoteKind.consultation => 'a consultation (for example with a doctor)',
    NoteKind.program => 'a program or event',
    NoteKind.other => 'a talk',
  };
  final summary = note.summary;
  return '''
You make a short quiz for a Deaf learner, who will read it in $language.
Below is what was said at $what called "${note.title}", sentence by sentence with the time.
It comes from speech recognition, so a few words may be wrong.

Write exactly ${quizLength(note)} questions, all in $language, following these rules:
- Ask only about what was said. Do not add facts of your own.
- Ask about the most important things: the main ideas, what to do, dates, times and numbers.
- Use short, simple sentences and everyday words.
- options: exactly 4 short answers, all different, and exactly one of them right. The wrong answers
  must be clearly wrong for someone who followed. No trick questions, no "all of the above" or
  "none of the above".
- answer: the position of the right answer in options (0, 1, 2 or 3).
- explain: one short sentence saying why that answer is right, from what was said.
${summary == null ? '' : '\nNotes made from it earlier (use them only to find what matters):\n${[summary.overview, ...summary.keyPoints].join('\n')}\n'}
What was said:
${[for (final line in note.lines) '[${clockTime(line.at)}] ${line.text}'].join('\n')}
''';
}

/// Gemini's JSON answer (the schema in lib/cloud/gemini_quiz_maker.dart) as questions. A question
/// is kept only with a question, exactly 4 different non-empty answers and an answer 0–3; the
/// answers are shuffled (models like to put the right one first). At most [max]; an unreadable
/// answer gives none.
List<QuizQuestion> quizFromGemini(String json, {int max = 5, Random? random}) {
  final r = random ?? Random();
  try {
    final questions = <QuizQuestion>[];
    for (final q in ((jsonDecode(json) as Map)['questions'] as List).whereType<Map>()) {
      final question = q['question'], options = q['options'], answer = q['answer'], explain = q['explain'];
      if (question is! String || question.trim().isEmpty || answer is! int || answer < 0 || answer > 3) continue;
      if (options is! List || options.length != 4 || options.any((o) => o is! String || o.trim().isEmpty)) continue;
      final texts = [for (final o in options) (o as String).trim()];
      if (texts.toSet().length != 4) continue;
      final order = [0, 1, 2, 3]..shuffle(r);
      questions.add(QuizQuestion(
        question: question.trim(),
        options: [for (final i in order) QuizOption(texts[i])],
        answer: order.indexOf(answer),
        explain: explain is String && explain.trim().isNotEmpty ? explain.trim() : null,
      ));
      if (questions.length == max) break;
    }
    return questions;
  } catch (_) {
    return const [];
  }
}

/// A quiz as saved on the phone (so playing it again costs no Gemini request).
Map<String, Object?> quizToMap(List<QuizQuestion> questions) => {
      'questions': [
        for (final q in questions)
          {
            'question': q.question,
            'options': [for (final o in q.options) o.text],
            'answer': q.answer,
            if (q.explain != null) 'explain': q.explain,
          },
      ],
    };

/// The opposite of [quizToMap]; nothing saved or damaged data gives null (a new quiz is made).
List<QuizQuestion>? quizFromMap(Map<String, Object?>? map) {
  if (map == null) return null;
  try {
    final questions = [
      for (final q in (map['questions'] as List).cast<Map>())
        QuizQuestion(
          question: q['question'] as String,
          options: [for (final o in (q['options'] as List).cast<String>()) QuizOption(o)],
          answer: q['answer'] as int,
          explain: q['explain'] as String?,
        ),
    ];
    return questions.isEmpty ? null : questions;
  } catch (_) {
    return null; // includes a question that breaks QuizQuestion's own check
  }
}
