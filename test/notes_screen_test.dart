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
import 'package:signsuara_app/ui/widgets/speech_rhythm.dart';

import 'fake_auth_backend.dart';
import 'fake_transcriber.dart';

var _openedListen = 0;

Future<AppServices> _pump(WidgetTester tester, {List<ListenNote> notes = const [], FakeSummarizer? gemini}) async {
  tester.view.physicalSize = const Size(1080, 2400); // a phone: 360 x 800
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  // "Reduce motion" on, like the phone setting: the drifting header and turning borders stand
  // still, so a test can wait for the screen to settle.
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
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

/// Scrolls [finder] to the middle of the screen (clear of the slim top bar and the floating switch),
/// then taps it.
Future<void> _tapInMiddle(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

/// Catches what the app copies.
String? Function() _clipboard() {
  String? copied;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform,
      (call) async {
    if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
    return null;
  });
  addTearDown(() =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  return () => copied;
}

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

  testWidgets('no notes yet: where they come from in three steps, and Go to Listen opens Listen', (tester) async {
    await _pump(tester);
    expect(find.text('What you listened to'), findsOneWidget);
    expect(find.text('No notes yet'), findsOneWidget);
    expect(find.text('0 min'), findsOneWidget, reason: 'real numbers only');
    expect(find.text('Open Listen and tap Start.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing, reason: 'nothing to search yet');
    await _tapInMiddle(tester, find.text('Go to Listen'));
    expect(_openedListen, 1);
    await tester.scrollUntilVisible(find.textContaining('As a guest, notes are kept only until the app closes'), 200,
        scrollable: find.byType(Scrollable).first);
  });

  testWidgets('notes grouped by day with kind, time, length and first words; a note opens on Gemini notes, '
      'and shows every sentence on the other side', (tester) async {
    await _pump(tester, notes: [meeting, visit]);
    expect(find.text('Today'), findsOneWidget, reason: 'grouped by day, newest first');
    expect(find.text('Doctor visit'), findsOneWidget);
    expect(find.text('Club meeting'), findsOneWidget);
    expect(find.text('Consultation · 9:30 AM'), findsOneWidget);
    expect(find.text('12 min'), findsOneWidget);
    expect(find.text('2 sentences'), findsNothing, reason: 'one quiet line: how long, and Gemini notes');
    expect(find.text('Makan ubat ini dua kali sehari'), findsOneWidget, reason: 'the first words as a preview');
    expect(find.text('2'), findsOneWidget, reason: 'the number of notes');
    expect(find.text('57 min'), findsOneWidget, reason: 'the time listened in all');

    await tester.tap(find.text('Doctor visit'));
    await tester.pumpAndSettle();
    expect(find.text('Consultation'), findsOneWidget, reason: 'the kind, at the top');
    expect(find.text('12 min'), findsOneWidget);
    expect(find.text('Malay'), findsOneWidget);
    expect(find.text('Clear notes by Gemini'), findsOneWidget, reason: 'it opens on the Gemini side');

    await tester.tap(find.text('What was said'));
    await tester.pumpAndSettle();
    expect(find.text('WHAT WAS SAID'), findsOneWidget);
    expect(find.text('Makan ubat ini dua kali sehari'), findsOneWidget);
    expect(find.text('Datang semula minggu depan'), findsOneWidget);
    expect(find.text('9:31 AM'), findsOneWidget, reason: 'each sentence with its time');
  });

  testWidgets('a note can be copied, edited (kind and title) and deleted', (tester) async {
    final copied = _clipboard();
    final services = await _pump(tester, notes: [visit]);
    await tester.tap(find.text('Doctor visit'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Copy the note'));
    await tester.pump();
    expect(copied(), contains('Doctor visit'));
    expect(copied(), contains('9:30 AM  Makan ubat ini dua kali sehari'));
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
    await tester.pumpAndSettle();
    expect(services.notes.all, isEmpty);
    expect(find.text('No notes yet'), findsOneWidget, reason: 'back on the list');
  });

  testWidgets("Summarise: the notice once, then Gemini's notes in parts, kept in the note; again asks first",
      (tester) async {
    final gemini = FakeSummarizer();
    final services = await _pump(tester, notes: [visit], gemini: gemini);
    await tester.tap(find.text('Doctor visit'));
    await tester.pumpAndSettle();
    expect(find.text('Clear notes by Gemini'), findsOneWidget);

    await _tapInMiddle(tester, find.text('Summarise with Gemini'));
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
    expect(find.text('Antibiotik'), findsOneWidget, reason: 'a hard word…');
    expect(find.text('Ubat yang membunuh kuman.'), findsOneWidget, reason: '…explained');
    expect(services.notes.all.single.summary!.overview, exampleSummary.overview, reason: 'kept in the note');

    await tester.tap(find.text('What was said'));
    await tester.pumpAndSettle();
    expect(find.text('WHAT WAS SAID'), findsOneWidget, reason: 'the transcript stays');
    await tester.tap(find.text('Gemini notes'));
    await tester.pumpAndSettle();

    await _tapInMiddle(tester, find.text('Summarise again'));
    await tester.pumpAndSettle();
    expect(find.text('Make notes with Gemini?'), findsNothing, reason: 'the notice is shown only once');
    expect(find.text('Make new notes?'), findsOneWidget, reason: 'replacing the notes costs a request: asked first');
    await tester.tap(find.text('Make new notes'));
    await tester.pumpAndSettle();
    expect(gemini.asked, hasLength(2));
  });

  testWidgets('when Gemini fails, the reason is shown and the note stays as it was', (tester) async {
    final gemini = FakeSummarizer(failure: const SummaryFailure('The summary needs the internet.'));
    final services = await _pump(tester, notes: [visit], gemini: gemini);
    await services.markSummaryNoticeSeen();
    await tester.tap(find.text('Doctor visit'));
    await tester.pumpAndSettle();
    await _tapInMiddle(tester, find.text('Summarise with Gemini'));
    await tester.pumpAndSettle();
    expect(find.text('The summary needs the internet.'), findsOneWidget);
    expect(find.text('Summarise with Gemini'), findsOneWidget, reason: 'it can be tried again');
    expect(services.notes.all.single.summary, isNull);
  });

  testWidgets('search finds words in the sentences; a kind chip filters; no match says so and shows all again',
      (tester) async {
    await _pump(tester, notes: [meeting, visit]);
    await tester.enterText(find.byType(TextField), 'minggu');
    await tester.pump();
    expect(find.text('Doctor visit'), findsOneWidget);
    expect(find.text('Club meeting'), findsNothing);
    expect(find.text('Datang semula minggu depan'), findsOneWidget, reason: 'the sentence it was found in');

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.text('No notes with "zzz"'), findsOneWidget);
    await tester.tap(find.text('Show all notes'));
    await tester.pump();
    expect(find.text('Doctor visit'), findsOneWidget);
    expect(find.text('Club meeting'), findsOneWidget);

    await tester.tap(find.text('Meeting  1'));
    await tester.pump();
    expect(find.text('Club meeting'), findsOneWidget);
    expect(find.text('Doctor visit'), findsNothing);
    await tester.tap(find.text('All  2'));
    await tester.pump();
    expect(find.text('Doctor visit'), findsOneWidget);
  });

  testWidgets("Gemini's notes: a tick on a to-do is kept in the note; a tap on a detail copies it", (tester) async {
    final copied = _clipboard();
    final services = await _pump(tester, notes: [visit.copyWith(summary: exampleSummary)]);
    expect(find.text('Gemini notes'), findsOneWidget, reason: 'the list shows which notes have them');
    await tester.tap(find.text('Doctor visit'));
    await tester.pumpAndSettle();
    expect(find.text('0 of 1 done'), findsOneWidget);

    await _tapInMiddle(tester, find.text('Take the medicine twice a day after meals.'));
    await tester.pumpAndSettle();
    expect(services.notes.all.single.summary!.done, {0});
    expect(find.text('1 of 1 done'), findsOneWidget);

    await _tapInMiddle(tester, find.text('Next visit: 8 October'));
    await tester.pump();
    expect(copied(), 'Next visit: 8 October');
    expect(find.text('Copied: Next visit: 8 October'), findsOneWidget);
  });

  test('the speech timeline counts the words heard in each slice of time', () {
    final levels = SpeechRhythm.levels(visit, 12); // 12 minutes: a slice a minute
    expect(levels[0], 1.0, reason: '6 words in the first minute: the busiest');
    expect(levels[1], closeTo(4 / 6, 1e-9), reason: '4 words in the second');
    expect(levels.skip(2), everyElement(0.0), reason: 'nothing after that');
  });
}
