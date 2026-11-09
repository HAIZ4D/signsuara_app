import 'dart:math';

import '../signer/bim_signs.dart';
import '../signer/sign_clips.dart';
import 'learn_ui.dart';
import 'quiz_question.dart';

/// Teka Isyarat ("guess the sign"): the avatar signs, you pick the meaning (README "Learn").
const tekaIsyaratLength = 10;

/// Every clip that can be asked: all signs and letters, not the rest pose, the hand going to and
/// from the spelling place, or the avatar's reactions. New clips join by themselves.
List<String> tekaIsyaratPool(SignClipLibrary library) => [
      for (final id in library.ids)
        if (id != SignClipLibrary.rest &&
            id != SignClipLibrary.spellIn &&
            id != SignClipLibrary.spellOut &&
            !LearnClips.reactions.contains(id))
          id,
    ]..sort();

bool _isSpelling(String id) => id.startsWith('letter_') || id.startsWith('number_');

/// The sign of the day (the hub): the same all day, another one the next day, going round all the
/// word signs (letters only when there are no word signs). Null without clips.
String? signOfTheDay(SignClipLibrary library, DateTime day) {
  final pool = tekaIsyaratPool(library);
  final words = [for (final id in pool) if (!_isSpelling(id)) id];
  final from = words.isNotEmpty ? words : pool;
  if (from.isEmpty) return null;
  final days = DateTime.utc(day.year, day.month, day.day).difference(DateTime.utc(2026)).inDays;
  return from[days % from.length];
}

/// The answer as shown: a word's gloss with its first English meaning under it; "Huruf A" for a
/// letter. A clip missing from the dictionary is named after its id.
QuizOption signAnswer(String id) {
  if (id.startsWith('letter_')) return QuizOption('Huruf ${id.substring(7).toUpperCase()}');
  if (id.startsWith('number_')) return QuizOption('Nombor ${id.substring(7)}');
  final sign = kBimSigns.where((s) => s.id == id).firstOrNull;
  final english = sign?.english.firstOrNull;
  return QuizOption(
    sign?.gloss ?? id.replaceAll('_', ' ').toUpperCase(),
    english == null ? null : english[0].toUpperCase() + english.substring(1),
  );
}

/// A round of up to [length] questions, about half letters and half words, no sign twice. Each
/// has 3 wrong answers from the same group (letters with letters), filled from the other group when
/// a group is too small. [only]: ask just these signs (e.g. the ones heard in a note); the wrong
/// answers still come from every clip. Null when the app has fewer than 4 clips, or none of [only].
List<QuizQuestion>? tekaIsyaratRound(SignClipLibrary library,
    {Random? random, int length = tekaIsyaratLength, List<String>? only}) {
  final r = random ?? Random();
  final pool = tekaIsyaratPool(library);
  if (pool.length < 4) return null;
  final letters = [for (final id in pool) if (_isSpelling(id)) id]..shuffle(r);
  final words = [for (final id in pool) if (!_isSpelling(id)) id]..shuffle(r);
  final n = min(length, pool.length);
  final fromWords = min(words.length, max(n ~/ 2, n - letters.length)); // a short group gives way
  final asked = only != null
      ? ([for (final id in only) if (pool.contains(id)) id]..shuffle(r)).take(length).toList()
      : ([...words.take(fromWords), ...letters.take(n - fromWords)]..shuffle(r));
  if (asked.isEmpty) return null;

  QuizQuestion ask(String id) {
    final (same, other) = _isSpelling(id) ? (letters, words) : (words, letters);
    final wrong = [
      ...([for (final x in same) if (x != id) x]..shuffle(r)),
      ...([...other]..shuffle(r)),
    ].take(3);
    final ids = [id, ...wrong]..shuffle(r);
    return QuizQuestion(
      clipId: id,
      clips: clipsToShow(library, id), // a letter: the hand rises first and comes down after
      question: 'What does this sign mean?',
      options: [for (final x in ids) signAnswer(x)],
      answer: ids.indexOf(id),
    );
  }

  return [for (final id in asked) ask(id)];
}
