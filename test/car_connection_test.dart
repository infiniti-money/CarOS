import 'package:flutter_test/flutter_test.dart';
import 'package:infiniti_caros/car_connection.dart';

void main() {
  test('duplicate play cannot release another loading lease', () {
    final gate = CarAudioGate();
    final first = gate.beginPlay(connected: true)!;
    expect(gate.beginPlay(connected: true), isNull);
    gate.finishPlay(first + 1);
    expect(gate.beginPlay(connected: true), isNull);
    gate.finishPlay(first);
    expect(gate.beginPlay(connected: true), isNotNull);
  });
  test('stop invalidates load and reconnect waits until both operations finish', () {
    final gate = CarAudioGate();
    final first = gate.beginPlay(connected: true)!;
    gate.beginStop();
    expect(gate.current(first, connected: true), isFalse);
    expect(gate.beginPlay(connected: true), isNull);
    gate.finishStop();
    expect(gate.beginPlay(connected: true), isNull);
    gate.finishPlay(first);
    final next = gate.beginPlay(connected: true)!;
    expect(gate.current(first, connected: true), isFalse);
    expect(gate.current(next, connected: true), isTrue);
  });
  test('disconnect, overlapping stops and disposal invalidate playback', () {
    final gate = CarAudioGate();
    expect(gate.beginPlay(connected: false), isNull);
    final token = gate.beginPlay(connected: true)!;
    expect(gate.current(token, connected: false), isFalse);
    gate.beginStop();
    gate.beginStop();
    gate.finishPlay(token);
    gate.finishStop();
    expect(gate.beginPlay(connected: true), isNull);
    gate.finishStop();
    final next = gate.beginPlay(connected: true)!;
    gate.dispose();
    expect(gate.current(next, connected: true), isFalse);
    expect(gate.beginPlay(connected: true), isNull);
  });
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
