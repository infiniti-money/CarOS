import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'playback_session.dart';
import 'trip.dart' show decodeTrip;

enum PersonalRecord { trips, parking, playback }
const personalRecordKeys = <PersonalRecord, String>{
  PersonalRecord.trips: 'trip_history',
  PersonalRecord.parking: 'parking_location',
  PersonalRecord.playback: playbackSessionKey,
};

Map<String, Object>? validatedParking(String? raw) {
  try {
    final value = jsonDecode(raw ?? '');
    if (value is! Map) return null;
    final lat = value['lat'], lon = value['lon'], saved = value['saved'];
    if (lat is! num || lon is! num || !lat.isFinite || !lon.isFinite ||
        lat.abs() > 90 || lon.abs() > 180 || saved is! String ||
        DateTime.tryParse(saved) == null) {
      return null;
    }
    return {'lat': lat, 'lon': lon, 'saved': saved};
  } catch (_) {
    return null;
  }
}

String exportPersonalRecords(SharedPreferences prefs, Set<PersonalRecord> selection) {
  final payload = <String, Object>{'schema': 1};
  if (selection.contains(PersonalRecord.trips)) {
    final trips = (prefs.getStringList('trip_history') ?? []).take(100)
        .map(decodeTrip).whereType<Map<String, dynamic>>();
    // Explicit field allowlist: do not include extra values in stored JSON.
    payload['trips'] = trips.map((row) => {
      'start': row['start'], 'seconds': row['seconds'], 'meters': row['meters'],
    }).toList();
  }
  if (selection.contains(PersonalRecord.parking)) {
    payload['parking'] = validatedParking(prefs.getString('parking_location')) ?? <String, Object>{};
  }
  if (selection.contains(PersonalRecord.playback)) {
    final session = PlaybackSession.decode(prefs.getString(playbackSessionKey));
    payload['playback'] = session == null ? <String, Object>{} : {
      'title': session.title, 'positionMs': session.position.inMilliseconds,
    };
  }
  return const JsonEncoder.withIndent('  ').convert(payload);
}

Future<Set<PersonalRecord>> deletePersonalRecords(SharedPreferences prefs, Set<PersonalRecord> selection) async {
  final failed = <PersonalRecord>{};
  for (final record in selection) {
    final key = personalRecordKeys[record]!;
    try {
      if (prefs.containsKey(key) && !await prefs.remove(key)) {
        failed.add(record);
      }
    } catch (_) {
      failed.add(record);
    }
  }
  return failed;
}
