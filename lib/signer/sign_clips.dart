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

  /// What to play for [steps]: each clip with the number of the step (word) it belongs to.
  /// A sign without a clip yet is fingerspelled when every letter has a clip; a word that can
  /// be neither signed nor fully spelled is left out (half a word would only confuse).
  List<(String clip, int step)> plan(List<SignStep> steps) => [
        for (final (i, step) in steps.indexed)
          for (final clip in _clipsFor(step)) (clip, i),
      ];

  List<String> _clipsFor(SignStep step) {
    if (step.signs.every(ids.contains)) return step.signs;
    if (step.spelled) return const [];
    final letters = [
      for (final c in step.text.toLowerCase().split('')) if (RegExp(r'^[a-z0-9]$').hasMatch(c)) spellingSign(c),
    ];
    return letters.isNotEmpty && letters.every(ids.contains) ? letters : const [];
  }
}
