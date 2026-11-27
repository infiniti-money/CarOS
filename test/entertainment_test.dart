import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infiniti_caros/entertainment.dart';

void main() {
  test('RSS HTTP failures are rejected', () async {
    final client = MockClient((_) async => http.Response('missing', 404));
    addTearDown(client.close);
    await expectLater(fetchPodcast(Uri.parse('https://example.org/feed'), client), throwsFormatException);
  });
  test('RSS response size is bounded', () async {
    final client = MockClient((_) async => http.Response('123456', 200));
    addTearDown(client.close);
    await expectLater(fetchPodcast(Uri.parse('https://example.org/feed'), client, maxBytes: 5), throwsFormatException);
  });
  test('RSS preserves Vietnamese episode names', () async {
    final client = MockClient((_) async => http.Response(
      '<rss><channel><item><title>Tiếng Việt</title><enclosure url="https://example.org/a.mp3" type="audio/mpeg"/></item></channel></rss>',
      200, headers: {'content-type': 'application/xml; charset=utf-8'}));
    addTearDown(client.close);
    final rows = await fetchPodcast(Uri.parse('https://example.org/feed'), client);
    expect(rows.single.title, 'Tiếng Việt');
  });
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
