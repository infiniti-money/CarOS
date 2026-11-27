import 'dart:convert';

String parkingSummary(String? raw) {
  if (raw == null) return 'Chưa lưu vị trí trên điện thoại';
  try {
    final data = jsonDecode(raw);
    if (data is! Map) return 'Vị trí không hợp lệ';
    final lat = data['lat'], lon = data['lon'];
    if (lat is! num || lon is! num || !lat.isFinite || !lon.isFinite ||
        lat.abs() > 90 || lon.abs() > 180) {
      return 'Vị trí không hợp lệ';
    }
    // Do not expose precise coordinates on the shared car display.
    return 'Đã lưu vị trí trên điện thoại • Chạm để cập nhật';
  } catch (_) {
    return 'Vị trí không hợp lệ';
  }
}

enum CarCategory { drivingTask, audio, poi, unavailable }

CarCategory carCategory(String? configured, {required bool ios}) {
  if (ios && configured == 'driving-task') return CarCategory.drivingTask;
  if (ios && configured == 'audio') return CarCategory.audio;
  if (!ios && configured == 'poi') return CarCategory.poi;
  return CarCategory.unavailable;
}

Uri? carAudioUri(String raw) {
  final uri = Uri.tryParse(raw);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty ||
      uri.userInfo.isNotEmpty || uri.hasFragment) {
    return null;
  }
  return uri;
}

// Keep a loading lease until its owner finishes, even if stop invalidates it.
// A new connection cannot start playback while an earlier load/stop is pending.
class CarAudioGate {
  int _epoch = 0;
  int? _loading;
  int _stops = 0;
  bool _disposed = false;

  int? beginPlay({required bool connected}) {
    if (_disposed || !connected || _loading != null || _stops != 0) return null;
    return _loading = ++_epoch;
  }

  bool current(int token, {required bool connected}) =>
      !_disposed && connected && token == _epoch && _stops == 0;

  void finishPlay(int token) {
    if (_loading == token) _loading = null;
  }

  void beginStop() {
    _epoch++;
    _stops++;
  }

  void finishStop() {
    if (_stops > 0) _stops--;
  }

  void dispose() {
    _disposed = true;
    _epoch++;
  }
}
