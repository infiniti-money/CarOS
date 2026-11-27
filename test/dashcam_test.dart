import 'package:flutter_test/flutter_test.dart';
import 'package:infiniti_caros/dashcam.dart';

void main() {
  test('dashcam only manages its own video filenames', () {
    expect(isDashClip('trip_123456.mp4'), isTrue);
    expect(isDashClip('../trip_123456.mp4'), isFalse);
    expect(isDashClip('other.mp4'), isFalse);
    expect(maxClips, 20);
    expect(clipDuration, const Duration(minutes: 5));
  });
}
