import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signsuara_app/custom/custom_gesture.dart';
import 'package:signsuara_app/custom/custom_gestures.dart';
import 'package:signsuara_app/custom/custom_gestures_page.dart';
import 'package:signsuara_app/custom/record_gesture_page.dart';
import 'package:signsuara_app/glove/glove_session.dart';
import 'package:signsuara_app/theme/app_theme.dart';

CustomGesture _gesture(String id, String malay, GestureCategory category) =>
    CustomGesture(id: id, malay: malay, moving: false, recordings: const [], category: category);

/// A phone-size screen with "reduce motion" on (the drifting header stands still).
void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

Future<CustomGestures> _pump(WidgetTester tester, List<CustomGesture> saved) async {
  _phone(tester);
  final gestures = CustomGestures();
  for (final g in saved) {
    await gestures.add(g);
  }
  await tester.pumpWidget(MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(body: CustomGesturesPage(gestures: gestures, session: GloveSession())),
  ));
  await tester.pump();
  return gestures;
}

/// The tick on a chosen option (category or Still/Moving), found by the option's spoken label.
Finder _ticked(String label) =>
    find.descendant(of: find.bySemanticsLabel(label), matching: find.byIcon(Icons.check_circle_rounded));

void main() {
  testWidgets('the categories count the signs; a tap shows only that category, a second tap all again',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, [
      _gesture('1', 'Solat', GestureCategory.religious),
      _gesture('2', 'Atom', GestureCategory.science),
      _gesture('3', 'Zad', GestureCategory.personal),
    ]);
    expect(find.text('All signs'), findsOneWidget);
    expect(find.text('3 saved'), findsOneWidget);
    expect(find.bySemanticsLabel('Technical, 0 signs'), findsOneWidget, reason: 'real counts, also zero');

    await tester.tap(find.bySemanticsLabel('Science, 1 sign'));
    await tester.pumpAndSettle();
    expect(find.text('Science signs'), findsOneWidget);
    expect(find.text('Atom'), findsOneWidget);
    expect(find.text('Solat'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Science, 1 sign'));
    await tester.pumpAndSettle();
    expect(find.text('All signs'), findsOneWidget, reason: 'a second tap shows all again');
    expect(find.text('Solat'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('an empty category offers to record a sign there, with that category already chosen',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, [_gesture('1', 'Solat', GestureCategory.religious)]);
    await tester.tap(find.bySemanticsLabel('Technical, 0 signs'));
    await tester.pumpAndSettle();
    expect(find.text('No technical signs yet'), findsOneWidget);
    await tester.ensureVisible(find.text('Record one'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record one'));
    await tester.pumpAndSettle();
    expect(find.text('Teach a new gesture'), findsOneWidget);
    expect(_ticked('Technical: Tools, computers, work'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('⋮ changes a category (it moves, and says so) and deletes after asking', (tester) async {
    final gestures = await _pump(tester, [_gesture('1', 'Zad', GestureCategory.personal)]);
    await tester.tap(find.byTooltip('More for Zad'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change category'));
    await tester.pumpAndSettle();
    expect(find.text('Category for "Zad"'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text('Religious')));
    await tester.pumpAndSettle();
    expect(gestures.all.single.category, GestureCategory.religious);
    expect(find.text('"Zad" is now in Religious.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5)); // the message goes away (it covers the bottom of the list)
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More for Zad'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete "Zad"?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(gestures.all, isEmpty);
    expect(find.text('"Zad" was deleted.'), findsOneWidget);
  });

  testWidgets('a new gesture is Personal unless another category is picked', (tester) async {
    final semantics = tester.ensureSemantics();
    _phone(tester);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: RecordGesturePage(gestures: CustomGestures(), session: GloveSession()),
    ));
    expect(_ticked('Personal: Names, family, daily life'), findsOneWidget);
    await tester.ensureVisible(find.bySemanticsLabel('Science: Science, health, medicine'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Science: Science, health, medicine'));
    await tester.pump();
    expect(_ticked('Science: Science, health, medicine'), findsOneWidget);
    expect(_ticked('Personal: Names, family, daily life'), findsNothing);
    semantics.dispose();
  });
}
