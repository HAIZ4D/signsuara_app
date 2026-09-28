import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signsuara_app/cloud/account.dart';
import 'package:signsuara_app/main.dart';
import 'package:signsuara_app/screens/login_screen.dart';
import 'package:signsuara_app/screens/splash_screen.dart';
import 'package:signsuara_app/theme/app_theme.dart';
import 'package:signsuara_app/ui/widgets/brand.dart';
import 'package:signsuara_app/ui/widgets/notice.dart';

import 'fake_auth_backend.dart';

Future<void> _startApp(WidgetTester tester, [FakeAuthBackend? backend]) async {
  await tester.pumpWidget(SignSuaraApp(account: Account(backend ?? FakeAuthBackend())));
  expect(find.text('SignSuara', findRichText: true), findsOneWidget, reason: 'splash first');
  expect(find.text('Your voice, in every gesture'), findsOneWidget);
  // Frame by frame like the phone (one frame moves the splash on by 0.1 s at most),
  // until the splash has fully faded out.
  for (var i = 0; i < 50 && find.byType(SplashScreen).evaluate().isNotEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.tap(find.text(text));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

const _home = 'Sign it, and be heard';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('splash, 3 welcome pages, sign-in page, then Home as a guest', (tester) async {
    await _startApp(tester);

    expect(find.text('Speak with your hands'), findsOneWidget);
    await _tap(tester, 'Continue');
    expect(find.text('A real two-way talk'), findsOneWidget);
    await _tap(tester, 'Continue');
    expect(find.text('Built for your world'), findsOneWidget);
    expect(find.textContaining('coming soon'), findsOneWidget, reason: 'no false promises');
    await _tap(tester, 'Get started');

    expect(find.text('Make SignSuara yours'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('coming soon'), findsNothing, reason: 'everything listed is built');
    await _tap(tester, 'Continue as guest');

    expect(find.text(_home), findsOneWidget);
    expect(find.textContaining('Guest', findRichText: true), findsOneWidget);
  });

  testWidgets('Continue with Google: Home greets the account by name', (tester) async {
    await _startApp(tester);
    await _tap(tester, 'Skip');
    await _tap(tester, 'Continue with Google');
    expect(find.text(_home), findsOneWidget);
    expect(find.textContaining('Test User', findRichText: true), findsOneWidget);
  });

  testWidgets('already signed in: no sign-in page', (tester) async {
    await _startApp(tester, FakeAuthBackend(currentUser: testUser));
    await _tap(tester, 'Skip');
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.textContaining('Test User', findRichText: true), findsOneWidget);
  });

  testWidgets('closing the Google picker stays on the sign-in page, without an error', (tester) async {
    await _startApp(tester, FakeAuthBackend(next: null));
    await _tap(tester, 'Skip');
    await _tap(tester, 'Continue with Google');
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(Notice), findsNothing);
  });

  testWidgets('a sign-in problem is shown, and guest still works', (tester) async {
    await _startApp(tester, FakeAuthBackend(failure: const SignInFailure('No internet connection.')));
    await _tap(tester, 'Skip');
    await _tap(tester, 'Continue with Google');
    expect(find.text('No internet connection.'), findsOneWidget);
    await _tap(tester, 'Continue as guest');
    expect(find.text(_home), findsOneWidget);
  });

  testWidgets('the welcome pages come back every time the app opens', (tester) async {
    // A phone that ran an earlier version still has this old "seen" flag saved: it is ignored now.
    SharedPreferences.setMockInitialValues({'onboarding_seen': true});
    await _startApp(tester, FakeAuthBackend(currentUser: testUser));
    expect(find.text('Speak with your hands'), findsOneWidget);
  });

  testWidgets('a very slow first frame does not skip the logo animation', (tester) async {
    await tester.pumpWidget(SignSuaraApp(account: Account(FakeAuthBackend())));
    await tester.pump(const Duration(seconds: 5)); // like a debug build starting up
    expect(find.byType(SplashScreen), findsOneWidget, reason: 'the splash is still playing');
    expect(find.text('Speak with your hands'), findsNothing);
  });

  testWidgets('the splash fills the whole screen, flag strip at the bottom', (tester) async {
    await tester.pumpWidget(SignSuaraApp(account: Account(FakeAuthBackend())));
    await tester.pump(SplashScreen.duration ~/ 2);
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final background = find.descendant(
        of: find.byType(SplashScreen),
        matching: find.byWidgetPredicate(
            (w) => w is DecoratedBox && (w.decoration as BoxDecoration).gradient == AppGradients.deep));
    expect(tester.getSize(background), screen);
    expect(tester.getBottomLeft(find.byType(FlagStrip)).dy, greaterThan(screen.height * 0.85));
  });
}
