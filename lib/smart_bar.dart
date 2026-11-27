import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SmartBar extends StatefulWidget {
  const SmartBar({super.key, required this.dark, required this.glass, required this.onAction});
  final bool dark, glass;
  final ValueChanged<String> onAction;
  @override
  State<SmartBar> createState() => _SmartBarState();
}

class _SmartBarState extends State<SmartBar> {
  bool native = false;
  MethodChannel? actions;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      probe();
    }
  }

  Future<void> probe() async {
    try {
      final available = await const MethodChannel('infiniti/glass').invokeMethod<bool>('available');
      if (mounted) setState(() => native = available == true);
    } catch (_) {
      // The Flutter bar remains usable if no native bridge is registered.
    }
  }

  void created(int id) {
    actions?.setMethodCallHandler(null);
    final channel = MethodChannel('infiniti/glass/actions/$id');
    actions = channel;
    channel.setMethodCallHandler((call) async {
      if (mounted && call.method == 'action' && call.arguments is String) {
        final action = call.arguments as String;
        if (const ['map','music','theme','voice','settings'].contains(action)) {
          widget.onAction(action);
        }
      }
    });
  }

  @override
  void dispose() {
    actions?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (native && widget.glass) {
      return SizedBox(height: 74, child: UiKitView(
        key: ValueKey(widget.dark), viewType: 'infiniti/glassbar',
        creationParams: {'dark': widget.dark},
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: created,
      ));
    }
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.surface.withValues(alpha: widget.glass ? .8 : 1), borderRadius: BorderRadius.circular(28), border: Border.all(color: colors.outlineVariant)),
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final item in <(String, String, IconData)>[
            ('map','Bản đồ',Icons.map_outlined),
            ('music','Âm nhạc',Icons.music_note),
            ('theme','Đổi chế độ sáng tối',widget.dark ? Icons.light_mode : Icons.dark_mode),
            ('voice','Trợ lý tiếng Việt',Icons.mic_none),
            ('settings','Cài đặt',Icons.settings_outlined),
          ])
            Flexible(child: IconButton(tooltip: item.$2, onPressed: () => widget.onAction(item.$1), icon: Icon(item.$3))),
        ],
      )),
    );
  }
}
