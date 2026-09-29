import 'bim_signs.dart';

/// One part of the signed version of a sentence: a sign from the dictionary, or a word spelled
/// letter by letter.
class SignStep {
  const SignStep({
    required this.text,
    required this.label,
    required this.signs,
    required this.spelled,
    required this.start,
    required this.end,
  });

  /// The words it stands for, as they were said ("Terima kasih", "Zad").
  final String text;

  /// How it is shown on screen: the gloss ("TERIMA KASIH") or the spelled letters ("Z·A·D").
  final String label;

  /// Clip ids to play, in order: one for a sign, one per letter or digit when spelled.
  final List<String> signs;

  /// True when there is no sign for it, so it is fingerspelled.
  final bool spelled;

  /// Where [text] is in the sentence (to highlight it while it is signed).
  final int start;
  final int end;
}

/// Speech → a sequence of BIM signs, word by word (README "Signer"):
/// 1. phrases in the dictionary first, the longest one wins ("terima kasih" is one sign);
/// 2. then single words, also without a spoken -lah, -kah, -nya or -pun ending ("tunggulah");
/// 3. anything else is fingerspelled (names, unknown words), digits with number signs.
/// It keeps the spoken word order: signed Malay or English, not full BIM grammar.
class SignTranslator {
  SignTranslator([List<BimSign> signs = kBimSigns]) {
    for (final sign in signs) {
      for (final words in [...sign.malay, ...sign.english]) {
        final key = words.split(' ').map(_clean).join(' ');
        _signs[key] = sign;
        final count = key.split(' ').length;
        if (count > _longest) _longest = count;
      }
    }
  }

  final _signs = <String, BimSign>{};
  var _longest = 1;

  static final _word = RegExp(r"[\p{L}\p{N}]+(?:['’-][\p{L}\p{N}]+)*", unicode: true);
  static const _endings = ['lah', 'kah', 'nya', 'pun'];

  static String _clean(String word) => word.toLowerCase().replaceAll('’', "'");

  List<SignStep> translate(String sentence) {
    final words = _word.allMatches(sentence).toList();
    final steps = <SignStep>[];
    var i = 0;
    while (i < words.length) {
      final found = _longestSign(words, i);
      if (found case (final sign, final used)) {
        final first = words[i], last = words[i + used - 1];
        steps.add(SignStep(
          text: sentence.substring(first.start, last.end),
          label: sign.gloss,
          signs: [sign.id],
          spelled: false,
          start: first.start,
          end: last.end,
        ));
        i += used;
        continue;
      }
      final word = words[i];
      final chars = [for (final c in _clean(word[0]!).split('')) if (RegExp(r'^[a-z0-9]$').hasMatch(c)) c];
      if (chars.isNotEmpty) {
        steps.add(SignStep(
          text: word[0]!,
          label: chars.join('·').toUpperCase(),
          signs: [for (final c in chars) spellingSign(c)],
          spelled: true,
          start: word.start,
          end: word.end,
        ));
      }
      i++;
    }
    return steps;
  }

  /// The longest dictionary phrase starting at word [i]: (sign, words used), or null.
  (BimSign, int)? _longestSign(List<RegExpMatch> words, int i) {
    for (var n = _longest; n >= 1; n--) {
      if (i + n > words.length) continue;
      final key = [for (final w in words.sublist(i, i + n)) _clean(w[0]!)].join(' ');
      if (_signs[key] case final sign?) return (sign, n);
    }
    final word = _clean(words[i][0]!);
    for (final ending in _endings) {
      if (word.length > ending.length + 1 && word.endsWith(ending)) {
        if (_signs[word.substring(0, word.length - ending.length)] case final sign?) return (sign, 1);
      }
    }
    return null;
  }
}
