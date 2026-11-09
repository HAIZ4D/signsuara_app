import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signsuara_app/app/app_services.dart';
import 'package:signsuara_app/cloud/account.dart';
import 'package:signsuara_app/learn/gemini_quiz_screen.dart';
import 'package:signsuara_app/learn/learn_progress.dart';
import 'package:signsuara_app/learn/learn_screen.dart';
import 'package:signsuara_app/learn/note_quiz.dart';
import 'package:signsuara_app/learn/quiz_screen.dart';
import 'package:signsuara_app/learn/results_screen.dart';
import 'package:signsuara_app/listen/listen_note.dart';
import 'package:signsuara_app/screens/note_screen.dart';
import 'package:signsuara_app/signer/sign_clips.dart';
import 'package:signsuara_app/signer/signer.dart';
import 'package:signsuara_app/speech/sign_words.dart';
import 'package:signsuara_app/theme/app_theme.dart';

import 'fake_auth_backend.dart';
import 'fake_transcriber.dart';

final _visit = ListenNote(
  id: 'n1',
  kind: NoteKind.consultation,
  title: 'Doctor visit',
  language: SpeechLanguage.english,
  startedAt: DateTime(2026, 11, 8, 9),
  endedAt: DateTime(2026, 11, 8, 9, 12),
  lines: [NoteLine('Take the medicine twice a day after meals.', DateTime(2026, 11, 8, 9, 1))],
);

/// A guest whose Gemini is a fake; reduce motion on, so the screens can settle.
Future<(AppServices, FakeQuizMaker)> _services(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400); // 360 x 800
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  final backend = FakeAuthBackend();
  final services = AppServices(
    account: Account(backend),
    signer: Signer(library: Future.value(const SignClipLibrary({}))),
    transcriber: FakeTranscriber(),
  );
  addTearDown(services.dispose);
  await services.start(); // the phone's storage: quizzes, the Gemini notice, progress
  await services.notes.save(_visit);
  return (services, backend.fakeQuizMaker);
}

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter_tts'), (call) async => call.method == 'isLanguageAvailable' ? true : 1);
  });

  testWidgets('hub → a note → the notice → Gemini makes the quiz; it is kept, so playing again asks Gemini nothing',
      (tester) async {
    final (services, gemini) = await _services(tester);
    await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: LearnScreen(services: services)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Gemini Quiz'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Quiz from notes'), findsOneWidget);

    await _tap(tester, 'Gemini Quiz');
    expect(find.text('Quiz from a note'), findsOneWidget);
    await _tap(tester, 'Doctor visit');
    expect(find.text('Make a quiz with Gemini?'), findsOneWidget, reason: 'what is sent to Google, the first time');
    await _tap(tester, 'Make quiz');
    expect(gemini.asked, [_visit]);
    expect(services.summaryNoticeSeen, isTrue, reason: 'one notice for summaries and quizzes');

    expect(find.byType(QuizScreen), findsOneWidget);
    expect(find.text('Question 1 of 2'), findsOneWidget);
    expect(find.text('How often is the medicine taken?'), findsOneWidget);
    await _tap(tester, 'Twice a day');
    expect(find.text('Correct! +10 XP'), findsOneWidget);
    expect(find.text('The doctor said twice a day, after meals.'), findsOneWidget, reason: 'the explanation');
    await _tap(tester, 'Next');
    await _tap(tester, 'Tomorrow');
    expect(find.text("Not quite. It's 8 October."), findsOneWidget);
    await _tap(tester, 'See results');

    expect(find.byType(ResultsScreen), findsOneWidget);
    expect(services.learn.xp, 10);
    expect(services.learn.has(LearnBadge.studyBuddy), isTrue);
    expect(find.text('Study buddy'), findsOneWidget, reason: 'shown as a new badge');

    await _tap(tester, 'Play again');
    expect(find.text('Question 1 of 2'), findsOneWidget, reason: 'the same quiz again');
    await tester.tap(find.byTooltip('Leave the game'));
    await tester.pumpAndSettle();

    await _tap(tester, 'Gemini Quiz');
    expect(find.text('Quiz saved'), findsOneWidget);
    await _tap(tester, 'Doctor visit');
    expect(find.byType(QuizScreen), findsOneWidget);
    expect(gemini.asked, hasLength(1), reason: 'the kept quiz: no new Gemini request');
  });

  testWidgets('no internet: the reason in plain words, and Try again', (tester) async {
    final (services, gemini) = await _services(tester);
    await services.markSummaryNoticeSeen();
    gemini.failure = const QuizFailure('The quiz needs the internet. Check the connection and try again.');
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Builder(
        builder: (context) => TextButton(onPressed: () => startNoteQuiz(context, services, _visit), child: const Text('go')),
      ),
    ));
    await _tap(tester, 'go');
    expect(find.text('The quiz needs the internet. Check the connection and try again.'), findsOneWidget);
    expect(services.savedQuiz(_visit.id), isNull, reason: 'nothing kept');

    gemini.failure = null;
    await _tap(tester, 'Try again');
    expect(find.byType(QuizScreen), findsOneWidget);
    expect(services.savedQuiz(_visit.id), hasLength(2));
  });

  testWidgets('a note offers its quiz: Make quiz, then Play quiz or a new one from Gemini', (tester) async {
    final (services, gemini) = await _services(tester);
    await services.markSummaryNoticeSeen();
    await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: NoteScreen(services: services, noteId: _visit.id)));
    await tester.pumpAndSettle();
    expect(find.text('Quiz yourself'), findsOneWidget);
    expect(find.text('3 questions from this note, made by Gemini. Wins XP in Learn.'), findsOneWidget, reason: 'a short note');

    await _tap(tester, 'Make quiz');
    expect(find.byType(QuizScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Leave the game'));
    await tester.pumpAndSettle();
    expect(find.text('Play quiz'), findsOneWidget);
    expect(find.text('New quiz from Gemini'), findsOneWidget);

    await _tap(tester, 'Play quiz');
    expect(gemini.asked, hasLength(1));
    await tester.tap(find.byTooltip('Leave the game'));
    await tester.pumpAndSettle();
    await _tap(tester, 'New quiz from Gemini');
    expect(gemini.asked, hasLength(2), reason: 'a new quiz was asked for');
  });
}
