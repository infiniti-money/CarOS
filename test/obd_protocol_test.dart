import 'package:flutter_test/flutter_test.dart';
import 'package:infiniti_caros/obd_protocol.dart';

void main() {
  test('real Mode 01 byte formulas', () {
    expect(decodeObd(ObdPid.rpm, '41 0C 1A F8\r>'), 1726);
    expect(decodeObd(ObdPid.speed, '410D3C'), 60);
    expect(decodeObd(ObdPid.coolant, '41057B'), 83);
    expect(decodeObd(ObdPid.fuel, '412FFF'), 100);
    expect(decodeObd(ObdPid.voltage, '414236B0'), 14);
  });
  test('missing, wrong, conflicting and truncated responses stay unavailable', () {
    for (final raw in ['NO DATA', '410C1234', '410D', '410DZZ', '410D01\r410D02']) {
      expect(decodeObd(ObdPid.speed, raw), isNull);
    }
    expect(decodeObd(ObdPid.speed, '410D00'), 0);
    expect(decodeObd(ObdPid.speed, '010D\r410D3C\r410D3C'), 60);
  });
  test('split BLE notifications are bounded and framed at prompt', () {
    final f = ObdFrame();
    expect(f.append([52, 49]), isNull);
    expect(f.append([48, 68, 51, 67, 62]), '410D3C');
    expect(() => f.append(List.filled(4097, 65)), throwsFormatException);
    expect(f.append([62]), '');
  });
  test('only setup and read commands are allowed; stale sample rejected', () {
    expect(allowedObdCommands.contains('04'), isFalse);
    expect(allowedObdCommands.contains('2E'), isFalse);
    expect(allowedObdCommands.contains('ATSH7E0'), isFalse);
    final now = DateTime(2026, 11, 27);
    expect(ObdSample(0, now).fresh(now), isTrue);
    expect(ObdSample(0, now).fresh(now.add(const Duration(seconds: 13))), isFalse);
    expect(ObdSample(0, now).fresh(now.subtract(const Duration(seconds: 1))), isFalse);
  });
}
