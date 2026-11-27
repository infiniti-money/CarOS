import 'dart:async';
import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:url_launcher/url_launcher.dart';

enum VoiceAction { map, music, phone, calendar, unknown }

VoiceAction parseVoice(String input) {
  final text = input.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  return switch (text) {
    'mở bản đồ' || 'bản đồ' => VoiceAction.map,
    'mở nhạc' || 'mở âm nhạc' || 'mở giải trí' => VoiceAction.music,
    'mở điện thoại' || 'mở danh bạ' || 'danh bạ' => VoiceAction.phone,
    'mở lịch' || 'xem lịch' || 'lịch hôm nay' => VoiceAction.calendar,
    _ => VoiceAction.unknown,
  };
}

String? safeDialNumber(String input) {
  final number = input.trim().replaceAll(RegExp(r'[ ()-]'), '');
  return RegExp(r'^\+?[0-9]{3,15}$').hasMatch(number) ? number : null;
}

class CommunicationScreen extends StatefulWidget {
  const CommunicationScreen({super.key, this.initialTab = 0});
  final int initialTab;
  @override
  State<CommunicationScreen> createState() => _CommunicationScreenState();
}

class _CommunicationScreenState extends State<CommunicationScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final speech = SpeechToText();
  final command = TextEditingController();
  final number = TextEditingController();
  final search = TextEditingController();
  late final TabController tabs;
  List<Contact> contacts = [];
  List<(String, DateTime)> events = [];
  String status = 'Chọn micro để nói hoặc nhập lệnh.';
  bool listening = false;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      unawaited(speech.cancel());
    }
  }

  Future<void> listen() async {
    if (busy) return;
    if (speech.isListening) {
      await speech.stop();
      return;
    }
    setState(() => busy = true);
    try {
      final available = await speech.initialize(
        onStatus: (_) {
          if (mounted) setState(() => listening = speech.isListening);
        },
        onError: (_) {
          if (mounted) setState(() { listening = false; status = 'Không nhận dạng được giọng nói'; });
        },
      );
      if (!mounted) return;
      if (!available) {
        setState(() => status = 'Micro hoặc nhận dạng giọng nói không khả dụng');
        return;
      }
      final locales = await speech.locales();
      final vietnamese = locales.where((locale) =>
        locale.localeId.toLowerCase().replaceAll('_', '-').startsWith('vi'));
      if (!mounted) return;
      if (vietnamese.isEmpty) {
        setState(() => status = 'Thiết bị chưa hỗ trợ nhận dạng tiếng Việt; hãy nhập lệnh.');
        return;
      }
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
      await speech.listen(localeId: vietnamese.first.localeId,
        listenFor: const Duration(seconds: 10),
        listenOptions: SpeechListenOptions(partialResults: true, cancelOnError: true),
        onResult: (result) {
          if (mounted) setState(() { command.text = result.recognizedWords; status = result.finalResult ? 'Kiểm tra lệnh rồi bấm Thực hiện' : 'Đang nghe'; });
        });
      if (mounted) setState(() => listening = speech.isListening);
    } catch (_) {
      if (mounted) setState(() => status = 'Không thể bật nhận dạng giọng nói');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> execute() async {
    if (busy || listening) return;
    switch (parseVoice(command.text)) {
      case VoiceAction.map:
        await open(Uri.parse('https://www.google.com/maps'));
        break;
      case VoiceAction.music:
        await open(Uri.parse('https://music.apple.com/'));
        break;
      case VoiceAction.phone:
        tabs.animateTo(1);
        break;
      case VoiceAction.calendar:
        tabs.animateTo(2);
        break;
      case VoiceAction.unknown:
        setState(() => status = 'Lệnh chưa hỗ trợ. Thử “mở bản đồ”, “mở danh bạ” hoặc “xem lịch”.');
        break;
    }
  }

  Future<void> open(Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    if (mounted) setState(() => status = 'Không thể mở ứng dụng trên thiết bị này');
  }

  Future<void> dial(String raw) async {
    final value = safeDialNumber(raw);
    if (value == null) {
      setState(() => status = 'Số điện thoại không hợp lệ');
      return;
    }
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Xác nhận gọi điện'),
      content: Text('Mở trình gọi điện cho $value?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Tiếp tục')),
      ],
    ));
    if (confirmed == true && mounted) await open(Uri(scheme: 'tel', path: value));
  }

  Future<void> loadContacts() async {
    if (busy || listening) return;
    setState(() { busy = true; contacts = []; });
    try {
      if (!await FlutterContacts.requestPermission(readonly: true)) {
        if (mounted) setState(() => status = 'Chưa cấp quyền danh bạ');
        return;
      }
      final rows = await FlutterContacts.getContacts(withProperties: true);
      if (mounted) setState(() { contacts = rows; status = 'Đã đọc ${rows.length} liên hệ'; });
    } catch (_) {
      if (mounted) setState(() => status = 'Không đọc được danh bạ');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> loadCalendar() async {
    if (busy || listening) return;
    setState(() { busy = true; events = []; });
    try {
      final calendar = DeviceCalendar.instance;
      final permission = await calendar.requestPermissions();
      if (permission != CalendarPermissionStatus.granted) {
        if (mounted) setState(() => status = 'Chưa cấp quyền đọc lịch');
        return;
      }
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final rows = await calendar.listEvents(today, today.add(const Duration(days: 7)));
      final items = rows.map((e) => (e.title, e.startDate)).toList()
        ..sort((a, b) => a.$2.compareTo(b.$2));
      if (mounted) setState(() { events = items; status = 'Có ${items.length} sự kiện trong 7 ngày'; });
    } catch (_) {
      if (mounted) setState(() => status = 'Không đọc được lịch thiết bị');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(speech.cancel());
    tabs.dispose();
    command.dispose();
    number.dispose();
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Trợ lý & Liên lạc'), bottom: TabBar(controller: tabs,
      tabs: const [Tab(text: 'Trợ lý'), Tab(text: 'Điện thoại'), Tab(text: 'Lịch')])),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: Text(status)),
      Expanded(child: TabBarView(controller: tabs, children: [
        ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Trợ lý tiếng Việt — chỉ nghe khi bạn bật micro.'),
          FilledButton.icon(onPressed: busy ? null : listen, icon: Icon(listening ? Icons.mic_off : Icons.mic), label: Text(listening ? 'Dừng nghe' : 'Bắt đầu nói')),
          TextField(controller: command, decoration: const InputDecoration(labelText: 'Lệnh tiếng Việt')),
          FilledButton(onPressed: busy || listening ? null : execute, child: const Text('Thực hiện')),
          const Text('Ví dụ: mở bản đồ, mở nhạc, mở danh bạ, xem lịch.'),
          const Text('Nhận dạng có thể dùng dịch vụ của hệ điều hành. Không gửi lời nói hoặc danh bạ đến máy chủ CarOS.'),
        ]),
        ListView(padding: const EdgeInsets.all(16), children: [
          TextField(controller: number, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Số điện thoại')),
          FilledButton(onPressed: busy || listening ? null : () => dial(number.text), child: const Text('Mở trình gọi')),
          OutlinedButton(onPressed: busy || listening ? null : loadContacts, child: const Text('Đọc danh bạ')),
          TextField(controller: search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Tìm tên liên hệ')),
          for (final contact in contacts.where((c) => c.displayName.toLowerCase().contains(search.text.toLowerCase())))
            for (final phone in contact.phones)
              ListTile(title: Text(contact.displayName), subtitle: Text(phone.number), trailing: const Icon(Icons.phone), onTap: busy || listening ? null : () => dial(phone.number)),
        ]),
        ListView(padding: const EdgeInsets.all(16), children: [
          OutlinedButton(onPressed: busy || listening ? null : loadCalendar, child: const Text('Đọc lịch 7 ngày')),
          for (final event in events)
            ListTile(leading: const Icon(Icons.event), title: Text(event.$1), subtitle: Text(event.$2.toLocal().toString().split('.').first)),
          const Text('Chỉ đọc; không sửa hoặc xóa sự kiện.'),
        ]),
      ])),
      const Padding(padding: EdgeInsets.all(8), child: Text('Chỉ thao tác khi đã đỗ xe.')),
    ]),
  );
}
