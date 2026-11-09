import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signsuara_app/app/app_services.dart';
import 'package:signsuara_app/app_storage.dart';
import 'package:signsuara_app/learn/learn_path_screen.dart';
import 'package:signsuara_app/learn/learn_progress.dart';
import 'package:signsuara_app/learn/learn_screen.dart';
import 'package:signsuara_app/learn/learn_units.dart';
import 'package:signsuara_app/learn/quiz_screen.dart';
import 'package:signsuara_app/learn/results_screen.dart';
import 'package:signsuara_app/learn/sign_lesson_screen.dart';
import 'package:signsuara_app/signer/sign_clips.dart';
import 'package:signsuara_app/signer/sign_player.dart';
import 'package:signsuara_app/theme/app_theme.dart';

import 'fake_clips.dart';

// The clips the app has today.
final _app = {
  for (var c = 'a'.codeUnitAt(0); c <= 'z'.codeUnitAt(0); c++) 'letter_${String.fromCharCode(c)}',
  ...['apa', 'apa_khabar', 'awak', 'buat_apa', 'makan_tengahari', 'nama', 'saya', 'sudah', 'terima_kasih', 'tidak', 'ya'],
  ...['rest', 'spell_in', 'spell_out'],
};

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter_tts'), (call) async => call.method == 'isLanguageAvailable' ? true : 1);
  });

  test('the path: units with at least 2 signs that have a clip; a new clip makes a unit appear', () {
    final units = pathUnits(SignClipLibrary(_app));
    expect([for (final u in units) u.id], ['kenali_diri', 'huruf_ai', 'jawab_tanya', 'huruf_jr', 'berbual', 'huruf_sz']);
    expect(units.first.available(SignClipLibrary(_app)), ['saya', 'nama', 'awak', 'terima_kasih'],
        reason: 'ASSALAMUALAIKUM has no clip yet');
    expect(pathUnits(SignClipLibrary({..._app, 'islam', 'solat'})).last.id, 'agama');
  });

  test('stars: 3 all right, 2 passed (70 %), 0 not; a unit opens when the one before is passed; kept after a restart',
      () async {
    expect([quizStars(4, 4), quizStars(3, 4), quizStars(2, 4), quizStars(7, 10), quizStars(6, 10)], [3, 2, 0, 2, 0]);
    final units = pathUnits(SignClipLibrary(_app));
    final learn = LearnProgress()..load(await AppStorage.open());
    expect((currentUnit(units, learn), unitOpen(units, learn, 1)), (0, false));
    await learn.rateUnit('kenali_diri', 1);
    expect(unitOpen(units, learn, 1), isFalse, reason: 'watched is not passed');
    await learn.rateUnit('kenali_diri', 2);
    expect((currentUnit(units, learn), unitOpen(units, learn, 1), unitsPassed(units, learn)), (1, true, 1));
    await learn.rateUnit('kenali_diri', 1);
    expect(learn.unitStars('kenali_diri'), 2, reason: 'the best stars are kept');

    final restarted = LearnProgress()..load(await AppStorage.open());
    expect(restarted.unitStars('kenali_diri'), 2);
  });

  Future<AppServices> services(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final image = (await tester.runAsync(() => createTestImage(width: 4, height: 4, cache: false)))!;
    final services = AppServices(signer: fakeSigner(image, _app));
    addTearDown(services.dispose);
    await tester.pump(); // the clip list
    return services;
  }

  Future<ClipReader?> noPictures(String id) async => null;

  testWidgets('hub: Continue opens unit 1; a perfect quiz gives 3 stars and opens unit 2', (tester) async {
    final s = await services(tester);
    await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: LearnScreen(services: s, openClip: noPictures)));
    await tester.pumpAndSettle();
    expect(find.text('Your path'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('NEXT'), 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp(r'Unit 1, Kenali Diri\. 0 of 3 stars\. Next to do\.')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'Unit 2, Huruf A–I\..*Locked\.')), findsOneWidget);

    await tester.tap(find.text('Kenali Diri'));
    await tester.pumpAndSettle();
    expect(find.text('Watch the signs'), findsOneWidget);
    expect(find.text('Practise with the glove'), findsOneWidget, reason: 'SAYA, NAMA, TERIMA KASIH are glove signs');
    await tester.tap(find.text('Quiz'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    final questions = tester.widget<QuizScreen>(find.byType(QuizScreen)).questions;
    expect(questions, hasLength(4));
    for (final (i, q) in questions.indexed) {
      await tester.tap(find.text(q.correct.text));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(i + 1 < questions.length ? 'Next' : 'See results'));
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(ResultsScreen), findsOneWidget);
    expect(find.text('Perfect: 3 stars! "Huruf A–I" is open now.'), findsOneWidget);
    expect(s.learn.unitStars('kenali_diri'), 3);
  });

  testWidgets('the path: a locked unit says what opens it; watching a whole lesson gives the first star', (tester) async {
    final s = await services(tester);
    await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: LearnPathScreen(services: s, openClip: noPictures)));
    await tester.pumpAndSettle();
    expect(find.text('0 of 6 units passed · pass a unit to open the next'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Unit 2, Huruf A–I.*Locked')), findsOneWidget);

    await tester.tap(find.text('Huruf A–I'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Pass "Kenali Diri" to open this unit.'), findsOneWidget);

    await tester.tap(find.text('Kenali Diri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Watch the signs'));
    await tester.pumpAndSettle();
    expect(find.byType(SignLessonScreen), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      expect(s.learn.unitStars('kenali_diri'), 0);
      await tester.tap(find.text('Next sign'));
      await tester.pumpAndSettle();
    }
    expect(find.text('TERIMA KASIH'), findsOneWidget);
    expect(s.learn.unitStars('kenali_diri'), 1, reason: 'the last sign was reached');
  });
}
