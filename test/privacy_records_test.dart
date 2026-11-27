import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:infiniti_caros/privacy_records.dart';
import 'package:infiniti_caros/playback_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('export only explicitly selected fields, no playback URL or extra trip fields', () async {
    SharedPreferences.setMockInitialValues({
      'trip_history': ['{"start":"2026-11-27T00:00:00Z","seconds":60,"meters":12,"extra":"private"}', 'invalid'],
      'parking_location': '{"lat":21,"lon":105,"saved":"2026-11-27T00:00:00Z"}',
      playbackSessionKey: '{"url":"https://example.org/private","title":"Podcast","positionMs":1000}',
      'dark': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final data = jsonDecode(exportPersonalRecords(prefs, {PersonalRecord.trips, PersonalRecord.playback})) as Map;
    expect(data.containsKey('parking'), isFalse);
    expect(data['trips'].length, 1);
    expect(data['trips'].first.containsKey('extra'), isFalse);
    expect(data['playback'].containsKey('url'), isFalse);
    expect(data.containsKey('dark'), isFalse);
    final parking = jsonDecode(exportPersonalRecords(prefs, {PersonalRecord.parking})) as Map;
    expect(parking['parking']['lat'], 21);
  });
  test('deletion leaves unselected data and settings untouched', () async {
    SharedPreferences.setMockInitialValues({'trip_history': ['x'], 'parking_location': 'x', playbackSessionKey: 'x', 'dark': true});
    final prefs = await SharedPreferences.getInstance();
    expect(await deletePersonalRecords(prefs, {PersonalRecord.trips, PersonalRecord.parking}), isEmpty);
    expect(prefs.containsKey('trip_history'), isFalse);
    expect(prefs.containsKey('parking_location'), isFalse);
    expect(prefs.containsKey(playbackSessionKey), isTrue);
    expect(prefs.getBool('dark'), isTrue);
  });
  test('invalid parking coordinates are excluded', () {
    expect(validatedParking('{"lat":91,"lon":105,"saved":"2026-11-27"}'), isNull);
    expect(validatedParking('{"lat":21,"lon":105,"saved":"invalid"}'), isNull);
  });
}
