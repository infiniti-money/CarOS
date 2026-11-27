import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_tts/flutter_tts.dart';
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

class TurnStep {
  const TurnStep(this.point, this.instruction);
  final LatLng point;
  final String instruction;
}

String vietnameseTurn(String type, String modifier, String road, int? exit) {
  final direction = switch (modifier) {
    'left' => 'Rẽ trái',
    'right' => 'Rẽ phải',
    'slight left' => 'Chếch trái',
    'slight right' => 'Chếch phải',
    'sharp left' => 'Rẽ gấp trái',
    'sharp right' => 'Rẽ gấp phải',
    'uturn' => 'Quay đầu',
    _ => 'Đi tiếp',
  };
  final instruction = switch (type) {
    'depart' => 'Bắt đầu đi',
    'arrive' => 'Đã gần đến điểm đến',
    'roundabout' || 'rotary' => exit == null ? 'Đi vào vòng xuyến' : 'Ra khỏi vòng xuyến tại lối thứ $exit',
    'merge' => 'Nhập làn',
    'fork' => direction,
    _ => direction,
  };
  return road.isEmpty || type == 'arrive' ? instruction : '$instruction vào $road';
}

List<TurnStep> parseSteps(Object? legs) {
  final result = <TurnStep>[];
  if (legs is! List) return result;
  for (final leg in legs) {
    if (leg is! Map || leg['steps'] is! List) continue;
    for (final step in leg['steps'] as List) {
      if (step is! Map || step['maneuver'] is! Map) continue;
      final m = step['maneuver'] as Map;
      final location = m['location'];
      if (location is! List || location.length < 2) continue;
      final point = validPoint(location[1], location[0]);
      if (point == null) continue;
      result.add(TurnStep(point, vietnameseTurn(
        m['type']?.toString() ?? '', m['modifier']?.toString() ?? '',
        step['name']?.toString() ?? '', m['exit'] is int ? m['exit'] as int : null,
      )));
    }
  }
  return result;
}

// Local planar distance to nearest route segment, adequate for short road offsets.
double routeOffset(LatLng fix, List<LatLng> points) {
  if (points.length < 2) return double.infinity;
  final scale = 111195.0 * math.cos(fix.latitude * math.pi / 180);
  double x(LatLng p) => (p.longitude - fix.longitude) * scale;
  double y(LatLng p) => (p.latitude - fix.latitude) * 111195.0;
  var best = double.infinity;
  for (var i = 1; i < points.length; i++) {
    final ax = x(points[i-1]), ay = y(points[i-1]);
    final dx = x(points[i])-ax, dy = y(points[i])-ay;
    final len = dx*dx + dy*dy;
    final t = len == 0 ? 0.0 : (-(ax*dx+ay*dy)/len).clamp(0.0,1.0).toDouble();
    best = math.min(best, math.sqrt(math.pow(ax+t*dx,2)+math.pow(ay+t*dy,2)));
  }
  return best;
}

class RoutePlan {
  const RoutePlan(this.points, this.meters, this.seconds, this.steps);
  final List<LatLng> points;
  final double meters, seconds;
  final List<TurnStep> steps;
}

class RouteProgress {
  const RouteProgress(this.remainingMeters, this.remainingSeconds, this.offsetMeters);
  final double remainingMeters, remainingSeconds, offsetMeters;
}

// Project onto each short local segment, then scale remaining geometric length
// to the provider's distance and duration. This is not traffic-aware map matching.
RouteProgress? estimateRouteProgress(LatLng fix, RoutePlan route, {double maxOffset = 80}) {
  if (route.points.length < 2 || !route.meters.isFinite || route.meters < 0 ||
      !route.seconds.isFinite || route.seconds < 0 ||
      !fix.latitude.isFinite || !fix.longitude.isFinite ||
      !maxOffset.isFinite || maxOffset <= 0) {
    return null;
  }
  final scale = 111195.0 * math.cos(fix.latitude * math.pi / 180);
  double x(LatLng p) {
    final delta = ((p.longitude - fix.longitude + 540) % 360) - 180;
    return delta * scale;
  }
  double y(LatLng p) => (p.latitude - fix.latitude) * 111195.0;
  var total = 0.0, best = double.infinity, along = 0.0;
  var alternate = double.infinity;
  for (var i = 1; i < route.points.length; i++) {
    final a = route.points[i - 1], b = route.points[i];
    final ax = x(a), ay = y(a), dx = x(b) - ax, dy = y(b) - ay;
    final squared = dx * dx + dy * dy;
    if (!squared.isFinite) return null;
    if (squared == 0) continue;
    final length = math.sqrt(squared);
    final fraction = (-(ax * dx + ay * dy) / squared).clamp(0.0, 1.0).toDouble();
    final offset = math.sqrt(math.pow(ax + fraction * dx, 2) + math.pow(ay + fraction * dy, 2));
    final projected = total + length * fraction;
    if (offset < best) {
      // Near-ties far apart along a loop/crossing are ambiguous.
      if ((projected - along).abs() > 100 && best.isFinite && best - offset <= 10) {
        alternate = best;
      } else if (alternate - offset > 10) {
        alternate = double.infinity;
      }
      best = offset;
      along = projected;
    } else if ((projected - along).abs() > 100 && offset - best <= 10) {
      alternate = math.min(alternate, offset);
    }
    total += length;
  }
  if (total <= 0 || !total.isFinite || best > maxOffset || alternate - best <= 10) {
    return null;
  }
  final remaining = (1 - along / total).clamp(0.0, 1.0).toDouble();
  return RouteProgress(route.meters * remaining, route.seconds * remaining, best);
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
  return RoutePlan(points, distance.toDouble(), duration.toDouble(), parseSteps(route['legs']));
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
  final tts = FlutterTts();
  bool guiding = false, reroute = false, voice = false;
  int stepIndex = 0, announced = -1, offRouteSamples = 0;
  DateTime? lastReroute;
  String instruction = '';
  final query = TextEditingController();
  StreamSubscription<Position>? gps;
  Timer? watchdog;
  http.Client? requestClient;
  LatLng? position, destination;
  DateTime? fixTime;
  double? fixAccuracy;
  RoutePlan? route;
  List<Place> places = [];
  bool ready = false, busy = false, follow = true, locating = false;
  String status = 'Bật GPS hoặc chọn điểm đến trên bản đồ.';
  bool get configuredTiles => tileTemplate.startsWith('https://') && tileAttribution.trim().isNotEmpty;
  bool get fresh {
    final time = fixTime;
    if (time == null) return false;
    final age = DateTime.now().difference(time);
    return age >= const Duration(seconds: -2) && age <= const Duration(seconds: 10);
  }

  RouteProgress? get progress {
    final current = route, fix = position, accuracy = fixAccuracy;
    if (current == null || fix == null || !fresh || busy || accuracy == null || accuracy > 25) return null;
    return estimateRouteProgress(fix, current);
  }

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
        accuracy: LocationAccuracy.high, distanceFilter: 0,
      )).listen((p) {
        final point = validPoint(p.latitude, p.longitude);
        final age = DateTime.now().difference(p.timestamp).inSeconds;
        if (!mounted || point == null || p.accuracy > 50 || p.accuracy < 0 ||
            !p.accuracy.isFinite || age > 10 || age < -2) {
          return;
        }
        if (fixTime != null && !p.timestamp.isAfter(fixTime!)) return;
        setState(() { position = point; fixTime = p.timestamp; fixAccuracy = p.accuracy; status = 'GPS đang hoạt động'; });
        if (ready && follow) map.move(point, 16);
        updateGuidance(point, p.accuracy);
      }, onError: (Object _) {
        if (mounted) unawaited(stopGps(message: 'GPS bị gián đoạn'));
      });
      watchdog = Timer.periodic(const Duration(seconds: 2), (_) {
        if (mounted && position != null && !fresh) {
          setState(() { position = null; fixAccuracy = null; status = 'GPS mất tín hiệu'; });
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
    guiding = false;
    reroute = false;
    unawaited(silence());
    final current = gps;
    gps = null;
    watchdog?.cancel();
    watchdog = null;
    if (mounted) setState(() { position = null; fixTime = null; fixAccuracy = null; status = message; });
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
    if (busy || guiding) return;
    setState(() { destination = point; route = null; follow = false; places = []; status = 'Đã chọn điểm đến'; });
    if (ready) map.move(point, 15);
  }

  Future<void> plan({bool automatic = false}) async {
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
    setState(() { busy = true; if (!automatic) route = null; });
    final client = http.Client();
    requestClient = client;
    try {
      final suffix = '/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}';
      final uri = serviceUri(routeEndpoint, {'overview':'full','geometries':'geojson','steps':'true'}, suffix:suffix);
      final result = parseRoute(await fetchMapJson(uri, client));
      if (mounted) setState(() { route = result; stepIndex = 0; announced = -1; offRouteSamples = 0; status = 'Đã tính tuyến dự kiến'; });
    } catch (_) {
      if (mounted) setState(() => status = 'Không tìm được tuyến đường');
    } finally {
      client.close();
      if (identical(client, requestClient)) requestClient = null;
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> silence() async {
    try { await tts.stop(); } catch (_) {}
  }

  Future<void> speak(String words) async {
    try {
      if (await tts.isLanguageAvailable('vi-VN') == true) {
        await tts.setLanguage('vi-VN');
        if (mounted && guiding && voice && fresh) await tts.speak(words);
      } else if (mounted) {
        setState(() { voice = false; status = 'Thiết bị chưa có giọng tiếng Việt'; });
      }
    } catch (_) {
      if (mounted) setState(() => voice = false);
    }
  }

  void updateGuidance(LatLng fix, double accuracy) {
    final current = route;
    if (!guiding || current == null || busy || !fresh || accuracy > 25) return;
    if (routeOffset(fix, current.points) > 80) {
      offRouteSamples++;
      final now = DateTime.now();
      if (reroute && offRouteSamples >= 3 &&
          (lastReroute == null || now.difference(lastReroute!).inSeconds >= 60)) {
        lastReroute = now;
        offRouteSamples = 0;
        unawaited(plan(automatic: true));
      }
      return;
    }
    offRouteSamples = 0;
    if (stepIndex >= current.steps.length) return;
    final step = current.steps[stepIndex];
    final meters = Geolocator.distanceBetween(fix.latitude, fix.longitude, step.point.latitude, step.point.longitude);
    if (meters <= 100 && announced != stepIndex) {
      announced = stepIndex;
      setState(() => instruction = step.instruction);
      if (voice) unawaited(speak(step.instruction));
    }
    if (meters <= 25) {
      stepIndex++;
      if (stepIndex == current.steps.length) {
        setState(() { guiding = false; reroute = false; instruction = 'Đã đến gần điểm đến'; });
      }
    }
  }

  Future<void> startGuidance() async {
    if (route == null || route!.steps.isEmpty || !fresh) {
      setState(() => status = 'Cần tuyến có chỉ dẫn và GPS mới');
      return;
    }
    final consent = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Bắt đầu dẫn đường'),
      content: const Text('Chỉ bật khi đã đỗ xe. Nếu bật tự tính lại tuyến, tọa độ hiện tại và điểm đến sẽ được gửi tới nhà cung cấp khi lệch tuyến. Luôn tuân thủ biển báo.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Bắt đầu')),
      ],
    ));
    if (consent != true || !mounted || !fresh) return;
    setState(() { guiding = true; stepIndex = 0; announced = -1; instruction = 'Đang theo tuyến'; follow = true; });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    watchdog?.cancel();
    unawaited(gps?.cancel());
    requestClient?.close();
    query.dispose();
    guiding = false;
    unawaited(silence());
    map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = progress;
    return Scaffold(
    appBar: AppBar(title: const Text('Bản đồ & dẫn đường')),
    body: Column(children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(status)),
      Wrap(spacing: 8, children: [
        FilledButton(onPressed: locating ? null : gps == null ? startGps : stopGps, child: Text(gps == null ? 'Bật GPS' : 'Dừng GPS')),
        OutlinedButton(onPressed: busy || guiding ? null : () => plan(), child: const Text('Tính tuyến')),
        TextButton(onPressed: position == null ? null : () {
          setState(() => follow = true);
          if (ready) map.move(position!, 16);
        }, child: const Text('Theo vị trí')),
      ]),
      if (route != null) Text('Tổng tuyến: ${(route!.meters / 1000).toStringAsFixed(1)} km • ${(route!.seconds / 60).ceil()} phút dự kiến'),
      if (route != null) Text(remaining == null ? 'Còn lại: chưa đủ GPS hoặc vị trí không rõ trên tuyến' : 'Còn lại khoảng ${(remaining.remainingMeters / 1000).toStringAsFixed(1)} km • ${(remaining.remainingSeconds / 60).ceil()} phút (ước tính, không có giao thông trực tiếp)'),
      if (route != null) Wrap(spacing: 8, children: [
        TextButton(onPressed: guiding ? () { setState(() { guiding = false; reroute = false; }); unawaited(silence()); } : startGuidance, child: Text(guiding ? 'Dừng dẫn đường' : 'Bắt đầu dẫn đường')),
        FilterChip(label: const Text('Giọng Việt'), selected: voice, onSelected: (v) { setState(() => voice = v); if (!v) unawaited(silence()); }),
        FilterChip(label: const Text('Tự tính lại tuyến'), selected: reroute, onSelected: guiding ? (v) => setState(() => reroute = v) : null),
      ]),
      if (guiding) Text(instruction, style: Theme.of(context).textTheme.titleLarge),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: [
        Expanded(child: TextField(controller: query, decoration: const InputDecoration(labelText: 'Tên địa điểm'))),
        IconButton(tooltip: 'Tìm địa điểm', onPressed: busy || guiding ? null : search, icon: const Icon(Icons.search)),
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
      const Padding(padding: EdgeInsets.all(6), child: Text('Dẫn đường thử nghiệm, luôn tuân thủ biển báo. Chỉ thao tác khi đã đỗ xe.')),
    ]),
    );
  }
}
