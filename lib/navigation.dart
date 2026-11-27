import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

const tileTemplate = String.fromEnvironment('CAROS_TILE_URL');
const tileAttribution = String.fromEnvironment('CAROS_TILE_ATTRIBUTION');
const searchEndpoint = String.fromEnvironment('CAROS_SEARCH_URL');
const routeEndpoint = String.fromEnvironment('CAROS_ROUTE_URL');

LatLng? validPoint(Object? lat, Object? lon) {
  final a = double.tryParse(lat.toString());
  final b = double.tryParse(lon.toString());
  if (a == null || b == null || !a.isFinite || !b.isFinite ||
      a.abs() > 85.05 || b.abs() > 180) {
    return null;
  }
  return LatLng(a, b);
}

class Place {
  const Place(this.name, this.point);
  final String name;
  final LatLng point;
}

List<Place> parsePlaces(Object? data) {
  if (data is! List) throw const FormatException('Invalid places');
  final places = <Place>[];
  for (final row in data.take(20)) {
    if (row is! Map) continue;
    final point = validPoint(row['lat'], row['lon']);
    final name = row['display_name'];
    if (point != null && name is String && name.trim().isNotEmpty) {
      places.add(Place(name, point));
    }
  }
  return places;
}

class RoutePlan {
  const RoutePlan(this.points, this.meters, this.seconds);
  final List<LatLng> points;
  final double meters, seconds;
}

RoutePlan parseRoute(Object? data) {
  if (data is! Map || data['code'] != 'Ok' || data['routes'] is! List ||
      (data['routes'] as List).isEmpty) {
    throw const FormatException('No route');
  }
  final route = (data['routes'] as List).first;
  if (route is! Map || route['geometry'] is! Map) {
    throw const FormatException('Invalid route');
  }
  final geometry = route['geometry'] as Map;
  final coords = geometry['coordinates'];
  final distance = route['distance'];
  final duration = route['duration'];
  if (geometry['type'] != 'LineString' || coords is! List ||
      coords.length < 2 || coords.length > 20000 ||
      distance is! num || !distance.isFinite || distance < 0 ||
      duration is! num || !duration.isFinite || duration < 0) {
    throw const FormatException('Invalid geometry');
  }
  final points = <LatLng>[];
  for (final pair in coords) {
    if (pair is! List || pair.length < 2) {
      throw const FormatException('Invalid coordinate');
    }
    final point = validPoint(pair[1], pair[0]);
    if (point == null) throw const FormatException('Invalid coordinate');
    points.add(point);
  }
  return RoutePlan(points, distance.toDouble(), duration.toDouble());
}

Uri serviceUri(String endpoint, Map<String, String> query, {String suffix = ''}) {
  final uri = Uri.tryParse(endpoint);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
    throw const FormatException('Configure an HTTPS provider');
  }
  return uri.replace(path: uri.path + suffix, queryParameters: {...uri.queryParameters, ...query});
}

Future<Object?> fetchMapJson(Uri uri, http.Client client) async {
  final request = http.Request('GET', uri)..followRedirects = false;
  request.headers['Accept'] = 'application/json';
  final result = await client.send(request).timeout(const Duration(seconds: 15));
  if (result.statusCode != 200 || (result.contentLength ?? 0) > 2000000) {
    final sub = result.stream.listen((_) {});
    await sub.cancel();
    throw const FormatException('Invalid service response');
  }
  final bytes = <int>[];
  await result.stream.forEach((chunk) {
    if (bytes.length + chunk.length > 2000000) {
      throw const FormatException('Response too large');
    }
    bytes.addAll(chunk);
  }).timeout(const Duration(seconds: 15), onTimeout: () {
    client.close();
    throw TimeoutException('Map request timed out');
  });
  return jsonDecode(utf8.decode(bytes));
}

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});
  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> with WidgetsBindingObserver {
  final map = MapController();
  final query = TextEditingController();
  StreamSubscription<Position>? gps;
  Timer? watchdog;
  http.Client? requestClient;
  LatLng? position, destination;
  DateTime? fixTime;
  RoutePlan? route;
  List<Place> places = [];
  bool ready = false, busy = false, follow = true, locating = false;
  String status = 'Bật GPS hoặc chọn điểm đến trên bản đồ.';
  bool get configuredTiles => tileTemplate.startsWith('https://') && tileAttribution.trim().isNotEmpty;
  bool get fresh => fixTime != null && DateTime.now().difference(fixTime!).inSeconds <= 10;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      unawaited(stopGps());
    }
  }

  Future<void> startGps() async {
    if (locating || gps != null) return;
    setState(() => locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw StateError('GPS off');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (!mounted || WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
      if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {
        setState(() => status = 'Chưa cấp quyền vị trí');
        return;
      }
      gps = Geolocator.getPositionStream(locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high, distanceFilter: 3,
      )).listen((p) {
        final point = validPoint(p.latitude, p.longitude);
        final age = DateTime.now().difference(p.timestamp).inSeconds;
        if (!mounted || point == null || p.accuracy > 50 || p.accuracy < 0 ||
            !p.accuracy.isFinite || age > 10 || age < -2) return;
        setState(() { position = point; fixTime = p.timestamp; status = 'GPS đang hoạt động'; });
        if (ready && follow) map.move(point, 16);
      }, onError: (Object _) {
        if (mounted) unawaited(stopGps(message: 'GPS bị gián đoạn'));
      });
      watchdog = Timer.periodic(const Duration(seconds: 2), (_) {
        if (mounted && position != null && !fresh) {
          setState(() { position = null; status = 'GPS mất tín hiệu'; });
        }
      });
      setState(() => status = 'Đang chờ GPS');
    } catch (_) {
      if (mounted) setState(() => status = 'Không thể bật GPS');
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  Future<void> stopGps({String message = 'GPS đã dừng'}) async {
    final current = gps;
    gps = null;
    watchdog?.cancel();
    watchdog = null;
    if (mounted) setState(() { position = null; fixTime = null; status = message; });
    await current?.cancel();
  }

  Future<void> search() async {
    if (busy || query.text.trim().isEmpty) return;
    if (searchEndpoint.isEmpty) {
      setState(() => status = 'Chưa cấu hình dịch vụ tìm địa điểm.');
      return;
    }
    setState(() { busy = true; places = []; });
    final client = http.Client();
    requestClient = client;
    try {
      final uri = serviceUri(searchEndpoint, {'q':query.text.trim(),'format':'jsonv2','limit':'10','accept-language':'vi'});
      final rows = parsePlaces(await fetchMapJson(uri, client));
      if (mounted) setState(() { places = rows; status = rows.isEmpty ? 'Không tìm thấy địa điểm' : 'Chọn điểm đến'; });
    } catch (_) {
      if (mounted) setState(() => status = 'Không tìm được địa điểm');
    } finally {
      client.close();
      if (identical(client, requestClient)) requestClient = null;
      if (mounted) setState(() => busy = false);
    }
  }

  void choose(LatLng point) {
    if (busy) return;
    setState(() { destination = point; route = null; follow = false; places = []; status = 'Đã chọn điểm đến'; });
    if (ready) map.move(point, 15);
  }

  Future<void> plan() async {
    final start = position, end = destination;
    if (busy) return;
    if (start == null || end == null || !fresh) {
      setState(() => status = 'Cần GPS mới và điểm đến');
      return;
    }
    if (routeEndpoint.isEmpty) {
      setState(() => status = 'Chưa cấu hình máy chủ tính tuyến.');
      return;
    }
    setState(() { busy = true; route = null; });
    final client = http.Client();
    requestClient = client;
    try {
      final suffix = '/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}';
      final uri = serviceUri(routeEndpoint, {'overview':'full','geometries':'geojson','steps':'false'}, suffix:suffix);
      final result = parseRoute(await fetchMapJson(uri, client));
      if (mounted) setState(() { route = result; status = 'Đã tính tuyến dự kiến'; });
    } catch (_) {
      if (mounted) setState(() => status = 'Không tìm được tuyến đường');
    } finally {
      client.close();
      if (identical(client, requestClient)) requestClient = null;
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    watchdog?.cancel();
    unawaited(gps?.cancel());
    requestClient?.close();
    query.dispose();
    map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Bản đồ & dẫn đường')),
    body: Column(children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(status)),
      Wrap(spacing: 8, children: [
        FilledButton(onPressed: locating ? null : gps == null ? startGps : stopGps, child: Text(gps == null ? 'Bật GPS' : 'Dừng GPS')),
        OutlinedButton(onPressed: busy ? null : plan, child: const Text('Tính tuyến')),
        TextButton(onPressed: position == null ? null : () {
          setState(() => follow = true);
          if (ready) map.move(position!, 16);
        }, child: const Text('Theo vị trí')),
      ]),
      if (route != null) Text('${(route!.meters / 1000).toStringAsFixed(1)} km • ${(route!.seconds / 60).ceil()} phút dự kiến'),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: [
        Expanded(child: TextField(controller: query, decoration: const InputDecoration(labelText: 'Tên địa điểm'))),
        IconButton(tooltip: 'Tìm địa điểm', onPressed: busy ? null : search, icon: const Icon(Icons.search)),
      ])),
      if (places.isNotEmpty) SizedBox(height: 100, child: ListView(children: [
        for (final place in places) ListTile(title: Text(place.name, maxLines: 2), onTap: () => choose(place.point)),
      ])),
      Expanded(child: FlutterMap(mapController: map, options: MapOptions(
        initialCenter: const LatLng(16, 108), initialZoom: 5,
        onMapReady: () { ready = true; if (position != null && follow) map.move(position!, 16); },
        onTap: (_, point) => choose(point),
      ), children: [
        if (configuredTiles) TileLayer(urlTemplate: tileTemplate, userAgentPackageName: 'com.infinitimoney.infiniti_caros'),
        if (route != null) PolylineLayer(polylines: [Polyline(points: route!.points, strokeWidth: 5, color: Colors.blue)]),
        MarkerLayer(markers: [
          if (position != null) Marker(point: position!, child: const Icon(Icons.my_location, color: Colors.blue, size: 32)),
          if (destination != null) Marker(point: destination!, child: const Icon(Icons.location_pin, color: Colors.red, size: 36)),
        ]),
      ])),
      if (!configuredTiles) const Text('Chưa cấu hình bản đồ nền; chỉ hiển thị tọa độ và tuyến nếu có.'),
      if (configuredTiles) Text(tileAttribution, style: const TextStyle(fontSize: 11)),
      const Padding(padding: EdgeInsets.all(6), child: Text('Tuyến dự kiến, chưa có chỉ dẫn từng ngã rẽ. Chỉ thao tác khi đã đỗ xe.')),
    ]),
  );
}
