import 'package:flutter_test/flutter_test.dart';
import 'package:signsuara_app/screens/hearing_screen.dart';
import 'package:signsuara_app/signer/bim_signs.dart';
import 'package:signsuara_app/signer/sign_translator.dart';

void main() {
  final translator = SignTranslator();

  List<String> labels(String sentence) => [for (final s in translator.translate(sentence)) s.label];

  test('a known phrase is one sign; a name is fingerspelled', () {
    final steps = translator.translate('Terima kasih, Zad!');
    expect([for (final s in steps) s.label], ['TERIMA KASIH', 'Z·A·D']);
    expect(steps[0].signs, ['terima_kasih']);
    expect(steps[0].spelled, isFalse);
    expect(steps[1].signs, ['letter_z', 'letter_a', 'letter_d']);
    expect(steps[1].spelled, isTrue);
    expect([steps[1].start, steps[1].end], [14, 17], reason: 'where "Zad" is, for highlighting');
    expect(steps[1].text, 'Zad');
  });

  test('the longest phrase wins over single words', () {
    final t = SignTranslator(const [
      BimSign('selamat', malay: ['selamat']),
      BimSign('selamat_pagi', malay: ['selamat pagi']),
    ]);
    expect([for (final s in t.translate('Selamat pagi')) s.signs], [
      ['selamat_pagi']
    ]);
    expect([for (final s in t.translate('Selamat datang')) s.label], ['SELAMAT', 'D·A·T·A·N·G']);
  });

  test('English speech uses the same signs', () {
    expect(labels('Thank you, please.'), ['TERIMA KASIH', 'SILA']);
    expect(labels('Please wait'), ['SILA', 'W·A·I·T'], reason: 'no sign for "wait": spelled');
    expect(labels('I understand'), ['SAYA', 'FAHAM']);
  });

  test('spoken endings (-lah, -kah, -nya, -pun) are dropped only when that gives a known word', () {
    expect(labels('Namanya'), ['NAMA']);
    expect(labels('Bolehkah?'), ['BOLEH']);
    expect(labels('sekolah'), ['S·E·K·O·L·A·H'], reason: '"seko" is not a word');
  });

  test('numbers use number signs; case, punctuation and empty text are fine', () {
    final steps = translator.translate('BILIK 3');
    expect(steps.last.signs, ['number_3']);
    expect(labels('  ya!!  TIDAK?? '), ['YA', 'TIDAK']);
    expect(translator.translate(''), isEmpty);
    expect(translator.translate('... !!'), isEmpty);
  });

  test('every quick reply in Hearing mode is fully signed (no spelling)', () {
    for (final (malay, english) in HearingScreen.quickReplies) {
      for (final reply in [malay, english]) {
        expect(translator.translate(reply).where((s) => s.spelled), isEmpty, reason: '"$reply" needs its signs');
      }
    }
  });

  test('the dictionary is consistent', () {
    final ids = [for (final s in kBimSigns) s.id];
    expect(ids.toSet().length, ids.length, reason: 'no id twice');
    final safeName = RegExp(r'^[a-z0-9_]+$');
    final seen = <String, String>{};
    for (final sign in kBimSigns) {
      expect(safeName.hasMatch(sign.id), isTrue, reason: '${sign.id} must be a safe clip file name');
      expect(sign.id.startsWith('letter_') || sign.id.startsWith('number_'), isFalse,
          reason: 'letter_ and number_ are for spelling');
      expect(sign.malay, isNotEmpty);
      for (final words in [...sign.malay, ...sign.english]) {
        expect(words, words.toLowerCase(), reason: 'lowercase: "$words"');
        expect(seen[words], isNull, reason: '"$words" is in ${seen[words]} and ${sign.id}');
        seen[words] = sign.id;
      }
    }
  });
}
