import 'package:flutter_test/flutter_test.dart';
import 'package:infiniti_caros/car_connection.dart';

void main() {
  test('unsupported categories fail closed on both platforms', () {
    expect(carCategory('audio', ios: true), CarCategory.audio);
    expect(carCategory('driving-task', ios: true), CarCategory.drivingTask);
    expect(carCategory('poi', ios: false), CarCategory.poi);
    expect(carCategory('audio', ios: false), CarCategory.unavailable);
    expect(carCategory('navigation', ios: true), CarCategory.unavailable);
    expect(carCategory(null, ios: true), CarCategory.unavailable);
  });
  test('radio sources reject insecure or credential-bearing URLs', () {
    expect(carAudioUri('https://example.org/live'), isNotNull);
    expect(carAudioUri('http://example.org/live'), isNull);
    expect(carAudioUri('https://user:pass@example.org/live'), isNull);
    expect(carAudioUri(''), isNull);
  });
  test('parking data is validated and coordinates stay private', () {
    expect(parkingSummary(null), contains('Chưa lưu'));
    expect(parkingSummary('{"lat":21.123456,"lon":105.123456}'), contains('Đã lưu'));
    expect(parkingSummary('{"lat":21.123456,"lon":105.123456}'), isNot(contains('21.123456')));
    expect(parkingSummary('{"lat":91,"lon":105}'), contains('không hợp lệ'));
    expect(parkingSummary('invalid'), contains('không hợp lệ'));
  });
}
