import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:infiniti_caros/dashcam.dart';

void main() {
  test('incomplete video is never published and staging is removed', () async {
    final dir = await Directory.systemTemp.createTemp('caros_clip_');
    addTearDown(() => dir.delete(recursive: true));
    await expectLater(saveDashClip(dir, 'trip_1.mp4', (path) async {
      await File(path).writeAsBytes([1, 2]);
      throw StateError('write failed');
    }), throwsStateError);
    expect(await dir.list().toList(), isEmpty);
  });
  test('completed video is published without overwriting existing file', () async {
    final dir = await Directory.systemTemp.createTemp('caros_clip_');
    addTearDown(() => dir.delete(recursive: true));
    final file = await saveDashClip(dir, 'trip_2.mp4', (path) async {
      await File(path).writeAsBytes([1, 2, 3]);
    });
    expect(await file.readAsBytes(), [1, 2, 3]);
    await expectLater(saveDashClip(dir, 'trip_2.mp4', (_) async {}), throwsStateError);
    expect(await dir.list().length, 1);
  });
  test('empty video and invalid file name are rejected', () async {
    final dir = await Directory.systemTemp.createTemp('caros_clip_');
    addTearDown(() => dir.delete(recursive: true));
    await expectLater(saveDashClip(dir, 'trip_3.mp4', (path) async {
      await File(path).create();
    }), throwsStateError);
    await expectLater(saveDashClip(dir, '../trip_3.mp4', (_) async {}), throwsArgumentError);
    expect(await dir.list().toList(), isEmpty);
  });
  test('dashcam only manages its own video filenames', () {
    expect(isDashClip('trip_123456.mp4'), isTrue);
    expect(isDashClip('../trip_123456.mp4'), isFalse);
    expect(isDashClip('other.mp4'), isFalse);
    expect(maxClips, 20);
    expect(clipDuration, const Duration(minutes: 5));
  });
}
