import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cell_tuner/main.dart';
import 'package:cell_tuner/router/router_snapshot.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  testWidgets('shows router signal data', (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      CellTunerApp(snapshotLoader: () async => _sampleSnapshot()),
    );
    await tester.pumpAndSettle();

    expect(find.text('CellTuner - v0.0.1'), findsOneWidget);
    expect(find.text('Dialog AirFibre'), findsOneWidget);
    expect(find.text('Router Connected @ 192.168.8.1'), findsOneWidget);
    expect(find.text('4G LTE'), findsOneWidget);
    expect(find.text('5G NR'), findsOneWidget);
    expect(find.text('-103dBm'), findsOneWidget);
    expect(find.text('-102dBm'), findsOneWidget);
    expect(find.text('WAN'), findsOneWidget);

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('navigates between dashboard sections',
      (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      CellTunerApp(snapshotLoader: () async => _sampleSnapshot()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(AnimatedIcon));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Signal'));
    await tester.pumpAndSettle();
    expect(find.text('Signal'), findsAtLeastNWidgets(2));

    await tester.tap(find.text('WAN'));
    await tester.pumpAndSettle();
    expect(find.text('10.180.12.29'), findsOneWidget);

    await tester.tap(find.text('Device'));
    await tester.pumpAndSettle();
    expect(find.text('9.4.6.0'), findsOneWidget);
    expect(find.text('413027083002840'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsNWidgets(2));

    debugDefaultTargetPlatformOverride = null;
  });

  test('detects tower handoff events with split and non-split cell id formatting', () {
    final now = DateTime.now();
    final sample1 = SignalMetricSample(
      timestamp: now.subtract(const Duration(seconds: 10)),
      rssiLte: -70,
      rssiNr5g: null,
      rsrpLte: -90,
      rsrpNr5g: null,
      rsrqLte: -10,
      rsrqNr5g: null,
      sinrLte: 15,
      sinrNr5g: null,
      cellIdLte: '5285379',
      cellIdNr5g: null,
    );
    final sample2 = SignalMetricSample(
      timestamp: now.subtract(const Duration(seconds: 5)),
      rssiLte: -72,
      rssiNr5g: null,
      rsrpLte: -92,
      rsrpNr5g: null,
      rsrqLte: -11,
      rsrqNr5g: null,
      sinrLte: 14,
      sinrNr5g: null,
      cellIdLte: '5285380',
      cellIdNr5g: null,
    );

    final handoffs = findHandoffEvents([sample1, sample2]);
    expect(handoffs.length, 1);
    expect(handoffs.first.formatChange(false), '5285379 → 5285380');
    expect(handoffs.first.formatChange(true), '20646-3 → 20646-4');
  });

  test('formats graph x-axis labels correctly for different time windows', () {
    expect(formatXAxisLabel(60, 60), '-60s');
    expect(formatXAxisLabel(30, 60), '-30s');
    expect(formatXAxisLabel(0, 60), 'Now');

    expect(formatXAxisLabel(120, 120), '-2m');
    expect(formatXAxisLabel(90, 120), '-1m 30s');
    expect(formatXAxisLabel(60, 120), '-1m');

    expect(formatXAxisLabel(300, 300), '-5m');
    expect(formatXAxisLabel(150, 300), '-2m 30s');

    expect(formatXAxisLabel(900, 900), '-15m');
    expect(formatXAxisLabel(1800, 1800), '-30m');

    expect(formatXAxisLabel(3600, 3600), '-1h');
    expect(formatXAxisLabel(2700, 3600), '-45m');
  });

  testWidgets('displays time window dropdown and changes selected window',
      (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      CellTunerApp(snapshotLoader: () async => _sampleSnapshot()),
    );
    await tester.pumpAndSettle();

    // Open sidebar and navigate to Signal page
    await tester.tap(find.byType(AnimatedIcon));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Signal'));
    await tester.pumpAndSettle();

    // Check time window dropdown is present with default '1min'
    expect(find.text('1min'), findsOneWidget);

    // Tap the dropdown to open it
    await tester.tap(find.text('1min'));
    await tester.pumpAndSettle();

    // Verify options are present
    expect(find.text('2min'), findsOneWidget);
    expect(find.text('5min'), findsOneWidget);
    expect(find.text('15min'), findsOneWidget);
    expect(find.text('30min'), findsOneWidget);
    expect(find.text('1hr'), findsOneWidget);

    // Select 5min
    await tester.tap(find.text('5min').last);
    await tester.pumpAndSettle();

    expect(find.text('5min'), findsOneWidget);

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('opens record session dialog, starts recording, and handles completion',
      (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      CellTunerApp(snapshotLoader: () async => _sampleSnapshot()),
    );
    await tester.pumpAndSettle();

    // Open sidebar and navigate to Signal page
    await tester.tap(find.byType(AnimatedIcon));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Signal'));
    await tester.pumpAndSettle();

    // Verify Record button exists
    expect(find.text('Record'), findsOneWidget);

    // Tap Record button to open dialog
    await tester.tap(find.text('Record'));
    await tester.pumpAndSettle();

    expect(find.text('Record Signal Session'), findsOneWidget);
    expect(find.text('Session Duration'), findsOneWidget);
    expect(find.text('Start Recording'), findsOneWidget);

    // Tap Start Recording
    await tester.tap(find.text('Start Recording'));
    await tester.pumpAndSettle();

    // Dialog should be dismissed, and button should now display Recording
    expect(find.text('Record Signal Session'), findsNothing);
    expect(find.textContaining('Recording'), findsOneWidget);

    // Tapping while recording opens recording in progress dialog
    await tester.tap(find.textContaining('Recording'));
    await tester.pumpAndSettle();

    expect(find.text('Recording in Progress'), findsOneWidget);
    expect(find.text('Stop & Save'), findsOneWidget);

    // Tap Stop & Save
    await tester.tap(find.text('Stop & Save'));
    await tester.pumpAndSettle();

    // Completion popup appears
    expect(find.text('Recording Complete'), findsOneWidget);
    expect(find.text('Open Folder'), findsOneWidget);
    expect(find.text('Open Report'), findsOneWidget);

    // Close completion dialog using the top-right X button
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byIcon(LucideIcons.x),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Recording Complete'), findsNothing);
    expect(find.text('Record'), findsOneWidget);

    // Verify premature cancel X button: start recording again
    await tester.tap(find.text('Record'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Recording'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Recording'), findsOneWidget);
    expect(find.byTooltip('Cancel and discard recording'), findsOneWidget);

    // Tap premature cancel X button
    await tester.tap(find.byTooltip('Cancel and discard recording'));
    await tester.pumpAndSettle();

    // Verify recording was cancelled and discarded
    expect(find.text('Record'), findsOneWidget);
    expect(find.text('Recording Complete'), findsNothing);

    // Verify reset graphs button exists and can be tapped
    expect(find.byTooltip('Reset and restart graphs'), findsOneWidget);
    final resetSize = tester.getSize(find.byTooltip('Reset and restart graphs'));
    expect(resetSize.width, 32.0);
    expect(resetSize.height, 32.0);
    await tester.tap(find.byTooltip('Reset and restart graphs'));
    await tester.pumpAndSettle();

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('reset button remains a tiny square on mobile viewport',
      (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      CellTunerApp(snapshotLoader: () async => _sampleSnapshot()),
    );
    await tester.pumpAndSettle();

    // Navigate to Signal
    await tester.tap(find.byType(AnimatedIcon));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Signal'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Reset and restart graphs'), findsOneWidget);
    final size = tester.getSize(find.byTooltip('Reset and restart graphs'));
    expect(size.width, 32.0);
    expect(size.height, 32.0);

    debugDefaultTargetPlatformOverride = null;
  });
}

RouterSnapshot _sampleSnapshot() {
  return RouterSnapshot.fromJson(<String, dynamic>{
    'SINR': '-3',
    'SINR_5G': '13',
    'RSRP': '-103',
    'RSRP_5G': '-102',
    'RSSI': '-92',
    'RSSI_5G': '-40',
    'RSRQ': '-10',
    'RSRQ_5G': '-11',
    'PCI': '274+99+99',
    'PCI_5G': '927',
    'FREQ': '1725+525+400',
    'FREQ_5G': '628896',
    'CELL_ID': '5285379',
    'bandwidth': '20+15+10',
    'bandwidth_5g': '100',
    'currentband': '3+1+1',
    'currentband_5g': '78',
    'wan_ip': '10.180.12.29',
    'wan_dns': '202.69.205.2',
    'wan_dns2': '202.69.205.1',
    'wan_ipv6_ip': '2400:ff00:280:929:18d6:1bcc:49f:5bc',
    'wan_ipv6_dns': '2402:4000::2',
    'wan_ipv6_dns2': '2402:4000::1',
    'uptime': '433138',
    'fake_version': '9.4.6.0',
    'imsi': '413027083002840',
    'imei': '860000080051930',
    'network_type_str': '5G(NSA)',
  });
}
