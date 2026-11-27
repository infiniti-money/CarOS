import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:infiniti_caros/navigation.dart';

void main() {
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
