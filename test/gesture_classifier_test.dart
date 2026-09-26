import 'package:flutter_test/flutter_test.dart';
import 'package:signsuara_app/ml/gesture_classifier.dart';
import 'package:signsuara_app/ml/signsuara_model.dart';

// Fake model: the test decides what it "predicts", so each rule can be checked on its own.
const _labels = ['X', 'Y', 'Rest'];
const _x = [0.9, 0.1, 0.0];
const _y = [0.1, 0.9, 0.0];
const _rest = [0.0, 0.0, 1.0];

List<double> _row({bool dead = false}) => [
      500, 500, 500, 500, 500, // flex
      ...dead ? List.filled(6, 0.0) : [10.0, 20.0, 30.0, 0.1, 0.2, 0.3], // yaw..az
    ];

class _Harness {
  final announced = <String>[];
  final sensor = <bool>[];
  final predictedAtRow = <int>[];
  var rows = 0;
  var proba = _rest;

  late final classifier = GestureClassifier(
    onGesture: announced.add,
    onMotionSensor: sensor.add,
    labels: _labels,
    score: (_) {
      predictedAtRow.add(rows);
      return proba;
    },
  );

  void feed(int n, {bool dead = false}) {
    for (var i = 0; i < n; i++) {
      rows++;
      classifier.addRow(_row(dead: dead));
    }
  }

  /// Feed live rows until the classifier makes one prediction, which returns [p].
  void predict(List<double> p) {
    proba = p;
    final before = predictedAtRow.length;
    while (predictedAtRow.length == before) {
      feed(1);
    }
  }
}

void main() {
  test('no prediction until the buffer is full', () {
    final h = _Harness()..feed(kWindowSize - 1);
    expect(h.predictedAtRow, isEmpty);

    h.feed(GestureClassifier.predictEvery);
    expect(h.predictedAtRow, hasLength(1));
    expect(h.predictedAtRow.first, greaterThanOrEqualTo(kWindowSize));
  });

  test('predicts every 5 rows', () {
    final h = _Harness()..feed(kWindowSize + 50);
    expect(h.predictedAtRow.length, greaterThanOrEqualTo(10));
    for (final r in h.predictedAtRow) {
      expect(r % GestureClassifier.predictEvery, 0);
    }
    for (var i = 1; i < h.predictedAtRow.length; i++) {
      expect(h.predictedAtRow[i] - h.predictedAtRow[i - 1], GestureClassifier.predictEvery);
    }
  });

  test('confidence below 0.70 is ignored, exactly 0.70 counts', () {
    final h = _Harness();
    for (var i = 0; i < 4; i++) {
      h.predict([0.69, 0.31, 0.0]);
    }
    expect(h.announced, isEmpty);

    h
      ..predict([0.70, 0.30, 0.0])
      ..predict([0.70, 0.30, 0.0]);
    expect(h.announced, ['X']);
  });

  test('a label must win 2 predictions in a row', () {
    final h = _Harness()
      ..predict(_x)
      ..predict(_y)
      ..predict(_x)
      ..predict([0.5, 0.5, 0.0]) // not confident: breaks the streak
      ..predict(_x);
    expect(h.announced, isEmpty);

    h.predict(_x);
    expect(h.announced, ['X']);
  });

  test('same label is not announced again, a new one is', () {
    final h = _Harness();
    for (var i = 0; i < 6; i++) {
      h.predict(_x);
    }
    expect(h.announced, ['X']);

    h
      ..predict(_y)
      ..predict(_y)
      ..predict(_x)
      ..predict(_x);
    expect(h.announced, ['X', 'Y', 'X']);
  });

  test('Rest is never announced, but lets the same word be signed again', () {
    final h = _Harness()
      ..predict(_rest)
      ..predict(_rest);
    expect(h.announced, isEmpty);
    expect(h.classifier.current, 'Rest');

    h
      ..predict(_x)
      ..predict(_x)
      ..predict(_rest)
      ..predict(_rest)
      ..predict(_x)
      ..predict(_x);
    expect(h.announced, ['X', 'X']);
  });

  test('dead motion sensor: no predictions until the window is clean again', () {
    final h = _Harness()..feed(kWindowSize + 5);
    final before = h.predictedAtRow.length;

    h.feed(20, dead: true);
    expect(h.sensor, [false]);
    expect(h.classifier.motionSensorOk, isFalse);
    expect(h.predictedAtRow.length, before, reason: 'must not predict on zeros');

    final lastDeadRow = h.rows;
    h.feed(1);
    expect(h.sensor, [false, true]);

    h.feed(kWindowSize + 10);
    final after = h.predictedAtRow.sublist(before);
    expect(after, isNotEmpty);
    expect(after.first, greaterThan(lastDeadRow + kWindowSize - 1),
        reason: 'dead rows must have left the window first');
  });

  test('dead sensor resets the 2-in-a-row streak', () {
    final h = _Harness()..predict(_x);
    h.feed(GestureClassifier.predictEvery, dead: true);
    h.predict(_x);
    expect(h.announced, isEmpty);
  });

  test('a row with the wrong number of values is rejected', () {
    expect(() => _Harness().classifier.addRow([1, 2, 3]), throwsArgumentError);
  });
}
