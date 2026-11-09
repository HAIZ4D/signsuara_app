import 'dart:ui' as ui;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signsuara_app/app/app_services.dart';
import 'package:signsuara_app/learn/learn_progress.dart';
import 'package:signsuara_app/learn/learn_screen.dart';
import 'package:signsuara_app/learn/quiz_question.dart';
import 'package:signsuara_app/learn/quiz_screen.dart';
import 'package:signsuara_app/learn/results_screen.dart';
import 'package:signsuara_app/learn/sign_quest_screen.dart';
import 'package:signsuara_app/signer/sign_clips.dart';
import 'package:signsuara_app/signer/sign_player.dart';
import 'package:signsuara_app/signer/signer.dart';
import 'package:signsuara_app/theme/app_theme.dart';
import 'package:signsuara_app/ui/widgets/gradient_button.dart';

import 'fake_clips.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400); // 360 x 800
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<ui.Image> _image(WidgetTester tester) async =>
    (await tester.runAsync(() => createTestImage(width: 4, height: 4, cache: false)))!;

/// Made-up clips (3 frames) for [ids].
ClipOpener _clips(ui.Image image, Set<String> ids) => (id) async => ids.contains(id) ? FakeClip(image, 3) : null;

QuizQuestion _question(String clip, List<String> answers, int right) => QuizQuestion(
      clipId: clip,
      question: 'What does this sign mean?',
      options: [for (final a in answers) QuizOption(a)],
      answer: right,
    );

VoidCallback? _next(WidgetTester tester) => tester.widget<GradientButton>(find.byType(GradientButton)).onTap;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter_tts'), (call) async => call.method == 'isLanguageAvailable' ? true : 1);
  });

  for (final reduced in [false, true]) {
    testWidgets('quiz: right = green + XP, wrong = the right answer shown, Results keep the XP (motion ${reduced ? 'reduced' : 'on'})',
        (tester) async {
      _phone(tester);
      if (reduced) {
        tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      }
      final image = await _image(tester);
      final progress = LearnProgress();
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: QuizScreen(
          title: 'Teka Isyarat',
          questions: [
            _question('letter_a', ['Huruf B', 'Huruf A', 'Huruf C', 'Huruf D'], 1),
            _question('saya', ['NAMA', 'YA', 'SAYA', 'TIDAK'], 2),
          ],
          progress: progress,
          timed: true,
          openClip: _clips(image, {'letter_a', 'saya'}),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Question 1 of 2'), findsOneWidget);
      expect(find.text('10s'), findsOneWidget);
      expect(_next(tester), isNull, reason: 'answer first');

      await tester.tap(find.text('Huruf A'));
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('Correct! +10 XP'), findsOneWidget);
      expect(find.text('10 XP'), findsOneWidget, reason: "this round's XP, top right");
      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2), reason: 'on the answer and in the words');
      expect(find.text('+10 XP'), reduced ? findsNothing : findsOneWidget, reason: 'the floating XP');

      await tester.tap(find.text('Next'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Question 2 of 2'), findsOneWidget);
      expect(find.text('Correct! +10 XP'), findsNothing);
      await tester.tap(find.text('NAMA'));
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text("Not quite. It's SAYA."), findsOneWidget);
      expect(find.byIcon(Icons.cancel_rounded), findsNWidgets(2), reason: 'on the wrong answer and in the words');
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget, reason: 'the right answer is shown');
      expect(progress.xp, 0, reason: 'saved only when the round is finished');

      await tester.tap(find.text('See results'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600)); // to the Results screen
      await tester.pump(const Duration(seconds: 1)); // the XP counts up
      expect(find.byType(ResultsScreen), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text(' / 2'), findsOneWidget);
      expect(find.text('+10 XP'), findsOneWidget);
      expect(find.text('1-day streak'), findsOneWidget);
      expect(find.text('Play again'), findsNothing, reason: 'this quiz has no next round');
      expect(progress.xp, 10);
      expect(tester.takeException(), isNull);
    });
  }

  for (final reduced in [false, true]) {
    testWidgets('Results: confetti for a perfect score or a new level, not otherwise (motion ${reduced ? 'reduced' : 'on'})',
        (tester) async {
      _phone(tester);
      if (reduced) {
        tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      }
      final buzzes = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') buzzes.add(call.arguments);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      Future<void> results(int right, {bool levelUp = false}) async {
        await tester.pumpWidget(MaterialApp(
          theme: buildAppTheme(),
          home: ResultsScreen(
            key: UniqueKey(),
            title: 'Teka Isyarat',
            right: right,
            total: 10,
            reward: (xp: right * 10, levelUp: levelUp, badges: const <LearnBadge>[]),
            progress: LearnProgress(),
          ),
        ));
        await tester.pump(const Duration(milliseconds: 300));
      }

      await results(10);
      expect(find.text('Perfect score!'), findsOneWidget);
      expect(find.byType(ConfettiWidget), reduced ? findsNothing : findsOneWidget);
      expect(buzzes, hasLength(1), reason: 'felt, also with less motion');
      await results(6, levelUp: true);
      expect(find.byType(ConfettiWidget), reduced ? findsNothing : findsOneWidget);
      await results(6);
      expect(find.byType(ConfettiWidget), findsNothing);
      expect(buzzes, hasLength(2), reason: 'nothing to celebrate: no buzz');
      await tester.pump(const Duration(seconds: 3));
    });
  }

  testWidgets("time's up after 10 s: the right answer is shown, Next works", (tester) async {
    _phone(tester);
    final image = await _image(tester);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: QuizScreen(
        title: 'Teka Isyarat',
        questions: [_question('letter_a', ['Huruf B', 'Huruf A', 'Huruf C', 'Huruf D'], 1)],
        progress: LearnProgress(),
        timed: true,
        openClip: _clips(image, {'letter_a'}),
      ),
    ));
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('5s'), findsOneWidget);
    expect(find.textContaining("Time's up"), findsNothing);
    await tester.pump(const Duration(seconds: 6));
    expect(find.text("Time's up. It's Huruf A."), findsOneWidget);
    expect(_next(tester), isNotNull);
    await tester.tap(find.text('Huruf B'));
    await tester.pump();
    expect(find.text("Time's up. It's Huruf A."), findsOneWidget, reason: 'no answering after the time is up');
    await tester.pump(const Duration(milliseconds: 500)); // flutter_animate starts each effect with a 0 s timer
  });

  testWidgets('Learn hub: real level and streak, Teka Isyarat opens a round of 10, Sign Quest waits for the glove',
      (tester) async {
    _phone(tester);
    final image = await _image(tester);
    final ids = {for (final c in 'abcdefg'.split('')) 'letter_$c', 'saya', 'nama', 'ya', 'tidak', 'apa', 'rest'};
    final services = AppServices(signer: fakeSigner(image, ids));
    addTearDown(services.dispose);
    await tester.pumpWidget(
        MaterialApp(theme: buildAppTheme(), home: LearnScreen(services: services, openClip: _clips(image, ids))));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Learn BIM'), findsOneWidget);
    expect(find.text('Jom belajar!'), findsOneWidget, reason: 'a guest: no name');
    expect(find.text('Level 1'), findsOneWidget);
    expect(find.text('0 / 100 XP'), findsOneWidget);
    expect(find.text('0 / 50 XP'), findsOneWidget, reason: "today's goal");
    expect(find.text('No streak'), findsOneWidget);

    final scroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Alphabet master'), 200, scrollable: scroll);
    expect(find.text('12 signs'), findsOneWidget, reason: "Teka Isyarat's tile");
    expect(find.text('Glove is off'), findsOneWidget, reason: "Sign Quest's tile");
    expect(find.text('0/26 letters'), findsOneWidget, reason: 'how close Alphabet master is');
    expect(find.text('0/7 days'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Sign Quest'), -200, scrollable: scroll);
    await tester.pump(const Duration(milliseconds: 600)); // the header keeps drifting: no pumpAndSettle
    await tester.tap(find.text('Sign Quest'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(SignQuestScreen), findsNothing, reason: 'the glove is not connected');
    expect(find.textContaining('Connect the glove on Home first'), findsOneWidget, reason: 'it says why');

    await tester.tap(find.text('Teka Isyarat'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(QuizScreen), findsOneWidget);
    expect(find.text('Question 1 of 10'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('without sign clips Teka Isyarat says why instead of starting', (tester) async {
    _phone(tester);
    final services = AppServices(signer: Signer(library: Future.value(const SignClipLibrary({}))));
    addTearDown(services.dispose);
    await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: LearnScreen(services: services)));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.tap(find.text('Teka Isyarat'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('needs at least 4 sign clips'), findsOneWidget);
    expect(find.byType(QuizScreen), findsNothing);
  });
}
