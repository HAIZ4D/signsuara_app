import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:signsuara_app/learn/teka_isyarat.dart';
import 'package:signsuara_app/signer/sign_clips.dart';

// The clips the app has today, plus the reaction clips that may come later.
final _app = SignClipLibrary({
  for (var c = 'a'.codeUnitAt(0); c <= 'z'.codeUnitAt(0); c++) 'letter_${String.fromCharCode(c)}',
  ...['apa', 'apa_khabar', 'awak', 'buat_apa', 'makan_tengahari', 'nama', 'saya', 'sudah', 'terima_kasih', 'tidak', 'ya'],
  ...['rest', 'spell_in', 'spell_out', 'wave', 'cheer', 'try_again'],
});

void main() {
  test('what can be asked: every sign and letter, not the rest pose, the spelling moves or reactions', () {
    final pool = tekaIsyaratPool(_app);
    expect(pool, hasLength(26 + 11));
    for (final notASign in ['rest', 'spell_in', 'spell_out', 'wave', 'cheer', 'try_again']) {
      expect(pool, isNot(contains(notASign)));
    }
  });

  test('a round: 10 signs, 5 letters and 5 words, none twice, 4 different answers from the same group', () {
    for (var seed = 0; seed < 20; seed++) {
      final round = tekaIsyaratRound(_app, random: Random(seed))!;
      expect(round, hasLength(10));
      expect({for (final q in round) q.clipId}, hasLength(10));
      expect(round.where((q) => q.clipId!.startsWith('letter_')), hasLength(5));
      for (final q in round) {
        final answers = [for (final o in q.options) o.text];
        expect(answers.toSet(), hasLength(4));
        expect(q.correct.text, signAnswer(q.clipId!).text);
        final letter = q.clipId!.startsWith('letter_');
        expect(answers.every((a) => a.startsWith('Huruf ') == letter), isTrue, reason: 'letters with letters: $answers');
        expect(q.clips, letter ? ['spell_in', q.clipId, 'spell_out'] : [q.clipId], reason: 'the hand rises to letters');
      }
    }
  });

  test('how answers read: gloss + English meaning, "Huruf A", or the id when not in the dictionary', () {
    final thanks = signAnswer('terima_kasih');
    expect((thanks.text, thanks.detail), ('TERIMA KASIH', 'Thank you'));
    expect(signAnswer('saya').detail, 'I');
    final q = signAnswer('letter_q');
    expect((q.text, q.detail), ('Huruf Q', null));
    final islam = signAnswer('islam'); // a clip that may come before its dictionary entry
    expect((islam.text, islam.detail), ('ISLAM', null));
  });

  test('a small app: a short group is filled from the other; fewer than 4 clips = no round', () {
    final few = SignClipLibrary({'letter_a', 'letter_b', 'saya', 'nama', 'ya', 'rest'});
    final round = tekaIsyaratRound(few, random: Random(1))!;
    expect(round, hasLength(5));
    expect(round.every((q) => {for (final o in q.options) o.text}.length == 4), isTrue);
    expect(round.every((q) => q.clips.length == 1), isTrue, reason: 'no spell_in/spell_out clips: letters alone');
    expect(tekaIsyaratRound(const SignClipLibrary({'letter_a', 'saya', 'nama', 'rest', 'wave'})), isNull);
    expect(tekaIsyaratRound(const SignClipLibrary({})), isNull);
  });
}
