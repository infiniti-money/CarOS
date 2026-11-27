import 'package:flutter_test/flutter_test.dart';
import 'package:infiniti_caros/playback_session.dart';

void main() {
  test('session round trip preserves position and Vietnamese title', () {
    final session = PlaybackSession(uri: Uri.parse('https://example.org/episode.mp3'),
      title: 'Tiếng Việt', position: const Duration(seconds: 42));
    final decoded = PlaybackSession.decode(session.encode())!;
    expect(decoded.title, session.title);
    expect(decoded.position, const Duration(seconds: 42));
    expect(decoded.uri, session.uri);
  });
  test('reject corrupt, credential-bearing or invalid session', () {
    expect(PlaybackSession.decode('bad json'), isNull);
    for (final url in ['http://example.org/a', 'https://user:pass@example.org/a',
      'https://example.org/a?token=secret', 'https://example.org/a#private']) {
      final session = PlaybackSession(uri: Uri.parse(url), title: 'Radio', position: Duration.zero);
      expect(PlaybackSession.decode(session.encode()), isNull);
    }
    expect(PlaybackSession.decode('{"url":"https://example.org/a","title":"Radio","positionMs":-1}'), isNull);
  });
  test('resume clamps missing and out of range duration to zero', () {
    final session = PlaybackSession(uri: Uri.parse('https://example.org/a'), title: 'Podcast', position: const Duration(seconds: 12));
    expect(session.resumePosition(const Duration(seconds: 30)), const Duration(seconds: 12));
    expect(session.resumePosition(const Duration(seconds: 12)), Duration.zero);
    expect(session.resumePosition(null), Duration.zero);
  });
}
