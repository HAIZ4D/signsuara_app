import 'dart:collection';

import 'features.dart';
import 'signsuara_model.dart';

/// Turns raw glove rows into announced gestures, following the
/// "Live prediction rules" in CLAUDE.md (same behaviour as live_v2.py).
/// Knows nothing about BLE: whoever reads the glove just calls [addRow].
class GestureClassifier {
  GestureClassifier({
    required this.onGesture,
    this.onMotionSensor,
    this.labels = kLabels,
    this.score = signsuaraScore,
  });

  static const rowLength = 11; // thumb, index, middle, ring, pinky, yaw, pitch, roll, ax, ay, az
  static const predictEvery = 5; // rows = 0.2 s at 25 Hz
  static const minConfidence = 0.70;
  static const restLabel = 'Rest';

  /// Called when a new gesture is accepted (never for Rest, never twice in a row).
  final void Function(String label) onGesture;

  /// Called when the motion sensor drops out (false) or comes back (true).
  final void Function(bool connected)? onMotionSensor;

  /// Model labels and scorer. Only replaced in unit tests.
  final List<String> labels;
  final List<double> Function(List<double> features) score;

  final _buffer = ListQueue<List<double>>();
  var _rowCount = 0;
  String? _previous; // last prediction, null if not confident
  String? _accepted; // last accepted label, including Rest
  var _sensorOk = true;

  /// Last accepted label (including Rest), or null before the first one.
  String? get current => _accepted;
  bool get motionSensorOk => _sensorOk;

  void addRow(List<double> row) {
    if (row.length != rowLength) {
      throw ArgumentError('Expected $rowLength values, got ${row.length}');
    }

    final ok = !_isDead(row);
    if (ok != _sensorOk) {
      _sensorOk = ok;
      onMotionSensor?.call(ok);
    }

    _buffer.addLast(row);
    if (_buffer.length > kWindowSize) _buffer.removeFirst();
    _rowCount++;
    if (_buffer.length < kWindowSize || _rowCount % predictEvery != 0) return;

    // A dead BNO055 sends zeros, and the model gives confident WRONG answers on
    // zeros, so never predict while any row in the window is dead.
    if (_buffer.any(_isDead)) {
      _previous = null;
      return;
    }

    final proba = score(extractFeatures(_buffer.toList()));
    var best = 0;
    for (var i = 1; i < proba.length; i++) {
      if (proba[i] > proba[best]) best = i;
    }
    final label = proba[best] >= minConfidence ? labels[best] : null;

    // Stability filter: the same confident label must win 2 predictions in a row.
    final stable = label != null && label == _previous;
    _previous = label;
    if (!stable || label == _accepted) return;

    _accepted = label;
    if (label != restLabel) onGesture(label);
  }

  /// yaw, pitch, roll, ax, ay, az all exactly 0 = the BNO055 has dropped out.
  static bool _isDead(List<double> row) => row.skip(5).every((v) => v == 0);
}
