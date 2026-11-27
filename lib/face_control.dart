import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'face_control_policy.dart';

class FaceControlScreen extends StatefulWidget {
  const FaceControlScreen({super.key});
  @override
  State<FaceControlScreen> createState() => _FaceControlScreenState();
}

class _FaceControlScreenState extends State<FaceControlScreen> with WidgetsBindingObserver {
  static const channel = MethodChannel('infiniti/face');
  final gesture = HeadTurnGate();
  CameraController? camera;
  StreamSubscription<Position>? gps;
  Timer? watchdog;
  Position? lastFix;
  bool parked = false, starting = false, stopping = false, active = false, processing = false;
  int generation = 0, selected = 0;
  DateTime? lastFrame;
  String status = 'Chỉ thử nghiệm khi xe đã đỗ hẳn.';
  final labels = const ['Hành trình', 'Giải trí', 'Camera hành trình'];

  bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  bool valid(Position? p) => p != null && faceControlAllowed(
    speed: p.speed, accuracy: p.accuracy, speedAccuracy: p.speedAccuracy,
    fix: p.timestamp, now: DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> start() async {
    if (!supported || !parked || starting || stopping || active) return;
    final token = ++generation;
    setState(() { starting = true; status = 'Kiểm tra vị trí và quyền camera'; });
    CameraController? pending;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw StateError('GPS unavailable');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {
        throw StateError('Location permission denied');
      }
      final fix = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best, timeLimit: Duration(seconds: 15)));
      if (!mounted || token != generation) return;
      if (!valid(fix)) throw StateError('Stationary GPS gate failed');
      lastFix = fix;
      gps = Geolocator.getPositionStream(locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best, distanceFilter: 0)).listen((p) {
          lastFix = p;
          if (!valid(p)) unawaited(stop('Đã dừng: GPS không xác nhận trạng thái tĩnh'));
        }, onError: (Object _) => unawaited(stop('Đã dừng: mất GPS')));
      watchdog = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!valid(lastFix)) unawaited(stop('Đã dừng: tín hiệu GPS quá cũ'));
      });
      final devices = await availableCameras();
      final front = devices.where((c) => c.lensDirection == CameraLensDirection.front);
      if (front.isEmpty) throw StateError('Front camera unavailable');
      if (!mounted || token != generation) return;
      pending = CameraController(front.first, ResolutionPreset.low,
        enableAudio: false, imageFormatGroup: ImageFormatGroup.bgra8888);
      await pending.initialize();
      if (!mounted || token != generation || !valid(lastFix) ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        await pending.dispose();
        pending = null;
        if (mounted && token == generation) await stop('Đã dừng: không đủ điều kiện an toàn');
        return;
      }
      camera = pending;
      pending = null;
      gesture.reset();
      setState(() { active = true; status = 'Nhìn thẳng rồi quay nhẹ đầu để đổi thẻ thử nghiệm.'; });
      await camera!.startImageStream((frame) => unawaited(analyze(frame, token)));
    } catch (_) {
      await pending?.dispose();
      if (mounted && token == generation) await stop('Không thể bật Face Control hoặc GPS không đủ chính xác');
    } finally {
      if (mounted) setState(() => starting = false);
    }
  }

  Future<void> analyze(CameraImage frame, int token) async {
    if (!active || processing || token != generation || !valid(lastFix)) return;
    if (frame.format.group != ImageFormatGroup.bgra8888 || frame.planes.length != 1) return;
    final now = DateTime.now();
    if (lastFrame != null && now.difference(lastFrame!) < const Duration(milliseconds: 700)) return;
    lastFrame = now;
    processing = true;
    try {
      final plane = frame.planes.single;
      final orientation = switch (camera?.value.deviceOrientation) {
        DeviceOrientation.landscapeLeft => 1,
        DeviceOrientation.landscapeRight => 3,
        DeviceOrientation.portraitDown => 8,
        _ => 6,
      };
      final yaw = await channel.invokeMethod<double>('yaw', {
        'bytes': plane.bytes, 'width': frame.width, 'height': frame.height,
        'stride': plane.bytesPerRow, 'orientation': orientation,
      });
      if (mounted && active && token == generation && valid(lastFix) && gesture.update(yaw)) {
        setState(() => selected = (selected + 1) % labels.length);
      }
    } catch (_) {
      if (mounted && token == generation) unawaited(stop('Đã dừng: nhận dạng không khả dụng'));
    } finally {
      processing = false;
    }
  }

  Future<void> stop(String message) async {
    generation++;
    gesture.reset();
    watchdog?.cancel();
    watchdog = null;
    final subscription = gps;
    gps = null;
    final c = camera;
    camera = null;
    if (mounted) setState(() { active = false; parked = false; status = message; stopping = true; });
    try {
      await subscription?.cancel();
      if (c != null) {
        try { if (c.value.isStreamingImages) await c.stopImageStream(); } finally { await c.dispose(); }
      }
    } catch (_) {
      // Never restart automatically after an error.
    } finally {
      if (mounted) setState(() => stopping = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(stop('Đã dừng: ứng dụng không còn hiển thị'));
    }
  }

  @override
  void dispose() {
    generation++;
    active = false;
    WidgetsBinding.instance.removeObserver(this);
    watchdog?.cancel();
    unawaited(gps?.cancel());
    unawaited(camera?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Thử nghiệm Face Control')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Không dùng khi lái xe. Chỉ đổi thẻ thông tin thử nghiệm, không gọi điện, xóa video hoặc điều khiển xe. GPS không chứng minh xe đã đỗ.'),
      Text(status),
      if (!supported) const Text('Nhận dạng Apple Vision chỉ có trên iOS trong phiên bản này.'),
      CheckboxListTile(value: parked, onChanged: supported && !active && !starting && !stopping ? (v) => setState(() => parked = v ?? false) : null, title: const Text('Tôi xác nhận xe đã đỗ hẳn')),
      FilledButton(onPressed: supported && parked && !starting && !stopping && !active ? start : null, child: const Text('Bật camera trước')),
      OutlinedButton(onPressed: active || starting ? () => stop('Đã dừng theo yêu cầu') : null, child: const Text('Dừng ngay')),
      if (camera?.value.isInitialized == true)
        AspectRatio(aspectRatio: camera!.value.aspectRatio, child: CameraPreview(camera!)),
      Card(child: ListTile(leading: const Icon(Icons.view_carousel), title: Text(labels[selected]), subtitle: const Text('Thẻ thử nghiệm, không mở ứng dụng'))),
      const Text('Khung hình xử lý trong bộ nhớ; không ghi video, lưu ảnh, nhận diện danh tính hay gửi lên máy chủ.'),
    ]),
  );
}
