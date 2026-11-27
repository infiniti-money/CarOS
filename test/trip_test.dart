import 'package:flutter_test/flutter_test.dart';
import 'package:infiniti_caros/trip.dart';

void main() {
  test('GPS freshness rejects stale and future timestamps', () {
    final now = DateTime.utc(2026, 11, 27);
    expect(isFreshGps(now, now), isTrue);
    expect(isFreshGps(now.subtract(const Duration(seconds: 10)), now), isTrue);
    expect(isFreshGps(now.subtract(const Duration(seconds: 11)), now), isFalse);
    expect(isFreshGps(now.add(const Duration(seconds: 3)), now), isFalse);
  });
  test('invalid trip history is rejected without crashing', () {
    expect(decodeTrip('broken'), isNull);
    expect(decodeTrip('[]'), isNull);
    expect(decodeTrip('{"start":"2026-11-27","seconds":12,"meters":4}'), isNotNull);
    expect(decodeTrip('{"start":"2026-11-27","seconds":-1,"meters":4}'), isNull);
    expect(decodeTrip('{"start":"2026-11-27","seconds":12,"meters":"bad"}'), isNull);
  });
  test('GPS speed conversion and invalid values', () {
    expect(speedKmh(10), 36);
    expect(speedKmh(0), 0);
    expect(speedKmh(-1), isNull);
    expect(speedKmh(double.nan), isNull);
  });
}
