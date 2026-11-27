import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart' as sharing;
import 'dashcam_policy.dart';
import 'face_control.dart';

const maxClips = 20;
const clipDuration = Duration(minutes: 5);

bool isDashClip(String name) => RegExp(r'^trip_[0-9]+\.mp4$').hasMatch(name);

// Interrupted copies are not valid video clips. Keep nonempty parts available
// for explicit review; only discard exact app-owned staging filenames.
Future<List<File>> interruptedClips(Directory directory) async {
  final result = <File>[];
  await for (final entry in directory.list(followLinks: false)) {
    final name = entry.uri.pathSegments.last;
    if (entry is File && name.endsWith('.part') &&
        isDashClip(name.substring(0, name.length - 5))) {
      result.add(entry);
    }
  }
  return result;
}

// Publish a clip only after the temporary file has been completely copied.
Future<File> saveDashClip(Directory directory, String name,
    Future<void> Function(String) write) async {
  if (!isDashClip(name)) throw ArgumentError.value(name, 'name');
  final destination = File('${directory.path}/$name');
  final pending = File('${destination.path}.part');
  if (await destination.exists() || await pending.exists()) {
    throw StateError('Clip already exists');
  }
  try {
    await write(pending.path);
    if (await pending.length() == 0) throw StateError('Empty clip');
    return await pending.rename(destination.path);
  } finally {
    if (await pending.exists()) await pending.delete();
  }
}

class DashCamScreen extends StatefulWidget {
  const DashCamScreen({super.key});
  @override
  State<DashCamScreen> createState() => _DashCamScreenState();
}

class _DashCamScreenState extends State<DashCamScreen> with WidgetsBindingObserver {
  CameraController? camera;
  Timer? timer;
  bool busy = false, recording = false, foreground = true, releasing = false;
  bool releaseRequested = false;
  String status = 'Bật camera khi đã đỗ xe. Không ghi âm.';
  List<File> clips = [];
  List<File> interrupted = [];
  Set<String> protectedNames = {};
  int libraryBytes = 0;
  bool loop = false, protectCurrent = false, libraryReady = false;

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

  Future<List<ClipRecord>> readLibrary(Directory dir) async {
    final records = <ClipRecord>[];
    await for (final entry in dir.list(followLinks: false)) {
      final name = entry.uri.pathSegments.last;
      if (entry is! File || !isDashClip(name)) continue;
      final locked = await File('${entry.path}.lock').exists();
      final stamp = int.parse(name.substring(5, name.length - 4));
      records.add(ClipRecord(name, await entry.length(), locked, stamp));
    }
    return records;
  }

  Future<void> refresh() async {
    try {
      final dir = await directory();
      final rows = await dir.list(followLinks: false).where((e) => e is File && isDashClip(e.uri.pathSegments.last)).cast<File>().toList();
      rows.sort((a,b) => b.path.compareTo(a.path));
      final records = await readLibrary(dir);
      final parts = await interruptedClips(dir);
      if (mounted) {
        setState(() {
        clips = rows;
        interrupted = parts;
        protectedNames = records.where((c) => c.locked).map((c) => c.name).toSet();
        libraryBytes = records.fold(0, (sum, c) => sum + c.bytes);
        libraryReady = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() { libraryReady = false; status = 'Không đọc được video đã lưu'; });
    }
  }

  Future<void> enable() async {
    if (busy || releasing || camera != null || !foreground) return;
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
      if (mounted && releaseRequested) unawaited(release());
    }
  }

  Future<void> begin() async {
    final c = camera;
    if (busy || releasing || recording || c == null || !foreground || !libraryReady) return;
    setState(() => busy = true);
    try {
      final existing = await readLibrary(await directory());
      if (planClipEviction(existing, 1, loop: loop) == null) {
        if (mounted) setState(() => status = 'Kho video đã đầy hoặc mọi video đều được khóa.');
        return;
      }
      if (!mounted || !foreground || releaseRequested) return;
      await c.startVideoRecording();
      if (!mounted) return;
      setState(() { recording = true; protectCurrent = false; status = 'ĐANG QUAY • Không ghi âm'; });
      timer = Timer(clipDuration, () => unawaited(finish(rotate: true)));
    } catch (_) {
      if (mounted) setState(() => status = 'Không bắt đầu được video');
    } finally {
      if (mounted) setState(() => busy = false);
      if (mounted && (releaseRequested || !foreground)) unawaited(release());
    }
  }

  Future<void> finish({bool rotate = false}) async {
    final c = camera;
    if (busy || !recording || c == null) return;
    timer?.cancel();
    setState(() => busy = true);
    var saved = false;
    try {
      final result = await c.stopVideoRecording();
      final dir = await directory();
      final name = 'trip_${DateTime.now().microsecondsSinceEpoch}.mp4';
      final source = File(result.path);
      try {
        final records = await readLibrary(dir);
        final removeNames = planClipEviction(records, await source.length(), loop: loop);
        if (removeNames == null) throw StateError('Không đủ dung lượng video');
        // Only delete after the new clip has been copied successfully.
        final file = await saveDashClip(dir, name, result.saveTo);
        if (protectCurrent) await File('${file.path}.lock').writeAsString('protected', flush: true);
        for (final old in removeNames) {
          final target = File('${dir.path}/$old');
          if (await File('${target.path}.lock').exists()) {
            throw StateError('Video protected');
          }
          await target.delete();
        }
        saved = true;
      } finally {
        try { await source.delete(); } catch (_) {}
        await refresh();
      }
      if (mounted) setState(() => status = 'Đã lưu video hành trình');
      await refresh();
    } catch (_) {
      if (mounted) setState(() => status = 'Dừng quay: không đủ dung lượng hoặc lỗi lưu video');
    } finally {
      if (mounted) setState(() { recording = false; busy = false; });
      if (mounted && releaseRequested && !releasing) {
        unawaited(release());
      } else if (mounted && saved && rotate && loop && foreground && !releasing) {
        unawaited(begin());
      }
    }
  }

  Future<void> release() async {
    if (!mounted || releasing) return;
    if (busy) {
      releaseRequested = true;
      return;
    }
    setState(() { releasing = true; releaseRequested = false; });
    try {
      if (recording) await finish();
      final c = camera;
      if (mounted) setState(() => camera = null);
      await c?.dispose();
    } catch (_) {
      if (mounted) setState(() => status = 'Không thể giải phóng camera');
    } finally {
      if (mounted) setState(() { releasing = false; releaseRequested = false; });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      unawaited(release());
    }
  }

  Future<void> discardInterrupted() async {
    if (busy || recording || releasing || camera != null || interrupted.isEmpty) return;
    setState(() => busy = true);
    try {
      final ok = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
        title: const Text('Xóa bản sao chưa hoàn tất?'),
        content: const Text('Các tệp tạm có thể chứa dữ liệu video chưa hoàn chỉnh. Không xóa video đã lưu hoặc khóa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa tệp tạm')),
        ],
      ));
      if (!mounted || ok != true || !foreground || releaseRequested) return;
      final dir = await directory();
      for (final file in await interruptedClips(dir)) {
        if (await FileSystemEntity.type(file.path, followLinks: false) == FileSystemEntityType.file) {
          await file.delete();
        }
      }
      await refresh();
      if (mounted) setState(() => status = 'Đã dọn các bản sao chưa hoàn tất');
    } catch (_) {
      if (mounted) setState(() => status = 'Không dọn được toàn bộ tệp tạm');
    } finally {
      if (mounted) setState(() => busy = false);
      if (mounted && releaseRequested) unawaited(release());
    }
  }

  Future<void> toggleProtection(File file) async {
    if (busy || recording || releasing) return;
    setState(() => busy = true);
    try {
      final lock = File('${file.path}.lock');
      if (await lock.exists()) {
        await lock.delete();
      } else {
        await lock.writeAsString('protected', flush: true);
      }
      await refresh();
    } catch (_) {
      if (mounted) setState(() => status = 'Không cập nhật được khóa video');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> remove(File file) async {
    if (busy || recording || releasing || protectedNames.contains(file.uri.pathSegments.last)) return;
    final ok = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Xóa video?'),
      content: const Text('Video sẽ bị xóa khỏi bộ nhớ của CarOS.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context,false), child: const Text('Hủy')),
        FilledButton(onPressed: () => Navigator.pop(context,true), child: const Text('Xóa')),
      ],
    ));
    if (ok != true || !mounted) return;
    try {
      if (await File('${file.path}.lock').exists()) return;
      await file.delete(); await refresh();
    }
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
    canPop: !recording && !busy && !releasing,
    child: Scaffold(appBar: AppBar(title: const Text('Camera hành trình')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Text(status),
        if (camera?.value.isInitialized == true)
          AspectRatio(aspectRatio: camera!.value.aspectRatio, child: CameraPreview(camera!)),
        Wrap(spacing: 8, children: [
          FilledButton(onPressed: busy || releasing || camera != null ? null : enable, child: const Text('Bật camera')),
          FilledButton(onPressed: busy || releasing || camera == null ? null : recording ? finish : begin, child: Text(recording ? 'Dừng và lưu' : 'Quay video')),
          OutlinedButton(onPressed: busy || releasing || camera == null ? null : release, child: const Text('Tắt camera')),
        ]),
        OutlinedButton.icon(onPressed: busy || recording || releasing || camera != null ? null : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const FaceControlScreen())), icon: const Icon(Icons.face), label: const Text('Thử điều khiển khuôn mặt khi đỗ xe')),
        SwitchListTile(title: const Text('Ghi vòng lặp'), subtitle: const Text('Khi đầy, tự xóa video cũ nhất chưa khóa. Chỉ bật khi đã đỗ xe.'), value: loop, onChanged: busy || recording || releasing ? null : (value) => setState(() => loop = value)),
        if (recording) OutlinedButton.icon(onPressed: busy ? null : () => setState(() => protectCurrent = !protectCurrent), icon: Icon(protectCurrent ? Icons.lock : Icons.lock_open), label: Text(protectCurrent ? 'Đoạn hiện tại đã được đánh dấu' : 'Bảo vệ đoạn đang quay')),
        Text('Kho video: ${(libraryBytes / 1048576).toStringAsFixed(1)} / 1024 MiB • ${clips.length}/20 đoạn'),
        const Text('Mỗi đoạn tối đa 5 phút. Dừng khi hết dung lượng; giới hạn áp dụng cho video đã lưu, không gồm tệp đang ghi. Chỉ xem hoặc xóa khi đã đỗ xe.'),
        if (interrupted.isNotEmpty)
          ListTile(leading: const Icon(Icons.warning_amber), title: Text('Có ${interrupted.length} tệp ghi chưa hoàn tất'), subtitle: const Text('Không phát như video hợp lệ; chỉ dọn khi bạn xác nhận.'), trailing: TextButton(onPressed: busy || recording || releasing || camera != null ? null : discardInterrupted, child: const Text('Dọn tệp'))),
        for (final clip in clips)
          ListTile(title: Text(clip.uri.pathSegments.last), leading: const Icon(Icons.movie),
            onTap: recording || busy || releasing ? null : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ClipScreen(file: clip))),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(tooltip: protectedNames.contains(clip.uri.pathSegments.last) ? 'Bỏ khóa video' : 'Bảo vệ video', onPressed: recording || busy || releasing ? null : () => toggleProtection(clip), icon: Icon(protectedNames.contains(clip.uri.pathSegments.last) ? Icons.lock : Icons.lock_open)),
              IconButton(tooltip: 'Xóa video', onPressed: recording || busy || releasing || protectedNames.contains(clip.uri.pathSegments.last) ? null : () => remove(clip), icon: const Icon(Icons.delete_outline)),
            ])),
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

class _ClipScreenState extends State<ClipScreen> with WidgetsBindingObserver {
  late final VideoPlayerController player;
  bool ready = false, failed = false, sharingFile = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
  Future<void> shareClip(BuildContext anchor) async {
    if (sharingFile || !ready) return;
    final box = anchor.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final origin = box.localToGlobal(Offset.zero) & box.size;
    setState(() => sharingFile = true);
    try {
      await player.pause();
      if (!mounted || !await widget.file.exists()) return;
      if (!mounted) return;
      await sharing.SharePlus.instance.share(sharing.ShareParams(
        files: [sharing.XFile(widget.file.path, mimeType: 'video/mp4')],
        sharePositionOrigin: origin,
      ));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không thể mở bảng chia sẻ video')));
    } finally {
      if (mounted) setState(() => sharingFile = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && ready) {
      unawaited(player.pause().catchError((Object _) {}));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(player.dispose());
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Xem video'), actions: [Builder(builder: (anchor) => IconButton(tooltip: 'Chia sẻ video', onPressed: ready && !sharingFile ? () => shareClip(anchor) : null, icon: const Icon(Icons.share)))]),
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
