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
          surface: Colors.white,
          surfaceContainerHighest: const Color(0xFFF1F5F9),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
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
  _DashboardSection _selectedSection = _DashboardSection.status;
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
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: _ErrorState(
              host: _host,
              error: snapshot.error.toString(),
              onRefresh: _refresh,
            ),
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

enum _DashboardSection { status, signal, wan, system, subscriber, settings }

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
    (_DashboardSection.status, 'Status', Icons.info_outline),
    (_DashboardSection.signal, 'Signal', Icons.monitor_heart_outlined),
    (_DashboardSection.wan, 'WAN', Icons.public_outlined),
    (_DashboardSection.system, 'System', Icons.memory_outlined),
    (_DashboardSection.subscriber, 'Subscriber', Icons.sim_card_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: expanded ? 248 : 76,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          right: BorderSide(
            color: colors.outlineVariant.withOpacity(0.3),
          ),
        ),
      ),
      child: Column(
        children: <Widget>[
          const SizedBox(height: 14),
          _NavigationItem(
            icon: Icons.menu_rounded,
            label: '',
            selected: false,
            expanded: expanded,
            onTap: onToggle,
            tooltip: expanded ? 'Collapse navigation' : 'Expand navigation',
          ),
          const SizedBox(height: 16),
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
    this.tooltip,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final message = tooltip ?? (expanded ? '' : label);
    final activeBg = colors.primary.withOpacity(0.12);
    final activeFg = colors.primary;
    final inactiveFg = colors.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Tooltip(
        message: message,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 48,
            padding: EdgeInsets.symmetric(horizontal: expanded ? 14 : 12),
            decoration: BoxDecoration(
              color: selected ? activeBg : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment:
                  expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  icon,
                  size: 22,
                  color: selected ? activeFg : inactiveFg,
                ),
                if (expanded && label.isNotEmpty) ...<Widget>[
                  const SizedBox(width: 14),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: selected ? activeFg : colors.onSurface,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        letterSpacing: -0.1,
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
            padding: const EdgeInsets.all(28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Column(
                  children: <Widget>[
                    _SectionPage(section: section, snapshot: snapshot),
                    const SizedBox(height: 40),
                    Text(
                      'CellTuner - v0.0.1',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
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
      _DashboardSection.status => _PagePanel(
          title: 'Status',
          subtitle: 'Real-time network and cellular metrics',
          icon: Icons.info_outline,
          child: _SignalTable(metrics: snapshot.metrics),
        ),
      _DashboardSection.signal => _PagePanel(
          title: 'Signal',
          subtitle: 'Signal tuning and spectrum analysis',
          icon: Icons.monitor_heart_outlined,
          child: const _SignalPlaceholder(),
        ),
      _DashboardSection.wan => _PagePanel(
          title: 'WAN',
          subtitle: 'Internet connection details',
          icon: Icons.public_outlined,
          child: _WanCard(wan: snapshot.wan),
        ),
      _DashboardSection.system => _PagePanel(
          title: 'System',
          subtitle: 'Router runtime and firmware',
          icon: Icons.memory_outlined,
          child: _SystemCard(system: snapshot.system),
        ),
      _DashboardSection.subscriber => _PagePanel(
          title: 'Subscriber',
          subtitle: 'SIM and device identity',
          icon: Icons.sim_card_outlined,
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
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 24, color: colors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        child,
      ],
    );
  }
}

class _SignalPlaceholder extends StatelessWidget {
  const _SignalPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: const Center(
        child: Text(
          'Signal',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _SettingsPlaceholder extends StatelessWidget {
  const _SettingsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: const Center(
        child: Text(
          'Settings',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
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
      padding: const EdgeInsets.fromLTRB(24, 12, 20, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(
            color: colors.outlineVariant.withOpacity(0.4),
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 8,
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Dialog AirFibre',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Connected - $host',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                _StatusChip(
                  icon: Icons.cell_tower_outlined,
                  label: networkType.isEmpty ? '-' : networkType,
                  isAccent: networkType.isNotEmpty,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (lastUpdated != null) ...<Widget>[
            Text(
              _formatClock(lastUpdated!),
              style: TextStyle(
                fontSize: 12,
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 12),
          ],
          IconButton(
            tooltip: 'Refresh',
            onPressed: onRefresh,
            style: IconButton.styleFrom(
              backgroundColor: colors.surfaceContainerHighest.withOpacity(0.6),
              hoverColor: colors.primary.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: colors.outlineVariant.withOpacity(0.3),
                ),
              ),
            ),
            icon: Icon(
              Icons.refresh_rounded,
              size: 20,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    this.isAccent = false,
  });

  final IconData icon;
  final String label;
  final bool isAccent;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bg = isAccent
        ? colors.primaryContainer.withOpacity(0.4)
        : colors.surfaceContainerHighest.withOpacity(0.6);
    final fg = isAccent ? colors.primary : colors.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isAccent
              ? colors.primary.withOpacity(0.2)
              : colors.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.icon,
    required this.rows,
  });

  final String title;
  final IconData icon;
  final List<_InfoRowData> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant.withOpacity(0.4)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: colors.primary, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < rows.length; i++) ...<Widget>[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: colors.outlineVariant.withOpacity(0.2),
                ),
              _InfoRow(row: rows[i]),
            ],
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
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 130,
            child: Text(
              row.label,
              style: textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              row.value.isEmpty ? '-' : row.value,
              textAlign: TextAlign.right,
              style: textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
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
      icon: Icons.sim_card_outlined,
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
      icon: Icons.public_outlined,
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
      icon: Icons.memory_outlined,
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
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant.withOpacity(0.4)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Table(
          columnWidths: const <int, TableColumnWidth>{
            0: FlexColumnWidth(1.2),
            1: FlexColumnWidth(),
            2: FlexColumnWidth(),
          },
          children: <TableRow>[
            TableRow(
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withOpacity(0.6),
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
                    bottom: BorderSide(
                      color: colors.outlineVariant.withOpacity(0.2),
                    ),
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
          fontSize: header ? 13 : 14,
          fontWeight: header ? FontWeight.w700 : FontWeight.w500,
          color: header ? Theme.of(context).colorScheme.onSurfaceVariant : null,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.wifi_off_rounded,
                    size: 36,
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 20),
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
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onRefresh,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
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
