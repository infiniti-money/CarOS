import 'package:flutter_test/flutter_test.dart';
import 'package:infiniti_caros/safety_policy.dart';

void main() {
  final now = DateTime.utc(2026, 11, 27);
  String? make({double lat = 21, double lon = 105, double accuracy = 10, DateTime? time}) =>
    locationMessage(latitude: lat, longitude: lon, accuracy: accuracy, fix: time ?? now, now: now);

  test('fresh valid location produces preview and HTTPS link', () {
    final text = make();
    expect(text, contains('21.00000, 105.00000'));
    expect(text, contains('https://www.google.com/maps/search/'));
  });
  test('stale, future, inaccurate and invalid locations rejected', () {
    expect(make(time: now.subtract(const Duration(seconds: 11))), isNull);
    expect(make(time: now.add(const Duration(seconds: 3))), isNull);
    expect(make(accuracy: 51), isNull);
    expect(make(accuracy: 0), isNull);
    expect(make(lat: double.nan), isNull);
    expect(make(lon: 181), isNull);
  });
}
