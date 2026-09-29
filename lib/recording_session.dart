import 'dart:convert';
import 'dart:io';

/// Formats a raw Cell ID according to LTE (eNB-Sector) or 5G (gNB-Sector) split convention.
String formatCellIdString(String raw, {required bool is5g}) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty || trimmed == '-') return raw;
  final val = int.tryParse(trimmed);
  if (val == null) return raw;
  if (!is5g) {
    final enb = val ~/ 256;
    final sector = val % 256;
    return '$enb-$sector';
  } else {
    final gnb = val ~/ 16384;
    final sector = val % 16384;
    return '$gnb-$sector';
  }
}

class SignalMetricSample {
  const SignalMetricSample({
    required this.timestamp,
    required this.rssiLte,
    required this.rssiNr5g,
    required this.rsrpLte,
    required this.rsrpNr5g,
    required this.rsrqLte,
    required this.rsrqNr5g,
    required this.sinrLte,
    required this.sinrNr5g,
    this.cellIdLte,
    this.cellIdNr5g,
  });

  final DateTime timestamp;
  final double? rssiLte;
  final double? rssiNr5g;
  final double? rsrpLte;
  final double? rsrpNr5g;
  final double? rsrqLte;
  final double? rsrqNr5g;
  final double? sinrLte;
  final double? sinrNr5g;
  final String? cellIdLte;
  final String? cellIdNr5g;

  double? getValue(String key, {required bool is5g}) {
    return switch (key.toUpperCase()) {
      'RSSI' => is5g ? rssiNr5g : rssiLte,
      'RSRP' => is5g ? rsrpNr5g : rsrpLte,
      'RSRQ' => is5g ? rsrqNr5g : rsrqLte,
      'SINR' => is5g ? sinrNr5g : sinrLte,
      _ => null,
    };
  }
}

class TowerHandoffEvent {
  const TowerHandoffEvent({
    required this.timestamp,
    required this.prevLte,
    required this.newLte,
    required this.prevNr5g,
    required this.newNr5g,
  });

  final DateTime timestamp;
  final String? prevLte;
  final String? newLte;
  final String? prevNr5g;
  final String? newNr5g;

  String formatChange(bool split) {
    final lteChanged = prevLte != null &&
        newLte != null &&
        prevLte!.isNotEmpty &&
        newLte!.isNotEmpty &&
        prevLte != '-' &&
        newLte != '-' &&
        prevLte != newLte;

    final nrChanged = prevNr5g != null &&
        newNr5g != null &&
        prevNr5g!.isNotEmpty &&
        newNr5g!.isNotEmpty &&
        prevNr5g != '-' &&
        newNr5g != '-' &&
        prevNr5g != newNr5g;

    if (lteChanged && nrChanged) {
      final pLte = split ? formatCellIdString(prevLte!, is5g: false) : prevLte!;
      final nLte = split ? formatCellIdString(newLte!, is5g: false) : newLte!;
      final pNr = split ? formatCellIdString(prevNr5g!, is5g: true) : prevNr5g!;
      final nNr = split ? formatCellIdString(newNr5g!, is5g: true) : newNr5g!;
      return '$pLte / $pNr → $nLte / $nNr';
    } else if (lteChanged) {
      final pLte = split ? formatCellIdString(prevLte!, is5g: false) : prevLte!;
      final nLte = split ? formatCellIdString(newLte!, is5g: false) : newLte!;
      return '$pLte → $nLte';
    } else if (nrChanged) {
      final pNr = split ? formatCellIdString(prevNr5g!, is5g: true) : prevNr5g!;
      final nNr = split ? formatCellIdString(newNr5g!, is5g: true) : newNr5g!;
      return '$pNr → $nNr';
    }

    return 'Tower Changed';
  }
}

List<TowerHandoffEvent> findHandoffEvents(List<SignalMetricSample> history) {
  final list = <TowerHandoffEvent>[];
  if (history.length < 2) return list;

  for (var i = 1; i < history.length; i++) {
    final prev = history[i - 1];
    final curr = history[i];

    final lteChanged = prev.cellIdLte != null &&
        curr.cellIdLte != null &&
        prev.cellIdLte!.isNotEmpty &&
        curr.cellIdLte!.isNotEmpty &&
        prev.cellIdLte != '-' &&
        curr.cellIdLte != '-' &&
        prev.cellIdLte != curr.cellIdLte;

    final nrChanged = prev.cellIdNr5g != null &&
        curr.cellIdNr5g != null &&
        prev.cellIdNr5g!.isNotEmpty &&
        curr.cellIdNr5g!.isNotEmpty &&
        prev.cellIdNr5g != '-' &&
        curr.cellIdNr5g != '-' &&
        prev.cellIdNr5g != curr.cellIdNr5g;

    if (lteChanged || nrChanged) {
      list.add(TowerHandoffEvent(
        timestamp: curr.timestamp,
        prevLte: prev.cellIdLte,
        newLte: curr.cellIdLte,
        prevNr5g: prev.cellIdNr5g,
        newNr5g: curr.cellIdNr5g,
      ));
    }
  }
  return list;
}

class SignalRecordingSession {
  SignalRecordingSession({
    required this.id,
    required this.startTime,
    required this.targetDurationSeconds,
    required this.durationLabel,
    this.routerHost = '192.168.8.1',
    List<SignalMetricSample>? initialSamples,
  }) : samples = initialSamples != null ? List.of(initialSamples) : <SignalMetricSample>[];

  final String id;
  final DateTime startTime;
  final double targetDurationSeconds;
  final String durationLabel;
  final String routerHost;
  final List<SignalMetricSample> samples;

  DateTime? endTime;
  bool isCompleted = false;

  double get elapsedSeconds {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime).inMilliseconds / 1000.0;
  }

  double progressFraction([DateTime? now]) {
    final current = endTime ?? (now ?? DateTime.now());
    final elapsed = current.difference(startTime).inMilliseconds / 1000.0;
    if (targetDurationSeconds <= 0) return 1.0;
    return (elapsed / targetDurationSeconds).clamp(0.0, 1.0);
  }

  int progressPercent([DateTime? now]) {
    return (progressFraction(now) * 100).toInt().clamp(0, 100);
  }

  void addSample(SignalMetricSample sample) {
    samples.add(sample);
  }

  void finish([DateTime? now]) {
    endTime = now ?? DateTime.now();
    isCompleted = true;
  }

  Map<String, dynamic> toJson() {
    final finishTime = endTime ?? (samples.isNotEmpty ? samples.last.timestamp : DateTime.now());
    final actualDuration = finishTime.difference(startTime).inMilliseconds / 1000.0;
    final handoffs = findHandoffEvents(samples);

    return <String, dynamic>{
      'version': '1.0',
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'session': <String, dynamic>{
        'id': id,
        'startTime': startTime.toUtc().toIso8601String(),
        'endTime': finishTime.toUtc().toIso8601String(),
        'targetDurationSeconds': targetDurationSeconds,
        'targetDurationLabel': durationLabel,
        'actualDurationSeconds': double.parse(actualDuration.toStringAsFixed(2)),
        'routerHost': routerHost,
        'sampleCount': samples.length,
        'handoffCount': handoffs.length,
      },
      'metrics': <Map<String, dynamic>>[
        <String, dynamic>{
          'key': 'RSSI',
          'name': 'RSSI (Received Signal Strength)',
          'unit': 'dBm',
        },
        <String, dynamic>{
          'key': 'RSRP',
          'name': 'RSRP (Reference Signal Received Power)',
          'unit': 'dBm',
        },
        <String, dynamic>{
          'key': 'RSRQ',
          'name': 'RSRQ (Reference Signal Received Quality)',
          'unit': 'dB',
        },
        <String, dynamic>{
          'key': 'SINR',
          'name': 'SINR (Signal to Interference & Noise)',
          'unit': 'dB',
        },
      ],
      'samples': samples.map((s) {
        final elapsed = s.timestamp.difference(startTime).inMilliseconds / 1000.0;
        return <String, dynamic>{
          'timestamp': s.timestamp.toUtc().toIso8601String(),
          'elapsedSeconds': double.parse(elapsed.toStringAsFixed(2)),
          'rssiLte': s.rssiLte,
          'rssiNr5g': s.rssiNr5g,
          'rsrpLte': s.rsrpLte,
          'rsrpNr5g': s.rsrpNr5g,
          'rsrqLte': s.rsrqLte,
          'rsrqNr5g': s.rsrqNr5g,
          'sinrLte': s.sinrLte,
          'sinrNr5g': s.sinrNr5g,
          'cellIdLte': s.cellIdLte,
          'cellIdNr5g': s.cellIdNr5g,
        };
      }).toList(),
      'handoffs': handoffs.map((h) {
        final elapsed = h.timestamp.difference(startTime).inMilliseconds / 1000.0;
        return <String, dynamic>{
          'timestamp': h.timestamp.toUtc().toIso8601String(),
          'elapsedSeconds': double.parse(elapsed.toStringAsFixed(2)),
          'prevCellIdLte': h.prevLte,
          'newCellIdLte': h.newLte,
          'prevCellIdNr5g': h.prevNr5g,
          'newCellIdNr5g': h.newNr5g,
          'formattedSplit': h.formatChange(true),
          'formattedRaw': h.formatChange(false),
        };
      }).toList(),
    };
  }
}

class RecordingStorage {
  static Directory getRecordingsDirectory() {
    try {
      final userProfile = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
      if (userProfile != null && userProfile.isNotEmpty) {
        final dir = Directory(
          '$userProfile${Platform.pathSeparator}Documents${Platform.pathSeparator}CellTuner${Platform.pathSeparator}Recordings',
        );
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        return dir;
      }
    } catch (_) {}

    final fallback = Directory('recordings');
    if (!fallback.existsSync()) {
      fallback.createSync(recursive: true);
    }
    return fallback;
  }

  static String generateFilename(DateTime timestamp) {
    final year = timestamp.year.toString().padLeft(4, '0');
    final month = timestamp.month.toString().padLeft(2, '0');
    final day = timestamp.day.toString().padLeft(2, '0');
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final second = timestamp.second.toString().padLeft(2, '0');
    return 'signal_recording_${year}-${month}-${day}_${hour}${minute}${second}.json';
  }

  static File saveRecordingSync(
    SignalRecordingSession session, {
    Directory? directory,
  }) {
    final targetDir = directory ?? getRecordingsDirectory();
    final filename = generateFilename(session.startTime);
    final file = File('${targetDir.path}${Platform.pathSeparator}$filename');
    const encoder = JsonEncoder.withIndent('  ');
    final jsonStr = encoder.convert(session.toJson());
    file.writeAsStringSync(jsonStr);
    return file;
  }

  static Future<File> saveRecording(
    SignalRecordingSession session, {
    Directory? directory,
  }) async {
    return saveRecordingSync(session, directory: directory);
  }

  static Future<void> openFile(String filePath) async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer.exe', ['/select,', filePath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', ['-R', filePath]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [File(filePath).parent.path]);
      }
    } catch (_) {}
  }
}
