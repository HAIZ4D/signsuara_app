enum SpeechLanguage {
  malay('ms-MY', 'BM', 'Malay'),
  english('en-US', 'EN', 'English');

  const SpeechLanguage(this.locale, this.short, this.displayName);

  final String locale; // text-to-speech language code
  final String short; // label on the language switch
  final String displayName;
}

/// What one model label means in each language. [englishSpoken] overrides what the voice says.
class SignWords {
  const SignWords(this.malay, this.english, {this.englishSpoken});

  final String malay;
  final String english;
  final String? englishSpoken;

  String shown(SpeechLanguage language) => language == SpeechLanguage.malay ? malay : english;

  String spoken(SpeechLanguage language) =>
      language == SpeechLanguage.malay ? malay : englishSpoken ?? english;
}

/// Label -> words. THE one place to add a word after training a new gesture (see README.md).
/// Rest is not here: it is never announced, so never spoken.
const kSignWords = <String, SignWords>{
  'A': SignWords('A', 'A'),
  'B': SignWords('B', 'B'),
  'Saya': SignWords('Saya', 'I / Me', englishSpoken: 'Me'),
  'Nama': SignWords('Nama', 'Name'),
  'TerimaKasih': SignWords('Terima kasih', 'Thank you'),
};

/// Words for a label. A label missing from the map is shown and spoken as-is: never a crash.
SignWords wordsFor(String label) => kSignWords[label] ?? SignWords(label, label);
