import '../listen/listen_note.dart';
import '../ml/gesture_classifier.dart';
import '../ml/signsuara_model.dart';
import '../signer/sign_clips.dart';
import '../signer/sign_translator.dart';
import 'sign_targets.dart';

/// A sign the avatar can show that was heard in a note (Learn: "Learn the signs you heard").
class HeardSign {
  const HeardSign({required this.id, required this.line, required this.start, required this.end, required this.times});

  final String id; // its clip ("terima_kasih")
  final String line; // the sentence it was first heard in
  final int start; // where in [line]
  final int end;
  final int times; // how often it was heard in the note
}

/// The signs heard in [note], in the order they were first said, each once: the words the signer
/// would sign (SignTranslator: phrases first, Malay or English) that have a clip. Fingerspelled
/// words (names, words without a sign) are left out: Eja Nama is for those.
List<HeardSign> signsInNote(ListenNote note, SignTranslator translator, SignClipLibrary library) {
  final first = <String, (String, int, int)>{};
  final times = <String, int>{};
  for (final line in note.lines) {
    for (final step in translator.translate(line.text)) {
      if (step.spelled || step.signs.length != 1 || !library.ids.contains(step.signs.single)) continue;
      final id = step.signs.single;
      times[id] = (times[id] ?? 0) + 1;
      first.putIfAbsent(id, () => (line.text, step.start, step.end));
    }
  }
  return [
    for (final MapEntry(key: id, value: (line, start, end)) in first.entries)
      HeardSign(id: id, line: line, start: start, end: end, times: times[id]!),
  ];
}

/// The glove's own signs (model labels) among the sign clips [ids]: Sign Quest can ask those.
List<String> gloveSignsAmong(Iterable<String> ids) => [
      for (final label in kLabels)
        if (label != GestureClassifier.restLabel && ids.contains(signClipFor(label))) label,
    ];
