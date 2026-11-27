import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(InfinitiApp(prefs: prefs));
}

class InfinitiApp extends StatefulWidget {
  const InfinitiApp({super.key, required this.prefs});
  final SharedPreferences prefs;
  @override
  State<InfinitiApp> createState() => _InfinitiAppState();
}

class _InfinitiAppState extends State<InfinitiApp> {
  late bool dark = widget.prefs.getBool('dark') ?? true;
  late bool glass = widget.prefs.getBool('glass') ?? true;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Infiniti CarOS',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: const Color(0xff4789db), brightness: dark ? Brightness.dark : Brightness.light, useMaterial3: true),
    home: Dashboard(dark: dark, glass: glass, onDark: (v) {
      setState(() => dark = v);
      widget.prefs.setBool('dark', v);
    }, onGlass: (v) {
      setState(() => glass = v);
      widget.prefs.setBool('glass', v);
    }),
  );
}

class Dashboard extends StatelessWidget {
  const Dashboard({super.key, required this.dark, required this.glass, required this.onDark, required this.onGlass});
  final bool dark, glass;
  final ValueChanged<bool> onDark, onGlass;

  Future<void> open(BuildContext context, String url) async {
    try {
      if (await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Surface launch failures rather than implying an integration succeeded.
    }
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không thể mở ứng dụng.')));
  }

  void settings(BuildContext context) {
    showModalBottomSheet<void>(context: context, builder: (context) {
      bool localDark = dark, localGlass = glass;
      return StatefulBuilder(builder: (context, refresh) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const ListTile(title: Text('Cài đặt'), subtitle: Text('Điều chỉnh khi đã đỗ xe')),
        SwitchListTile(title: const Text('Chế độ tối'), value: localDark, onChanged: (v) { refresh(() => localDark = v); onDark(v); }),
        SwitchListTile(title: const Text('Hiệu ứng kính'), value: localGlass, onChanged: (v) { refresh(() => localGlass = v); onGlass(v); }),
        const ListTile(title: Text('Infiniti CarOS 2.0'), subtitle: Text('Bản nền tảng • Chưa kết nối dữ liệu xe')),
      ])));
    });
  }

  Widget panel(BuildContext context, Widget child) {
    final colors = Theme.of(context).colorScheme;
    return ClipRRect(borderRadius: BorderRadius.circular(24), child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: glass ? 16 : 0, sigmaY: glass ? 16 : 0),
      child: DecoratedBox(decoration: BoxDecoration(color: colors.surface.withValues(alpha: glass ? .76 : 1), borderRadius: BorderRadius.circular(24), border: Border.all(color: colors.outlineVariant)), child: Padding(padding: const EdgeInsets.all(16), child: child)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = <(String, IconData, VoidCallback)>[
      ('Bản đồ', Icons.map_outlined, () => open(context, 'https://www.google.com/maps')),
      ('Apple Maps', Icons.navigation_outlined, () => open(context, 'https://maps.apple.com/')),
      ('Âm nhạc', Icons.music_note, () => open(context, 'https://music.apple.com/')),
      ('Spotify', Icons.headphones, () => open(context, 'https://open.spotify.com/')),
      ('Podcast', Icons.podcasts, () => open(context, 'https://podcasts.apple.com/')),
      ('Cài đặt', Icons.settings_outlined, () => settings(context)),
    ];
    return Scaffold(body: DecoratedBox(
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: dark ? const [Color(0xff101b2d), Color(0xff26364a)] : const [Color(0xffe3efff), Color(0xfff6f8fc)])),
      child: SafeArea(child: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 650;
        final tiles = GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: wide ? 6 : 3, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.15, children: entries.map((e) => InkWell(borderRadius: BorderRadius.circular(24), onTap: e.$3, child: panel(context, Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(e.$2, size: 30, color: scheme.primary), const SizedBox(height: 6),
          Text(e.$1, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
        ])))).toList());
        return Column(children: [
          Expanded(child: ListView(padding: const EdgeInsets.all(12), children: [
            const Text('INFINITI', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 4)),
            const Text('CarOS • Tiếng Việt'),
            const SizedBox(height: 12),
            panel(context, const Row(children: [Icon(Icons.info_outline), SizedBox(width: 12), Expanded(child: Text('Chế độ độc lập • Chưa có dữ liệu GPS hoặc kết nối xe'))])),
            const SizedBox(height: 12),
            panel(context, Row(children: [
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Hành trình'), Text('— km/h', style: TextStyle(fontSize: 28)), Text('GPS chưa tích hợp')])),
              FilledButton.icon(onPressed: () => open(context, 'https://www.google.com/maps'), icon: const Icon(Icons.navigation), label: const Text('Mở bản đồ')),
            ])),
            const SizedBox(height: 12), tiles,
          ])),
          Padding(padding: const EdgeInsets.all(12), child: panel(context, Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            IconButton(tooltip: 'Bản đồ', onPressed: () => open(context, 'https://www.google.com/maps'), icon: const Icon(Icons.map)),
            IconButton(tooltip: 'Âm nhạc', onPressed: () => open(context, 'https://music.apple.com/'), icon: const Icon(Icons.music_note)),
            IconButton(tooltip: 'Đổi chế độ sáng tối', onPressed: () => onDark(!dark), icon: Icon(dark ? Icons.light_mode : Icons.dark_mode)),
            IconButton(tooltip: 'Cài đặt', onPressed: () => settings(context), icon: const Icon(Icons.settings)),
          ]))),
        ]);
      })),
    ));
  }
}
