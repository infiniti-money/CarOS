import 'package:flutter_test/flutter_test.dart';
import 'package:infiniti_caros/face_control_policy.dart';

void main() {
  test('GPS gate rejects motion, stale or uncertain data', () {
    final now = DateTime.utc(2026, 11, 27);
    bool check(double speed, double accuracy, double speedAccuracy, DateTime fix) =>
      faceControlAllowed(speed: speed, accuracy: accuracy, speedAccuracy: speedAccuracy, fix: fix, now: now);
    expect(check(0, 5, 0.2, now), isTrue);
    expect(check(1, 5, 0.2, now), isFalse);
    expect(check(0, 50, 0.2, now), isFalse);
    expect(check(0, 5, -1, now), isFalse);
    expect(check(0, 5, 0.2, now.subtract(const Duration(seconds: 5))), isFalse);
  });
  test('head-turn requires two center and two turn samples, then rearming', () {
    final gate = HeadTurnGate();
    expect(gate.update(0.5), isFalse);
    expect(gate.update(0), isFalse);
    expect(gate.update(0), isFalse);
    expect(gate.update(0.4), isFalse);
    expect(gate.update(0.4), isTrue);
    expect(gate.update(0.4), isFalse);
    gate.update(0);
    gate.update(0);
    gate.update(null);
    expect(gate.update(0.4), isFalse);
  });
}
