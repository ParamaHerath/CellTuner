import 'package:cell_tuner/recording_html_generator.dart';
import 'package:cell_tuner/recording_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RecordingHtmlGenerator', () {
    test('generates valid interactive standalone HTML report', () {
      final start = DateTime(2026, 9, 30, 10, 0, 0);
      final session = SignalRecordingSession(
        id: 'test-session-html',
        startTime: start,
        targetDurationSeconds: 60,
        durationLabel: '1min',
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
        timestamp: start.add(const Duration(seconds: 20)),
        rssiLte: -72,
        rssiNr5g: -42,
        rsrpLte: -92,
        rsrpNr5g: -102,
        rsrqLte: -11,
        rsrqNr5g: -12,
        sinrLte: 14,
        sinrNr5g: 18,
        cellIdLte: '5285380',
        cellIdNr5g: null,
      ));

      session.finish(start.add(const Duration(seconds: 60)));

      final html = generateRecordingHtml(session);

      expect(html, startsWith('<!DOCTYPE html>'));
      expect(html, contains('<title>CellTuner · Session Report'));

      // Embedded session payload
      expect(html, contains('192.168.8.1'));
      expect(html, contains('5285379'));
      expect(html, contains('5285380'));
      expect(html, contains('20646-3 → 20646-4'));

      // Metrics cards
      expect(html, contains('card-RSSI'));
      expect(html, contains('card-RSRP'));
      expect(html, contains('card-RSRQ'));
      expect(html, contains('card-SINR'));

      // Canvas elements
      expect(html, contains('canvas-RSSI'));
      expect(html, contains('canvas-RSRP'));
      expect(html, contains('canvas-RSRQ'));
      expect(html, contains('canvas-SINR'));

      // Interactive controls & Scrub lines
      expect(html, contains('zoomInBtn'));
      expect(html, contains('zoomOutBtn'));
      expect(html, contains('zoomResetBtn'));
      expect(html, contains('techModeGroup'));
      expect(html, contains('cellIdGroup'));
      expect(html, contains('scrub-RSSI'));
      expect(html, contains('chart-scrub-line'));
      expect(html, contains('cursor: default'));

      // Script methods & Handoff styling
      expect(html, contains('drawChart'));
      expect(html, contains('calculateDynamicYRange'));
      expect(html, contains('getFormattedCellId'));
      expect(html, contains('formatCellIdString'));
      expect(html, contains('setZoom'));
      expect(html, contains('#111827'));
    });
  });
}
