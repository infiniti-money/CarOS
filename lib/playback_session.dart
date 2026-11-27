import 'dart:convert';

const playbackSessionKey = 'playback_session_v1';

class PlaybackSession {
  const PlaybackSession({required this.uri, required this.title, required this.position});
  final Uri uri;
  final String title;
  final Duration position;

  // No credentials, query strings, fragments or non-HTTPS URLs at rest.
  // Signed or private URLs may contain secrets; users must re-enter them.
  static bool allowed(Uri uri) => uri.scheme == 'https' && uri.host.isNotEmpty &&
      uri.userInfo.isEmpty && !uri.hasQuery && !uri.hasFragment &&
      uri.toString().length <= 2048;

  static PlaybackSession? decode(String? raw) {
    if (raw == null || raw.length > 4096) return null;
    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return null;
      final url = data['url'];
      final title = data['title'];
      final ms = data['positionMs'];
      if (url is! String || title is! String || title.isEmpty || title.length > 200 ||
          ms is! int || ms < 0 || ms > const Duration(days: 7).inMilliseconds) {
        return null;
      }
      final uri = Uri.tryParse(url);
      if (uri == null || !allowed(uri)) return null;
      return PlaybackSession(uri: uri, title: title, position: Duration(milliseconds: ms));
    } catch (_) {
      return null;
    }
  }

  String encode() => jsonEncode({'url': uri.toString(), 'title': title, 'positionMs': position.inMilliseconds});

  Duration resumePosition(Duration? duration) {
    if (duration == null || duration <= Duration.zero || position >= duration) {
      return Duration.zero;
    }
    return position;
  }
}
