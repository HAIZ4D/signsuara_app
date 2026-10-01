import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signsuara_app/app/app_services.dart';
import 'package:signsuara_app/listen/listen_note.dart';
import 'package:signsuara_app/listen/listen_session.dart';
import 'package:signsuara_app/screens/hearing_screen.dart';
import 'package:signsuara_app/signer/sign_clips.dart';
import 'package:signsuara_app/signer/sign_player_view.dart';
import 'package:signsuara_app/signer/signer.dart';
import 'package:signsuara_app/theme/app_theme.dart';

import 'fake_clips.dart';
import 'fake_transcriber.dart';

late FakeTranscriber _mic;

Future<AppServices> _pumpScreen(WidgetTester tester, {Signer? signer}) async {
  tester.view.physicalSize = const Size(1080, 2400); // a phone: 360 x 800
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  _mic = FakeTranscriber();
  // Without test clips: a signer with none, whatever clips the app itself ships.
  final services =
      AppServices(signer: signer ?? Signer(library: Future.value(const SignClipLibrary({}))), transcriber: _mic);
  addTearDown(services.dispose);
  await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: Scaffold(body: HearingScreen(services: services))));
  return services;
}

/// The words highlighted on the stage right now (the word being signed), or '' when none is.
String _highlighted(WidgetTester tester) {
  for (final text in tester.widgetList<RichText>(find.byType(RichText))) {
    String? found;
    text.text.visitChildren((span) {
      if (span is TextSpan && span.style?.backgroundColor == AppColors.yellow) found = span.text;
      return found == null;
    });
    if (found != null) return found!;
  }
  return '';
}

/// The screen clock for [ms]: frames of 20 ms, like a real screen (one picture per frame at most).
Future<void> _playFor(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 20) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.tap(find.bySemanticsLabel(label));
  await tester.pump();
}

/// They say [words] and pause: Android stops, the words become a line, and listening starts again.
Future<void> _sentence(WidgetTester tester, String words) async {
  _mic.say(words);
  await tester.pump();
  _mic.finish();
  await tester.pump(const Duration(milliseconds: 300)); // the session listens again
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter_tts'), (call) async => call.method == 'isLanguageAvailable' ? true : 1);
  });

  testWidgets('ready: Start listening and a hint; no quick replies, nothing to stop', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpScreen(tester);
    expect(find.text('HEARING MODE'), findsOneWidget);
    expect(find.textContaining('Their words show up here'), findsOneWidget);
    expect(find.textContaining('Every sentence is kept as a note'), findsOneWidget);
    expect(find.bySemanticsLabel('Start listening'), findsOneWidget);
    expect(find.text('Terima kasih'), findsNothing, reason: 'the quick replies are gone');
    expect(find.byTooltip('Stop and save'), findsOneWidget);
    expect(tester.widget<Opacity>(find.ancestor(of: find.byIcon(Icons.stop_rounded), matching: find.byType(Opacity)).first).opacity,
        lessThan(1), reason: 'no session yet: Stop is shown disabled');
    semantics.dispose();
  });

  testWidgets('a session: words live, each sentence kept in the card and big on the stage', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpScreen(tester);
    await _tap(tester, 'Start listening');
    expect(_mic.listens, 1);
    expect(find.textContaining('Listening ·'), findsOneWidget, reason: 'with the time it has run');

    _mic.say('Hello there');
    await tester.pump();
    expect(find.text('Hello there'), findsNWidgets(2), reason: 'live on the stage and in the card');
    _mic.finish();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_mic.listens, 2, reason: 'it listens again by itself after the pause');
    await _sentence(tester, 'How are you?');
    expect(find.text('Hello there'), findsOneWidget, reason: 'the earlier sentence stays in the card');
    expect(find.text('How are you?'), findsNWidgets(2));
    expect(find.text('2 sentences'), findsNothing, reason: 'the count shows when it is not listening');

    final normal = DefaultTextStyle.of(tester.element(find.text('How are you?').first)).style.fontSize;
    await tester.tap(find.text('Aa'));
    await tester.pump(); // the size change starts
    await tester.pump(const Duration(milliseconds: 400));
    final large = DefaultTextStyle.of(tester.element(find.text('How are you?').first)).style.fontSize;
    expect(large, greaterThan(normal!));
    semantics.dispose();
  });

  testWidgets('Pause and Continue; Stop names it in a sheet and saves it', (tester) async {
    final semantics = tester.ensureSemantics();
    final services = await _pumpScreen(tester);
    await _tap(tester, 'Start listening');
    await _sentence(tester, 'Makan ubat dua kali sehari');

    await _tap(tester, 'Pause listening');
    expect(services.listenSession.state, ListenState.paused);
    expect(find.textContaining('Paused ·'), findsOneWidget);
    expect(find.text('1 sentence'), findsOneWidget);
    await _tap(tester, 'Continue listening');
    expect(services.listenSession.state, ListenState.listening);

    await tester.tap(find.byTooltip('Stop and save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500)); // the sheet slides up
    expect(find.text('Save this listening'), findsOneWidget);
    expect(find.text('1 sentence · under a minute'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Consultation'));
    await tester.pump();
    expect(find.textContaining('Consultation · '), findsOneWidget, reason: 'the title follows the kind');
    await tester.tap(find.text('Save note'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final saved = (await services.listenSession.store().watch().first).single;
    expect(saved.kind, NoteKind.consultation);
    expect(saved.title, startsWith('Consultation · '));
    expect(saved.lines.single.text, 'Makan ubat dua kali sehari');
    expect(find.textContaining('Saved "Consultation'), findsOneWidget);
    expect(find.bySemanticsLabel('Start listening'), findsOneWidget, reason: 'ready for the next session');
    semantics.dispose();
  });

  testWidgets('Stop with nothing heard keeps nothing', (tester) async {
    final semantics = tester.ensureSemantics();
    final services = await _pumpScreen(tester);
    await _tap(tester, 'Start listening');
    await tester.tap(find.byTooltip('Stop and save'));
    await tester.pump();
    expect(find.text('Nothing was heard, so nothing was saved.'), findsOneWidget);
    expect(await services.listenSession.store().watch().first, isEmpty);
    semantics.dispose();
  });

  testWidgets('a problem pauses the session and says why', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpScreen(tester);
    await _tap(tester, 'Start listening');
    _mic.fail('error_network');
    await tester.pump();
    expect(find.textContaining('needs internet'), findsOneWidget);
    expect(find.bySemanticsLabel('Continue listening'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('paused, the stage shows how the words will be signed; a name is fingerspelled', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpScreen(tester);
    await _tap(tester, 'Start listening');
    await _sentence(tester, 'Terima kasih Zad');
    await _tap(tester, 'Pause listening');
    expect(find.text('TERIMA KASIH'), findsOneWidget);
    expect(find.text('Z·A·D'), findsOneWidget);
    expect(find.bySemanticsLabel('In signs: TERIMA KASIH, spelled Z A D'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('with sign clips the avatar signs each sentence: word highlighted, replay, slower', (tester) async {
    final semantics = tester.ensureSemantics();
    final image = (await tester.runAsync(() => createTestImage(width: 4, height: 4, cache: false)))!;
    final services = await _pumpScreen(tester, signer: fakeSigner(image, {'terima_kasih'}));
    await tester.pump();
    expect(find.text('BIM signer'), findsOneWidget, reason: 'no longer "coming soon"');
    expect(find.byType(SignPlayerView), findsOneWidget);

    await _tap(tester, 'Start listening');
    await _sentence(tester, 'Terima kasih');
    await tester.pump();
    expect(services.signer.signing, isTrue, reason: 'signed while the next sentence is listened for');
    expect(_highlighted(tester), 'Terima kasih', reason: 'the words being signed are highlighted');
    expect(find.bySemanticsLabel('Sign it again'), findsOneWidget);

    await _playFor(tester, 300);
    expect(services.signer.signing, isFalse, reason: 'the screen clock played it to the end');
    expect(_highlighted(tester), isEmpty, reason: 'nothing highlighted once it is signed');

    await _tap(tester, 'Sign it again');
    await tester.pump();
    expect(services.signer.signing, isTrue);

    await _tap(tester, 'Slower signing');
    expect(services.signer.slow, isTrue);
    semantics.dispose();
  });

  testWidgets('words without a sign clip yet are grey, and there is nothing to sign again', (tester) async {
    final semantics = tester.ensureSemantics();
    final image = (await tester.runAsync(() => createTestImage(width: 4, height: 4, cache: false)))!;
    final services = await _pumpScreen(tester, signer: fakeSigner(image, {'rest'}));
    await tester.pump();
    expect(find.byType(SignPlayerView), findsOneWidget, reason: 'the avatar stands ready');

    await _tap(tester, 'Start listening');
    await _sentence(tester, 'Terima kasih'); // no clip for it yet
    expect(services.signer.signing, isFalse);
    expect(services.signer.isSigned(0), isFalse);
    expect(find.text('Grey words have no sign clip yet.'), findsOneWidget);
    final replay = tester.getSemantics(find.bySemanticsLabel('Sign it again'));
    expect(replay.getSemanticsData().flagsCollection.isEnabled, Tristate.isFalse, reason: 'shown as disabled');
    semantics.dispose();
  });

  testWidgets('the language switches, but not in the middle of a session', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpScreen(tester);
    await tester.tap(find.text('Malay → text'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('English → text'), findsOneWidget);

    await _tap(tester, 'Start listening');
    await tester.tap(find.text('English → text'));
    await tester.pump();
    expect(find.text('English → text'), findsOneWidget);
    expect(find.text('The language can be changed after you stop listening.'), findsOneWidget);
    semantics.dispose();
  });
}
