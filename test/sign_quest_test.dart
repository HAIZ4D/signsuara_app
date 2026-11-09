import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signsuara_app/app/app_services.dart';
import 'package:signsuara_app/glove/glove_session.dart';
import 'package:signsuara_app/learn/learn_progress.dart';
import 'package:signsuara_app/learn/learn_screen.dart';
import 'package:signsuara_app/learn/results_screen.dart';
import 'package:signsuara_app/learn/sign_quest_screen.dart';
import 'package:signsuara_app/learn/sign_targets.dart';
import 'package:signsuara_app/signer/sign_clips.dart';
import 'package:signsuara_app/signer/sign_player.dart';
import 'package:signsuara_app/theme/app_theme.dart';
import 'package:signsuara_app/ui/widgets/gradient_button.dart';

import 'fake_clips.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400); // 360 x 800
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

ClipOpener _clips(ui.Image image, Set<String> ids) => (id) async => ids.contains(id) ? FakeClip(image, 3) : null;

/// Services with a "connected" glove and the given clips.
Future<(AppServices, ui.Image)> _services(WidgetTester tester, Set<String> ids) async {
  final image = (await tester.runAsync(() => createTestImage(width: 4, height: 4, cache: false)))!;
  final services = AppServices(signer: fakeSigner(image, ids));
  addTearDown(services.dispose);
  services.session.setStatus('Streaming', link: GloveLink.connected);
  return (services, image);
}

/// One glove row as the glove sends it: "seq,thumb,index,middle,ring,pinky,yaw,pitch,roll,ax,ay,az".
void _row(AppServices services, int seq, List<double> fingers, {bool deadSensor = false}) => services.session
    .addPacket('$seq,${fingers.join(',')},${deadSensor ? '0,0,0,0,0,0' : '10,20,30,0.1,0.2,0.3'}'.codeUnits);

VoidCallback? _button(WidgetTester tester) => tester.widget<GradientButton>(find.byType(GradientButton)).onTap;

Future<void> _countdown(WidgetTester tester) async {
  await tester.tap(find.byType(GradientButton)); // I'm ready / Try again
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 3100));
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter_tts'), (call) async => call.method == 'isLanguageAvailable' ? true : 1);
  });

  test('a model label finds its clip; Sign Quest asks the signs (not Rest) the avatar can show', () {
    expect(signClipFor('A'), 'letter_a');
    expect(signClipFor('TerimaKasih'), 'terima_kasih');
    expect(signClipFor('MakanTengahari'), 'makan_tengahari');
    expect(signClipFor('Saya'), 'saya');
    final library = SignClipLibrary({'letter_a', 'saya', 'terima_kasih', 'makan_tengahari', 'rest', 'ya'});
    expect(signQuestSigns(library), unorderedEquals(['A', 'Saya', 'TerimaKasih', 'MakanTengahari']));
    expect(signQuestRound(const SignClipLibrary({'rest', 'ya'})), isNull);
  });

  test('fingers in place within the tolerance; stars counted after the glove can first answer', () {
    expect(fingerMatches([900, 600, 700, 800, 500], [900 + kFingerTolerance, 600, 700 - kFingerTolerance - 1, 800, 400]),
        [true, true, false, true, false]);
    expect(SignQuestScreen.warmUp, const Duration(milliseconds: 1800));
    expect(SignQuestScreen.starsFor(Duration.zero), 3);
    expect(SignQuestScreen.starsFor(const Duration(milliseconds: 2500)), 2);
    expect(SignQuestScreen.starsFor(const Duration(seconds: 5)), 1);
  });

  testWidgets('while a game listens, signs go only to it (no speech, no chat); custom gestures off and back on',
      (tester) async {
    final (services, _) = await _services(tester, {});
    final heard = <String>[];
    services.gestureOverride = heard.add;
    services.session.onGesture!('Saya'); // what the glove's recogniser calls
    expect(heard, ['Saya']);
    expect(services.log.messages, isEmpty);

    services.gestureOverride = null;
    services.session.onGesture!('Saya');
    expect(services.log.messages, hasLength(1), reason: 'Chat as before');

    expect(services.customGesturesOn, isTrue);
    services.customGesturesOn = false;
    expect(services.session.customMatch, isNull);
    services.customGesturesOn = true;
    expect(services.session.customMatch, isNotNull);
  });

  testWidgets('Sign Quest: other signs on the way are shown, the right one wins stars, 3 tries, then Results',
      (tester) async {
    _phone(tester);
    final (services, image) = await _services(tester, {'saya', 'nama', 'rest'});
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: SignQuestScreen(services: services, signs: const ['Saya', 'Nama'], openClip: _clips(image, {'saya', 'nama'})),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('SAYA'), findsOneWidget);
    expect(find.text('I / Me'), findsOneWidget);
    expect(find.text("I'm ready"), findsOneWidget);
    expect(services.gestureOverride, isNotNull);
    expect(services.customGesturesOn, isFalse);
    expect(services.session.recognitionPaused, isTrue, reason: 'not before "Go"');

    services.session.onGesture!('Saya');
    await tester.pump();
    expect(find.textContaining('Correct'), findsNothing, reason: 'a sign before "Go" does not count');

    await _countdown(tester);
    expect(find.text('Sign it now!'), findsOneWidget);
    expect(services.session.recognitionPaused, isFalse);

    services.session.onGesture!('Nama');
    await tester.pump();
    expect(find.text('The glove sees Nama. Keep going!'), findsOneWidget);

    services.session.onGesture!('Saya');
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('Correct! +15 XP'), findsOneWidget, reason: 'as fast as the glove can answer: 3 stars');
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
    expect(services.log.messages, isEmpty, reason: 'nothing went to Chat');

    await tester.tap(find.text('Next sign'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('NAMA'), findsOneWidget);
    for (final message in ["Time's up. Try 2 of 3 next.", "Time's up. Try 3 of 3 next.", 'Out of tries. On to the next sign.']) {
      await _countdown(tester);
      await tester.pump(const Duration(seconds: 8));
      expect(find.text(message), findsOneWidget);
    }
    expect(find.text('See results'), findsOneWidget);

    await tester.tap(find.text('See results'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(ResultsScreen), findsOneWidget);
    expect(find.text(' / 6'), findsOneWidget);
    expect(find.text('stars'), findsOneWidget);
    expect(services.learn.xp, 15);
    expect(services.learn.has(LearnBadge.firstSign), isTrue);
    expect(services.gestureOverride, isNull, reason: 'the game closed: Chat hears signs again');
    expect(services.customGesturesOn, isTrue);
    expect(services.session.recognitionPaused, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the finger meter counts fingers in place; a dead motion sensor stops the game', (tester) async {
    _phone(tester);
    final (services, image) = await _services(tester, {'letter_a'});
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: SignQuestScreen(services: services, signs: const ['A'], openClip: _clips(image, {'letter_a'})),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('HURUF A'), findsOneWidget);
    expect(find.text('Waiting for the glove…'), findsOneWidget);

    _row(services, 1, kSignFingerTargets['A']!);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('5 of 5 in place'), findsOneWidget);
    _row(services, 2, [864, 926, 786, 730, 764]); // a resting hand: only the thumb is like A's
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('1 of 5 in place'), findsOneWidget);

    _row(services, 3, [864, 926, 786, 730, 764], deadSensor: true);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Motion sensor disconnected. Check the glove.'), findsOneWidget);
    expect(_button(tester), isNull, reason: "can't start while the glove can't recognise");
  });

  testWidgets('Learn hub: Sign Quest needs the glove; connected, it opens a round', (tester) async {
    _phone(tester);
    final (services, image) = await _services(tester, {'saya', 'nama', 'letter_a', 'rest'});
    services.session.setStatus('Not connected', link: GloveLink.disconnected);
    await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(), home: LearnScreen(services: services, openClip: _clips(image, {'saya', 'nama', 'letter_a'}))));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.scrollUntilVisible(find.text('Sign Quest'), 200, scrollable: find.byType(Scrollable).first);
    await tester.pump(const Duration(milliseconds: 600)); // the header keeps drifting: no pumpAndSettle
    expect(find.text('Glove is off'), findsOneWidget);
    await tester.tap(find.text('Sign Quest'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(SignQuestScreen), findsNothing);

    services.session.setStatus('Streaming', link: GloveLink.connected);
    await tester.pump();
    expect(find.text('Glove is off'), findsNothing);
    expect(find.text('Use the glove'), findsOneWidget);
    await tester.tap(find.text('Sign Quest'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(SignQuestScreen), findsOneWidget);
    expect(find.textContaining('Sign 1 of 3'), findsOneWidget, reason: 'the 3 model signs with a clip');
    await tester.pump(const Duration(milliseconds: 100)); // flutter_animate starts each effect with a 0 s timer
  });

  testWidgets('the countdown is felt: a tick for 3, 2 and 1, a stronger buzz at Go', (tester) async {
    _phone(tester);
    final (services, image) = await _services(tester, {'saya'});
    final buzzes = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') buzzes.add(call.arguments);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: SignQuestScreen(services: services, signs: const ['Saya'], openClip: _clips(image, {'saya'})),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text("I'm ready"));
    for (var t = 0; t < 32; t++) {
      await tester.pump(const Duration(milliseconds: 100)); // like the screen's frames
    }
    expect(buzzes, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.mediumImpact',
    ]);
  });

  testWidgets('a try the glove cannot follow (disconnected) does not count', (tester) async {
    _phone(tester);
    final (services, image) = await _services(tester, {'saya'});
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: SignQuestScreen(services: services, signs: const ['Saya'], openClip: _clips(image, {'saya'})),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await _countdown(tester);
    expect(find.text('Sign it now!'), findsOneWidget);

    services.session.setStatus('Disconnected', link: GloveLink.disconnected);
    await tester.pump();
    expect(find.text('The glove is not connected.'), findsOneWidget);
    expect(find.textContaining('try 1 of 3'), findsOneWidget, reason: 'the try was not used up');
    expect(_button(tester), isNull);
    await tester.pump(const Duration(seconds: 9));
    expect(find.textContaining("Time's up"), findsNothing, reason: 'the clock stopped');
  });
}
