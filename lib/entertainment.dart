import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xml/xml.dart';

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

class EntertainmentScreen extends StatefulWidget {
  const EntertainmentScreen({super.key});
  @override
  State<EntertainmentScreen> createState() => _EntertainmentScreenState();
}

class _EntertainmentScreenState extends State<EntertainmentScreen> {
  final player = AudioPlayer();
  final source = TextEditingController();
  final feed = TextEditingController();
  final client = http.Client();
  List<Episode> episodes = [];
  String message = 'Chọn nguồn âm thanh HTTPS hợp pháp';
  String title = 'Chưa chọn nội dung';
  bool busy = false;
  bool loadingFeed = false;
  bool hasSource = false;
  StreamSubscription<PlayerException>? errors;

  @override
  void initState() {
    super.initState();
    errors = player.errorStream.listen((_) {
      if (mounted) setState(() => message = 'Không thể phát nguồn âm thanh');
    });
  }

  Future<void> playSource(Uri uri, String name) async {
    if (busy) return;
    setState(() { busy = true; hasSource = false; message = 'Đang tải âm thanh'; });
    try {
      await player.stop();
      await player.setUrl(uri.toString()).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      setState(() { title = name; hasSource = true; message = 'Đã tải nguồn'; });
      unawaited(resume());
    } catch (_) {
      if (mounted) setState(() => message = 'Nguồn âm thanh không khả dụng');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resume() async {
    try {
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

  Future<void> loadFeed() async {
    final uri = secureMediaUri(feed.text);
    if (uri == null || loadingFeed) {
      setState(() => message = 'Nhập địa chỉ RSS HTTPS hợp lệ');
      return;
    }
    setState(() { loadingFeed = true; episodes = []; });
    try {
      final request = http.Request('GET', uri)..followRedirects = false;
      final response = await client.send(request).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) throw FormatException('HTTP ${response.statusCode}');
      final bytes = <int>[];
      await for (final chunk in response.stream.timeout(const Duration(seconds: 15))) {
        bytes.addAll(chunk);
        if (bytes.length > 2000000) throw const FormatException('RSS too large');
      }
      final parsed = parseEpisodes(http.Response.bytes(bytes, 200, headers: {'content-type':'application/xml; charset=utf-8'}).body);
      if (mounted) setState(() { episodes = parsed; message = parsed.isEmpty ? 'Không tìm thấy tập âm thanh HTTPS' : 'Đã tải ${parsed.length} tập'; });
    } catch (_) {
      if (mounted) setState(() => message = 'Không tải được RSS; kiểm tra URL trực tiếp');
    } finally {
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
    client.close();
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
        final playing = state?.playing ?? false;
        final processing = state?.processingState;
        final waiting = processing == ProcessingState.loading || processing == ProcessingState.buffering;
        return Row(children: [
          IconButton(tooltip: playing ? 'Tạm dừng' : 'Phát', onPressed: !hasSource || busy ? null : playing ? pause : resume, icon: Icon(playing ? Icons.pause_circle : Icons.play_circle, size: 42)),
          Expanded(child: Text(waiting ? 'Đang đệm' : processing == ProcessingState.completed ? 'Đã kết thúc' : playing ? 'Đang phát' : 'Tạm dừng')),
        ]);
      }),
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
      ListTile(title: const Text('Spotify'), subtitle: const Text('Mở dịch vụ chính thức • Chưa kết nối API'), onTap: () => external('https://open.spotify.com/')),
      ListTile(title: const Text('Apple Music'), subtitle: const Text('Mở dịch vụ chính thức • Chưa tích hợp MusicKit'), onTap: () => external('https://music.apple.com/')),
      const Text('Chỉ nhập nguồn tin cậy và thao tác khi đã đỗ xe.'),
    ]),
  );
}
