import 'dart:ui';
import 'trip.dart';
import 'entertainment.dart';
import 'communication.dart';
import 'navigation.dart';
import 'smart_bar.dart';
import 'dashcam.dart';
import 'launcher_prefs.dart';
import 'launcher_editor.dart';
import 'safety_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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

class _InfinitiAppState extends State<InfinitiApp> with WidgetsBindingObserver {
  late bool dark = widget.prefs.getBool('dark') ?? true;
  late bool glass = widget.prefs.getBool('glass') ?? true;
  late LauncherPrefs layout = LauncherPrefs.decode(widget.prefs.getString('launcher_layout'));
  bool get effectiveDark => layout.systemTheme ? WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark : dark;
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); }
  @override
  void didChangePlatformBrightness() { if (mounted && layout.systemTheme) setState(() {}); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Infiniti CarOS',
    debugShowCheckedModeBanner: false,
    locale: const Locale('vi'),
    supportedLocales: const [Locale('vi')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(colorSchemeSeed: const Color(0xff4789db), brightness: effectiveDark ? Brightness.dark : Brightness.light, useMaterial3: true),
    home: Dashboard(prefs: widget.prefs, dark: effectiveDark, glass: glass, layout: layout, onLayout: (value) async {
      final safe = LauncherPrefs.decode(value.encode());
      if (await widget.prefs.setString('launcher_layout', safe.encode()) && mounted) {
        setState(() => layout = safe);
      }
    }, onDark: (v) {
      setState(() { dark = v; layout = LauncherPrefs(order: layout.order, hidden: layout.hidden, wallpaper: layout.wallpaper, systemTheme: false); });
      widget.prefs.setString('launcher_layout', layout.encode());
      widget.prefs.setBool('dark', v);
    }, onGlass: (v) {
      setState(() => glass = v);
      widget.prefs.setBool('glass', v);
    }),
  );
}

class Dashboard extends StatelessWidget {
  const Dashboard({super.key, required this.prefs, required this.dark, required this.glass, required this.onDark, required this.onGlass, required this.layout, required this.onLayout});
  final SharedPreferences prefs;
  final bool dark, glass;
  final ValueChanged<bool> onDark, onGlass;
  final LauncherPrefs layout;
  final Future<void> Function(LauncherPrefs) onLayout;

  Future<void> editLauncher(BuildContext context) async {
    final result = await Navigator.of(context).push<LauncherPrefs>(MaterialPageRoute(builder: (_) => LauncherEditor(initial: layout)));
    if (result != null && context.mounted) await onLayout(result);
  }

  List<Color> get background => switch (layout.wallpaper) {
    'forest' => dark ? const [Color(0xff102b24), Color(0xff263c32)] : const [Color(0xffdcefe2), Color(0xfff6faf5)],
    'graphite' => dark ? const [Color(0xff17191c), Color(0xff34383e)] : const [Color(0xffe1e3e7), Color(0xfffafafa)],
    _ => dark ? const [Color(0xff101b2d), Color(0xff26364a)] : const [Color(0xffe3efff), Color(0xfff6f8fc)],
  };

  Future<void> open(BuildContext context, String url) async {
    try {
      if (await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Surface launch failures rather than implying an integration succeeded.
    }
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không thể mở ứng dụng.')));
  }

  void settings(BuildContext context) {
    final thisContext = context;
    showModalBottomSheet<void>(context: context, builder: (context) {
      bool localDark = dark, localGlass = glass;
      return StatefulBuilder(builder: (context, refresh) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const ListTile(title: Text('Cài đặt'), subtitle: Text('Điều chỉnh khi đã đỗ xe')),
        SwitchListTile(title: const Text('Chế độ tối'), value: localDark, onChanged: (v) { refresh(() => localDark = v); onDark(v); }),
        SwitchListTile(title: const Text('Hiệu ứng kính'), value: localGlass, onChanged: (v) { refresh(() => localGlass = v); onGlass(v); }),
        ListTile(title: const Text('Tùy chỉnh Launcher'), subtitle: const Text('Thứ tự, hiển thị, hình nền và tự động sáng/tối'), onTap: () { Navigator.pop(context); editLauncher(thisContext); }),
        const ListTile(title: Text('Infiniti CarOS 2.5'), subtitle: Text('Bản nền tảng • Chưa kết nối dữ liệu xe')),
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
    final allEntries = <(String, IconData, VoidCallback)>[
      ('Bản đồ', Icons.map_outlined, () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const NavigationScreen()))),
      ('Bản đồ Apple', Icons.navigation_outlined, () => open(context, 'https://maps.apple.com/')),
      ('Giải trí', Icons.music_note, () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const EntertainmentScreen()))),
      ('Spotify', Icons.headphones, () => open(context, 'https://open.spotify.com/')),
      ('Podcast', Icons.podcasts, () => open(context, 'https://podcasts.apple.com/')),
      ('Trợ lý', Icons.mic_none, () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CommunicationScreen()))),
      ('Điện thoại', Icons.phone_outlined, () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CommunicationScreen(initialTab: 1)))),
      ('Lịch', Icons.calendar_month, () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CommunicationScreen(initialTab: 2)))),
      ('Camera hành trình', Icons.videocam_outlined, () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DashCamScreen()))),
      ('Cài đặt', Icons.settings_outlined, () => settings(context)),
    ];
    final entries = [for (final name in layout.visible) ...allEntries.where((entry) => entry.$1 == name)];
    return Scaffold(body: DecoratedBox(
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: background)),
      child: SafeArea(child: LayoutBuilder(builder: (context, constraints) {
        final split = constraints.maxWidth >= 900;
        final columns = split ? 4 : constraints.maxWidth >= 760 ? 5 : constraints.maxWidth < 360 ? 2 : 3;
        final tiles = GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: columns, mainAxisSpacing: 8, crossAxisSpacing: 8, mainAxisExtent: 144, children: entries.map((e) => InkWell(borderRadius: BorderRadius.circular(24), onTap: e.$3, child: panel(context, Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 54, height: 54, decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [scheme.primaryContainer, scheme.surface])), child: Icon(e.$2, size: 30, color: scheme.onPrimaryContainer)), const SizedBox(height: 6),
          Flexible(child: Text(e.$1, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis)),
        ])))).toList());
        final launcher = SmartBar(dark: dark, glass: glass, launcherItems: entries.map((e) => e.$1).toList(), columns: columns, fallback: tiles, onAction: (label) {
          for (final entry in entries) {
            if (entry.$1 == label) { entry.$3(); return; }
          }
        });
        final trip = panel(context, TripPanel(prefs: prefs));
        return Column(children: [
          Expanded(child: ListView(padding: const EdgeInsets.all(12), children: [
            const Text('INFINITI', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 4)),
            const Text('CarOS • Tiếng Việt'),
            const SizedBox(height: 12),
            panel(context, const Row(children: [Icon(Icons.info_outline), SizedBox(width: 12), Expanded(child: Text('Chế độ độc lập • Chưa kết nối xe'))])),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SafetyScreen())), icon: const Icon(Icons.health_and_safety_outlined), label: const Text('An toàn và hỗ trợ')),
            const SizedBox(height: 12),
            if (split) Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 4, child: trip),
              const SizedBox(width: 12),
              Expanded(flex: 6, child: launcher),
            ]) else ...[trip, const SizedBox(height: 12), launcher],
          ])),
          Padding(padding: const EdgeInsets.all(12), child: SmartBar(
            dark: dark, glass: glass, onAction: (action) {
              switch (action) {
                case 'map': Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const NavigationScreen())); break;
                case 'music': Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const EntertainmentScreen())); break;
                case 'theme': onDark(!dark); break;
                case 'voice': Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CommunicationScreen())); break;
                case 'settings': settings(context); break;
              }
            },
          )),
        ]);
      })),
    ));
  }
}
