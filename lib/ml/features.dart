import 'dart:math';

/// One raw glove row: thumb,index,middle,ring,pinky,yaw,pitch,roll,ax,ay,az
/// Must stay IDENTICAL to features.py in signsuara_ml.
List<double> extractFeatures(List<List<double>> window) {
  final channels = <List<double>>[
    for (var i = 0; i < 5; i++) [for (final r in window) r[i]], // 5 flex
    [for (final r in window) r[6]], // pitch
    [for (final r in window) r[7]], // roll
    [for (final r in window) sqrt(r[8] * r[8] + r[9] * r[9] + r[10] * r[10])], // acc
  ];

  final out = <double>[];
  for (final v in channels) {
    final n = v.length;
    final mean = v.reduce((a, b) => a + b) / n;
    final variance = v.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) / n;
    out
      ..add(mean)
      ..add(v.reduce(min))
      ..add(v.reduce(max))
      ..add(sqrt(variance))
      ..add((v[n - 1] + v[n - 2] + v[n - 3]) / 3 - (v[0] + v[1] + v[2]) / 3);
  }
  return out;
}