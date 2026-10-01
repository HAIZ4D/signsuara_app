import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

import '../listen/listen_note.dart';
import '../listen/note_summary.dart';

/// The only file that uses firebase_ai: Gemini on the paid Agent Platform (Vertex AI) service,
/// through Firebase AI Logic (README "Listen and Notes"). No API key in the app: it goes through the
/// app's own Firebase project. Google does not use what paid-tier requests send to train its models.
class GeminiSummarizer implements Summarizer {
  /// One place for the model name (README "Listen and Notes").
  static const model = 'gemini-3.8-flash';

  // The answer's shape: the fields NoteSummary.fromJson reads.
  static final _schema = Schema.object(properties: {
    'overview': Schema.string(),
    'keyPoints': Schema.array(items: Schema.string()),
    'actions': Schema.array(items: Schema.string()),
    'details': Schema.array(items: Schema.string()),
    'terms': Schema.array(
      items: Schema.object(properties: {'term': Schema.string(), 'meaning': Schema.string()}),
    ),
  });

  // The paid "Agent Platform (formerly Vertex AI)" provider; its default location is global.
  late final GenerativeModel _gemini = FirebaseAI.agentPlatform().generativeModel(
    model: model,
    // Low temperature: it sticks to what was said instead of inventing.
    generationConfig: GenerationConfig(responseMimeType: 'application/json', responseSchema: _schema, temperature: 0.2),
  );

  @override
  Future<NoteSummary> summarize(ListenNote note) async {
    try {
      final answer = await _gemini
          .generateContent([Content.text(summaryPrompt(note))]).timeout(const Duration(seconds: 90));
      final summary = NoteSummary.fromJson(answer.text ?? '', madeAt: DateTime.now(), model: model);
      if (summary == null) throw const SummaryFailure('Gemini gave an answer the app could not read. Try again.');
      return summary;
    } on SummaryFailure {
      rethrow;
    } on TimeoutException {
      throw const SummaryFailure('Gemini took too long to answer. Check the internet and try again.');
    } on ServiceApiNotEnabled catch (e) {
      debugPrint('Gemini: $e');
      throw const SummaryFailure('Gemini is not set up for this app yet (Firebase AI Logic).');
    } on QuotaExceeded catch (e) {
      debugPrint('Gemini: $e');
      throw const SummaryFailure('Too many summaries right now. Wait a minute and try again.');
    } on FirebaseAIException catch (e) {
      debugPrint('Gemini: $e');
      throw const SummaryFailure('Gemini could not make the summary. Try again in a moment.');
    } catch (e) {
      debugPrint('Gemini: $e'); // no internet, mostly
      throw const SummaryFailure('The summary needs the internet. Check the connection and try again.');
    }
  }
}
