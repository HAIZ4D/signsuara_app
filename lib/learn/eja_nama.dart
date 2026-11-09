import 'dart:math';

import '../signer/bim_signs.dart';
import '../signer/sign_clips.dart';

/// Eja Nama (README "Learn"): any name fingerspelled by the avatar, and Baca Jari ("read the
/// fingers"), a game where you type the word she fingerspells.

/// The words of [text] in the letters a–z only (lowercase), at most [maxLetters] letters in all,
/// and whether anything was left out (digits, ' and -, …: there are no clips for them).
({List<String> words, bool dropped}) spellWords(String text, {int maxLetters = 24}) {
  final words = <String>[];
  var dropped = false;
  var count = 0;
  for (final part in text.toLowerCase().split(RegExp(r'\s+'))) {
    final letters = part.replaceAll(RegExp('[^a-z]'), '');
    if (letters.length != part.length) dropped = true;
    if (letters.isEmpty) continue;
    final room = maxLetters - count;
    if (room <= 0) {
      dropped = true;
      break;
    }
    final word = letters.length > room ? letters.substring(0, room) : letters;
    if (word.length < letters.length) dropped = true;
    words.add(word);
    count += word.length;
  }
  return (words: words, dropped: dropped);
}

/// What the avatar plays to fingerspell [words]: each word's letters, between the hand rising to
/// the spelling place and coming down again (spell_in / spell_out, when the app has them; so two
/// words get a short break). With each clip: the letter it shows as (word, letter), or null while
/// the hand moves. Null when a letter has no clip.
List<(String, (int, int)?)>? spellPlan(SignClipLibrary library, List<String> words) {
  final wrap = library.ids.contains(SignClipLibrary.spellIn) && library.ids.contains(SignClipLibrary.spellOut);
  final out = <(String, (int, int)?)>[];
  for (final (w, word) in words.indexed) {
    if (wrap) out.add((SignClipLibrary.spellIn, null));
    for (final (i, char) in word.split('').indexed) {
      final clip = spellingSign(char);
      if (!library.ids.contains(clip)) return null;
      out.add((clip, (w, i)));
    }
    if (wrap) out.add((SignClipLibrary.spellOut, null));
  }
  return out;
}

/// Baca Jari's words: short everyday Malay words, with their English (shown after each answer).
const kSpellWords = <(String, String)>[
  ('ibu', 'mother'), ('ayah', 'father'), ('adik', 'younger brother or sister'), ('kakak', 'older sister'),
  ('abang', 'older brother'), ('kawan', 'friend'), ('guru', 'teacher'), ('buku', 'book'), ('meja', 'table'),
  ('rumah', 'house'), ('kereta', 'car'), ('kucing', 'cat'), ('ikan', 'fish'), ('ayam', 'chicken'),
  ('nasi', 'rice'), ('air', 'water'), ('roti', 'bread'), ('susu', 'milk'), ('teh', 'tea'), ('kopi', 'coffee'),
  ('tidur', 'sleep'), ('main', 'play'), ('baca', 'read'), ('tulis', 'write'), ('suka', 'like'),
  ('besar', 'big'), ('kecil', 'small'), ('panas', 'hot'), ('sejuk', 'cold'), ('pagi', 'morning'),
  ('malam', 'night'), ('hujan', 'rain'), ('bola', 'ball'), ('bunga', 'flower'), ('pintu', 'door'),
];

const bacaJariLength = 5;

/// A round of Baca Jari: [length] different words whose letters all have clips; null when there
/// are not that many.
List<(String, String)>? bacaJariRound(SignClipLibrary library, {Random? random, int length = bacaJariLength}) {
  final words = [for (final w in kSpellWords) if (spellPlan(library, [w.$1]) != null) w]..shuffle(random ?? Random());
  return words.length < length ? null : words.take(length).toList();
}

/// True when [typed] is [word]: capitals, spaces and other marks don't count.
bool sameWord(String typed, String word) => typed.toLowerCase().replaceAll(RegExp('[^a-z]'), '') == word;
