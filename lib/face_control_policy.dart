// A fresh slow GPS sample is a conservative gate, not proof of parking.
bool faceControlAllowed({required double speed, required double accuracy,
    required double speedAccuracy, required DateTime fix, required DateTime now}) {
  final age = now.difference(fix);
  return speed.isFinite && speed >= 0 && speed <= 0.3 &&
      accuracy.isFinite && accuracy > 0 && accuracy <= 20 &&
      speedAccuracy.isFinite && speedAccuracy >= 0 && speedAccuracy <= 1 &&
      age >= const Duration(seconds: -1) && age <= const Duration(seconds: 4);
}

class HeadTurnGate {
  int centered = 0, turned = 0;
  bool armed = false;
  bool update(double? yaw) {
    if (yaw == null || !yaw.isFinite) {
      reset();
      return false;
    }
    if (yaw.abs() <= 0.12) {
      turned = 0;
      if (++centered >= 2) armed = true;
    } else if (yaw.abs() >= 0.32 && armed) {
      centered = 0;
      if (++turned >= 2) {
        reset();
        return true;
      }
    } else {
      centered = 0;
      turned = 0;
    }
    return false;
  }

  void reset() {
    centered = 0;
    turned = 0;
    armed = false;
  }
}
