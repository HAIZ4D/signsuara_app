import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signsuara_app/app/app_services.dart';
import 'package:signsuara_app/learn/eja_nama.dart';
import 'package:signsuara_app/learn/eja_nama_screen.dart';
import 'package:signsuara_app/learn/read_fingers_screen.dart';
import 'package:signsuara_app/learn/results_screen.dart';
import 'package:signsuara_app/signer/sign_clips.dart';
import 'package:signsuara_app/signer/sign_player.dart';
import 'package:signsuara_app/theme/app_theme.dart';

import 'fake_clips.dart';

final _alphabet = {for (var c = 'a'.codeUnitAt(0); c <= 'z'.codeUnitAt(0); c++) 'letter_${String.fromCharCode(c)}'};

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter_tts'), (call) async => call.method == 'isLanguageAvailable' ? true : 1);
  });

  test('a name: letters a–z only, word by word, at most 24 letters; what was left out is told', () {
    final name = spellWords('Haizad');
    expect(name.words, ['haizad']);
    expect(name.dropped, isFalse);
    final mixed = spellWords("  Nur'Ain bt. Ali 2 ");
    expect(mixed.words, ['nurain', 'bt', 'ali']);
    expect(mixed.dropped, isTrue);
    final long = spellWords('Abcdefghijkl Mnopqrstuvwx Yz');
    expect(long.words, ['abcdefghijkl', 'mnopqrstuvwx']);
    expect(long.dropped, isTrue, reason: 'longer than 24 letters');
    expect(spellWords(' 123 ').words, isEmpty);
  });

  test('the clips for a name: the hand rises before each word and comes down after; a letter without a clip = none', () {
    final library = SignClipLibrary({..._alphabet, 'spell_in', 'spell_out'});
    expect(spellPlan(library, ['ali', 'bt']), [
      ('spell_in', null),
      ('letter_a', (0, 0)),
      ('letter_l', (0, 1)),
      ('letter_i', (0, 2)),
      ('spell_out', null),
      ('spell_in', null),
      ('letter_b', (1, 0)),
      ('letter_t', (1, 1)),
      ('spell_out', null),
    ]);
    expect(spellPlan(SignClipLibrary({'letter_a', 'letter_l', 'letter_i'}), ['ali']),
        [('letter_a', (0, 0)), ('letter_l', (0, 1)), ('letter_i', (0, 2))], reason: 'without the hand moves');
    expect(spellPlan(const SignClipLibrary({'letter_a'}), ['ali']), isNull);
  });

  test("Baca Jari's words: short, plain a–z, all different; a round of 5 different words; reading ignores capitals", () {
    final words = [for (final (w, _) in kSpellWords) w];
    expect(words.toSet(), hasLength(words.length));
    for (final (word, english) in kSpellWords) {
      expect(word, matches(RegExp(r'^[a-z]{3,6}$')));
      expect(english, isNotEmpty);
    }
    final round = bacaJariRound(SignClipLibrary(_alphabet), random: Random(3))!;
    expect(round.map((w) => w.$1).toSet(), hasLength(bacaJariLength));
    expect(bacaJariRound(const SignClipLibrary({'letter_a'})), isNull);
    expect(sameWord(' Ibu ', 'ibu'), isTrue);
    expect(sameWord('IBU', 'ibu'), isTrue);
    expect(sameWord('ibi', 'ibu'), isFalse);
  });

  Future<(AppServices, List<String>)> pump(WidgetTester tester, Widget Function(AppServices, ClipOpener) screen) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final image = (await tester.runAsync(() => createTestImage(width: 4, height: 4, cache: false)))!;
    final ids = {..._alphabet, 'spell_in', 'spell_out', 'rest'};
    final services = AppServices(signer: fakeSigner(image, ids));
    addTearDown(services.dispose);
    final opened = <String>[];
    Future<ClipReader?> open(String id) async {
      opened.add(id);
      return ids.contains(id) ? FakeClip(image, 3) : null;
    }

    await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: screen(services, open)));
    await tester.pump(const Duration(milliseconds: 300));
    return (services, opened);
  }

  Future<void> play(WidgetTester tester, int ms) async {
    for (var t = 0; t < ms; t += 20) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  testWidgets('Eja Nama: a typed name is fingerspelled, letter by letter, and what was left out is said', (tester) async {
    final (_, opened) = await pump(tester, (s, open) => EjaNamaScreen(services: s, openClip: open));
    expect(find.text('Type a name, then tap Spell it.'), findsOneWidget);
    expect(opened, ['rest'], reason: 'she stands ready from the start (no wave clip here)');
    opened.clear();

    await tester.enterText(find.byType(TextField), 'Ali-2');
    await tester.tap(find.text('Spell it'));
    await tester.pump();
    await play(tester, 1000);
    expect(opened, ['spell_in', 'letter_a', 'letter_l', 'letter_i', 'spell_out']);
    expect(find.text('Only the letters A–Z are spelled.'), findsOneWidget);
    for (final letter in ['A', 'L', 'I']) {
      expect(find.text(letter), findsOneWidget);
    }
    expect(find.bySemanticsLabel('Spelling ALI'), findsOneWidget);
  });

  testWidgets('Baca Jari: type what she spells; right wins XP and its letters, wrong shows the word; then Results',
      (tester) async {
    final (services, opened) = await pump(
        tester, (s, open) => ReadFingersScreen(services: s, words: const [('ibu', 'mother'), ('air', 'water')], openClip: open));
    await play(tester, 600);
    expect(opened.take(5), ['spell_in', 'letter_i', 'letter_b', 'letter_u', 'spell_out']);
    expect(find.text('3 letters'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ibu');
    await tester.tap(find.text('Check'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Correct! IBU means "mother". +10 XP'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField), 'api');
    await tester.tap(find.text('Check'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Not quite. It was AIR ("water").'), findsOneWidget);

    await tester.tap(find.text('See results'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(ResultsScreen), findsOneWidget);
    expect(services.learn.xp, 10);
    expect(services.learn.lettersRight, {'i', 'b', 'u'});
    expect(tester.takeException(), isNull);
  });
}
