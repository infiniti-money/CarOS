import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_carplay/flutter_carplay.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart' show InfinitiApp;
import 'car_connection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(CarHost(prefs: prefs));
}

class CarHost extends StatefulWidget {
  const CarHost({super.key, required this.prefs});
  final SharedPreferences prefs;
  @override
  State<CarHost> createState() => _CarHostState();
}

class _CarHostState extends State<CarHost> {
  FlutterCarplay? ios;
  FlutterAndroidAuto? android;
  ConnectionStatusTypes status = ConnectionStatusTypes.unknown;
  bool installing = false, retry = false;
  int generation = 0;
  CarCategory category = CarCategory.unavailable;
  AudioPlayer? audio;
  final audioGate = CarAudioGate();
  static final stream = carAudioUri(const String.fromEnvironment('CAROS_CAR_AUDIO_URL'));

  @override
  void initState() {
    super.initState();
    if (kIsWeb || !const bool.fromEnvironment('CAROS_CAR_HOST')) return;
    unawaited(prepare());
  }

  Future<void> prepare() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      String? configured;
      try {
        configured = await const MethodChannel('infiniti/car_profile').invokeMethod<String>('category');
      } catch (_) { return; }
      if (!mounted) return;
      category = carCategory(configured, ios: true);
      if (category == CarCategory.unavailable) return;
      if (category == CarCategory.audio) audio = AudioPlayer();
      ios = FlutterCarplay()..addListenerOnConnectionChange(changed);
      unawaited(install());
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      category = carCategory(const String.fromEnvironment('CAROS_ANDROID_CATEGORY', defaultValue: 'poi'), ios: false);
      if (category != CarCategory.poi) return;
      android = FlutterAndroidAuto()..addListenerOnConnectionChange(changed);
      if (FlutterAndroidAuto.connectionStatus == ConnectionStatusTypes.connected.name) {
        changed(ConnectionStatusTypes.connected);
      }
    }
  }

  void changed(ConnectionStatusTypes next) {
    if (!mounted) return;
    final newConnection = next == ConnectionStatusTypes.connected && status != next;
    setState(() => status = next);
    if (newConnection && android != null) unawaited(install());
    if (next != ConnectionStatusTypes.connected && audio != null) {
      unawaited(stopCarAudio(audio!).catchError((Object _) {}));
    }
  }

  Future<void> install() async {
    if (installing) { retry = true; return; }
    installing = true;
    final token = generation;
    try {
      // Reload because the phone UI may have changed parking state.
      await widget.prefs.reload();
      if (!mounted || token != generation) return;
      final parking = parkingSummary(widget.prefs.getString('parking_location'));
      if (ios != null && category == CarCategory.audio) {
        await installAudio();
      } else if (ios != null && category == CarCategory.drivingTask) {
        await FlutterCarplay.setRootTemplate(rootTemplate: CPListTemplate(
          title: 'Infiniti CarOS',
          sections: [CPListSection(items: [
            CPListItem(text: 'Vị trí đỗ xe', detailText: parking,
              onPress: (complete, item) async {
                try {
                  await widget.prefs.reload();
                  item.setDetailText(parkingSummary(widget.prefs.getString('parking_location')));
                } finally { await complete(); }
              }),
          ])],
        ));
      } else if (android != null && status == ConnectionStatusTypes.connected) {
        await FlutterAndroidAuto.setRootTemplate(template: AAListTemplate(
          title: 'Infiniti CarOS',
          sections: [AAListSection(items: [
            AAListItem(title: 'Vị trí đỗ xe', subtitle: parking,
              onPress: (complete, item) async {
                try { await widget.prefs.reload(); retry = true; }
                finally { await complete(); }
                if (mounted && status == ConnectionStatusTypes.connected) unawaited(install());
              }),
          ])],
        ));
      }
    } catch (error) {
      debugPrint('CarOS native root unavailable: ${error.runtimeType}');
    } finally {
      installing = false;
      if (retry && mounted && token == generation) {
        retry = false;
        if (ios != null || status == ConnectionStatusTypes.connected) unawaited(install());
      }
    }
  }

  Future<void> stopCarAudio(AudioPlayer player) async {
    audioGate.beginStop();
    try {
      await player.stop();
    } finally {
      audioGate.finishStop();
    }
  }

  bool get audioConnected => mounted && status == ConnectionStatusTypes.connected;

  Future<void> installAudio() async {
    final player = audio;
    if (player == null) return;
    await FlutterCarplay.setRootTemplate(rootTemplate: CPListTemplate(
      title: 'Âm thanh Infiniti',
      sections: [CPListSection(items: [
        CPListItem(text: 'Phát radio', detailText: stream == null ? 'Chưa cấu hình nguồn HTTPS hợp lệ' : 'Nguồn radio được cấu hình',
          onPress: (complete, item) async {
            int? lease;
            try {
              if (stream == null) return;
              final token = audioGate.beginPlay(connected: audioConnected);
              if (token == null) return;
              lease = token;
              await player.setUrl(stream.toString()).timeout(const Duration(seconds: 15));
              if (!audioGate.current(token, connected: audioConnected)) return;
              unawaited(player.play().catchError((Object _) {
                if (audioGate.current(token, connected: audioConnected)) {
                  item.setDetailText('Không phát được radio');
                }
              }));
              item.setDetailText('Đã yêu cầu phát radio');
            } catch (_) {
              final token = lease;
              if (token != null && audioGate.current(token, connected: audioConnected)) {
                item.setDetailText('Không tải được nguồn radio');
                try { await stopCarAudio(player); } catch (_) {}
              }
            } finally {
              final token = lease;
              if (token != null) audioGate.finishPlay(token);
              await complete();
            }
          }),
        CPListItem(text: 'Dừng radio', detailText: 'Chạm để dừng nguồn radio của CarOS',
          onPress: (complete, item) async {
            try {
              if (!audioConnected) return;
              await stopCarAudio(player);
              if (audioConnected) item.setDetailText('Đã dừng radio');
            } catch (_) {
              if (audioConnected) item.setDetailText('Không thể dừng radio');
            } finally { await complete(); }
          }),
      ])],
    ));
  }

  @override
  void dispose() {
    generation++;
    audioGate.dispose();
    unawaited(audio?.dispose());
    ios?.removeListenerOnConnectionChange();
    ios?.closeConnection();
    android?.removeListenerOnConnectionChange();
    android?.closeConnection();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => InfinitiApp(prefs: widget.prefs);
}
