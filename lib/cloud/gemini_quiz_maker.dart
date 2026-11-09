import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/foundation.dart';

import '../learn/note_quiz.dart';
import '../learn/quiz_question.dart';
import '../listen/listen_note.dart';
import 'gemini_summarizer.dart';

/// Gemini Quiz (README "Learn"): one of the two files that use firebase_ai, the same way as
/// gemini_summarizer.dart (the paid Agent Platform service through Firebase AI Logic, the same
/// model, App Check, no API key in the app).
class GeminiQuizMaker implements QuizMaker {
  static const _notAllowed = 'Gemini did not accept this phone (App Check). Check the internet; if it '
      "is on, add this phone's App Check debug token in the Firebase console.";

  // The answer's shape: the fields quizFromGemini reads.
  static final _schema = Schema.object(properties: {
    'questions': Schema.array(
      minItems: 1,
      maxItems: 5,
      items: Schema.object(properties: {
        'question': Schema.string(),
        'options': Schema.array(items: Schema.string(), minItems: 4, maxItems: 4),
        'answer': Schema.integer(),
        'explain': Schema.string(),
      }),
    ),
  });

  late final GenerativeModel _gemini = FirebaseAI.agentPlatform().generativeModel(
    model: GeminiSummarizer.model,
    // Low temperature: questions about what was said, not invented ones.
    generationConfig: GenerationConfig(responseMimeType: 'application/json', responseSchema: _schema, temperature: 0.2),
  );

  @override
  Future<List<QuizQuestion>> makeQuiz(ListenNote note) async {
    try {
      final answer =
          await _gemini.generateContent([Content.text(quizPrompt(note))]).timeout(const Duration(seconds: 90));
      final questions = quizFromGemini(answer.text ?? '', max: quizLength(note));
      if (questions.isEmpty) throw const QuizFailure('Gemini gave a quiz the app could not use. Try again.');
      return questions;
    } on QuizFailure {
      rethrow;
    } on TimeoutException {
      throw const QuizFailure('Gemini took too long to answer. Check the internet and try again.');
    } on ServiceApiNotEnabled catch (e) {
      debugPrint('Gemini quiz: $e');
      throw const QuizFailure('Gemini is not set up for this app yet (Firebase AI Logic).');
    } on QuotaExceeded catch (e) {
      debugPrint('Gemini quiz: $e');
      throw const QuizFailure('Too many quizzes right now. Wait a minute and try again.');
    } on FirebaseAIException catch (e) {
      debugPrint('Gemini quiz: $e');
      if (e.message.contains('App Check')) throw const QuizFailure(_notAllowed); // token refused
      throw const QuizFailure('Gemini could not make the quiz. Try again in a moment.');
    } catch (e) {
      debugPrint('Gemini quiz: $e'); // no internet, mostly
      // No App Check token for this phone: not added in the console, or no internet.
      if (e is FirebaseException && e.plugin == 'firebase_app_check') throw const QuizFailure(_notAllowed);
      throw const QuizFailure('The quiz needs the internet. Check the connection and try again.');
    }
  }
}
