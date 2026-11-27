import 'package:flutter_test/flutter_test.dart';
import 'package:infiniti_caros/launcher_prefs.dart';

void main() {
  test('corrupt layout falls back to full launcher', () {
    final p = LauncherPrefs.decode('not json');
    expect(p.visible, launcherDefaults);
    expect(p.wallpaper, 'ocean');
    expect(p.systemTheme, isFalse);
  });
  test('layout validates order and keeps settings available', () {
    final p = LauncherPrefs.decode('{"order":["Spotify","Spotify","unknown"],"hidden":["Lịch","Cài đặt"],"wallpaper":"forest","systemTheme":true}');
    expect(p.visible.first, 'Spotify');
    expect(p.visible.where((x) => x == 'Spotify').length, 1);
    expect(p.visible, isNot(contains('Lịch')));
    expect(p.visible, contains('Cài đặt'));
    final copy = LauncherPrefs.decode(p.encode());
    expect(copy.visible, p.visible);
    expect(copy.wallpaper, 'forest');
    expect(copy.systemTheme, isTrue);
  });
  test('unknown wallpaper falls back', () {
    expect(LauncherPrefs.decode('{"wallpaper":"unknown"}').wallpaper, 'ocean');
  });
}
