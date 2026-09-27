import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cell_tuner/main.dart';
import 'package:cell_tuner/router/router_snapshot.dart';

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

    await tester.tap(find.text('Signal'));
    await tester.pumpAndSettle();
    expect(find.text('Signal'), findsAtLeastNWidgets(2));

    await tester.tap(find.text('WAN'));
    await tester.pumpAndSettle();
    expect(find.text('10.180.12.29'), findsOneWidget);

    await tester.tap(find.text('System'));
    await tester.pumpAndSettle();
    expect(find.text('9.4.6.0'), findsOneWidget);

    await tester.tap(find.text('Subscriber'));
    await tester.pumpAndSettle();
    expect(find.text('413027083002840'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsNWidgets(2));

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
