import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signsuara_app/custom/custom_gesture.dart';
import 'package:signsuara_app/custom/custom_gestures.dart';
import 'package:signsuara_app/custom/custom_gestures_page.dart';
import 'package:signsuara_app/custom/record_gesture_page.dart';
import 'package:signsuara_app/glove/glove_session.dart';
import 'package:signsuara_app/main.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('app opens on Home: greeting, glove card (not connected), start card, empty history',
      (tester) async {
    await tester.pumpWidget(const SignSuaraApp());
    expect(find.textContaining('Assalamualaikum', findRichText: true), findsOneWidget);
    expect(find.textContaining('Guest', findRichText: true), findsOneWidget);
    expect(find.text('SignSuara Glove'), findsOneWidget);
    expect(find.text('NOT CONNECTED'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
    expect(find.text('Sign it, and be heard'), findsOneWidget);

    // Further down the page: scroll like on the phone.
    await tester.scrollUntilVisible(find.text('No conversations yet'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('SubhanAllah'), findsOneWidget);
    expect(find.text('No conversations yet'), findsOneWidget);
  });

  testWidgets('the capsule tabs switch screens', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const SignSuaraApp());
    Future<void> openTab(String label) async {
      await tester.tap(find.bySemanticsLabel(label));
      await tester.pump(const Duration(milliseconds: 700));
    }

    await openTab('Learn');
    expect(find.text('Learn and sign the Arabic letters'), findsOneWidget);
    expect(find.text('Coming soon'), findsOneWidget);

    await openTab('Conversation');
    expect(find.text('Conversation'), findsWidgets);
    expect(find.bySemanticsLabel('You sign'), findsOneWidget);
    expect(find.bySemanticsLabel('They speak'), findsOneWidget);

    await openTab('Hearing');
    expect(find.text('HEARING MODE'), findsOneWidget);
    expect(find.bySemanticsLabel('Tap to speak'), findsOneWidget);

    await openTab('Gestures');
    expect(find.textContaining('No custom gestures yet'), findsOneWidget);

    await openTab('Home');
    expect(find.text('Sign it, and be heard'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('My gestures: empty message, then the list with a delete button', (tester) async {
    final gestures = CustomGestures();
    await tester.pumpWidget(MaterialApp(home: CustomGesturesPage(gestures: gestures, session: GloveSession())));
    expect(find.textContaining('No custom gestures yet'), findsOneWidget);
    expect(find.textContaining('Terima kasih'), findsOneWidget, reason: 'built-in signs listed');

    await tester.runAsync(() => gestures.add(const CustomGesture(
        id: '1', malay: 'Saya lapar', english: 'I am hungry', moving: false, recordings: [])));
    await tester.pump();
    expect(find.text('Saya lapar'), findsOneWidget);
    expect(find.text('I am hungry · Still'), findsOneWidget);
    expect(find.byTooltip('Delete'), findsOneWidget);
  });

  testWidgets('New gesture: recording needs a Malay phrase and a connected glove', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: RecordGesturePage(gestures: CustomGestures(), session: GloveSession())));
    expect(find.text('Connect the glove first (on the main screen).'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Saya lapar');
    await tester.pump();
    final start = tester.widget<ButtonStyleButton>(find.ancestor(
        of: find.text('Start recording'), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)));
    expect(start.onPressed, isNull, reason: 'glove is not connected');
  });
}
