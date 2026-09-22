class RouterSnapshot {
  const RouterSnapshot({
    required this.networkType,
    required this.imsi,
    required this.imei,
    required this.metrics,
    required this.wan,
    required this.system,
  });

  factory RouterSnapshot.fromJson(Map<String, dynamic> json) {
    return RouterSnapshot(
      networkType: _stringValue(json, 'network_type_str'),
      imsi: _stringValue(json, 'imsi'),
      imei: _stringValue(json, 'imei'),
      metrics: <RouterMetric>[
        RouterMetric.fromJson(json, label: 'PCI', key: 'PCI'),
        RouterMetric.fromJson(json, label: 'SINR', key: 'SINR', unit: 'dB'),
        RouterMetric.fromJson(json, label: 'RSRP', key: 'RSRP', unit: 'dBm'),
        RouterMetric.fromJson(json, label: 'RSSI', key: 'RSSI', unit: 'dBm'),
        RouterMetric.fromJson(json, label: 'EARFCN', key: 'FREQ'),
        RouterMetric.fromJson(json, label: 'RSRQ', key: 'RSRQ', unit: 'dB'),
        RouterMetric.fromJson(json, label: 'Cell ID', key: 'CELL_ID'),
        RouterMetric.fromJson(json, label: 'Current Band', key: 'currentband'),
        RouterMetric.fromJson(json, label: 'Bandwidth', key: 'bandwidth'),
      ],
      wan: WanInfo.fromJson(json),
      system: SystemInfo.fromJson(json),
    );
  }

  final String networkType;
  final String imsi;
  final String imei;
  final List<RouterMetric> metrics;
  final WanInfo wan;
  final SystemInfo system;
}

class RouterMetric {
  const RouterMetric({
    required this.label,
    required this.lte,
    required this.nr5g,
    this.unit = '',
  });

  factory RouterMetric.fromJson(
    Map<String, dynamic> json, {
    required String label,
    required String key,
    String unit = '',
  }) {
    return RouterMetric(
      label: label,
      lte: _stringValue(json, key),
      nr5g: _fiveGValue(json, key),
      unit: unit,
    );
  }

  final String label;
  final String lte;
  final String nr5g;
  final String unit;

  String valueFor(CellularLayer layer) {
    final value = switch (layer) {
      CellularLayer.lte => lte,
      CellularLayer.nr5g => nr5g,
    };
    if (value.isEmpty) {
      return '-';
    }
    return unit.isEmpty ? value : '$value$unit';
  }
}

enum CellularLayer { lte, nr5g }

class WanInfo {
  const WanInfo({
    required this.ipAddress,
    required this.preferredDns,
    required this.alternateDns,
    required this.ipv6Address,
    required this.preferredIpv6Dns,
    required this.backupIpv6Dns,
  });

  factory WanInfo.fromJson(Map<String, dynamic> json) {
    return WanInfo(
      ipAddress: _stringValue(json, 'wan_ip'),
      preferredDns: _stringValue(json, 'wan_dns'),
      alternateDns: _stringValue(json, 'wan_dns2'),
      ipv6Address: _stringValue(json, 'wan_ipv6_ip'),
      preferredIpv6Dns: _stringValue(json, 'wan_ipv6_dns'),
      backupIpv6Dns: _stringValue(json, 'wan_ipv6_dns2'),
    );
  }

  final String ipAddress;
  final String preferredDns;
  final String alternateDns;
  final String ipv6Address;
  final String preferredIpv6Dns;
  final String backupIpv6Dns;
}

class SystemInfo {
  const SystemInfo({
    required this.uptimeSeconds,
    required this.firmwareVersion,
  });

  factory SystemInfo.fromJson(Map<String, dynamic> json) {
    return SystemInfo(
      uptimeSeconds: int.tryParse(_stringValue(json, 'uptime')) ?? 0,
      firmwareVersion: _stringValue(json, 'fake_version'),
    );
  }

  final int uptimeSeconds;
  final String firmwareVersion;

  String get formattedUptime {
    final duration = Duration(seconds: uptimeSeconds);
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24).toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$days day(s) $hours:$minutes:$seconds';
  }
}

String _stringValue(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value == null ? '' : value.toString();
}

String _fiveGValue(Map<String, dynamic> json, String key) {
  final expected = '${key}_5g'.toLowerCase();
  for (final entry in json.entries) {
    if (entry.key.toLowerCase() == expected) {
      return entry.value == null ? '' : entry.value.toString();
    }
  }
  return '';
}
