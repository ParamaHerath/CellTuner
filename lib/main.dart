import 'dart:async';

import 'package:flutter/material.dart';

import 'router/router_api_client.dart';
import 'router/router_snapshot.dart';

void main() {
  runApp(const CellTunerApp());
}

typedef RouterSnapshotLoader = Future<RouterSnapshot> Function();

class CellTunerApp extends StatelessWidget {
  const CellTunerApp({super.key, this.snapshotLoader});

  final RouterSnapshotLoader? snapshotLoader;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CellTuner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          surface: const Color(0xFFF7F8FA),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
        useMaterial3: true,
      ),
      home: RouterDashboardScreen(snapshotLoader: snapshotLoader),
    );
  }
}

class RouterDashboardScreen extends StatefulWidget {
  const RouterDashboardScreen({super.key, this.snapshotLoader});

  final RouterSnapshotLoader? snapshotLoader;

  @override
  State<RouterDashboardScreen> createState() => _RouterDashboardScreenState();
}

class _RouterDashboardScreenState extends State<RouterDashboardScreen> {
  static const _host = '192.168.8.1';

  late final RouterApiClient? _client;
  late Future<RouterSnapshot> _snapshotFuture;
  Timer? _refreshTimer;
  DateTime? _lastUpdated;
  _DashboardSection _selectedSection = _DashboardSection.cellularSignal;
  bool _sidebarExpanded = true;

  RouterSnapshotLoader get _loader =>
      widget.snapshotLoader ?? _client!.fetchSnapshot;

  @override
  void initState() {
    super.initState();
    _client =
        widget.snapshotLoader == null ? RouterApiClient(host: _host) : null;
    _snapshotFuture = _loadSnapshot();
    if (widget.snapshotLoader == null) {
      _refreshTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _refresh(),
      );
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _client?.close();
    super.dispose();
  }

  Future<RouterSnapshot> _loadSnapshot() async {
    final snapshot = await _loader();
    if (mounted) {
      setState(() {
        _lastUpdated = DateTime.now();
      });
    }
    return snapshot;
  }

  void _refresh() {
    setState(() {
      _snapshotFuture = _loadSnapshot();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RouterSnapshot>(
      future: _snapshotFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _ErrorState(
            host: _host,
            error: snapshot.error.toString(),
            onRefresh: _refresh,
          );
        }

        final data = snapshot.requireData;
        return _DashboardShell(
          selectedSection: _selectedSection,
          sidebarExpanded: _sidebarExpanded,
          onSectionSelected: (section) {
            setState(() => _selectedSection = section);
          },
          onToggleSidebar: () {
            setState(() => _sidebarExpanded = !_sidebarExpanded);
          },
          child: _DashboardContent(
            snapshot: data,
            host: _host,
            lastUpdated: _lastUpdated,
            section: _selectedSection,
            onRefresh: _refresh,
          ),
        );
      },
    );
  }
}

enum _DashboardSection { cellularSignal, wan, system, subscriber, settings }

class _DashboardShell extends StatelessWidget {
  const _DashboardShell({
    required this.selectedSection,
    required this.sidebarExpanded,
    required this.onSectionSelected,
    required this.onToggleSidebar,
    required this.child,
  });

  final _DashboardSection selectedSection;
  final bool sidebarExpanded;
  final ValueChanged<_DashboardSection> onSectionSelected;
  final VoidCallback onToggleSidebar;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: <Widget>[
            _NavigationSidebar(
              selectedSection: selectedSection,
              expanded: sidebarExpanded,
              onSectionSelected: onSectionSelected,
              onToggle: onToggleSidebar,
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _NavigationSidebar extends StatelessWidget {
  const _NavigationSidebar({
    required this.selectedSection,
    required this.expanded,
    required this.onSectionSelected,
    required this.onToggle,
  });

  final _DashboardSection selectedSection;
  final bool expanded;
  final ValueChanged<_DashboardSection> onSectionSelected;
  final VoidCallback onToggle;

  static const _items = <(_DashboardSection, String, IconData)>[
    (_DashboardSection.cellularSignal, 'Cellular Signal', Icons.monitor_heart),
    (_DashboardSection.wan, 'WAN', Icons.public),
    (_DashboardSection.system, 'System', Icons.memory),
    (_DashboardSection.subscriber, 'Subscriber', Icons.sim_card),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: expanded ? 248 : 76,
      color: colors.surface,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
            child: Row(
              mainAxisAlignment: expanded ? MainAxisAlignment.end : MainAxisAlignment.center,
              children: <Widget>[
                IconButton(
                  tooltip:
                      expanded ? 'Collapse navigation' : 'Expand navigation',
                  onPressed: onToggle,
                  icon: Icon(
                    expanded ? Icons.chevron_left : Icons.chevron_right,
                  ),
                ),
              ],
            ),
          ),
          for (final item in _items)
            _NavigationItem(
              icon: item.$3,
              label: item.$2,
              selected: selectedSection == item.$1,
              expanded: expanded,
              onTap: () => onSectionSelected(item.$1),
            ),
          const Spacer(),
          _NavigationItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            selected: selectedSection == _DashboardSection.settings,
            expanded: expanded,
            onTap: () => onSectionSelected(_DashboardSection.settings),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Tooltip(
        message: expanded ? '' : label,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            height: 48,
            padding: EdgeInsets.symmetric(horizontal: expanded ? 14 : 12),
            decoration: BoxDecoration(
              color: selected ? colors.secondaryContainer : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment:
                  expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon,
                    color: selected ? colors.primary : colors.onSurfaceVariant),
                if (expanded) ...<Widget>[
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? colors.primary : colors.onSurface,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.snapshot,
    required this.host,
    required this.lastUpdated,
    required this.section,
    required this.onRefresh,
  });

  final RouterSnapshot snapshot;
  final String host;
  final DateTime? lastUpdated;
  final _DashboardSection section;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _StatusBar(
          host: host,
          networkType: snapshot.networkType,
          lastUpdated: lastUpdated,
          onRefresh: onRefresh,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Column(
                  children: <Widget>[
                    _SectionPage(section: section, snapshot: snapshot),
                    const SizedBox(height: 32),
                    Text(
                      'CellTuner - v0.0.1',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionPage extends StatelessWidget {
  const _SectionPage({required this.section, required this.snapshot});

  final _DashboardSection section;
  final RouterSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return switch (section) {
      _DashboardSection.cellularSignal =>
        _SignalTable(metrics: snapshot.metrics),
      _DashboardSection.wan => _PagePanel(
          title: 'WAN',
          subtitle: 'Internet connection details',
          icon: Icons.public,
          child: _WanCard(wan: snapshot.wan),
        ),
      _DashboardSection.system => _PagePanel(
          title: 'System',
          subtitle: 'Router runtime and firmware',
          icon: Icons.memory,
          child: _SystemCard(system: snapshot.system),
        ),
      _DashboardSection.subscriber => _PagePanel(
          title: 'Subscriber',
          subtitle: 'SIM and device identity',
          icon: Icons.sim_card,
          child: _IdentityCard(snapshot: snapshot),
        ),
      _DashboardSection.settings => const _SettingsPlaceholder(),
    };
  }
}

class _PagePanel extends StatelessWidget {
  const _PagePanel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        child,
      ],
    );
  }
}

class _SettingsPlaceholder extends StatelessWidget {
  const _SettingsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Settings'),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.host,
    required this.networkType,
    required this.lastUpdated,
    required this.onRefresh,
  });

  final String host;
  final String networkType;
  final DateTime? lastUpdated;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 14),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 12,
        spacing: 16,
        children: <Widget>[
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: <Widget>[
              Text(
                'Dialog AirFibre',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              _StatusChip(icon: Icons.router, label: host),
              _StatusChip(
                icon: Icons.network_cell,
                label: networkType.isEmpty ? '-' : networkType,
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (lastUpdated != null)
                _StatusChip(
                    icon: Icons.schedule, label: _formatClock(lastUpdated!)),
              IconButton(
                tooltip: 'Refresh',
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.host,
    required this.networkType,
    required this.lastUpdated,
  });

  final String host;
  final String networkType;
  final DateTime? lastUpdated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.cell_tower, color: theme.colorScheme.onPrimary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Dialog AirFibre',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _StatusChip(icon: Icons.router, label: host),
                  _StatusChip(
                    icon: Icons.network_cell,
                    label: networkType.isEmpty ? '-' : networkType,
                  ),
                  if (lastUpdated != null)
                    _StatusChip(
                      icon: Icons.schedule,
                      label: _formatClock(lastUpdated!),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: colors.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard(
      {required this.title, required this.icon, required this.rows});

  final String title;
  final IconData icon;
  final List<_InfoRowData> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, color: colors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final row in rows) _InfoRow(row: row),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.row});

  final _InfoRowData row;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 116,
            child: Text(
              row.label,
              style: textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              row.value.isEmpty ? '-' : row.value,
              textAlign: TextAlign.right,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.snapshot});

  final RouterSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: 'Subscriber',
      icon: Icons.sim_card,
      rows: <_InfoRowData>[
        _InfoRowData('IMSI', snapshot.imsi),
        _InfoRowData('IMEI', snapshot.imei),
      ],
    );
  }
}

class _WanCard extends StatelessWidget {
  const _WanCard({required this.wan});

  final WanInfo wan;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: 'WAN',
      icon: Icons.public,
      rows: <_InfoRowData>[
        _InfoRowData('IP Address', wan.ipAddress),
        _InfoRowData('Preferred DNS', wan.preferredDns),
        _InfoRowData('Alternate DNS', wan.alternateDns),
        _InfoRowData('IPv6 Address', wan.ipv6Address),
        _InfoRowData('IPv6 DNS', wan.preferredIpv6Dns),
        _InfoRowData('Backup IPv6', wan.backupIpv6Dns),
      ],
    );
  }
}

class _SystemCard extends StatelessWidget {
  const _SystemCard({required this.system});

  final SystemInfo system;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: 'System',
      icon: Icons.memory,
      rows: <_InfoRowData>[
        _InfoRowData('Runtime', system.formattedUptime),
        _InfoRowData('Firmware', system.firmwareVersion),
      ],
    );
  }
}

class _SignalTable extends StatelessWidget {
  const _SignalTable({required this.metrics});

  final List<RouterMetric> metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.monitor_heart, color: colors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Cellular Signal',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Table(
                columnWidths: const <int, TableColumnWidth>{
                  0: FlexColumnWidth(1.1),
                  1: FlexColumnWidth(),
                  2: FlexColumnWidth(),
                },
                children: <TableRow>[
                  TableRow(
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                    ),
                    children: const <Widget>[
                      _TableCell('Metric', header: true),
                      _TableCell('4G LTE', header: true),
                      _TableCell('5G NR', header: true),
                    ],
                  ),
                  for (final metric in metrics)
                    TableRow(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: colors.outlineVariant),
                        ),
                      ),
                      children: <Widget>[
                        _TableCell(metric.label),
                        _TableCell(metric.valueFor(CellularLayer.lte)),
                        _TableCell(metric.valueFor(CellularLayer.nr5g)),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  const _TableCell(this.value, {this.header = false});

  final String value;
  final bool header;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: header ? FontWeight.w700 : FontWeight.w500,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: SelectableText(value, style: style),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.host,
    required this.error,
    required this.onRefresh,
  });

  final String host;
  final String error;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.wifi_off,
                  size: 48,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Could not reach $host',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  error,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRowData {
  const _InfoRowData(this.label, this.value);

  final String label;
  final String value;
}

String _formatClock(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  final second = time.second.toString().padLeft(2, '0');
  return '$hour:$minute:$second';
}
