import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xml/xml.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'playback_session.dart';

Uri? secureMediaUri(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty &&
      uri.userInfo.isEmpty ? uri : null;
}

class Episode {
  const Episode(this.title, this.uri);
  final String title;
  final Uri uri;
}

List<Episode> parseEpisodes(String rss) {
  final document = XmlDocument.parse(rss);
  return document.findAllElements('item').map((item) {
    final enclosure = item.getElement('enclosure');
    final uri = secureMediaUri(enclosure?.getAttribute('url') ?? '');
    final type = enclosure?.getAttribute('type') ?? '';
    if (uri == null || !type.startsWith('audio/')) return null;
    return Episode(item.getElement('title')?.innerText ?? 'Podcast', uri);
  }).whereType<Episode>().take(100).toList();
}

Future<List<Episode>> fetchPodcast(Uri uri, http.Client client, {
  Duration timeout = const Duration(seconds: 15),
  int maxBytes = 2000000,
}) async {
  if (secureMediaUri(uri.toString()) == null) {
    throw const FormatException('HTTPS RSS required');
  }
  final request = http.Request('GET', uri)..followRedirects = false;
  final response = await client.send(request).timeout(timeout);
  if (response.statusCode != 200 ||
      (response.contentLength ?? 0) > maxBytes) {
    final subscription = response.stream.listen((_) {});
    await subscription.cancel();
    throw const FormatException('RSS response rejected');
  }
  final bytes = <int>[];
  await response.stream.timeout(timeout).forEach((chunk) {
    if (bytes.length + chunk.length > maxBytes) {
      throw const FormatException('RSS too large');
    }
    bytes.addAll(chunk);
  }).timeout(timeout, onTimeout: () {
    client.close();
    throw TimeoutException('RSS download exceeded deadline');
  });
  return parseEpisodes(utf8.decode(bytes));
}

class EntertainmentScreen extends StatefulWidget {
  const EntertainmentScreen({super.key, required this.prefs});
  final SharedPreferences prefs;
  @override
  State<EntertainmentScreen> createState() => _EntertainmentScreenState();
}

class _EntertainmentScreenState extends State<EntertainmentScreen> {
  final player = AudioPlayer();
  final source = TextEditingController();
  final feed = TextEditingController();
  http.Client? feedClient;
  List<Episode> episodes = [];
  String message = 'Chọn nguồn âm thanh HTTPS hợp pháp';
  String title = 'Chưa chọn nội dung';
  bool busy = false;
  bool loadingFeed = false;
  bool hasSource = false;
  bool saving = false;
  Uri? currentUri;
  late PlaybackSession? saved = PlaybackSession.decode(widget.prefs.getString(playbackSessionKey));
  StreamSubscription<PlayerException>? errors;

  @override
  void initState() {
    super.initState();
    errors = player.errorStream.listen((_) {
      if (mounted) setState(() => message = 'Không thể phát nguồn âm thanh');
    });
  }

  Future<void> playSource(Uri uri, String name, {PlaybackSession? restore}) async {
    if (busy) return;
    setState(() { busy = true; hasSource = false; currentUri = null; message = 'Đang tải âm thanh'; });
    try {
      await player.stop();
      final duration = await player.setUrl(uri.toString()).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (restore != null) {
        final position = restore.resumePosition(duration);
        if (position > Duration.zero) await player.seek(position);
      }
      if (!mounted) return;
      setState(() { title = name; currentUri = uri; hasSource = true; message = restore == null ? 'Đã tải nguồn' : 'Đã khôi phục ở trạng thái tạm dừng'; });
      if (restore == null) unawaited(resume());
    } catch (_) {
      if (mounted) {
        try { await player.stop(); } catch (_) {}
        if (mounted) setState(() => message = 'Nguồn âm thanh không khả dụng');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resume() async {
    try {
      if (player.processingState == ProcessingState.completed) {
        await player.seek(Duration.zero);
      }
      await player.play();
    } catch (_) {
      if (mounted) setState(() => message = 'Không thể phát âm thanh');
    }
  }

  Future<void> pause() async {
    try {
      await player.pause();
    } catch (_) {
      if (mounted) setState(() => message = 'Không thể tạm dừng');
    }
  }

  Future<void> saveSession() async {
    final uri = currentUri;
    if (busy || saving || !hasSource || uri == null) return;
    if (!PlaybackSession.allowed(uri)) {
      setState(() => message = 'Không lưu URL chứa thông tin xác thực, tham số hoặc đoạn neo.');
      return;
    }
    final position = player.duration == null ? Duration.zero : player.position;
    final session = PlaybackSession(uri: uri, title: title, position: position);
    final validated = PlaybackSession.decode(session.encode());
    if (validated == null) {
      setState(() => message = 'Không thể lưu phiên này.');
      return;
    }
    setState(() => saving = true);
    try {
      final ok = await widget.prefs.setString(playbackSessionKey, validated.encode());
      if (mounted) {
        setState(() {
          if (ok) saved = validated;
          message = ok ? 'Đã lưu phiên trên thiết bị' : 'Không lưu được phiên';
        });
      }
    } catch (_) {
      if (mounted) setState(() => message = 'Không lưu được phiên');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> clearSession() async {
    if (saving || busy) return;
    setState(() => saving = true);
    try {
      final ok = await widget.prefs.remove(playbackSessionKey);
      if (mounted) {
        setState(() {
          if (ok) saved = null;
          message = ok ? 'Đã xóa phiên đã lưu' : 'Không xóa được phiên';
        });
      }
    } catch (_) {
      if (mounted) setState(() => message = 'Không xóa được phiên');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> loadFeed() async {
    final uri = secureMediaUri(feed.text);
    if (loadingFeed) return;
    if (uri == null) {
      setState(() => message = 'Nhập địa chỉ RSS HTTPS hợp lệ');
      return;
    }
    setState(() { loadingFeed = true; episodes = []; });
    final client = http.Client();
    feedClient = client;
    try {
      final parsed = await fetchPodcast(uri, client);
      if (mounted) setState(() { episodes = parsed; message = parsed.isEmpty ? 'Không tìm thấy tập âm thanh HTTPS' : 'Đã tải ${parsed.length} tập'; });
    } catch (_) {
      if (mounted) setState(() => message = 'Không tải được RSS; kiểm tra URL trực tiếp');
    } finally {
      client.close();
      if (identical(feedClient, client)) feedClient = null;
      if (mounted) setState(() => loadingFeed = false);
    }
  }

  Future<void> external(String url) async {
    try {
      await player.pause();
      if (await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    if (mounted) setState(() => message = 'Không thể mở dịch vụ');
  }

  @override
  void dispose() {
    unawaited(errors?.cancel());
    unawaited(player.dispose());
    feedClient?.close();
    source.dispose();
    feed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Trung tâm giải trí')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      Text(message),
      StreamBuilder<PlayerState>(stream: player.playerStateStream, builder: (context, snapshot) {
        final state = snapshot.data;
        final playing = (state?.playing ?? false) && state?.processingState != ProcessingState.completed;
        final processing = state?.processingState;
        final waiting = processing == ProcessingState.loading || processing == ProcessingState.buffering;
        return Row(children: [
          IconButton(tooltip: playing ? 'Tạm dừng' : 'Phát', onPressed: !hasSource || busy ? null : playing ? pause : resume, icon: Icon(playing ? Icons.pause_circle : Icons.play_circle, size: 42)),
          Expanded(child: Text(waiting ? 'Đang đệm' : processing == ProcessingState.completed ? 'Đã kết thúc' : playing ? 'Đang phát' : 'Tạm dừng')),
        ]);
      }),
      const Divider(),
      const Text('Phiên phát cục bộ'),
      const Text('Lưu thủ công nguồn công khai và vị trí phát. Không tự phát khi mở lại.'),
      Wrap(spacing: 8, children: [
        OutlinedButton(onPressed: !hasSource || busy || saving ? null : saveSession, child: const Text('Lưu phiên hiện tại')),
        if (saved != null) ...[
          OutlinedButton(onPressed: busy || saving ? null : () { final previous = saved; if (previous != null) unawaited(playSource(previous.uri, previous.title, restore: previous)); }, child: const Text('Khôi phục phiên')),
          TextButton(onPressed: busy || saving ? null : clearSession, child: const Text('Xóa phiên')),
        ],
      ]),
      if (saved != null) Text('Đã lưu: ${saved!.title}'),
      const Divider(),
      const Text('Radio trực tuyến'),
      TextField(controller: source, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'URL luồng radio HTTPS')),
      FilledButton(onPressed: busy ? null : () {
        final uri = secureMediaUri(source.text);
        if (uri == null) { setState(() => message = 'URL HTTPS không hợp lệ'); return; }
        unawaited(playSource(uri, 'Radio'));
      }, child: const Text('Phát radio')),
      const Divider(),
      const Text('Podcast RSS'),
      TextField(controller: feed, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'URL RSS HTTPS')),
      OutlinedButton(onPressed: loadingFeed ? null : loadFeed, child: const Text('Tải danh sách tập')),
      for (final episode in episodes) ListTile(title: Text(episode.title), trailing: const Icon(Icons.play_arrow), onTap: busy ? null : () => playSource(episode.uri, episode.title)),
      const Divider(),
      ListTile(title: const Text('Spotify'), subtitle: const Text('Mở dịch vụ chính thức • Chưa kết nối API'), onTap: busy ? null : () => external('https://open.spotify.com/')),
      ListTile(title: const Text('Apple Music'), subtitle: const Text('Mở dịch vụ chính thức • Chưa tích hợp MusicKit'), onTap: busy ? null : () => external('https://music.apple.com/')),
      const Text('Chỉ nhập nguồn tin cậy và thao tác khi đã đỗ xe.'),
    ]),
  );
}
