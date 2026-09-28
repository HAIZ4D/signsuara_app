import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signsuara_app/app/app_services.dart';
import 'package:signsuara_app/cloud/account.dart';
import 'package:signsuara_app/screens/history_screen.dart';
import 'package:signsuara_app/screens/home_screen.dart';
import 'package:signsuara_app/theme/app_theme.dart';

import 'fake_auth_backend.dart';

Future<AppServices> _pumpHome(WidgetTester tester, {Account? account}) async {
  final services = AppServices(account: account);
  addTearDown(services.dispose);
  await tester.pumpWidget(MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(body: HomeScreen(services: services, onOpenTab: (_) {}, onOpenProfile: () {})),
  ));
  return services;
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) =>
    tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter_tts'), (call) async => call.method == 'isLanguageAvailable' ? true : 1);
  });

  testWidgets('a conversation shows on Home, opens as bubbles, and can be deleted', (tester) async {
    final services = await _pumpHome(tester);
    await _scrollTo(tester, find.text('No conversations yet'));
    expect(find.textContaining('Sign in to keep your conversations'), findsOneWidget);

    services.log.addSigned('TerimaKasih');
    services.log.addHeard('Sama-sama');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await _scrollTo(tester, find.textContaining('They: Sama-sama'));
    expect(find.text('2 messages'), findsOneWidget);
    expect(find.textContaining('kept only until the app closes'), findsOneWidget, reason: 'guest');

    await tester.tap(find.textContaining('They: Sama-sama'));
    await tester.pumpAndSettle();
    expect(find.byType(PastConversationScreen), findsOneWidget);
    expect(find.text('Terima kasih'), findsOneWidget, reason: 'my sign, in Malay (default)');
    expect(find.text('Thank you'), findsOneWidget, reason: 'with the other language below');
    expect(find.text('Sama-sama'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete conversation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(PastConversationScreen), findsNothing);
    await _scrollTo(tester, find.text('No conversations yet'));
  });

  testWidgets('signed in: See all lists the conversations saved to the account', (tester) async {
    final services = await _pumpHome(tester, account: Account(FakeAuthBackend(currentUser: testUser)));
    services.log.addSigned('Saya');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await _scrollTo(tester, find.text('See all'));
    expect(find.textContaining('kept only until the app closes'), findsNothing);

    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryScreen), findsOneWidget);
    expect(find.text('You: Saya'), findsOneWidget);
    expect(find.textContaining('Saved to your Google account'), findsOneWidget);
  });
}
