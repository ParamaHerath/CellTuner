import 'dart:convert';
import 'dart:io';

import 'package:cell_tuner/recording_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SignalRecordingSession', () {
    test('tracks samples and computes progress percent', () {
      final start = DateTime(2026, 9, 29, 10, 0, 0);
      final session = SignalRecordingSession(
        id: 'test-session',
        startTime: start,
        targetDurationSeconds: 60,
        durationLabel: '1min',
        routerHost: '192.168.8.1',
      );

      expect(session.progressFraction(start), 0.0);
      expect(session.progressPercent(start), 0);

      final halfWay = start.add(const Duration(seconds: 30));
      expect(session.progressFraction(halfWay), 0.5);
      expect(session.progressPercent(halfWay), 50);

      final finished = start.add(const Duration(seconds: 60));
      expect(session.progressFraction(finished), 1.0);
      expect(session.progressPercent(finished), 100);

      // Over duration clamps to 1.0 / 100
      final over = start.add(const Duration(seconds: 75));
      expect(session.progressFraction(over), 1.0);
      expect(session.progressPercent(over), 100);
    });

    test('serializes complete structured session to JSON with handoffs', () async {
      final start = DateTime(2026, 9, 29, 12, 0, 0);
      final session = SignalRecordingSession(
        id: 'rec-123',
        startTime: start,
        targetDurationSeconds: 120,
        durationLabel: '2min',
        routerHost: '192.168.8.1',
      );

      session.addSample(SignalMetricSample(
        timestamp: start,
        rssiLte: -70,
        rssiNr5g: -40,
        rsrpLte: -90,
        rsrpNr5g: -100,
        rsrqLte: -10,
        rsrqNr5g: -11,
        sinrLte: 15,
        sinrNr5g: 20,
        cellIdLte: '5285379',
        cellIdNr5g: null,
      ));

      session.addSample(SignalMetricSample(
        timestamp: start.add(const Duration(seconds: 15)),
        rssiLte: -75,
        rssiNr5g: -45,
        rsrpLte: -95,
        rsrpNr5g: -105,
        rsrqLte: -12,
        rsrqNr5g: -13,
        sinrLte: 10,
        sinrNr5g: 15,
        cellIdLte: '5285380',
        cellIdNr5g: null,
      ));

      session.finish(start.add(const Duration(seconds: 120)));

      final jsonMap = session.toJson();
      expect(jsonMap['version'], '1.0');
      expect(jsonMap['session']['id'], 'rec-123');
      expect(jsonMap['session']['targetDurationSeconds'], 120.0);
      expect(jsonMap['session']['targetDurationLabel'], '2min');
      expect(jsonMap['session']['sampleCount'], 2);
      expect(jsonMap['session']['handoffCount'], 1);

      // Verify metrics metadata
      final metrics = jsonMap['metrics'] as List;
      expect(metrics.length, 4);
      expect(metrics.any((m) => m['key'] == 'RSRP'), isTrue);

      // Verify samples
      final samples = jsonMap['samples'] as List;
      expect(samples.length, 2);
      expect(samples[0]['elapsedSeconds'], 0.0);
      expect(samples[1]['elapsedSeconds'], 15.0);

      // Verify handoffs
      final handoffs = jsonMap['handoffs'] as List;
      expect(handoffs.length, 1);
      expect(handoffs[0]['elapsedSeconds'], 15.0);
      expect(handoffs[0]['prevCellIdLte'], '5285379');
      expect(handoffs[0]['newCellIdLte'], '5285380');
      expect(handoffs[0]['formattedSplit'], '20646-3 → 20646-4');
      expect(handoffs[0]['formattedRaw'], '5285379 → 5285380');

      // Test file saving to a temporary directory
      final tempDir = await Directory.systemTemp.createTemp('celltuner_rec_test_');
      try {
        final result = await RecordingStorage.saveRecording(session, directory: tempDir);
        expect(result.jsonFile.existsSync(), isTrue);
        expect(result.htmlFile.existsSync(), isTrue);

        final rawContent = await result.jsonFile.readAsString();
        final decoded = json.decode(rawContent) as Map<String, dynamic>;
        expect(decoded['version'], '1.0');
        expect(decoded['session']['sampleCount'], 2);

        final rawHtml = await result.htmlFile.readAsString();
        expect(rawHtml, contains('<!DOCTYPE html>'));
        expect(rawHtml, contains('CellTuner · Session Report'));
      } finally {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      }
    });
  });
}
