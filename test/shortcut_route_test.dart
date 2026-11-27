import 'package:flutter_test/flutter_test.dart';
import 'package:infiniti_caros/shortcut_route.dart';

void main() {
  test('Siri routes use an exact allowlist', () {
    expect(parseShortcutRoute('map'), ShortcutRoute.map);
    expect(parseShortcutRoute('audio'), ShortcutRoute.audio);
    expect(parseShortcutRoute('assistant'), ShortcutRoute.assistant);
  });
  test('reject arbitrary or sensitive actions', () {
    for (final value in [null, 42, ' MAP ', 'tel:113', 'https://example.org', 'record', 'delete', 'play', 'share', 'gps']) {
      expect(parseShortcutRoute(value), isNull);
    }
  });
}
