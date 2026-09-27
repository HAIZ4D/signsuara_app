import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:signsuara_app/custom/custom_gesture.dart';
import 'package:signsuara_app/custom/custom_matcher.dart';
import 'package:signsuara_app/custom/reference_bank.dart';
import 'package:signsuara_app/ml/features.dart';
import 'package:signsuara_app/ml/signsuara_model.dart';

List<List<double>> _csv(String path) => [
      for (final line in File(path).readAsLinesSync().skip(1))
        if (line.trim().isNotEmpty) [for (final v in line.split(',')) double.parse(v.trim())]
    ];

/// Windows exactly as GestureClassifier sees them live: every 5 rows once the buffer is full.
List<List<double>> _liveWindows(List<List<double>> rows) => [
      for (var end = kWindowSize; end <= rows.length; end++)
        if (end % 5 == 0) extractFeatures(rows.sublist(end - kWindowSize, end))
    ];

/// Live rule: announced when the custom gesture wins 2 predictions in a row.
bool _announced(CustomGestureMatcher m, List<List<double>> rows, String label) {
  final wins = [for (final w in _liveWindows(rows)) m.match(w) == label];
  for (var i = 1; i < wins.length; i++) {
    if (wins[i] && wins[i - 1]) return true;
  }
  return false;
}

bool _same(List<double> a, List<double> b) {
  for (var i = 0; i < a.length; i++) {
    if ((a[i] - b[i]).abs() > 1e-6) return false;
  }
  return true;
}

/// Reference bank without [dropLabel] (it must be "new") and without the windows of the
/// recording being tested (it must not match itself) — the same fair test as the Python script.
CustomGestureMatcher _matcher(List<CustomGesture> gestures,
    {String? dropLabel, List<List<double>> tested = const [], bool testedMoving = false}) {
  final own = trainingWindows(tested, moving: testedMoving);
  final keep = [
    for (var i = 0; i < kReferenceWindows.length; i++)
      if (kReferenceLabels[i] != dropLabel && !own.any((w) => _same(w, kReferenceWindows[i]))) i
  ];
  return CustomGestureMatcher(gestures,
      reference: [for (final i in keep) kReferenceWindows[i]],
      referenceLabels: [for (final i in keep) kReferenceLabels[i]]);
}

CustomGesture _gesture(List<List<List<double>>> recordings, {bool moving = true}) => CustomGesture(
    id: 'test', malay: 'Saya lapar', english: 'I am hungry', moving: moving, recordings: recordings);

void main() {
  final nama = [
    _csv('test/fixtures/Nama.csv'),
    for (var i = 1; i <= 5; i++) _csv('test/fixtures/custom_nama/$i.csv'),
  ];

  test('reference bank matches the model (regenerate with export.py if this fails)', () {
    expect(kReferenceLabels.toSet(), kLabels.toSet());
    expect(kReferenceWindows, hasLength(kReferenceLabels.length));
    expect(kReferenceWindows.every((w) => w.length == kFeatureNames.length), isTrue);
    expect(kFeatureScales, hasLength(kFeatureNames.length));
    expect(kFeatureScales.every((s) => s > 0), isTrue);
  });

  test('windows are chosen exactly like train_v2.py', () {
    // Peaks computed by pandas acc.rolling(5, center=True).mean().idxmax() on the fixtures.
    expect(accPeak(_csv('test/fixtures/Nama.csv')), 38);
    expect(accPeak(_csv('test/fixtures/TerimaKasih.csv')), 23);
    expect(accPeak(_csv('test/fixtures/A.csv')), 13);

    final a = _csv('test/fixtures/A.csv');
    expect(trainingWindows(a, moving: false), [extractFeatures(a.sublist(a.length - kWindowSize))]);
    expect(trainingWindows(nama.first, moving: true), hasLength(5));
  });

  test('bank windows are the same as the Dart windows (Python and Dart agree)', () {
    for (final w in trainingWindows(_csv('test/fixtures/A.csv'), moving: false)) {
      expect(kReferenceWindows.any((r) => _same(r, w)), isTrue);
    }
  });

  test('a new gesture is recognised in held-out recordings (leave-one-out, 6 Nama recordings)', () {
    var hits = 0;
    for (var i = 0; i < nama.length; i++) {
      final g = _gesture([for (var j = 0; j < nama.length; j++) if (j != i) nama[j]]);
      final m = _matcher([g], dropLabel: 'Nama', tested: nama[i], testedMoving: true);
      if (_announced(m, nama[i], g.label)) hits++;
    }
    expect(hits, greaterThanOrEqualTo(5), reason: 'found in $hits of 6 held-out recordings');
  });

  test('the custom gesture is never announced during other signs or Rest', () {
    final g = _gesture(nama.sublist(1));
    for (final (name, moving) in [('A', false), ('B', false), ('Rest', false), ('Saya', false), ('TerimaKasih', true)]) {
      final rows = _csv('test/fixtures/$name.csv');
      final m = _matcher([g], dropLabel: 'Nama', tested: rows, testedMoving: moving);
      expect(_announced(m, rows, g.label), isFalse, reason: name);
    }
  });

  test('warns when a custom gesture looks like a built-in sign', () {
    final g = _gesture(nama.sublist(1));
    expect(CustomGestureMatcher(const []).tooSimilarTo(g), 'Nama'); // Nama IS a built-in sign
    expect(_matcher(const [], dropLabel: 'Nama').tooSimilarTo(g), isNull); // as if Nama were new
  });

  test('no custom gestures, or only 1 recording: never matches', () {
    final window = _liveWindows(nama.first).first;
    expect(CustomGestureMatcher(const []).match(window), isNull);
    expect(_matcher([_gesture([nama.first])], dropLabel: 'Nama').match(window), isNull);
  });

  test('custom gesture survives saving and loading (JSON)', () {
    final g = _gesture(nama.sublist(1, 3), moving: false);
    final back = CustomGesture.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>);
    expect([back.id, back.malay, back.english, back.moving], [g.id, g.malay, g.english, g.moving]);
    expect(back.recordings, g.recordings);
    expect(back.label, 'custom:test');
    expect(back.words.english, 'I am hungry');
  });
}
