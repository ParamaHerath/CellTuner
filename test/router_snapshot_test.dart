import 'package:cell_tuner/router/router_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the ZLT E200 pre-login info response', () {
    final snapshot = RouterSnapshot.fromJson(<String, dynamic>{
      'success': true,
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
      'CELL_ID_5G': '',
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

    expect(snapshot.networkType, '5G(NSA)');
    expect(snapshot.imsi, '413027083002840');
    expect(snapshot.imei, '860000080051930');
    expect(snapshot.metrics.first.valueFor(CellularLayer.lte), '274+99+99');
    expect(snapshot.metrics.first.valueFor(CellularLayer.nr5g), '927');
    expect(snapshot.metrics[1].valueFor(CellularLayer.lte), '-3dB');
    expect(snapshot.metrics[1].valueFor(CellularLayer.nr5g), '13dB');
    expect(snapshot.metrics.last.valueFor(CellularLayer.nr5g), '100');
    expect(snapshot.wan.ipAddress, '10.180.12.29');
    expect(snapshot.system.firmwareVersion, '9.4.6.0');
    expect(snapshot.system.formattedUptime, '5 day(s) 00:18:58');
  });
}
