import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:infiniti_caros/navigation.dart';

void main() {
  test('night tiles use independent provider and attribution; fallback is day', () {
    const day = MapTileSource('https://day.example.org/{z}/{x}/{y}.png', 'Day credit');
    const night = MapTileSource('https://night.example.org/{z}/{x}/{y}.png', 'Night credit');
    const invalid = MapTileSource('', '');
    expect(selectMapTiles(night: true, daySource: day, nightSource: night)?.attribution, 'Night credit');
    expect(selectMapTiles(night: false, daySource: day, nightSource: night)?.template, day.template);
    expect(selectMapTiles(night: true, daySource: day, nightSource: invalid)?.template, day.template);
    expect(selectMapTiles(night: false, daySource: invalid, nightSource: night), isNull);
  });
  test('tile providers require HTTPS, placeholders and attribution', () {
    expect(const MapTileSource('http://example.org/{z}/{x}/{y}.png', 'Credit').valid, isFalse);
    expect(const MapTileSource('https://example.org/tile.png', 'Credit').valid, isFalse);
    expect(const MapTileSource('https://example.org/{z}/{x}/{y}.png', '').valid, isFalse);
    expect(const MapTileSource('https://user:secret@example.org/{z}/{x}/{y}.png', 'Credit').valid, isFalse);
  });
  test('remaining estimate follows route fraction rather than straight-line distance', () {
    const route = RoutePlan([LatLng(21,105.8), LatLng(21,105.9)], 10000, 600, []);
    final result = estimateRouteProgress(const LatLng(21,105.85), route)!;
    expect(result.remainingMeters, closeTo(5000, 1));
    expect(result.remainingSeconds, closeTo(300, 1));
    expect(estimateRouteProgress(const LatLng(21,105.9), route)!.remainingMeters, closeTo(0, 1));
  });
  test('off-route, degenerate or ambiguous loop does not show an estimate', () {
    const route = RoutePlan([LatLng(21,105.8), LatLng(21,105.9)], 10000, 600, []);
    expect(estimateRouteProgress(const LatLng(21.01,105.85), route), isNull);
    const repeated = RoutePlan([LatLng(21,105.8), LatLng(21,105.8)], 100, 10, []);
    expect(estimateRouteProgress(const LatLng(21,105.8), repeated), isNull);
    const loop = RoutePlan([LatLng(21,105.8), LatLng(21,105.9), LatLng(21,105.8)], 20000, 1200, []);
    expect(estimateRouteProgress(const LatLng(21,105.85), loop), isNull);
  });
  test('Vietnamese turns and roundabout exit', () {
    expect(vietnameseTurn('turn','left','Lê Lợi',null), 'Rẽ trái vào Lê Lợi');
    expect(vietnameseTurn('roundabout','','',2), 'Ra khỏi vòng xuyến tại lối thứ 2');
  });
  test('offset measures nearest segment, not only vertices', () {
    expect(routeOffset(const LatLng(21,105.85), const [LatLng(21,105.8),LatLng(21,105.9)]), lessThan(1));
  });
  test('place parsing rejects invalid coordinates', () {
    final rows = parsePlaces([
      {'lat':'21.0','lon':'105.8','display_name':'Hà Nội'},
      {'lat':'NaN','lon':'105','display_name':'Invalid'},
    ]);
    expect(rows.single.name, 'Hà Nội');
    expect(validPoint(91, 105), isNull);
  });
  test('OSRM geometry preserves longitude and latitude order', () {
    final route = parseRoute({'code':'Ok','routes':[{
      'distance':1000,'duration':120,'geometry':{'type':'LineString','coordinates':[[105.8,21.0],[105.9,21.1]]}
    }]});
    expect(route.points.first.latitude, 21);
    expect(route.points.first.longitude, 105.8);
    expect(route.meters, 1000);
    expect(() => parseRoute({'code':'NoRoute'}), throwsFormatException);
  });
  test('service configuration requires HTTPS', () {
    expect(() => serviceUri('http://example.org', {}), throwsFormatException);
    expect(serviceUri('https://example.org/search', {'q':'Hà Nội'}).queryParameters['q'], 'Hà Nội');
  });
}
