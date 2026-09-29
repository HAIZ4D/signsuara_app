import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signsuara_app/app/app_services.dart';
import 'package:signsuara_app/app/licences.dart';
import 'package:signsuara_app/cloud/account.dart';
import 'package:signsuara_app/screens/profile_screen.dart';
import 'package:signsuara_app/speech/sign_words.dart';
import 'package:signsuara_app/theme/app_theme.dart';

import 'fake_auth_backend.dart';

Future<AppServices> _pumpProfile(WidgetTester tester, {Account? account, PhotoPicker? pickPhoto}) async {
  tester.view.physicalSize = const Size(1080, 2400); // a phone: 360 x 800
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final services = AppServices(account: account ?? Account(FakeAuthBackend()));
  addTearDown(services.dispose);
  await tester.pumpWidget(MaterialApp(
    theme: buildAppTheme(),
    home: pickPhoto == null
        ? ProfileScreen(services: services)
        : ProfileScreen(services: services, pickPhoto: pickPhoto),
  ));
  return services;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 150, scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(finder); // fully on screen, so a tap lands on it
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter_tts'), (call) async => call.method == 'isLanguageAvailable' ? true : 1);
  });

  testWidgets('guest: real numbers and settings; language switch; sign in from here', (tester) async {
    final semantics = tester.ensureSemantics();
    final services = await _pumpProfile(tester);
    expect(find.text('Guest · not signed in'), findsOneWidget);
    expect(find.bySemanticsLabel('0 Conversations'), findsOneWidget);
    expect(find.bySemanticsLabel('5 Built-in signs'), findsOneWidget, reason: 'A, B, Saya, Nama, Terima kasih');
    expect(find.text('Not connected'), findsOneWidget, reason: 'glove');
    expect(find.text('Connect'), findsOneWidget);

    await tester.tap(find.text('EN'));
    await _settle(tester);
    expect(services.speaker.language, SpeechLanguage.english);
    expect(find.textContaining('Spoken in English'), findsOneWidget);

    await _scrollTo(tester, find.text('Continue with Google'));
    await tester.tap(find.text('Continue with Google'));
    await _settle(tester);
    expect(services.account.name, 'Test User');
    await _scrollTo(tester, find.text('Sign out'));
    expect(find.text('Google account'), findsOneWidget);
    expect(find.text('test.user@example.com'), findsWidgets);
    semantics.dispose();
  });

  testWidgets('conversation history: count, and Clear all asks first', (tester) async {
    final services = await _pumpProfile(tester);
    services.log.addHeard('Sila tunggu');
    await _settle(tester);
    await _scrollTo(tester, find.text('Clear all'));
    expect(find.text('1 kept until the app closes (guest)'), findsOneWidget);

    await tester.tap(find.text('Clear all'));
    await _settle(tester);
    expect(find.text('Delete all conversations?'), findsOneWidget);
    await tester.tap(find.text('Delete all'));
    await _settle(tester);
    expect(find.text('0 kept until the app closes (guest)'), findsOneWidget);
    expect(find.text('Clear all'), findsNothing);
  });

  testWidgets('signed in: history and backup are in the account; sign out', (tester) async {
    final services = await _pumpProfile(tester, account: Account(FakeAuthBackend(currentUser: testUser)));
    services.backup.start();
    services.log.addSigned('Saya');
    await _settle(tester);
    expect(find.text('1 saved to your Google account'), findsOneWidget);
    expect(find.textContaining('Backed up to your Google account.'), findsOneWidget);
    expect(find.byTooltip('Check the backup now'), findsOneWidget);

    await _scrollTo(tester, find.text('Sign out'));
    await tester.tap(find.text('Sign out'));
    await _settle(tester);
    expect(services.account.signedIn, isFalse);
    expect(find.text('Continue with Google'), findsOneWidget, reason: 'can sign in again');
  });

  testWidgets('signed in: change the name in Profile (a guest has no name row)', (tester) async {
    final services = await _pumpProfile(tester, account: Account(FakeAuthBackend(currentUser: testUser)));
    await _scrollTo(tester, find.byTooltip('Change your name'));
    expect(find.text('Test User · shown on Home'), findsOneWidget);
    await tester.tap(find.byTooltip('Change your name'));
    await _settle(tester);
    expect(find.text('Change your name'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Haizad');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await _settle(tester);

    expect(services.account.name, 'Haizad');
    expect(find.text('Haizad · shown on Home'), findsOneWidget);

    await services.account.signOut();
    await _settle(tester);
    expect(find.byTooltip('Change your name'), findsNothing);
  });

  testWidgets('signed in: change the photo from the gallery, then back to the Google photo', (tester) async {
    final semantics = tester.ensureSemantics();
    ImageSource? asked;
    final services = await _pumpProfile(tester,
        account: Account(FakeAuthBackend(currentUser: testUser)),
        pickPhoto: (source) async => Uint8List.fromList([0xFF, 0xD8, 0xFF, (asked = source).index]));

    await tester.tap(find.bySemanticsLabel('Change your photo'));
    await _settle(tester);
    expect(find.text('Take a photo'), findsOneWidget);
    expect(find.text('Use my Google photo'), findsNothing, reason: 'nothing to go back to yet');
    await tester.tap(find.text('Choose from gallery'));
    await _settle(tester);
    expect(asked, ImageSource.gallery);
    expect(services.account.user?.customPhoto, isTrue);

    await tester.tap(find.bySemanticsLabel('Change your photo'));
    await _settle(tester);
    await tester.tap(find.text('Use my Google photo'));
    await _settle(tester);
    expect(services.account.user?.customPhoto, isFalse);
    semantics.dispose();
  });

  testWidgets('a failed photo change says why; a guest cannot change the photo', (tester) async {
    final semantics = tester.ensureSemantics();
    final backend = FakeAuthBackend(currentUser: testUser)
      ..photoFailure = const SignInFailure('No internet connection. The photo was not changed.');
    final account = Account(backend);
    await _pumpProfile(tester, account: account, pickPhoto: (_) async => Uint8List(4));

    await tester.tap(find.bySemanticsLabel('Change your photo'));
    await _settle(tester);
    await tester.tap(find.text('Take a photo'));
    await _settle(tester);
    expect(find.text('No internet connection. The photo was not changed.'), findsWidgets);

    await account.signOut();
    await _settle(tester);
    expect(find.bySemanticsLabel('Change your photo'), findsNothing);
    semantics.dispose();
  });

  testWidgets('About opens with the project name', (tester) async {
    await _pumpProfile(tester);
    await _scrollTo(tester, find.text('About SignSuara'));
    await tester.tap(find.text('About SignSuara'));
    await _settle(tester);
    expect(find.textContaining('Universiti Putra Malaysia'), findsWidgets);
    expect(find.text('View licenses'), findsOneWidget);
  });

  test("the licences page gets the fonts' licence texts and the signer character's credit", () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final entries = await appLicences().toList();
    expect([for (final e in entries) ...e.packages], ['Sora font', 'Plus Jakarta Sans font', 'BIM signer character']);
    for (final e in entries.take(2)) {
      expect(e.paragraphs.map((p) => p.text).join(' '), contains('SIL OPEN FONT LICENSE'));
    }
    expect(entries.last.paragraphs.single.text, contains('水銀メイド'), reason: 'its licence requires credit');
  });
}
