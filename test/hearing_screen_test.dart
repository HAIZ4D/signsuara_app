import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signsuara_app/app/app_services.dart';
import 'package:signsuara_app/screens/hearing_screen.dart';
import 'package:signsuara_app/signer/sign_player_view.dart';
import 'package:signsuara_app/signer/signer.dart';
import 'package:signsuara_app/theme/app_theme.dart';

import 'fake_clips.dart';

Future<AppServices> _pumpScreen(WidgetTester tester, {Signer? signer}) async {
  if (signer != null) {
    tester.view.physicalSize = const Size(1080, 2400); // a phone: 360 x 800
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }
  final services = AppServices(signer: signer);
  addTearDown(services.dispose);
  await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: Scaffold(body: HearingScreen(services: services))));
  return services;
}

/// The screen clock for [ms]: frames of 20 ms, like a real screen (one picture per frame at most).
Future<void> _playFor(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 20) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter_tts'), (call) async => call.method == 'isLanguageAvailable' ? true : 1);
  });

  testWidgets('starts with a hint, quick replies and the mic', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpScreen(tester);
    expect(find.text('HEARING MODE'), findsOneWidget);
    expect(find.textContaining('Your words show up here'), findsOneWidget);
    expect(find.text('READY'), findsOneWidget);
    for (final q in ['Sila tunggu', 'Terima kasih', 'Ya', 'Tidak']) {
      expect(find.text(q), findsOneWidget, reason: 'Malay quick reply $q');
    }
    expect(find.bySemanticsLabel('Tap to speak'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('latest words big on the stage, earlier ones in the card', (tester) async {
    final services = await _pumpScreen(tester);
    services.log
      ..addHeard('Hello there')
      ..addHeard('How are you?');
    await tester.pump();
    expect(find.text('How are you?'), findsOneWidget); // stage
    expect(find.text('Hello there'), findsOneWidget); // earlier card
    expect(find.text('SAID'), findsOneWidget);

    Text stage() => tester.widget<Text>(find.text('How are you?'));
    final normal = DefaultTextStyle.of(tester.element(find.text('How are you?'))).style.fontSize;
    await tester.tap(find.text('Aa'));
    await tester.pump(const Duration(milliseconds: 400));
    final large = DefaultTextStyle.of(tester.element(find.text('How are you?'))).style.fontSize;
    expect(stage().data, 'How are you?');
    expect(large, greaterThan(normal!));
  });

  testWidgets('a quick reply is shown big and added to the conversation; clear empties it', (tester) async {
    final services = await _pumpScreen(tester);
    await tester.tap(find.text('Terima kasih'));
    await tester.pump();
    expect(services.log.messages.single.text, 'Terima kasih');
    expect(find.text('Terima kasih'), findsNWidgets(2)); // stage + chip
    expect(find.text('TERIMA KASIH'), findsOneWidget, reason: 'how it will be signed');

    await tester.tap(find.byTooltip('Clear conversation'));
    await tester.pump();
    expect(services.log.messages, isEmpty);
    expect(find.text('READY'), findsOneWidget);
  });

  testWidgets('the stage shows how the words will be signed; a name is fingerspelled', (tester) async {
    final semantics = tester.ensureSemantics();
    final services = await _pumpScreen(tester);
    services.log.addHeard('Terima kasih Zad');
    await tester.pump();
    expect(find.text('TERIMA KASIH'), findsOneWidget);
    expect(find.text('Z·A·D'), findsOneWidget);
    expect(find.bySemanticsLabel('In signs: TERIMA KASIH, spelled Z A D'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('with sign clips the avatar signs it: word highlighted, sign in the pill, replay, slower',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final image = (await tester.runAsync(() => createTestImage(width: 4, height: 4, cache: false)))!;
    final services = await _pumpScreen(tester, signer: fakeSigner(image, {'terima_kasih'}));
    await tester.pump();
    expect(find.text('BIM signer'), findsOneWidget, reason: 'no longer "coming soon"');
    expect(find.byType(SignPlayerView), findsOneWidget);

    await tester.tap(find.text('Terima kasih'));
    await tester.pump();
    await tester.pump();
    expect(services.signer.signing, isTrue);
    expect(find.text('TERIMA KASIH'), findsOneWidget, reason: 'the sign being signed, in the pill');
    expect(find.bySemanticsLabel('Sign it again'), findsOneWidget);

    await _playFor(tester, 300);
    expect(services.signer.signing, isFalse, reason: 'the screen clock played it to the end');
    expect(find.text('SAID'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Sign it again'));
    await tester.pump();
    await tester.pump();
    expect(services.signer.signing, isTrue);

    await tester.tap(find.bySemanticsLabel('Slower signing'));
    await tester.pump();
    expect(services.signer.slow, isTrue);
    semantics.dispose();
  });

  testWidgets('switching language changes the quick replies', (tester) async {
    await _pumpScreen(tester);
    await tester.tap(find.text('Malay → text'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('English → text'), findsOneWidget);
    expect(find.text('Please wait'), findsOneWidget);
  });
}
