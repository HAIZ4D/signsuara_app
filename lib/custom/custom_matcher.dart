import 'dart:math';

import 'custom_gesture.dart';
import 'reference_bank.dart';

/// Recognises custom gestures (see "Custom gestures" in README.md). A custom gesture wins only when the live
/// window is (1) inside that gesture's own limit AND (2) closer to its recordings than to ANY
/// built-in example in the reference bank, including Rest. Otherwise the built-in model decides.
/// Validated on the real recordings in tools/eval_custom_matcher.py (95% hits, 0.2% false).
class CustomGestureMatcher {
  CustomGestureMatcher(
    List<CustomGesture> gestures, {
    List<List<double>> reference = kReferenceWindows,
    this.referenceLabels = kReferenceLabels,
    List<double> scales = kFeatureScales,
  }) : _scales = scales {
    _reference = [for (final w in reference) _scaled(w)];
    for (final g in gestures) {
      final perRecording = _windowsPerRecording(g);
      if (perRecording.length < 2) continue; // a limit needs at least 2 recordings
      _banks[g.label] = [for (final windows in perRecording) ...windows];
      _limits[g.label] = limitFactor * _largestLeaveOneOut(perRecording);
    }
  }

  /// "Close enough" = 1.5 x the largest distance between the gesture's own recordings.
  static const limitFactor = 1.5;

  final List<String> referenceLabels;
  final List<double> _scales;
  late final List<List<double>> _reference;
  final _banks = <String, List<List<double>>>{}; // custom label -> scaled windows
  final _limits = <String, double>{};

  bool get isEmpty => _banks.isEmpty;

  /// The matching custom gesture's label, or null (then the built-in model decides).
  String? match(List<double> features) {
    if (_banks.isEmpty) return null;
    final v = _scaled(features);
    String? best;
    var bestDistance = double.infinity;
    for (final MapEntry(key: label, value: bank) in _banks.entries) {
      final d = _nearest(v, bank).$1;
      if (d < bestDistance) {
        bestDistance = d;
        best = label;
      }
    }
    if (best == null || bestDistance >= _limits[best]!) return null;
    return bestDistance < _nearest(v, _reference).$1 ? best : null;
  }

  /// The built-in sign that [gesture] is too similar to, or null if it is fine.
  /// "Too similar" = most of its recordings are closer to a built-in example than to the
  /// gesture's other recordings, so live it would rarely win.
  String? tooSimilarTo(CustomGesture gesture) {
    final perRecording = _windowsPerRecording(gesture);
    if (perRecording.isEmpty) return null;
    final lostTo = <String>[];
    for (var i = 0; i < perRecording.length; i++) {
      final others = [
        for (var j = 0; j < perRecording.length; j++)
          if (j != i) ...perRecording[j]
      ];
      String? builtIn;
      var wins = false;
      for (final w in perRecording[i]) {
        final (dRef, refIndex) = _nearest(w, _reference);
        if (_nearest(w, others).$1 < dRef) {
          wins = true;
          break;
        }
        builtIn ??= referenceLabels[refIndex];
      }
      if (!wins) lostTo.add(builtIn!);
    }
    if (lostTo.length * 2 < perRecording.length) return null;
    final counts = <String, int>{};
    for (final l in lostTo) {
      counts[l] = (counts[l] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }

  List<List<List<double>>> _windowsPerRecording(CustomGesture g) => [
        for (final r in g.recordings) [for (final w in trainingWindows(r, moving: g.moving)) _scaled(w)]
      ];

  double _largestLeaveOneOut(List<List<List<double>>> perRecording) {
    var largest = 0.0;
    for (var i = 0; i < perRecording.length; i++) {
      final others = [
        for (var j = 0; j < perRecording.length; j++)
          if (j != i) ...perRecording[j]
      ];
      final closest = perRecording[i].map((w) => _nearest(w, others).$1).reduce(min);
      largest = max(largest, closest);
    }
    return largest;
  }

  List<double> _scaled(List<double> f) => [for (var i = 0; i < f.length; i++) f[i] / _scales[i]];

  /// (distance, index) of the nearest window in [bank].
  static (double, int) _nearest(List<double> v, List<List<double>> bank) {
    var best = double.infinity;
    var index = -1;
    for (var k = 0; k < bank.length; k++) {
      var sum = 0.0;
      for (var i = 0; i < v.length; i++) {
        final d = v[i] - bank[k][i];
        sum += d * d;
      }
      if (sum < best) {
        best = sum;
        index = k;
      }
    }
    return (sqrt(best), index);
  }
}
