import 'package:flutter_test/flutter_test.dart';
import 'package:signsuara_app/ui/finger_bend.dart';

List<double> _row(List<double> fingers) => [...fingers, 10, 20, 30, 0.1, 0.2, 0.3];

void main() {
  test('straight fingers read 0, fully bent fingers read 1 (straight = HIGH, bent = LOW)', () {
    expect(fingerBend(_row([950, 976, 830, 741, 768])), [0, 0, 0, 0, 0]);
    expect(fingerBend(_row([602, 555, 573, 509, 507])), [1, 1, 1, 1, 1]);
  });

  test('halfway between straight and bent reads 0.5', () {
    expect(fingerBend(_row([776, 765.5, 701.5, 625, 637.5])), [0.5, 0.5, 0.5, 0.5, 0.5]);
  });

  test('values outside the range are clamped, e.g. a 4095 thumb spike reads straight', () {
    expect(fingerBend(_row([4095, 400, 900, 300, 1000])), [0, 1, 0, 1, 0]);
  });

  test('no glove data yet: all fingers read straight', () {
    expect(fingerBend(null), [0, 0, 0, 0, 0]);
  });
}
