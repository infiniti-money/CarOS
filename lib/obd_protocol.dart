import 'dart:convert';

enum ObdPid {
  rpm('010C', 'Vòng tua', 'rpm', 2),
  speed('010D', 'Tốc độ ECU', 'km/h', 1),
  coolant('0105', 'Nhiệt độ nước làm mát', '°C', 1),
  fuel('012F', 'Mức nhiên liệu', '%', 1),
  voltage('0142', 'Điện áp module', 'V', 2);

  const ObdPid(this.command, this.label, this.unit, this.bytes);
  final String command, label, unit;
  final int bytes;
}

const adapterSetup = ['ATE0', 'ATL0', 'ATS0', 'ATH0', 'ATSP0'];
final allowedObdCommands = Set<String>.unmodifiable([
  ...adapterSetup, ...ObdPid.values.map((p) => p.command),
]);

// Only exact Mode 01 payloads, no guessed header stripping, no concatenation
// of responses from distinct ECUs. Conflicting readings are unavailable.
double? decodeObd(ObdPid pid, String response) {
  final prefix = '41${pid.command.substring(2)}';
  final values = <double>{};
  for (final raw in response.toUpperCase().split(RegExp(r'[\r\n>]+'))) {
    final line = raw.replaceAll(RegExp(r'\s+'), '');
    if (!line.startsWith(prefix) || line.length != 4 + 2 * pid.bytes ||
        !RegExp(r'^[0-9A-F]+
    final a = int.parse(line.substring(4, 6), radix: 16);
    final b = pid.bytes == 2 ? int.parse(line.substring(6, 8), radix: 16) : 0;
    final value = switch (pid) {
      ObdPid.rpm => (256 * a + b) / 4,
      ObdPid.speed => a.toDouble(),
      ObdPid.coolant => (a - 40).toDouble(),
      ObdPid.fuel => a * 100 / 255,
      ObdPid.voltage => (256 * a + b) / 1000,
    };
    values.add(value);
  }
  return values.length == 1 ? values.single : null;
}

bool adapterOk(String response) => response.toUpperCase()
    .split(RegExp(r'[\r\n>]+')).any((line) => line.trim() == 'OK');

class ObdFrame {
  final _buffer = <int>[];
  String? append(List<int> chunk) {
    if (_buffer.length + chunk.length > 4096) {
      _buffer.clear();
      throw const FormatException('OBD response too large');
    }
    _buffer.addAll(chunk);
    final end = _buffer.indexOf(62);
    if (end == -1) return null;
    final response = ascii.decode(_buffer.sublist(0, end), allowInvalid: true);
    // Discard trailing bytes, never reuse stale responses for a new request.
    _buffer.clear();
    return response;
  }

  void clear() => _buffer.clear();
}

class ObdSample {
  const ObdSample(this.value, this.at);
  final double value;
  final DateTime at;
  bool fresh(DateTime now) {
    final age = now.difference(at);
    return age >= Duration.zero && age <= const Duration(seconds: 12);
  }
}
).hasMatch(line)) {
      continue;
    }
    final a = int.parse(line.substring(4, 6), radix: 16);
    final b = pid.bytes == 2 ? int.parse(line.substring(6, 8), radix: 16) : 0;
    final value = switch (pid) {
      ObdPid.rpm => (256 * a + b) / 4,
      ObdPid.speed => a.toDouble(),
      ObdPid.coolant => (a - 40).toDouble(),
      ObdPid.fuel => a * 100 / 255,
      ObdPid.voltage => (256 * a + b) / 1000,
    };
    values.add(value);
  }
  return values.length == 1 ? values.single : null;
}

bool adapterOk(String response) => response.toUpperCase()
    .split(RegExp(r'[\r\n>]+')).any((line) => line.trim() == 'OK');

class ObdFrame {
  final _buffer = <int>[];
  String? append(List<int> chunk) {
    if (_buffer.length + chunk.length > 4096) {
      _buffer.clear();
      throw const FormatException('OBD response too large');
    }
    _buffer.addAll(chunk);
    final end = _buffer.indexOf(62);
    if (end == -1) return null;
    final response = ascii.decode(_buffer.sublist(0, end), allowInvalid: true);
    // Discard trailing bytes, never reuse stale responses for a new request.
    _buffer.clear();
    return response;
  }

  void clear() => _buffer.clear();
}

class ObdSample {
  const ObdSample(this.value, this.at);
  final double value;
  final DateTime at;
  bool fresh(DateTime now) {
    final age = now.difference(at);
    return age >= Duration.zero && age <= const Duration(seconds: 12);
  }
}
