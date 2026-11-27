import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

const maxClips = 20;
const clipDuration = Duration(minutes: 5);

bool isDashClip(String name) => RegExp(r'^trip_[0-9]+\.mp4$').hasMatch(name);

class DashCamScreen extends StatefulWidget {
  const DashCamScreen({super.key});
  @override
  State<DashCamScreen> createState() => _DashCamScreenState();
}

class _DashCamScreenState extends State<DashCamScreen> with WidgetsBindingObserver {
  CameraController? camera;
  Timer? timer;
  bool busy = false, recording = false, foreground = true;
  String status = 'Bật camera khi đã đỗ xe. Không ghi âm.';
  List<File> clips = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(refresh());
  }

  Future<Directory> directory() async {
    final base = await getApplicationSupportDirectory();
    return Directory('${base.path}/dashcam').create(recursive: true);
  }

  Future<void> refresh() async {
    try {
      final dir = await directory();
      final rows = await dir.list(followLinks: false).where((e) => e is File && isDashClip(e.uri.pathSegments.last)).cast<File>().toList();
      rows.sort((a,b) => b.path.compareTo(a.path));
      if (mounted) setState(() => clips = rows);
    } catch (_) {
      if (mounted) setState(() => status = 'Không đọc được video đã lưu');
    }
  }

  Future<void> enable() async {
    if (busy || camera != null) return;
    setState(() => busy = true);
    CameraController? pending;
    try {
      final cameras = await availableCameras();
      final back = cameras.where((c) => c.lensDirection == CameraLensDirection.back);
      if (back.isEmpty) throw StateError('No rear camera');
      pending = CameraController(back.first, ResolutionPreset.medium, enableAudio: false);
      await pending.initialize();
      if (!mounted || !foreground) {
        await pending.dispose();
        return;
      }
      setState(() { camera = pending; status = 'Camera sẵn sàng'; });
    } catch (_) {
      await pending?.dispose();
      if (mounted) setState(() => status = 'Camera không khả dụng hoặc chưa cấp quyền');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> begin() async {
    final c = camera;
    if (busy || recording || c == null || !foreground) return;
    if (clips.length >= maxClips) {
      setState(() => status = 'Đã đủ 20 video. Xóa video cũ trước khi quay.');
      return;
    }
    setState(() => busy = true);
    try {
      await c.startVideoRecording();
      if (!mounted) return;
      setState(() { recording = true; status = 'ĐANG QUAY • Không ghi âm'; });
      timer = Timer(clipDuration, () => unawaited(finish()));
    } catch (_) {
      if (mounted) setState(() => status = 'Không bắt đầu được video');
    } finally {
      if (mounted) setState(() => busy = false);
      if (!foreground) unawaited(release());
    }
  }

  Future<void> finish() async {
    final c = camera;
    if (busy || !recording || c == null) return;
    timer?.cancel();
    setState(() => busy = true);
    try {
      final result = await c.stopVideoRecording();
      final dir = await directory();
      final destination = '${dir.path}/trip_${DateTime.now().microsecondsSinceEpoch}.mp4';
      await result.saveTo(destination);
      try { await File(result.path).delete(); } catch (_) {}
      if (mounted) setState(() => status = 'Đã lưu video hành trình');
      await refresh();
    } catch (_) {
      if (mounted) setState(() => status = 'Không lưu được video');
    } finally {
      if (mounted) setState(() { recording = false; busy = false; });
    }
  }

  Future<void> release() async {
    if (busy) return;
    if (recording) await finish();
    final c = camera;
    if (mounted) setState(() => camera = null);
    await c?.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      unawaited(release());
    }
  }

  Future<void> remove(File file) async {
    final ok = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Xóa video?'),
      content: const Text('Video sẽ bị xóa khỏi bộ nhớ của CarOS.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context,false), child: const Text('Hủy')),
        FilledButton(onPressed: () => Navigator.pop(context,true), child: const Text('Xóa')),
      ],
    ));
    if (ok != true || !mounted) return;
    try { await file.delete(); await refresh(); }
    catch (_) { if (mounted) setState(() => status = 'Không xóa được video'); }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    unawaited(camera?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !recording && !busy,
    child: Scaffold(appBar: AppBar(title: const Text('Camera hành trình')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Text(status),
        if (camera?.value.isInitialized == true)
          AspectRatio(aspectRatio: camera!.value.aspectRatio, child: CameraPreview(camera!)),
        Wrap(spacing: 8, children: [
          FilledButton(onPressed: busy || camera != null ? null : enable, child: const Text('Bật camera')),
          FilledButton(onPressed: busy || camera == null ? null : recording ? finish : begin, child: Text(recording ? 'Dừng và lưu' : 'Quay video')),
          OutlinedButton(onPressed: busy || camera == null ? null : release, child: const Text('Tắt camera')),
        ]),
        const Text('Mỗi đoạn tối đa 5 phút. Tối đa 20 đoạn; không tự xóa. Chỉ xem hoặc xóa khi đã đỗ xe.'),
        for (final clip in clips)
          ListTile(title: Text(clip.uri.pathSegments.last), leading: const Icon(Icons.movie),
            onTap: recording || busy ? null : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ClipScreen(file: clip))),
            trailing: IconButton(tooltip: 'Xóa video', onPressed: recording || busy ? null : () => remove(clip), icon: const Icon(Icons.delete_outline))),
      ]),
    ),
  );
}

class ClipScreen extends StatefulWidget {
  const ClipScreen({super.key, required this.file});
  final File file;
  @override
  State<ClipScreen> createState() => _ClipScreenState();
}

class _ClipScreenState extends State<ClipScreen> {
  late final VideoPlayerController player;
  bool ready = false, failed = false;
  @override
  void initState() {
    super.initState();
    player = VideoPlayerController.file(widget.file);
    unawaited(load());
  }
  Future<void> load() async {
    try {
      await player.initialize();
      if (mounted) setState(() => ready = true);
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }
  @override
  void dispose() { unawaited(player.dispose()); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Xem video')),
    body: Center(child: failed ? const Text('Không đọc được video') : !ready ? const CircularProgressIndicator() :
      Column(mainAxisSize: MainAxisSize.min, children: [
        AspectRatio(aspectRatio: player.value.aspectRatio, child: VideoPlayer(player)),
        ValueListenableBuilder<VideoPlayerValue>(valueListenable: player, builder: (context, value, _) => IconButton(
          tooltip: value.isPlaying ? 'Tạm dừng' : 'Phát',
          icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
          onPressed: () async {
            if (value.isPlaying) { await player.pause(); }
            else { if (value.position >= value.duration) await player.seekTo(Duration.zero); await player.play(); }
          },
        )),
      ])),
  );
}
