import 'package:flutter_test/flutter_test.dart';
import 'package:infiniti_caros/communication.dart';

void main() {
  test('Vietnamese commands only match supported intents', () {
    expect(parseVoice(' MỞ   BẢN ĐỒ '), VoiceAction.map);
    expect(parseVoice('mở danh bạ'), VoiceAction.phone);
    expect(parseVoice('xem lịch'), VoiceAction.calendar);
    expect(parseVoice('mở nhạc'), VoiceAction.music);
    expect(parseVoice('gọi ngay 0123456789'), VoiceAction.unknown);
  });
  test('dial rejects invalid input and service codes', () {
    expect(safeDialNumber('+84 912-345-678'), '+84912345678');
    expect(safeDialNumber('*123#'), isNull);
    expect(safeDialNumber('tel:123'), isNull);
    expect(safeDialNumber(''), isNull);
  });
}
