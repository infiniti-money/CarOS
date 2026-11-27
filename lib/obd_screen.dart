import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'obd_protocol.dart';

const obdDeviceKey = 'obd_ble_device_v1';
const obdAutoKey = 'obd_ble_auto_v1';

// Supported BLE UART profile. Other adapters need their documented UUIDs.
final _service = Uuid.parse('0000ffe0-0000-1000-8000-00805f9b34fb');
final _uart = Uuid.parse('0000ffe1-0000-1000-8000-00805f9b34fb');

class ObdScreen extends StatefulWidget {
  const ObdScreen({super.key, required this.prefs});
  final SharedPreferences prefs;
  @override
  State<ObdScreen> createState() => _ObdScreenState();
}

class _ObdScreenState extends State<ObdScreen> with WidgetsBindingObserver {
  FlutterReactiveBle? ble;
  final devices = <String, DiscoveredDevice>{};
  final readings = <ObdPid, ObdSample>{};
  final frame = ObdFrame();
  StreamSubscription<DiscoveredDevice>? scan;
  StreamSubscription<ConnectionStateUpdate>? link;
  StreamSubscription<List<int>>? notifications;
  StreamSubscription<BleStatus>? bluetoothStatus;
  Timer? scanTimer, retry, refresh;
  Completer<String>? pending;
  QualifiedCharacteristic? channel;
  int generation = 0;
  int attempts = 0;
  bool busy = false, connected = false, active = true, auto = false;
  bool permissionReady = false;
  String? selected;
  String message = 'Chỉ kết nối adapter OBD-II BLE của bạn khi đã đỗ xe.';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    selected = widget.prefs.getString(obdDeviceKey);
    auto = widget.prefs.getBool(obdAutoKey) == true && selected != null;
    refresh = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && readings.isNotEmpty) setState(() {});
    });
    // No automatic permission prompt; previously approved device only.
    if (auto) unawaited(startSaved());
  }

  bool valid(int token) => mounted && active && generation == token;
  void show(String value) {
    if (mounted) setState(() => message = value);
  }

  Future<bool> permissions({required bool ask}) async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    if (Platform.isAndroid) {
      final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
      final list = sdk >= 31
          ? [Permission.bluetoothScan, Permission.bluetoothConnect]
          : [Permission.locationWhenInUse];
      for (final p in list) {
        final status = ask ? await p.request() : await p.status;
        if (!status.isGranted) return false;
      }
    }
    // CoreBluetooth handles the iOS system consent prompt.
    return true;
  }

  Future<bool> ready({required bool ask}) async {
    if (!await permissions(ask: ask) || !mounted || !active) return false;
    ble ??= FlutterReactiveBle();
    final radio = ble!;
    final status = await radio.statusStream.firstWhere((s) => s != BleStatus.unknown)
        .timeout(const Duration(seconds: 8));
    if (status != BleStatus.ready) return false;
    permissionReady = true;
    bluetoothStatus ??= radio.statusStream.listen((s) {
      if (s != BleStatus.ready && (connected || busy)) {
        unawaited(disconnect('Bluetooth không khả dụng', reconnect: false));
      }
    });
    return true;
  }

  Future<void> startSaved() async {
    final id = selected;
    if (id == null || !auto || busy || !active) return;
    final token = ++generation;
    setState(() => busy = true);
    try {
      if (!await ready(ask: false) || !valid(token)) {
        if (valid(token)) show('Cần bật Bluetooth/cấp quyền để kết nối lại.');
        return;
      }
      await connect(id, token);
    } catch (_) {
      if (valid(token)) await disconnect('Không thể kết nối lại', reconnect: true);
    } finally {
      if (valid(token) && link == null) setState(() => busy = false);
    }
  }

  Future<void> discover() async {
    if (busy || connected || !active) return;
    retry?.cancel();
    final token = ++generation;
    setState(() { busy = true; devices.clear(); message = 'Đang tìm adapter BLE FFE0…'; });
    try {
      if (!await ready(ask: true) || !valid(token)) {
        if (valid(token)) {
          setState(() { busy = false; message = 'Chưa có quyền hoặc Bluetooth chưa sẵn sàng.'; });
        }
        return;
      }
      scan = ble!.scanForDevices(withServices: [_service],
          scanMode: ScanMode.lowLatency, requireLocationServicesEnabled: false).listen((d) {
        if (valid(token) && (devices.length < 30 || devices.containsKey(d.id))) {
          setState(() => devices[d.id] = d);
        }
      }, onError: (Object _) {
        if (valid(token)) unawaited(stopScan('Không thể quét Bluetooth.'));
      });
      scanTimer = Timer(const Duration(seconds: 10), () {
        if (valid(token)) unawaited(stopScan('Chọn adapter của bạn trong danh sách.'));
      });
    } catch (_) {
      if (valid(token)) await stopScan('Không thể quét Bluetooth.');
    }
  }

  Future<void> stopScan(String text) async {
    scanTimer?.cancel();
    final current = scan;
    scan = null;
    await current?.cancel();
    if (mounted && active) setState(() { busy = false; message = text; });
  }

  Future<void> choose(String id) async {
    if (connected || !permissionReady || !active) return;
    final approved = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Kết nối adapter của bạn?'),
      content: const Text('CarOS chỉ đọc dữ liệu OBD-II tiêu chuẩn. Không xóa lỗi, không thay đổi cấu hình ECU. Thực hiện khi xe đỗ an toàn.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Kết nối')),
      ],
    ));
    if (approved != true || !mounted || !active || connected || link != null) return;
    final token = ++generation;
    scanTimer?.cancel();
    await scan?.cancel();
    scan = null;
    if (!valid(token)) return;
    setState(() { selected = id; attempts = 0; busy = true; devices.clear(); });
    try {
      await connect(id, token);
    } catch (_) {
      if (valid(token)) await disconnect('Kết nối không thành công', reconnect: false);
    }
  }

  Future<void> connect(String id, int token) async {
    if (!valid(token)) return;
    show('Đang kết nối adapter…');
    link = ble!.connectToAdvertisingDevice(id: id, withServices: [_service],
      prescanDuration: const Duration(seconds: 5),
      servicesWithCharacteristicsToDiscover: {_service: [_uart]},
      connectionTimeout: const Duration(seconds: 10)).listen((update) {
      if (!valid(token)) return;
      if (update.connectionState == DeviceConnectionState.connected && !connected) {
        setState(() { connected = true; message = 'Đang xác minh adapter…'; });
        unawaited(readLoop(id, token));
      } else if (update.connectionState == DeviceConnectionState.disconnected) {
        unawaited(disconnect('Mất kết nối OBD-II', reconnect: true));
      }
    }, onError: (Object _) {
      if (valid(token)) unawaited(disconnect('Không tìm thấy adapter', reconnect: true));
    });
  }

  Future<String> send(String command, int token) async {
    if (!valid(token) || channel == null || pending != null ||
        !allowedObdCommands.contains(command)) {
      throw StateError('Unavailable OBD command');
    }
    frame.clear();
    final completion = Completer<String>();
    pending = completion;
    try {
      await ble!.writeCharacteristicWithResponse(channel!, value: ascii.encode('$command\r'))
          .timeout(const Duration(seconds: 3));
      return await completion.future.timeout(const Duration(seconds: 4));
    } finally {
      if (identical(pending, completion)) pending = null;
    }
  }

  Future<void> readLoop(String id, int token) async {
    final characteristic = QualifiedCharacteristic(serviceId: _service,
        characteristicId: _uart, deviceId: id);
    channel = characteristic;
    try {
      notifications = ble!.subscribeToCharacteristic(characteristic).listen((bytes) {
        if (!valid(token) || pending == null || pending!.isCompleted) return;
        try {
          final response = frame.append(bytes);
          if (response != null) pending!.complete(response);
        } catch (_) {
          pending!.completeError(const FormatException('Invalid OBD frame'));
        }
      }, onError: (Object _) {
        if (valid(token)) unawaited(disconnect('Không nhận được dữ liệu BLE', reconnect: true));
      });
      // Give notification subscription time to become active; timeout fails closed.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      for (final command in adapterSetup) {
        if (!valid(token)) return;
        if (!adapterOk(await send(command, token))) throw StateError('Adapter not verified');
      }
      if (!valid(token)) return;
      setState(() { busy = false; attempts = 0; message = 'Đã kết nối adapter; đang đọc ECU.'; });
      while (valid(token) && connected) {
        for (final pid in ObdPid.values) {
          if (!valid(token)) return;
          final value = decodeObd(pid, await send(pid.command, token));
          if (!valid(token)) return;
          setState(() {
            if (value == null) { readings.remove(pid); }
            else { readings[pid] = ObdSample(value, DateTime.now()); }
          });
          await Future<void>.delayed(const Duration(milliseconds: 400));
        }
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    } catch (_) {
      if (valid(token)) await disconnect('Adapter/ECU không phản hồi hợp lệ', reconnect: true);
    }
  }

  Future<void> disconnect(String text, {required bool reconnect}) async {
    final token = ++generation;
    retry?.cancel();
    scanTimer?.cancel();
    final oldScan = scan, oldLink = link, oldNotifications = notifications;
    scan = null; link = null; notifications = null; channel = null;
    // Pending request will expire on its bounded timeout. Avoid completing
    // its future with an unhandled error before the write is acknowledged.
    pending = null; frame.clear();
    if (mounted) setState(() { connected = false; busy = true; readings.clear(); message = text; });
    try { await oldScan?.cancel(); } catch (_) {}
    try { await oldNotifications?.cancel(); } catch (_) {}
    try { await oldLink?.cancel(); } catch (_) {}
    if (!valid(token)) return;
    setState(() => busy = false);
    if (reconnect && auto && selected != null && attempts < 3) {
      attempts++;
      retry = Timer(Duration(seconds: 5 * attempts), () {
        if (valid(token)) unawaited(startSaved());
      });
    }
  }

  Future<void> remember(bool value) async {
    final id = selected;
    if (id == null) return;
    retry?.cancel();
    try {
      if (value) {
        if (!connected || busy) return;
        if (!await widget.prefs.setString(obdDeviceKey, id)) return;
        if (!await widget.prefs.setBool(obdAutoKey, true)) {
          await widget.prefs.remove(obdDeviceKey);
          return;
        }
      } else {
        await widget.prefs.remove(obdAutoKey);
        await widget.prefs.remove(obdDeviceKey);
      }
      if (mounted) setState(() => auto = value);
    } catch (_) { show('Không lưu được lựa chọn kết nối.'); }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      active = true;
      if (mounted) setState(() => busy = false);
      if (auto) { attempts = 0; unawaited(startSaved()); }
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      active = false;
      unawaited(disconnect('Đã dừng đọc khi ứng dụng vào nền', reconnect: false));
    }
  }

  @override
  void dispose() {
    active = false;
    generation++;
    WidgetsBinding.instance.removeObserver(this);
    refresh?.cancel(); retry?.cancel(); scanTimer?.cancel();
    unawaited(scan?.cancel()); unawaited(notifications?.cancel());
    unawaited(link?.cancel()); unawaited(bluetoothStatus?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Thông số xe • OBD-II')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Text(message),
      const Text('Chỉ hỗ trợ BLE UART FFE0/FFE1 tương thích ELM327. Không phải Bluetooth Classic hoặc đồng hồ an toàn của xe.'),
      Wrap(spacing: 8, children: [
        FilledButton(onPressed: busy || connected ? null : discover, child: const Text('Tìm adapter')),
        OutlinedButton(onPressed: busy || connected ? () async {
          await remember(false);
          await disconnect('Đã ngắt kết nối', reconnect: false);
        } : null, child: const Text('Ngắt kết nối')),
      ]),
      for (final d in devices.values)
        ListTile(title: Text(d.name.isEmpty ? 'Adapter BLE' : d.name),
          subtitle: Text('Tín hiệu ${d.rssi} dBm'), onTap: () => choose(d.id)),
      SwitchListTile(title: const Text('Ghi nhớ và tự kết nối lại'),
        subtitle: const Text('Chỉ khi mở màn hình này; tối đa 3 lần thử lại'),
        value: auto, onChanged: (connected && !busy) || auto ? remember : null),
      const Divider(),
      for (final pid in ObdPid.values)
        ListTile(title: Text(pid.label), trailing: Text(
          connected && readings[pid]?.fresh(DateTime.now()) == true
            ? '${readings[pid]!.value.toStringAsFixed(pid == ObdPid.voltage ? 2 : 0)} ${pid.unit}'
            : '—', style: Theme.of(context).textTheme.titleLarge)),
      const Text('Không có dữ liệu hoặc tín hiệu cũ: —. Không dùng để thay thế đồng hồ xe.'),
    ]),
  );
}
