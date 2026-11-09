import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signsuara_app/app/app_services.dart';
import 'package:signsuara_app/learn/learn_screen.dart';
import 'package:signsuara_app/learn/note_lesson_screen.dart';
import 'package:signsuara_app/learn/note_signs.dart';
import 'package:signsuara_app/learn/quiz_screen.dart';
import 'package:signsuara_app/learn/sign_lesson_screen.dart';
import 'package:signsuara_app/learn/teka_isyarat.dart';
import 'package:signsuara_app/listen/listen_note.dart';
import 'package:signsuara_app/screens/note_screen.dart';
import 'package:signsuara_app/signer/sign_clips.dart';
import 'package:signsuara_app/signer/sign_player.dart';
import 'package:signsuara_app/signer/sign_translator.dart';
import 'package:signsuara_app/speech/sign_words.dart';
import 'package:signsuara_app/theme/app_theme.dart';

import 'fake_clips.dart';

final _clips = {
  'saya', 'nama', 'terima_kasih', 'apa_khabar', 'apa', 'ya', 'tidak', 'rest',
  for (var c = 'a'.codeUnitAt(0); c <= 'z'.codeUnitAt(0); c++) 'letter_${String.fromCharCode(c)}',
};

ListenNote _note(String id, List<String> lines, {SpeechLanguage language = SpeechLanguage.malay}) {
  final start = DateTime(2026, 11, 8, 9);
  return ListenNote(
    id: id,
    kind: NoteKind.lesson,
    title: 'Kelas BIM',
    language: language,
    startedAt: start,
    endedAt: start.add(const Duration(minutes: 5)),
    lines: [for (final (i, text) in lines.indexed) NoteLine(text, start.add(Duration(minutes: i)))],
  );
}

final _class = _note('n1', ['Saya nama Haizad. Terima kasih!', 'Apa khabar? Saya baik.']);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter_tts'), (call) async => call.method == 'isLanguageAvailable' ? true : 1);
  });

  test('the signs heard in a note: in the order first said, once each, only with a clip; names left out', () {
    final heard = signsInNote(_class, SignTranslator(), SignClipLibrary(_clips));
    expect([for (final s in heard) s.id], ['saya', 'nama', 'terima_kasih', 'apa_khabar'],
        reason: 'HAIZAD is spelled, BAIK has no clip');
    final saya = heard.first;
    expect(saya.times, 2);
    expect(saya.line.substring(saya.start, saya.end), 'Saya');
    final thanks = heard[2];
    expect(thanks.line.substring(thanks.start, thanks.end), 'Terima kasih', reason: 'a phrase is one sign');

    final english = _note('n2', ['Thank you, I am fine. No!'], language: SpeechLanguage.english);
    expect([for (final s in signsInNote(english, SignTranslator(), SignClipLibrary(_clips))) s.id],
        ['terima_kasih', 'saya', 'tidak']);
    expect(signsInNote(_note('n3', ['Haizad']), SignTranslator(), SignClipLibrary(_clips)), isEmpty);
  });

  test("the glove's own signs among them; a quiz on just these signs", () {
    expect(gloveSignsAmong(['saya', 'apa', 'terima_kasih']), ['Saya', 'TerimaKasih']);
    final round = tekaIsyaratRound(SignClipLibrary(_clips), only: ['saya', 'nama'], random: Random(1))!;
    expect({for (final q in round) q.clipId}, {'saya', 'nama'});
    expect(round.every((q) => {for (final o in q.options) o.text}.length == 4), isTrue, reason: 'wrong answers from every clip');
    expect(tekaIsyaratRound(SignClipLibrary(_clips), only: ['islam']), isNull, reason: 'no clip');
  });

  Future<AppServices> services(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final image = (await tester.runAsync(() => createTestImage(width: 4, height: 4, cache: false)))!;
    final services = AppServices(signer: fakeSigner(image, _clips));
    addTearDown(services.dispose);
    await services.notes.save(_class);
    await services.notes.save(_note('n0', ['Haizad']));
    return services;
  }

  ClipOpener clips(WidgetTester tester) => (id) async => null; // no pictures needed here

  testWidgets('the lesson: each sign with where it was heard, then a quiz on just these', (tester) async {
    final s = await services(tester);
    final heard = heardSigns(s, _class);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: SignLessonScreen(
        services: s,
        title: 'Signs from your note',
        subtitle: _class.title,
        ids: [for (final h in heard) h.id],
        heard: {for (final h in heard) h.id: h},
        openClip: clips(tester),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('SAYA'), findsOneWidget);
    expect(find.text('Heard 2×'), findsOneWidget);
    expect(find.textContaining('Saya nama Haizad', findRichText: true), findsOneWidget);
    expect(find.text('Sign 1 of 4 · Kelas BIM'), findsOneWidget);

    for (final gloss in ['NAMA', 'TERIMA KASIH', 'APA KHABAR']) {
      await tester.tap(find.text('Next sign'));
      await tester.pumpAndSettle();
      expect(find.text(gloss), findsOneWidget);
    }
    expect(find.text('Practise with the glove'), findsOneWidget, reason: 'SAYA, NAMA and TERIMA KASIH are glove signs');
    await tester.tap(find.text('Quiz me on these'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(QuizScreen), findsOneWidget);
    expect(find.text('Question 1 of 4'), findsOneWidget);
  });

  testWidgets('a note offers the lesson of its signs; Learn lists notes with how many signs', (tester) async {
    final s = await services(tester);
    await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: NoteScreen(services: s, noteId: 'n1')));
    await tester.pumpAndSettle();
    expect(find.text('Learn the signs you heard'), findsOneWidget);
    expect(find.text('4 signs in this note'), findsOneWidget);
    expect(find.text('TERIMA KASIH'), findsOneWidget);

    await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: NoteScreen(services: s, noteId: 'n0')));
    await tester.pumpAndSettle();
    expect(find.text('Learn the signs you heard'), findsNothing, reason: 'only a name: nothing to sign');

    await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: LearnScreen(services: s, openClip: clips(tester))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Signs in your notes'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('1 note with signs'), findsOneWidget);
    await tester.ensureVisible(find.text('Signs in your notes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Signs in your notes'));
    await tester.pumpAndSettle();
    expect(find.text('4 signs'), findsOneWidget);
    expect(find.text('No signs'), findsOneWidget);
    await tester.tap(find.text('Kelas BIM').first);
    await tester.pumpAndSettle();
    expect(find.byType(SignLessonScreen), findsOneWidget);
  });
}
