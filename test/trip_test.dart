import 'package:flutter_test/flutter_test.dart';
import 'package:infiniti_caros/trip.dart';

void main() {
  test('GPS speed conversion and invalid values', () {
    expect(speedKmh(10), 36);
    expect(speedKmh(0), 0);
    expect(speedKmh(-1), isNull);
    expect(speedKmh(double.nan), isNull);
  });
}
