import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signsuara_app/app/app_services.dart';
import 'package:signsuara_app/cloud/account.dart';
import 'package:signsuara_app/listen/listen_note.dart';
import 'package:signsuara_app/listen/note_summary.dart';
import 'package:signsuara_app/screens/notes_screen.dart';
import 'package:signsuara_app/signer/sign_clips.dart';
import 'package:signsuara_app/signer/signer.dart';
import 'package:signsuara_app/speech/sign_words.dart';
import 'package:signsuara_app/theme/app_theme.dart';

import 'fake_auth_backend.dart';
import 'fake_transcriber.dart';

var _openedListen = 0;

Future<AppServices> _pump(WidgetTester tester, {List<ListenNote> notes = const [], FakeSummarizer? gemini}) async {
  tester.view.physicalSize = const Size(1080, 2400); // a phone: 360 x 800
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final services = AppServices(
    account: Account(FakeAuthBackend(summarizer: gemini)), // a guest; Gemini is a fake
    signer: Signer(library: Future.value(const SignClipLibrary({}))),
    transcriber: FakeTranscriber(),
  );
  addTearDown(services.dispose);
  await services.start(); // the phone's storage (it remembers the Gemini notice)
  for (final note in notes) {
    await services.notes.save(note);
  }
  _openedListen = 0;
  await tester.pumpWidget(MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(body: NotesScreen(services: services, onOpenListen: () => _openedListen++)),
  ));
  await tester.pump();
  return services;
}

ListenNote _note(String id, NoteKind kind, String title, DateTime start, List<String> lines, {int minutes = 12}) =>
    ListenNote(
      id: id,
      kind: kind,
      title: title,
      language: SpeechLanguage.malay,
      startedAt: start,
      endedAt: start.add(Duration(minutes: minutes)),
      lines: [for (final (i, text) in lines.indexed) NoteLine(text, start.add(Duration(minutes: i)))],
    );

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day, 9, 30);
  final visit = _note('n2', NoteKind.consultation, 'Doctor visit', today,
      ['Makan ubat ini dua kali sehari', 'Datang semula minggu depan']);
  final meeting = _note('n1', NoteKind.meeting, 'Club meeting', today.subtract(const Duration(days: 3)), ['Agenda one'],
      minutes: 45);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter_tts'), (call) async => call.method == 'isLanguageAvailable' ? true : 1);
  });

  testWidgets('no notes yet: it says where they come from, and Go to Listen opens Listen', (tester) async {
    await _pump(tester);
    expect(find.text('What you listened to'), findsOneWidget);
    expect(find.text('No notes yet'), findsOneWidget);
    expect(find.text('0 min'), findsOneWidget, reason: 'real numbers only');
    expect(find.textContaining('As a guest, notes are kept only until the app closes'), findsOneWidget);
    await tester.tap(find.text('Go to Listen'));
    expect(_openedListen, 1);
  });

  testWidgets('notes grouped by day: kind, time, length and first words; one opens with every sentence',
      (tester) async {
    await _pump(tester, notes: [meeting, visit]);
    expect(find.text('Today'), findsOneWidget, reason: 'grouped by day, newest first');
    expect(find.text('Doctor visit'), findsOneWidget);
    expect(find.text('Club meeting'), findsOneWidget);
    expect(find.text('9:30 AM · 12 min · 2 sentences'), findsOneWidget);
    expect(find.text('Makan ubat ini dua kali sehari'), findsOneWidget, reason: 'the first words as a preview');
    expect(find.text('2'), findsOneWidget, reason: 'the number of notes');
    expect(find.text('57 min'), findsOneWidget, reason: 'the time listened in all');

    await tester.tap(find.text('Doctor visit'));
    await tester.pumpAndSettle();
    expect(find.text('Consultation'), findsOneWidget, reason: 'the kind, at the top');
    expect(find.text('WHAT WAS SAID'), findsOneWidget);
    expect(find.text('Makan ubat ini dua kali sehari'), findsOneWidget);
    expect(find.text('Datang semula minggu depan'), findsOneWidget);
    expect(find.text('9:31 AM'), findsOneWidget, reason: 'each sentence with its time');
    expect(find.textContaining('12 min · 2 sentences · Malay'), findsOneWidget);
  });

  testWidgets('a note can be copied, edited (kind and title) and deleted', (tester) async {
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform,
        (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    final services = await _pump(tester, notes: [visit]);
    await tester.tap(find.text('Doctor visit'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Copy the note'));
    await tester.pump();
    expect(copied, contains('Doctor visit'));
    expect(copied, contains('9:30 AM  Makan ubat ini dua kali sehari'));
    expect(find.text('The note was copied.'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit note'));
    await tester.pumpAndSettle();
    expect(find.text('Edit note'), findsWidgets);
    await tester.tap(find.text('Class'));
    await tester.enterText(find.byType(TextField), 'Check-up');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(services.notes.all.single.kind, NoteKind.lesson);
    expect(services.notes.all.single.title, 'Check-up');
    expect(find.text('Check-up'), findsOneWidget, reason: 'the page shows the change at once');

    await tester.tap(find.byTooltip('Delete note'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this note?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600)); // back to the list (its hero keeps moving)
    expect(services.notes.all, isEmpty);
    expect(find.text('No notes yet'), findsOneWidget, reason: 'back on the list');
  });

  testWidgets("Summarise: the notice once, then Gemini's notes in parts, kept in the note", (tester) async {
    final gemini = FakeSummarizer();
    final services = await _pump(tester, notes: [visit], gemini: gemini);
    await tester.tap(find.text('Doctor visit'));
    await tester.pumpAndSettle();
    expect(find.text('Clear notes by Gemini'), findsOneWidget);

    await tester.tap(find.text('Summarise with Gemini'));
    await tester.pumpAndSettle();
    expect(find.text('Make notes with Gemini?'), findsOneWidget, reason: 'it says what is sent to Google first');
    expect(find.textContaining('not medical advice'), findsOneWidget);
    await tester.tap(find.text('Make notes'));
    await tester.pumpAndSettle();

    expect(gemini.asked.single.id, 'n2');
    expect(find.text('SUMMARY'), findsOneWidget);
    expect(find.text('The doctor explained how to take the new medicine.'), findsOneWidget);
    expect(find.text('Take the medicine twice a day after meals.'), findsOneWidget);
    expect(find.text('Next visit: 8 October'), findsOneWidget, reason: 'an important detail');
    expect(find.text('Antibiotik  Ubat yang membunuh kuman.', findRichText: true), findsOneWidget);
    await tester.scrollUntilVisible(find.text('WHAT WAS SAID'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('WHAT WAS SAID'), findsOneWidget, reason: 'the transcript stays');
    expect(services.notes.all.single.summary!.overview, exampleSummary.overview, reason: 'kept in the note');

    await tester.ensureVisible(find.text('Summarise again'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Summarise again'));
    await tester.pumpAndSettle();
    expect(find.text('Make notes with Gemini?'), findsNothing, reason: 'the notice is shown only once');
    expect(gemini.asked, hasLength(2));
  });

  testWidgets('when Gemini fails, the reason is shown and the note stays as it was', (tester) async {
    final gemini = FakeSummarizer(failure: const SummaryFailure('The summary needs the internet.'));
    final services = await _pump(tester, notes: [visit], gemini: gemini);
    await services.markSummaryNoticeSeen();
    await tester.tap(find.text('Doctor visit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Summarise with Gemini'));
    await tester.pumpAndSettle();
    expect(find.text('The summary needs the internet.'), findsOneWidget);
    expect(find.text('Summarise with Gemini'), findsOneWidget, reason: 'it can be tried again');
    expect(services.notes.all.single.summary, isNull);
  });
}
