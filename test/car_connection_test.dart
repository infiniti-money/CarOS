import 'package:flutter_test/flutter_test.dart';
import 'package:infiniti_caros/car_connection.dart';

void main() {
  test('parking data is validated and coordinates stay private', () {
    expect(parkingSummary(null), contains('Chưa lưu'));
    expect(parkingSummary('{"lat":21.123456,"lon":105.123456}'), contains('Đã lưu'));
    expect(parkingSummary('{"lat":21.123456,"lon":105.123456}'), isNot(contains('21.123456')));
    expect(parkingSummary('{"lat":91,"lon":105}'), contains('không hợp lệ'));
    expect(parkingSummary('invalid'), contains('không hợp lệ'));
  });
}
