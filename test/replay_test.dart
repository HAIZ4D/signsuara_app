import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:signsuara_app/ml/gesture_classifier.dart';
import 'package:signsuara_app/ml/signsuara_model.dart';

// Replays real glove recordings (test/fixtures/<label>.csv, 25 Hz) row by row
// through the REAL model and checks what the classifier announces.
void main() {
  const header = 'thumb,index,middle,ring,pinky,yaw,pitch,roll,ax,ay,az';
  final fixtures = Directory('test/fixtures')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.csv'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('fixtures exist', () => expect(fixtures, isNotEmpty));

  for (final file in fixtures) {
    final label = file.uri.pathSegments.last.replaceAll('.csv', '');

    test('replay $label', () {
      expect(kLabels, contains(label));
      final lines = file.readAsLinesSync().where((l) => l.trim().isNotEmpty).toList();
      expect(lines.first.trim(), header);

      final announced = <String>[];
      final classifier = GestureClassifier(onGesture: announced.add);
      for (final line in lines.skip(1)) {
        classifier.addRow(line.split(',').map((v) => double.parse(v.trim())).toList());
      }

      expect(classifier.current, label);
      expect(announced, label == GestureClassifier.restLabel ? isEmpty : [label]);
    });
  }
}
