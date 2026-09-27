import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:signsuara_app/glove/glove_session.dart';
import 'package:signsuara_app/ml/gesture_classifier.dart';

const _row = '862,938,719,611,575,159.31,35.13,33.50,1.21,0.07,-1.02';
List<int> _packet(Object seq, [String row = _row]) => utf8.encode('$seq,$row');

void main() {
  test('parses a glove packet', () {
    final p = GlovePacket.tryParse(_packet(42))!;
    expect(p.seq, 42);
    expect(p.row, hasLength(GestureClassifier.rowLength));
    expect(p.row.first, 862);
    expect(p.row.last, -1.02);
  });

  test('rejects broken packets', () {
    for (final bad in [
      '42,862,938,719,611,5', // cut to 20 bytes: MTU was not raised
      _row, // no seq
      '42,$_row,7', // too many values
      '42,862,938,719,611,575,nan,35.13,33.50,1.21,0.07,-1.02', // Arduino prints "nan"
      'x,$_row',
      '',
    ]) {
      expect(GlovePacket.tryParse(utf8.encode(bad)), isNull, reason: bad);
    }
  });

  test('counts rows lost between packets, skips broken ones', () {
    final s = GloveSession()..startStream();
    for (final seq in [10, 11, 12, 15, 16]) {
      s.addPacket(_packet(seq));
    }
    s.addPacket(utf8.encode('17,862,938'));
    expect(s.rows, 5);
    expect(s.dropped, 2);
    expect(s.badPackets, 1);
    expect(s.lastRow, hasLength(GestureClassifier.rowLength));
  });

  test('a new connection does not count the seq jump as dropped rows', () {
    final s = GloveSession()..startStream();
    s.addPacket(_packet(500));
    s.startStream(); // glove restarted and we reconnected: seq starts again at 0
    s.addPacket(_packet(0));
    expect(s.dropped, 0);
  });

  test('clearing the sentence empties the announced list', () {
    final s = GloveSession()..announced.addAll(['Saya', 'Nama']);
    s.clearAnnounced();
    expect(s.announced, isEmpty);
  });

  test('while recording (paused), rows reach listeners but nothing is recognised', () {
    final s = GloveSession()..startStream();
    s.recognitionPaused = true;
    final seen = <List<double>>[];
    s.addRowListener(seen.add);
    final lines = File('test/fixtures/Saya.csv').readAsLinesSync().skip(1).where((l) => l.trim().isNotEmpty);
    var seq = 0;
    for (final line in lines) {
      s.addPacket(_packet(seq++, line.trim()));
    }
    expect(seen, hasLength(seq));
    expect(s.announced, isEmpty);
    expect(s.current, isNull);

    s.removeRowListener(seen.add);
    s.recognitionPaused = false;
    s.addPacket(_packet(seq++));
    expect(seen, hasLength(seq - 1), reason: 'listener removed');
  });

  test('a custom match is announced like a built-in sign', () {
    final spoken = <String>[];
    final s = GloveSession(onGesture: spoken.add)
      ..customMatch = ((_) => 'custom:1')
      ..startStream();
    for (var i = 0; i < 50; i++) {
      s.addPacket(_packet(i));
    }
    expect(spoken, ['custom:1']);
  });

  test('dead motion sensor is reported', () {
    final s = GloveSession()..startStream();
    s.addPacket(_packet(1, '500,500,500,500,500,0.00,0.00,0.00,0.00,0.00,0.00'));
    expect(s.motionSensorOk, isFalse);
  });

  // The replay test again, but through the BLE packet path (text -> parse -> classifier).
  final fixtures = Directory('test/fixtures').listSync().whereType<File>()
      .where((f) => f.path.endsWith('.csv'));
  for (final file in fixtures) {
    final label = file.uri.pathSegments.last.replaceAll('.csv', '');

    test('replay $label as BLE packets', () {
      final spoken = <String>[];
      final s = GloveSession(onGesture: spoken.add)..startStream();
      final lines = file.readAsLinesSync().skip(1).where((l) => l.trim().isNotEmpty);
      var seq = 0;
      for (final line in lines) {
        s.addPacket(_packet(seq++, line.trim()));
      }

      expect(s.badPackets, 0);
      expect(s.current, label);
      expect(spoken, label == GestureClassifier.restLabel ? isEmpty : [label]);
      expect(s.announced, spoken);
    });
  }
}
