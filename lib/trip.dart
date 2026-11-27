import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

double? speedKmh(double metersPerSecond) =>
    metersPerSecond.isFinite && metersPerSecond >= 0 ? metersPerSecond * 3.6 : null;

class TripPanel extends StatefulWidget {
  const TripPanel({super.key, required this.prefs});
  final SharedPreferences prefs;
  @override
  State<TripPanel> createState() => _TripPanelState();
}

class _TripPanelState extends State<TripPanel> with WidgetsBindingObserver {
  StreamSubscription<Position>? sub;
  Position? last;
  DateTime? started;
  double distance = 0;
  double? speed;
  bool busy = false;
  String status = 'GPS chưa bật';
  List<String> get history => widget.prefs.getStringList('trip_history') ?? [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && started != null) {
      unawaited(stop());
    }
  }

  Future<void> start() async {
    if (busy || started != null) return;
    setState(() => busy = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) setState(() => status = 'Hãy bật dịch vụ vị trí');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (!mounted) return;
      if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {
        setState(() => status = 'Chưa cấp quyền vị trí trong Cài đặt');
        return;
      }
      setState(() {
        started = DateTime.now();
        distance = 0;
        last = null;
        speed = null;
        status = 'Đang chờ tín hiệu GPS';
      });
      sub = Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 0)).listen(onPosition, onError: (Object error) {
        if (mounted) {
          unawaited(stop(message: 'GPS bị gián đoạn'));
        }
      });
    } catch (_) {
      if (mounted) {
        if (started != null) {
          await stop(message: 'Không thể bật GPS');
        } else {
          setState(() => status = 'Không thể bật GPS');
        }
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void onPosition(Position p) {
    if (!mounted || started == null) return;
    if (!p.accuracy.isFinite || p.accuracy < 0 || p.accuracy > 50) {
      setState(() { speed = null; last = null; status = 'GPS chưa đủ chính xác'; });
      return;
    }
    setState(() {
      final previous = last;
      if (previous != null) {
        final seconds = p.timestamp.difference(previous.timestamp).inMilliseconds / 1000;
        final meters = Geolocator.distanceBetween(previous.latitude, previous.longitude, p.latitude, p.longitude);
        if (seconds > 0 && seconds <= 30 && meters >= 5 && meters / seconds <= 70) {
          distance += meters;
        }
      }
      last = p;
      speed = speedKmh(p.speed);
      status = 'GPS đang hoạt động';
    });
  }

  Future<void> stop({String message = 'Đã kết thúc hành trình'}) async {
    final begin = started;
    if (begin == null) return;
    final meters = distance;
    final subscription = sub;
    sub = null;
    setState(() { started = null; speed = null; last = null; status = message; busy = true; });
    try {
      await subscription?.cancel();
      final rows = history;
      rows.insert(0, jsonEncode({'start': begin.toIso8601String(), 'seconds': DateTime.now().difference(begin).inSeconds, 'meters': meters}));
      final saved = await widget.prefs.setStringList('trip_history', rows.take(100).toList());
      if (!saved && mounted) setState(() => status = 'Không lưu được hành trình');
    } catch (_) {
      if (mounted) setState(() => status = 'Không lưu được hành trình');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> map() async {
    final point = last;
    final query = point == null ? '' : '?api=1&query=${point.latitude},${point.longitude}';
    try {
      if (await launchUrl(Uri.parse('https://www.google.com/maps/search/$query'), mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    if (mounted) setState(() => status = 'Không thể mở bản đồ');
  }

  void showHistory() {
    showModalBottomSheet<void>(context: context, builder: (context) => SafeArea(child: ListView(children: [
      const ListTile(title: Text('Lịch sử hành trình'), subtitle: Text('Chỉ lưu tổng quãng đường và thời gian trên thiết bị')),
      for (final row in history) Builder(builder: (context) {
        final data = jsonDecode(row) as Map<String, dynamic>;
        return ListTile(title: Text('${((data['meters'] as num) / 1000).toStringAsFixed(2)} km'), subtitle: Text('${data['start']} • ${data['seconds']} giây'));
      }),
      if (history.isEmpty) const ListTile(title: Text('Chưa có hành trình')),
      TextButton(onPressed: () async {
        await widget.prefs.remove('trip_history');
        if (context.mounted) Navigator.pop(context);
      }, child: const Text('Xóa lịch sử')),
    ])));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Hành trình'),
    Text(speed == null ? '— km/h' : '${speed!.toStringAsFixed(0)} km/h', style: const TextStyle(fontSize: 28)),
    Text(status),
    Text('${(distance / 1000).toStringAsFixed(2)} km • Quãng đường ước tính'),
    const Text('Chỉ theo dõi khi mở ứng dụng. Thao tác khi đã đỗ xe.'),
    Wrap(spacing: 8, children: [
      FilledButton(onPressed: busy ? null : started == null ? start : stop, child: Text(started == null ? 'Bắt đầu' : 'Kết thúc')),
      OutlinedButton(onPressed: map, child: const Text('Mở bản đồ')),
      TextButton(onPressed: showHistory, child: const Text('Lịch sử')),
    ]),
  ]);
}
