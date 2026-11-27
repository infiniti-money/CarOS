import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:infiniti_caros/dashcam.dart';
import 'package:infiniti_caros/dashcam_policy.dart';

void main() {
  test('loop only evicts oldest unlocked videos', () {
    const clips = [ClipRecord('protected', 60, true, 1),
      ClipRecord('new', 20, false, 3), ClipRecord('old', 20, false, 2)];
    expect(planClipEviction(clips, 20, loop: true, byteLimit: 100), ['old']);
    expect(planClipEviction(clips, 20, loop: false, byteLimit: 100), isNull);
    expect(planClipEviction(clips, 50, loop: true, byteLimit: 100), isNull);
  });
  test('count and oversized new clips are bounded', () {
    const clips = [ClipRecord('old', 2, false, 1)];
    expect(planClipEviction(clips, 3, loop: true, countLimit: 1), ['old']);
    expect(planClipEviction(clips, 101, loop: true, byteLimit: 100), isNull);
    expect(planClipEviction([], 3, loop: false, byteLimit: 100), isEmpty);
  });
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
