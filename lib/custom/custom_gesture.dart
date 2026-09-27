import 'dart:math';

import '../ml/features.dart';
import '../ml/signsuara_model.dart';
import '../speech/sign_words.dart';

/// A gesture recorded on the phone, with its own phrase (CLAUDE.md step 8).
class CustomGesture {
  const CustomGesture({
    required this.id,
    required this.malay,
    this.english = '',
    required this.moving,
    required this.recordings,
  });

  static const recordingsNeeded = 5;
  static const recordingRows = 75; // 3 s at 25 Hz, like record_v2.py
  static const labelPrefix = 'custom:';

  final String id;
  final String malay;
  final String english; // may be empty: then the Malay text is used
  final bool moving;
  final List<List<List<double>>> recordings; // raw glove rows (11 values), saved as-is

  String get label => '$labelPrefix$id';
  SignWords get words => SignWords(malay, english.isEmpty ? malay : english);

  Map<String, Object> toJson() =>
      {'id': id, 'malay': malay, 'english': english, 'moving': moving, 'recordings': recordings};

  factory CustomGesture.fromJson(Map<String, dynamic> json) => CustomGesture(
        id: json['id'] as String,
        malay: json['malay'] as String,
        english: json['english'] as String? ?? '',
        moving: json['moving'] as bool,
        recordings: [
          for (final rec in json['recordings'] as List)
            [
              for (final row in rec as List) [for (final v in row as List) (v as num).toDouble()]
            ]
        ],
      );
}

const _shifts = [-6, -3, 0, 3, 6]; // same as train_v2.py

/// Feature vectors of one recording, windows chosen exactly like train_v2.py:
/// still = the last window (sign held), moving = centred on the movement peak, 5 shifts.
List<List<double>> trainingWindows(List<List<double>> rows, {required bool moving}) {
  final n = rows.length;
  if (n < kWindowSize) return [];
  final starts = moving
      ? [for (final s in _shifts) accPeak(rows) - kWindowSize ~/ 2 + s]
      : [n - kWindowSize];
  return [
    for (final start in starts)
      extractFeatures(rows.sublist(start.clamp(0, n - kWindowSize), start.clamp(0, n - kWindowSize) + kWindowSize))
  ];
}

/// Row index of the strongest movement, like pandas `acc.rolling(5, center=True).mean().idxmax()`.
int accPeak(List<List<double>> rows) {
  final acc = [for (final r in rows) sqrt(r[8] * r[8] + r[9] * r[9] + r[10] * r[10])];
  var best = 2;
  var bestMean = double.negativeInfinity;
  for (var i = 2; i < acc.length - 2; i++) {
    final mean = (acc[i - 2] + acc[i - 1] + acc[i] + acc[i + 1] + acc[i + 2]) / 5;
    if (mean > bestMean) {
      bestMean = mean;
      best = i;
    }
  }
  return best;
}
