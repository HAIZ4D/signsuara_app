/// One sign the BIM signer can show. [id] names its clip (`assets/signs/<id>.webp`, from signer
/// step S2 on); [malay] and [english] are the words or phrases (lowercase) signed with it.
class BimSign {
  const BimSign(this.id, {required this.malay, this.english = const []});

  final String id;
  final List<String> malay;
  final List<String> english;

  /// How the sign is written on screen (a "gloss"): its first Malay word in capitals.
  String get gloss => malay.first.toUpperCase();
}

/// THE sign dictionary: the words the signer knows (README "Signer"). It lists meanings only;
/// each sign's movement comes from its clip, which must be checked by a fluent BIM signer before
/// it is added. Words that are not here are fingerspelled letter by letter.
const kBimSigns = <BimSign>[
  // The glove's own signs
  BimSign('saya', malay: ['saya', 'aku'], english: ['i', 'me', 'my']),
  BimSign('nama', malay: ['nama'], english: ['name']),
  BimSign('terima_kasih', malay: ['terima kasih'], english: ['thank you', 'thanks']),
  // Common answers
  BimSign('ya', malay: ['ya'], english: ['yes']),
  BimSign('tidak', malay: ['tidak', 'tak'], english: ['no', 'not']),
  // Everyday words
  BimSign('assalamualaikum', malay: ['assalamualaikum']),
  BimSign('baik', malay: ['baik'], english: ['fine', 'good']),
  BimSign('maaf', malay: ['maaf'], english: ['sorry']),
  BimSign('tolong', malay: ['tolong'], english: ['help']),
  BimSign('faham', malay: ['faham'], english: ['understand']),
  BimSign('boleh', malay: ['boleh'], english: ['can']),
  BimSign('apa', malay: ['apa'], english: ['what']),
  BimSign('mana', malay: ['mana'], english: ['where']),
  BimSign('makan', malay: ['makan'], english: ['eat']),
  BimSign('minum', malay: ['minum'], english: ['drink']),
  BimSign('tandas', malay: ['tandas'], english: ['toilet']),
  BimSign('sakit', malay: ['sakit'], english: ['sick', 'pain', 'hurt']),
];

/// The fingerspelling clip of a letter (a–z) or the sign of a digit (0–9).
String spellingSign(String char) => RegExp(r'^[0-9]$').hasMatch(char) ? 'number_$char' : 'letter_$char';
