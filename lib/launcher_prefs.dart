import 'dart:convert';

const launcherDefaults = ['Bản đồ', 'Bản đồ Apple', 'Giải trí', 'Spotify',
  'Podcast', 'Trợ lý', 'Điện thoại', 'Lịch', 'Camera hành trình', 'Cài đặt'];
const wallpaperChoices = ['ocean', 'forest', 'graphite'];

class LauncherPrefs {
  const LauncherPrefs({required this.order, required this.hidden, required this.wallpaper, required this.systemTheme});
  final List<String> order;
  final Set<String> hidden;
  final String wallpaper;
  final bool systemTheme;
  factory LauncherPrefs.decode(String? raw) {
    Map data = {};
    try {
      final value = jsonDecode(raw ?? '{}');
      if (value is Map) data = value;
    } catch (_) {}
    final order = <String>[];
    final stored = data['order'];
    if (stored is List) {
      for (final item in stored) {
        if (item is String && launcherDefaults.contains(item) && !order.contains(item)) {
          order.add(item);
        }
      }
    }
    order.addAll(launcherDefaults.where((item) => !order.contains(item)));
    final hidden = <String>{};
    if (data['hidden'] is List) {
      for (final item in data['hidden'] as List) {
        if (item is String && launcherDefaults.contains(item) && item != 'Cài đặt') {
          hidden.add(item);
        }
      }
    }
    return LauncherPrefs(order: order, hidden: hidden,
      wallpaper: wallpaperChoices.contains(data['wallpaper']) ? data['wallpaper'] as String : 'ocean',
      systemTheme: data['systemTheme'] == true);
  }
  List<String> get visible => order.where((item) => !hidden.contains(item) || item == 'Cài đặt').toList();
  String encode() => jsonEncode({'order': order, 'hidden': hidden.toList(), 'wallpaper': wallpaper, 'systemTheme': systemTheme});
}
