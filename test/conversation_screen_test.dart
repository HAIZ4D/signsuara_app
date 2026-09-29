import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signsuara_app/app/app_services.dart';
import 'package:signsuara_app/history/conversation_log.dart';
import 'package:signsuara_app/screens/conversation_screen.dart';
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
  await tester.pumpWidget(MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(body: ConversationScreen(services: services)),
  ));
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
    // Stand-in for the phone's voice engine: every language is "installed".
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter_tts'), (call) async => call.method == 'isLanguageAvailable' ? true : 1);
  });

  testWidgets('empty conversation: hint, glove not connected, turn toggle', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpScreen(tester);
    expect(find.textContaining('Sign with your glove'), findsOneWidget);
    expect(find.text('Glove not connected'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
    expect(find.bySemanticsLabel('You sign'), findsOneWidget);
    expect(find.bySemanticsLabel('They speak'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('after they speak the dock shows the signer; tapping their bubble signs it again', (tester) async {
    final semantics = tester.ensureSemantics();
    final image = (await tester.runAsync(() => createTestImage(width: 4, height: 4, cache: false)))!;
    final services = await _pumpScreen(tester, signer: fakeSigner(image, {'ya'}));
    await tester.pump();
    expect(find.byType(SignPlayerView), findsNothing, reason: 'the finger sensors, until they speak');

    services.log.addHeard('Ya');
    await tester.pump();
    await tester.pump();
    expect(find.byType(SignPlayerView), findsOneWidget);
    expect(find.text('YA'), findsOneWidget, reason: 'the sign being signed');

    await _playFor(tester, 300);
    await tester.pump(const Duration(milliseconds: 600)); // the dock switches back
    expect(find.byType(SignPlayerView), findsNothing, reason: 'signed: the sensors come back');
    expect(find.text('Glove not connected'), findsOneWidget);

    await tester.tap(find.text('Ya')); // their bubble
    await tester.pump();
    await tester.pump();
    expect(services.signer.signing, isTrue);
    await _playFor(tester, 300);
    semantics.dispose();
  });

  testWidgets('signed and heard messages become bubbles; BM/EN switch changes the words', (tester) async {
    final services = await _pumpScreen(tester);
    services.log
      ..addSigned('Saya')
      ..addHeard('Please wait here');
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Saya'), findsOneWidget); // Malay first (default)
    expect(find.text('I / Me'), findsOneWidget); // meaning in the other language
    expect(find.text('SIGNED · SPOKEN ALOUD'), findsOneWidget);
    expect(find.text('Please wait here'), findsOneWidget);
    expect(find.text('HEARD'), findsOneWidget);

    await tester.tap(find.text('Malay'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('English'), findsOneWidget);
    expect(find.text('I / Me'), findsOneWidget);
    expect(find.text('Saya'), findsOneWidget); // now the smaller line

    await tester.tap(find.byTooltip('Clear conversation'));
    await tester.pump();
    expect(services.log.messages, isEmpty);
    expect(find.textContaining('Sign with your glove'), findsOneWidget);
  });

  test('a sign recognised from real glove data is spoken AND added to the conversation', () {
    final services = AppServices();
    addTearDown(services.dispose);
    final lines = File('test/fixtures/Saya.csv').readAsLinesSync().skip(1).where((l) => l.trim().isNotEmpty);
    services.session.startStream();
    var seq = 0;
    for (final line in lines) {
      services.session.addPacket(utf8.encode('${seq++},${line.trim()}'));
    }
    expect([for (final m in services.log.messages) (m.side, m.label)], [(Side.me, 'Saya')]);
  });
}
