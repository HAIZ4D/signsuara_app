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

  testWidgets('home page starts disconnected, Malay selected, nothing signed or heard yet',
      (tester) async {
    await tester.pumpWidget(const SignSuaraApp());
    expect(find.text('Not connected'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
    expect(find.text('BM'), findsOneWidget);
    expect(find.text('EN'), findsOneWidget);
    expect(find.text('Sign something…'), findsOneWidget);
    expect(find.text('They said'), findsOneWidget);
    expect(find.text('Tap to talk'), findsOneWidget);
    expect(find.byTooltip('My gestures'), findsOneWidget);
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
