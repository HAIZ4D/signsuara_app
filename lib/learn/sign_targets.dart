import 'dart:math';

import '../ml/gesture_classifier.dart';
import '../ml/signsuara_model.dart';
import '../signer/sign_clips.dart';

/// Where each finger should be for a sign: the average raw flex value (thumb, index, middle, ring,
/// pinky; on this glove straight = HIGH, bent = LOW) of all its training rows. Made by
/// `python tools/export_finger_targets.py` (signsuara_data_v2.csv, 2026-11-08): run it again after
/// retraining and paste its output here. A sign without an entry shows the fingers without a guide.
const kSignFingerTargets = <String, List<double>>{
  'A': [892, 580, 590, 550, 579], // 2250 rows, 30 recordings; spread 35, 37, 20, 22, 15
  'B': [700, 933, 789, 720, 696], // 3000 rows, 40 recordings; spread 66, 14, 15, 6, 34
  'Islam': [804, 735, 478, 482, 546], // 2250 rows, 30 recordings; spread 40, 48, 47, 33, 29
  'MakanTengahari': [833, 853, 752, 656, 679], // 2250 rows, 30 recordings; spread 65, 96, 45, 69, 33
  'Nama': [829, 941, 755, 634, 573], // 2250 rows, 30 recordings; spread 88, 6, 19, 22, 41
  'Puasa': [804, 932, 772, 712, 733], // 3000 rows, 40 recordings; spread 16, 14, 8, 6, 8
  'Saya': [833, 941, 616, 558, 570], // 2250 rows, 30 recordings; spread 51, 24, 44, 31, 37
  'Solat': [808, 878, 777, 705, 725], // 2250 rows, 30 recordings; spread 22, 43, 22, 8, 19
  'TerimaKasih': [906, 942, 817, 728, 705], // 2250 rows, 30 recordings; spread 29, 9, 8, 9, 9
  'Zakat': [895, 890, 755, 679, 750], // 2250 rows, 30 recordings; spread 15, 14, 11, 9, 7
};

/// A finger is "in place" within this many ADC counts of its target. On this glove a finger moves
/// only ~350–420 counts from straight to bent (lib/ui/finger_bend.dart); 300 (the first guess) made
/// almost every finger "in place", even a resting hand for B. Most fingers vary less than 80 across
/// the training recordings (see the spreads above); a few vary more (MakanTengahari's index 96,
/// Nama's thumb 88), so those can flicker between in place and not.
const kFingerTolerance = 80.0;

/// Which fingers (thumb … pinky) are within [kFingerTolerance] of [target].
List<bool> fingerMatches(List<double> row, List<double> target) =>
    [for (var i = 0; i < 5; i++) (row[i] - target[i]).abs() <= kFingerTolerance];

/// The avatar's clip for a model label: one letter → `letter_x`; CamelCase → snake_case
/// (`TerimaKasih` → `terima_kasih`).
String signClipFor(String label) => label.length == 1
    ? 'letter_${label.toLowerCase()}'
    : label.replaceAllMapped(RegExp('([a-z0-9])([A-Z])'), (m) => '${m[1]}_${m[2]}').toLowerCase();

/// The model's signs (not Rest) that the avatar can show. A new model sign joins once its clip is
/// in `assets/signs/`: no code change.
List<String> signQuestSigns(SignClipLibrary library) => [
      for (final label in kLabels)
        if (label != GestureClassifier.restLabel && library.ids.contains(signClipFor(label))) label,
    ];

/// A round of up to [length] different signs; null when the avatar can show none of them.
List<String>? signQuestRound(SignClipLibrary library, {Random? random, int length = 5}) {
  final signs = signQuestSigns(library)..shuffle(random ?? Random());
  return signs.isEmpty ? null : signs.take(length).toList();
}
