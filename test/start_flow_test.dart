import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signsuara_app/app_storage.dart';
import 'package:signsuara_app/main.dart';
import 'package:signsuara_app/screens/splash_screen.dart';

Future<void> _startApp(WidgetTester tester) async {
  await tester.pumpWidget(const SignSuaraApp());
  await tester.pump(); // storage read
  expect(find.text('SignSuara', findRichText: true), findsOneWidget, reason: 'splash first');
  expect(find.text('Your voice, in every gesture'), findsOneWidget);
  await tester.pump(SplashScreen.duration);
  // Wait until the splash has fully faded out (don't guess frame timings).
  for (var i = 0; i < 30 && find.byType(SplashScreen).evaluate().isNotEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  testWidgets('first launch: splash, 3 welcome pages, then Home; not shown again', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _startApp(tester);

    expect(find.text('Speak with your hands'), findsOneWidget);
    await _tap(tester, 'Continue');
    expect(find.text('A real two-way talk'), findsOneWidget);
    await _tap(tester, 'Continue');
    expect(find.text('Built for your world'), findsOneWidget);
    expect(find.textContaining('coming soon'), findsOneWidget, reason: 'no false promises');
    await _tap(tester, 'Get started');

    expect(find.text('Sign it, and be heard'), findsOneWidget, reason: 'Home');
    expect((await AppStorage.open()).loadOnboardingSeen(), isTrue);
  });

  testWidgets('returning user: splash, then straight to Home', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_seen': true});
    await _startApp(tester);
    expect(find.text('Speak with your hands'), findsNothing);
    expect(find.text('Sign it, and be heard'), findsOneWidget);
  });

  testWidgets('Skip goes straight to Home and is remembered', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _startApp(tester);
    await _tap(tester, 'Skip');
    expect(find.text('Sign it, and be heard'), findsOneWidget);
    expect((await AppStorage.open()).loadOnboardingSeen(), isTrue);
  });
}
