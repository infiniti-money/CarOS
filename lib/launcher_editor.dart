import 'package:flutter/material.dart';
import 'launcher_prefs.dart';

class LauncherEditor extends StatefulWidget {
  const LauncherEditor({super.key, required this.initial});
  final LauncherPrefs initial;
  @override
  State<LauncherEditor> createState() => _LauncherEditorState();
}
class _LauncherEditorState extends State<LauncherEditor> {
  late List<String> order = [...widget.initial.order];
  late Set<String> hidden = {...widget.initial.hidden};
  late String wallpaper = widget.initial.wallpaper;
  late bool automatic = widget.initial.systemTheme;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tùy chỉnh Launcher')),
    body: Column(children: [
      const Padding(padding: EdgeInsets.all(12), child: Text('Chỉ tùy chỉnh khi đã đỗ xe. Kéo để sắp xếp, bật/tắt biểu tượng.')),
      SwitchListTile(title: const Text('Sáng/tối theo hệ thống'), value: automatic,
        onChanged: (value) => setState(() => automatic = value)),
      ListTile(title: const Text('Hình nền'), trailing: DropdownButton<String>(
        value: wallpaper, items: const [
          DropdownMenuItem(value: 'ocean', child: Text('Đại dương')),
          DropdownMenuItem(value: 'forest', child: Text('Rừng xanh')),
          DropdownMenuItem(value: 'graphite', child: Text('Than chì')),
        ], onChanged: (value) {
          if (value != null) setState(() => wallpaper = value);
        })),
      Expanded(child: ReorderableListView(
        onReorderItem: (oldIndex, newIndex) => setState(() {
          order.insert(newIndex, order.removeAt(oldIndex));
        }),
        children: [for (final item in order)
          CheckboxListTile(key: ValueKey(item), title: Text(item), value: !hidden.contains(item),
            onChanged: item == 'Cài đặt' ? null : (checked) => setState(() {
              if (checked == true) { hidden.remove(item); } else { hidden.add(item); }
            })),
        ],
      )),
      SafeArea(top: false, child: Padding(padding: const EdgeInsets.all(12), child: Wrap(spacing: 12, children: [
        OutlinedButton(onPressed: () => setState(() {
          order = [...launcherDefaults]; hidden = {}; wallpaper = 'ocean'; automatic = false;
        }), child: const Text('Khôi phục mặc định')),
        FilledButton(onPressed: () => Navigator.pop(context, LauncherPrefs(
          order: order, hidden: hidden, wallpaper: wallpaper, systemTheme: automatic,
        )), child: const Text('Lưu tùy chỉnh')),
      ]))),
    ]),
  );
}
