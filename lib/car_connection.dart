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
