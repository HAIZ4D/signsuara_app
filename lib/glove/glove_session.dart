import 'package:flutter/foundation.dart';

import '../ml/gesture_classifier.dart';

/// One BLE notification from the glove: "seq,thumb,index,...,az" as text
/// (see "BLE protocol" in README.md).
class GlovePacket {
  const GlovePacket(this.seq, this.row);

  final int seq; // row number since the glove powered on
  final List<double> row; // the 11 values, same order as USB Serial

  /// Returns null for a broken packet, e.g. one cut short because the MTU is too small.
  static GlovePacket? tryParse(List<int> bytes) {
    final parts = String.fromCharCodes(bytes).trim().split(',');
    if (parts.length != GestureClassifier.rowLength + 1) return null;
    final seq = int.tryParse(parts.first);
    final row = [for (final p in parts.skip(1)) double.tryParse(p)];
    if (seq == null || row.any((v) => v == null || !v.isFinite)) return null;
    return GlovePacket(seq, [for (final v in row) v!]);
  }
}

enum GloveLink { disconnected, busy, connected }

/// Everything between "a BLE notification arrived" and "a gesture was recognised".
/// Knows nothing about Bluetooth itself, so it can be tested without the glove.
class GloveSession extends ChangeNotifier {
  GloveSession({this.onGesture});

  /// Called for every announced gesture (text-to-speech will hook in here).
  final void Function(String label)? onGesture;

  String status = 'Not connected';
  GloveLink link = GloveLink.disconnected;
  final announced = <String>[];
  bool motionSensorOk = true;
  List<double>? lastRow;
  int rows = 0, dropped = 0, badPackets = 0;

  /// Custom-gesture matcher, asked before the built-in model. Set by the home page.
  String? Function(List<double> features)? customMatch;

  late GestureClassifier _classifier = _newClassifier();
  int? _lastSeq;
  var _paused = false;
  final _rowListeners = <void Function(List<double> row)>[];

  /// While true (recording a custom gesture) rows are only passed to row listeners.
  bool get recognitionPaused => _paused;
  set recognitionPaused(bool value) {
    _paused = value;
    if (!value) _classifier = _newClassifier(); // fresh window: no recording rows in it
  }

  void addRowListener(void Function(List<double> row) listener) => _rowListeners.add(listener);
  void removeRowListener(void Function(List<double> row) listener) => _rowListeners.remove(listener);

  /// Last accepted label (including Rest), or null.
  String? get current => _classifier.current;

  void setStatus(String text, {required GloveLink link}) {
    status = text;
    this.link = link;
    notifyListeners();
  }

  void clearAnnounced() {
    announced.clear();
    notifyListeners();
  }

  /// Call at every (re)connection, so rows from before never mix with new ones.
  void startStream() {
    _classifier = _newClassifier();
    _lastSeq = null;
    motionSensorOk = true;
    notifyListeners();
  }

  void addPacket(List<int> bytes) {
    final packet = GlovePacket.tryParse(bytes);
    if (packet == null) {
      badPackets++;
    } else {
      final last = _lastSeq;
      if (last != null && packet.seq > last + 1) dropped += packet.seq - last - 1;
      _lastSeq = packet.seq;
      rows++;
      lastRow = packet.row;
      if (!_paused) _classifier.addRow(packet.row);
      for (final listener in [..._rowListeners]) {
        listener(packet.row);
      }
    }
    notifyListeners();
  }

  GestureClassifier _newClassifier() => GestureClassifier(
        onGesture: (label) {
          announced.add(label);
          onGesture?.call(label);
        },
        onMotionSensor: (ok) => motionSensorOk = ok,
        customMatch: (features) => customMatch?.call(features),
      );
}
