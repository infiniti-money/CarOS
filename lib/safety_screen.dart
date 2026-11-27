import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'communication.dart' show safeDialNumber;
import 'safety_policy.dart';

class SafetyScreen extends StatefulWidget {
  const SafetyScreen({super.key});
  @override
  State<SafetyScreen> createState() => _SafetyScreenState();
}

class _SafetyScreenState extends State<SafetyScreen> with WidgetsBindingObserver {
  final number = TextEditingController();
  Position? sample;
  bool busy = false;
  int generation = 0;
  String status = 'Không theo dõi hoặc gửi vị trí tự động.';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  String? get preview {
    final fix = sample;
    if (fix == null) return null;
    return locationMessage(latitude: fix.latitude, longitude: fix.longitude,
      accuracy: fix.accuracy, fix: fix.timestamp, now: DateTime.now());
  }

  Future<void> locate() async {
    if (busy) return;
    final token = ++generation;
    setState(() { busy = true; sample = null; status = 'Đang lấy một vị trí GPS'; });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw StateError('GPS disabled');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {
        throw StateError('Permission denied');
      }
      final position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15),
      ));
      if (!mounted || token != generation || WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
      setState(() {
        sample = position;
        status = preview == null ? 'GPS chưa đủ mới hoặc chính xác' : 'Xem trước và tự xác nhận nếu muốn sao chép.';
      });
    } catch (_) {
      if (mounted && token == generation) setState(() => status = 'Không lấy được vị trí. Kiểm tra quyền và GPS.');
    } finally {
      if (mounted && token == generation) setState(() => busy = false);
    }
  }

  Future<void> copyLocation() async {
    final text = preview;
    if (text == null || busy) {
      setState(() { sample = null; status = 'Vị trí đã cũ, hãy lấy lại GPS.'; });
      return;
    }
    // Revalidate at the point of explicit user action.
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) setState(() { sample = null; status = 'Đã sao chép. Bạn tự chọn người nhận và gửi; CarOS chưa gửi đi.'; });
    } catch (_) {
      if (mounted) setState(() => status = 'Không thể sao chép vị trí.');
    }
  }

  Future<void> callHelp() async {
    if (busy) return;
    final phone = safeDialNumber(number.text);
    if (phone == null) {
      setState(() => status = 'Nhập số điện thoại hỗ trợ hợp lệ.');
      return;
    }
    final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Mở trình gọi điện?'),
      content: Text('Số đã chọn: $phone. CarOS không tự thực hiện cuộc gọi.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Mở trình gọi')),
      ],
    ));
    if (!mounted || confirm != true) return;
    try {
      if (await launchUrl(Uri(scheme: 'tel', path: phone), mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    if (mounted) setState(() => status = 'Không mở được trình gọi. Dùng ứng dụng Điện thoại của thiết bị.');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden || state == AppLifecycleState.detached) {
      generation++;
      if (mounted) setState(() { sample = null; busy = false; status = 'Đã hủy phiên xem trước vị trí.'; });
    }
  }

  @override
  void dispose() {
    generation++;
    WidgetsBinding.instance.removeObserver(this);
    number.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = preview;
    return Scaffold(appBar: AppBar(title: const Text('An toàn và hỗ trợ')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Nếu khẩn cấp, sử dụng trình gọi điện hoặc dịch vụ cứu hộ địa phương. CarOS không thay thế hệ thống SOS của thiết bị.'),
        const SizedBox(height: 12),
        TextField(controller: number, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Số liên hệ hỗ trợ do bạn chọn')),
        FilledButton.icon(onPressed: busy ? null : callHelp, icon: const Icon(Icons.phone), label: const Text('SOS thủ công')),
        const Divider(),
        const Text('Chia sẻ vị trí một lần'),
        const Text('Chỉ thực hiện khi an toàn. Nội dung được đưa vào clipboard khi bạn bấm sao chép, có thể được đọc bởi ứng dụng nhận. Không gửi ngầm.'),
        OutlinedButton(onPressed: busy ? null : locate, child: const Text('Lấy vị trí hiện tại')),
        if (text != null) ...[
          SelectableText(text),
          FilledButton(onPressed: busy ? null : copyLocation, child: const Text('Xác nhận sao chép vị trí')),
          TextButton(onPressed: () => setState(() { sample = null; status = 'Đã hủy xem trước'; }), child: const Text('Hủy xem trước')),
        ],
        Text(status),
      ]),
    );
  }
}
