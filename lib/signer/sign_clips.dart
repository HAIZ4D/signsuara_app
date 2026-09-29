import 'package:flutter/services.dart';

import 'bim_signs.dart';
import 'sign_translator.dart';

/// Which signs have a clip in the app: the files in `assets/signs/` (README "Signer").
/// Dropping a new `<id>.webp` there is all it takes; no code change.
class SignClipLibrary {
  const SignClipLibrary(this.ids);

  /// Sign ids with a clip ("terima_kasih", "letter_a", "rest", …).
  final Set<String> ids;

  /// The avatar standing still, shown before anything is signed (optional clip).
  static const rest = 'rest';

  /// Reads the app's asset list once. No list (or no clips): an empty library.
  static Future<SignClipLibrary> fromAssets([AssetBundle? bundle]) async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(bundle ?? rootBundle);
      const folder = 'assets/signs/', type = '.webp';
      return SignClipLibrary({
        for (final path in manifest.listAssets())
          if (path.startsWith(folder) && path.endsWith(type)) path.substring(folder.length, path.length - type.length),
      });
    } catch (_) {
      return const SignClipLibrary({});
    }
  }

  bool get isEmpty => ids.isEmpty;

  /// The hand rising to where letters are signed, and going back down to the rest pose.
  static const spellIn = 'spell_in', spellOut = 'spell_out';

  /// What to play for [steps]: each clip with the number of the step (word) it belongs to.
  /// A sign without a clip yet is fingerspelled when every letter has a clip; a word that can
  /// be neither signed nor fully spelled is left out (half a word would only confuse).
  /// Letters stay up at the shoulder: a run of spelled words is wrapped in [spellIn] ... [spellOut]
  /// (when those clips exist), instead of the hand going down between letters.
  List<(String clip, int step)> plan(List<SignStep> steps) {
    final wrap = ids.contains(spellIn) && ids.contains(spellOut);
    final out = <(String, int)>[];
    var up = false; // the hand is at the letters' place
    var last = 0;
    for (final (i, step) in steps.indexed) {
      final clips = _clipsFor(step);
      if (clips.isEmpty) continue;
      final letters = clips.every(_isSpelling);
      if (wrap && letters && !up) out.add((spellIn, i));
      if (wrap && !letters && up) out.add((spellOut, last));
      up = letters;
      last = i;
      out.addAll([for (final clip in clips) (clip, i)]);
    }
    if (wrap && up) out.add((spellOut, last));
    return out;
  }

  static bool _isSpelling(String clip) => clip.startsWith('letter_') || clip.startsWith('number_');

  List<String> _clipsFor(SignStep step) {
    if (step.signs.every(ids.contains)) return step.signs;
    if (step.spelled) return const [];
    final letters = [
      for (final c in step.text.toLowerCase().split('')) if (RegExp(r'^[a-z0-9]$').hasMatch(c)) spellingSign(c),
    ];
    return letters.isNotEmpty && letters.every(ids.contains) ? letters : const [];
  }
}
