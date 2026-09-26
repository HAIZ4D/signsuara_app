import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:signsuara_app/ml/features.dart';
import 'package:signsuara_app/ml/signsuara_model.dart';

List<double> _nums(List l) => l.map((x) => (x as num).toDouble()).toList();

void main() {
  final data = jsonDecode(File('test/parity_cases.json').readAsStringSync());

  test('labels match', () {
    expect(List<String>.from(data['labels']), kLabels);
  });

  for (final c in data['cases']) {
    test('Python = Dart for ${c['label']}', () {
      final rows = [for (final r in c['rows']) _nums(r)];
      final features = extractFeatures(rows);
      final expected = _nums(c['features']);
      expect(features.length, kFeatureNames.length);

      for (var i = 0; i < features.length; i++) {
        expect(features[i], closeTo(expected[i], 1e-6), reason: kFeatureNames[i]);
      }
      final proba = signsuaraScore(features);
      final expectedProba = _nums(c['proba']);
      expect(proba.length, kLabels.length);
      for (var i = 0; i < proba.length; i++) {
        expect(proba[i], closeTo(expectedProba[i], 1e-9), reason: kLabels[i]);
      }
    });
  }
}