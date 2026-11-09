import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signsuara_app/app/app_services.dart';
import 'package:signsuara_app/app_storage.dart';
import 'package:signsuara_app/learn/learn_progress.dart';
import 'package:signsuara_app/learn/learn_screen.dart';
import 'package:signsuara_app/learn/sign_lesson_screen.dart';
import 'package:signsuara_app/learn/teka_isyarat.dart';
import 'package:signsuara_app/signer/sign_clips.dart';
import 'package:signsuara_app/signer/sign_player.dart';
import 'package:signsuara_app/theme/app_theme.dart';

import 'fake_clips.dart';

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

  test("today's XP counts today only; the sign of the day gives 5 XP once a day and keeps the streak", () async {
    var now = DateTime(2026, 11, 8, 20);
    final learn = LearnProgress(clock: () => now)..load(await AppStorage.open());
    await learn.finishRound(xp: 30);
    expect(learn.xpToday, 30);
    expect(learn.watchedSignToday, isFalse);
    expect(await learn.watchSignOfTheDay(), isNotNull);
    expect(await learn.watchSignOfTheDay(), isNull, reason: 'once a day');
    expect((learn.xp, learn.xpToday, learn.watchedSignToday), (35, 35, true));

    now = DateTime(2026, 11, 9, 8);
    expect((learn.xpToday, learn.watchedSignToday), (0, false), reason: 'a new day');
    await learn.watchSignOfTheDay();
    expect((learn.xpToday, learn.streak), (5, 2), reason: 'watching it is enough to keep the streak');

    final restarted = LearnProgress(clock: () => now)..load(await AppStorage.open());
    expect((restarted.xpToday, restarted.watchedSignToday, restarted.xp), (5, true, 40));
  });

  test('the sign of the day: the same all day, another the next day, a word sign; none without clips', () {
    final library = SignClipLibrary(_app);
    final morning = signOfTheDay(library, DateTime(2026, 11, 8, 7))!;
    expect(signOfTheDay(library, DateTime(2026, 11, 8, 23)), morning);
    expect(signOfTheDay(library, DateTime(2026, 11, 9)), isNot(morning));
    expect(morning.startsWith('letter_'), isFalse);
    final week = {for (var d = 1; d <= 11; d++) signOfTheDay(library, DateTime(2026, 12, d))};
    expect(week, hasLength(11), reason: 'it goes round all 11 word signs');
    expect(signOfTheDay(const SignClipLibrary({}), DateTime(2026, 11, 8)), isNull);
  });

  testWidgets('Cikgu Suara suggests the sign of the day; once watched it is ticked, counted, and she suggests the path',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final image = (await tester.runAsync(() => createTestImage(width: 4, height: 4, cache: false)))!;
    final services = AppServices(signer: fakeSigner(image, _app));
    addTearDown(services.dispose);
    Future<ClipReader?> noPictures(String id) async => null;
    await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: LearnScreen(services: services, openClip: noPictures)));
    await tester.pumpAndSettle();

    final sign = signAnswer(signOfTheDay(services.signer.library, DateTime.now())!).text;
    expect(find.text("Today's sign is $sign. Want to see it?"), findsOneWidget);
    expect(find.text('SIGN OF THE DAY'), findsOneWidget);
    await tester.tap(find.text('Show me'));
    await tester.pumpAndSettle();
    expect(find.byType(SignLessonScreen), findsOneWidget);
    expect(find.text('Sign of the day'), findsOneWidget);
    expect(services.learn.watchedSignToday, isTrue);

    await tester.tap(find.byTooltip('Leave the lesson'));
    await tester.pumpAndSettle();
    expect(find.text('Watched'), findsOneWidget);
    expect(find.text('5 / 50 XP'), findsOneWidget, reason: "today's goal");
    expect(find.text('1-day streak'), findsOneWidget);
    expect(find.text('Next up: unit 1, Kenali Diri.'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('tapping Cikgu Suara makes her wave again (cheer every other time); with motion on nothing breaks',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final image = (await tester.runAsync(() => createTestImage(width: 4, height: 4, cache: false)))!;
    final ids = {..._app, 'wave', 'cheer'};
    final services = AppServices(signer: fakeSigner(image, ids));
    addTearDown(services.dispose);
    final played = <String>[];
    Future<ClipReader?> clips(String id) async {
      played.add(id);
      return FakeClip(image, 3);
    }

    await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: LearnScreen(services: services, openClip: clips)));
    for (var t = 0; t < 20; t++) {
      await tester.pump(const Duration(milliseconds: 100)); // the hub's entrances (2 s), frame by frame
    }
    expect(played, ['wave'], reason: 'she says hello');
    await tester.tap(find.bySemanticsLabel('Cikgu Suara. Tap to say hi.'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.bySemanticsLabel('Cikgu Suara. Tap to say hi.'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(played, ['wave', 'wave', 'cheer']);
    expect(tester.takeException(), isNull);
  });
}
