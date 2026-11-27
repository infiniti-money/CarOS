import 'package:flutter_test/flutter_test.dart';
import 'package:infiniti_caros/entertainment.dart';

void main() {
  test('only HTTPS media URLs without credentials', () {
    expect(secureMediaUri('https://example.org/radio.mp3'), isNotNull);
    expect(secureMediaUri('http://example.org/radio.mp3'), isNull);
    expect(secureMediaUri('https://user:pass@example.org/a'), isNull);
    expect(secureMediaUri('file:///tmp/audio'), isNull);
  });
  test('RSS accepts HTTPS audio enclosures only', () {
    final episodes = parseEpisodes('<rss><channel><item><title>Tập 1</title><enclosure url="https://example.org/a.mp3" type="audio/mpeg"/></item><item><enclosure url="http://example.org/b.mp3" type="audio/mpeg"/></item><item><enclosure url="https://example.org/c.mp4" type="video/mp4"/></item></channel></rss>');
    expect(episodes.length, 1);
    expect(episodes.single.title, 'Tập 1');
  });
}
