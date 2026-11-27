import 'trip.dart' show isFreshGps;

String? locationMessage({required double latitude, required double longitude,
    required double accuracy, required DateTime fix, required DateTime now}) {
  if (!isFreshGps(fix, now) || !latitude.isFinite || latitude.abs() > 90 ||
      !longitude.isFinite || longitude.abs() > 180 ||
      !accuracy.isFinite || accuracy <= 0 || accuracy > 50) {
    return null;
  }
  final lat = latitude.toStringAsFixed(5);
  final lon = longitude.toStringAsFixed(5);
  final link = Uri.https('www.google.com', '/maps/search/', {
    'api': '1', 'query': '$lat,$lon',
  });
  return 'Vị trí của tôi (GPS, sai số ước tính ${accuracy.ceil()} m): $lat, $lon\n'
      'Thời điểm: ${fix.toLocal().toIso8601String()}\n$link';
}
