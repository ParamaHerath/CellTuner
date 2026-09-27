import 'dart:async';

import 'package:flutter/cupertino.dart';
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

class _RouterDashboardScreenState extends State<RouterDashboardScreen>
    with SingleTickerProviderStateMixin {
  String _host = '192.168.8.1';
  double _refreshIntervalSeconds = 1.0;
  bool _splitCellId = false;

  late RouterApiClient? _client;
  late Future<RouterSnapshot> _snapshotFuture;
  Timer? _refreshTimer;
  DateTime? _lastUpdated;
  _DashboardSection _selectedSection = _DashboardSection.status;
  bool _sidebarExpanded = true;
  bool _mobileSidebarOpen = false;
  late final AnimationController _mobileMenuAnimation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );
  final List<SignalMetricSample> _signalHistory = <SignalMetricSample>[];
  Set<String> _selectedSignalMetrics = <String>{'RSSI', 'RSRP', 'RSRQ', 'SINR'};
  String _signalTechMode = 'Both (4G & 5G)';

  RouterSnapshotLoader get _loader =>
      widget.snapshotLoader ?? _client!.fetchSnapshot;

  @override
  void initState() {
    super.initState();
    _client =
        widget.snapshotLoader == null ? RouterApiClient(host: _host) : null;
    _snapshotFuture = _loadSnapshot();
    if (widget.snapshotLoader == null) {
      _startRefreshTimer();
    }
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    final ms = (_refreshIntervalSeconds * 1000).round();
    _refreshTimer = Timer.periodic(
      Duration(milliseconds: ms),
      (_) => _refresh(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _mobileMenuAnimation.dispose();
    _client?.close();
    super.dispose();
  }

  void _toggleMobileSidebar() {
    setState(() {
      _mobileSidebarOpen = !_mobileSidebarOpen;
      if (_mobileSidebarOpen) {
        _mobileMenuAnimation.forward();
      } else {
        _mobileMenuAnimation.reverse();
      }
    });
  }

  Future<RouterSnapshot> _loadSnapshot() async {
    final snapshot = await _loader();
    if (mounted) {
      setState(() {
        _lastUpdated = DateTime.now();
        _recordSignalSnapshot(snapshot);
      });
    }
    return snapshot;
  }

  void _recordSignalSnapshot(RouterSnapshot snapshot) {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(seconds: 65));

    double? findVal(String key, CellularLayer layer) {
      for (final m in snapshot.metrics) {
        if (m.label.toUpperCase() == key) {
          final raw = m.valueFor(layer);
          if (raw == '-') return null;
          final match = RegExp(r'(-?\d+(?:\.\d+)?)').firstMatch(raw);
          if (match != null) return double.tryParse(match.group(1)!);
        }
      }
      return null;
    }

    _signalHistory.add(SignalMetricSample(
      timestamp: now,
      rssiLte: findVal('RSSI', CellularLayer.lte),
      rssiNr5g: findVal('RSSI', CellularLayer.nr5g),
      rsrpLte: findVal('RSRP', CellularLayer.lte),
      rsrpNr5g: findVal('RSRP', CellularLayer.nr5g),
      rsrqLte: findVal('RSRQ', CellularLayer.lte),
      rsrqNr5g: findVal('RSRQ', CellularLayer.nr5g),
      sinrLte: findVal('SINR', CellularLayer.lte),
      sinrNr5g: findVal('SINR', CellularLayer.nr5g),
    ));

    _signalHistory.removeWhere((s) => s.timestamp.isBefore(cutoff));
  }

  void _refresh() {
    setState(() {
      _snapshotFuture = _loadSnapshot();
    });
  }

  void _updateHost(String newHost) {
    final trimmed = newHost.trim();
    if (trimmed.isEmpty || trimmed == _host) return;
    setState(() {
      _host = trimmed;
      if (widget.snapshotLoader == null) {
        _client?.close();
        _client = RouterApiClient(host: _host);
      }
      _refresh();
    });
  }

  void _updateRefreshInterval(double seconds) {
    if (seconds == _refreshIntervalSeconds) return;
    setState(() {
      _refreshIntervalSeconds = seconds;
      if (widget.snapshotLoader == null) {
        _startRefreshTimer();
      }
    });
  }

  void _updateSplitCellId(bool enabled) {
    if (enabled == _splitCellId) return;
    setState(() {
      _splitCellId = enabled;
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
        final isMobile = _isMobileLayout(context);
        return _DashboardShell(
          selectedSection: _selectedSection,
          sidebarExpanded: _sidebarExpanded,
          isMobile: isMobile,
          menuAnimation: _mobileMenuAnimation,
          onSectionSelected: (section) {
            setState(() {
              _selectedSection = section;
              if (isMobile && _mobileSidebarOpen) {
                _mobileSidebarOpen = false;
                _mobileMenuAnimation.reverse();
              }
            });
          },
          onToggleSidebar: () {
            if (isMobile) {
              _toggleMobileSidebar();
            } else {
              setState(() => _sidebarExpanded = !_sidebarExpanded);
            }
          },
          statusBar: _StatusBar(
            networkType: data.networkType,
            metrics: data.metrics,
            lastUpdated: _lastUpdated,
            onRefresh: _refresh,
            isMobile: isMobile,
            onToggleSidebar: _toggleMobileSidebar,
            menuAnimation: _mobileMenuAnimation,
          ),
          child: _DashboardContent(
            isMobile: isMobile,
            snapshot: data,
            host: _host,
            refreshIntervalSeconds: _refreshIntervalSeconds,
            splitCellId: _splitCellId,
            signalHistory: _signalHistory,
            selectedSignalMetrics: _selectedSignalMetrics,
            signalTechMode: _signalTechMode,
            lastUpdated: _lastUpdated,
            section: _selectedSection,
            onRefresh: _refresh,
            onHostChanged: _updateHost,
            onRefreshIntervalChanged: _updateRefreshInterval,
            onSplitCellIdChanged: _updateSplitCellId,
            onSelectedSignalMetricsChanged: (metrics) {
              setState(() => _selectedSignalMetrics = metrics);
            },
            onSignalTechModeChanged: (mode) {
              setState(() => _signalTechMode = mode);
            },
          ),
        );
      },
    );
  }
}

enum _DashboardSection { status, signal, wan, system, subscriber, settings }

bool _isMobileLayout(BuildContext context) {
  final platform = Theme.of(context).platform;
  final isMobilePlatform =
      platform == TargetPlatform.android || platform == TargetPlatform.iOS;
  return isMobilePlatform || MediaQuery.sizeOf(context).width < 600;
}

class _DashboardShell extends StatelessWidget {
  const _DashboardShell({
    required this.selectedSection,
    required this.sidebarExpanded,
    required this.onSectionSelected,
    required this.onToggleSidebar,
    required this.statusBar,
    required this.child,
    this.isMobile = false,
    this.menuAnimation,
  });

  final _DashboardSection selectedSection;
  final bool sidebarExpanded;
  final ValueChanged<_DashboardSection> onSectionSelected;
  final VoidCallback onToggleSidebar;
  final Widget statusBar;
  final Widget child;
  final bool isMobile;
  final Animation<double>? menuAnimation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: isMobile ? 0 : 535,
            minHeight: isMobile ? 0 : 500,
          ),
          child: Column(
            children: <Widget>[
              statusBar,
              Expanded(
                child: isMobile
                    ? Stack(
                        children: <Widget>[
                          Positioned.fill(child: child),
                          if (menuAnimation != null)
                            Positioned.fill(
                              child: AnimatedBuilder(
                                animation: menuAnimation!,
                                builder: (context, _) {
                                  if (menuAnimation!.value == 0.0) {
                                    return const SizedBox.shrink();
                                  }
                                  return GestureDetector(
                                    onTap: onToggleSidebar,
                                    behavior: HitTestBehavior.opaque,
                                    child: Container(
                                      color: Colors.black.withOpacity(
                                        0.35 * menuAnimation!.value,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          if (menuAnimation != null)
                            Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              width: 250,
                              child: AnimatedBuilder(
                                animation: menuAnimation!,
                                builder: (context, sidebarWidget) {
                                  if (menuAnimation!.value == 0.0) {
                                    return const SizedBox.shrink();
                                  }
                                  return FractionalTranslation(
                                    translation: Offset(
                                      menuAnimation!.value - 1.0,
                                      0,
                                    ),
                                    child: sidebarWidget,
                                  );
                                },
                                child: Material(
                                  elevation: 8,
                                  shadowColor: Colors.black45,
                                  child: _NavigationSidebar(
                                    selectedSection: selectedSection,
                                    expanded: true,
                                    isMobile: true,
                                    onSectionSelected: onSectionSelected,
                                    onToggle: onToggleSidebar,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      )
                    : Row(
                        children: <Widget>[
                          _NavigationSidebar(
                            selectedSection: selectedSection,
                            expanded: sidebarExpanded,
                            isMobile: false,
                            onSectionSelected: onSectionSelected,
                            onToggle: onToggleSidebar,
                          ),
                          Expanded(child: child),
                        ],
                      ),
              ),
            ],
          ),
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
    this.isMobile = false,
  });

  final _DashboardSection selectedSection;
  final bool expanded;
  final ValueChanged<_DashboardSection> onSectionSelected;
  final VoidCallback onToggle;
  final bool isMobile;

  static const _items = <(_DashboardSection, String, IconData)>[
    (_DashboardSection.status, 'Status', CupertinoIcons.info),
    (_DashboardSection.signal, 'Signal', CupertinoIcons.waveform_path_ecg),
    (_DashboardSection.wan, 'WAN', CupertinoIcons.globe),
    (_DashboardSection.system, 'System', CupertinoIcons.desktopcomputer),
    (_DashboardSection.subscriber, 'Subscriber', CupertinoIcons.person_crop_square),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: isMobile ? 250 : (expanded ? 248 : 76),
      clipBehavior: Clip.hardEdge,
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
          const SizedBox(height: 8),
          if (!isMobile)
            _NavigationItem(
              icon: CupertinoIcons.bars,
              label: '',
              selected: false,
              expanded: expanded,
              onTap: onToggle,
              tooltip: expanded ? 'Collapse navigation' : 'Expand navigation',
            ),
          for (final item in _items)
            _NavigationItem(
              icon: item.$3,
              label: item.$2,
              selected: selectedSection == item.$1,
              expanded: isMobile ? true : expanded,
              onTap: () => onSectionSelected(item.$1),
            ),
          const Spacer(),
          _NavigationItem(
            icon: CupertinoIcons.settings,
            label: 'Settings',
            selected: selectedSection == _DashboardSection.settings,
            expanded: isMobile ? true : expanded,
            onTap: () => onSectionSelected(_DashboardSection.settings),
          ),
          const SizedBox(height: 8),
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
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 48,
            decoration: BoxDecoration(
              color: selected ? activeBg : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: <Widget>[
                const SizedBox(width: 4),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: Icon(
                      icon,
                      size: 22,
                      color: selected ? activeFg : inactiveFg,
                    ),
                  ),
                ),
                if (label.isNotEmpty)
                  Expanded(
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.centerLeft,
                        minWidth: 0,
                        maxWidth: 160,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: expanded ? 1.0 : 0.0,
                          curve: Curves.easeInOut,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 6, right: 12),
                            child: Text(
                              label,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.clip,
                              style: TextStyle(
                                fontSize: 14,
                                color: selected ? activeFg : colors.onSurface,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
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
    required this.refreshIntervalSeconds,
    required this.splitCellId,
    required this.signalHistory,
    required this.selectedSignalMetrics,
    required this.signalTechMode,
    required this.lastUpdated,
    required this.section,
    required this.onRefresh,
    required this.onHostChanged,
    required this.onRefreshIntervalChanged,
    required this.onSplitCellIdChanged,
    required this.onSelectedSignalMetricsChanged,
    required this.onSignalTechModeChanged,
    this.isMobile = false,
  });

  final RouterSnapshot snapshot;
  final String host;
  final double refreshIntervalSeconds;
  final bool splitCellId;
  final List<SignalMetricSample> signalHistory;
  final Set<String> selectedSignalMetrics;
  final String signalTechMode;
  final DateTime? lastUpdated;
  final _DashboardSection section;
  final VoidCallback onRefresh;
  final ValueChanged<String> onHostChanged;
  final ValueChanged<double> onRefreshIntervalChanged;
  final ValueChanged<bool> onSplitCellIdChanged;
  final ValueChanged<Set<String>> onSelectedSignalMetricsChanged;
  final ValueChanged<String> onSignalTechModeChanged;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 32,
        vertical: isMobile ? 18 : 28,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isMobile ? double.infinity : 1560,
          ),
          child: Column(
            children: <Widget>[
              _SectionPage(
                section: section,
                snapshot: snapshot,
                host: host,
                refreshIntervalSeconds: refreshIntervalSeconds,
                splitCellId: splitCellId,
                signalHistory: signalHistory,
                selectedSignalMetrics: selectedSignalMetrics,
                signalTechMode: signalTechMode,
                onHostChanged: onHostChanged,
                onRefreshIntervalChanged: onRefreshIntervalChanged,
                onSplitCellIdChanged: onSplitCellIdChanged,
                onSelectedSignalMetricsChanged: onSelectedSignalMetricsChanged,
                onSignalTechModeChanged: onSignalTechModeChanged,
              ),
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
    );
  }
}

class _SectionPage extends StatelessWidget {
  const _SectionPage({
    required this.section,
    required this.snapshot,
    required this.host,
    required this.refreshIntervalSeconds,
    required this.splitCellId,
    required this.signalHistory,
    required this.selectedSignalMetrics,
    required this.signalTechMode,
    required this.onHostChanged,
    required this.onRefreshIntervalChanged,
    required this.onSplitCellIdChanged,
    required this.onSelectedSignalMetricsChanged,
    required this.onSignalTechModeChanged,
  });

  final _DashboardSection section;
  final RouterSnapshot snapshot;
  final String host;
  final double refreshIntervalSeconds;
  final bool splitCellId;
  final List<SignalMetricSample> signalHistory;
  final Set<String> selectedSignalMetrics;
  final String signalTechMode;
  final ValueChanged<String> onHostChanged;
  final ValueChanged<double> onRefreshIntervalChanged;
  final ValueChanged<bool> onSplitCellIdChanged;
  final ValueChanged<Set<String>> onSelectedSignalMetricsChanged;
  final ValueChanged<String> onSignalTechModeChanged;

  @override
  Widget build(BuildContext context) {
    return switch (section) {
      _DashboardSection.status => _PagePanel(
          title: 'Status',
          subtitle: 'Real-time network and cellular metrics',
          icon: CupertinoIcons.info,
          child: _SignalTable(
            metrics: snapshot.metrics,
            splitCellId: splitCellId,
          ),
        ),
      _DashboardSection.signal => _PagePanel(
          title: 'Signal',
          subtitle: 'Signal tuning and spectrum analysis',
          icon: CupertinoIcons.waveform_path_ecg,
          headerActions: Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              _CellIdBadge(
                snapshot: snapshot,
                splitCellId: splitCellId,
              ),
              _MetricsDropdown(
                selectedMetrics: selectedSignalMetrics,
                onChanged: onSelectedSignalMetricsChanged,
              ),
              _TechModeDropdown(
                mode: signalTechMode,
                onChanged: onSignalTechModeChanged,
              ),
            ],
          ),
          child: _SignalPage(
            history: signalHistory,
            snapshot: snapshot,
            selectedMetrics: selectedSignalMetrics,
            techMode: signalTechMode,
          ),
        ),
      _DashboardSection.wan => _PagePanel(
          title: 'WAN',
          subtitle: 'Internet connection details',
          icon: CupertinoIcons.globe,
          child: _WanCard(wan: snapshot.wan),
        ),
      _DashboardSection.system => _PagePanel(
          title: 'System',
          subtitle: 'Router runtime and firmware',
          icon: CupertinoIcons.desktopcomputer,
          child: _SystemCard(system: snapshot.system),
        ),
      _DashboardSection.subscriber => _PagePanel(
          title: 'Subscriber',
          subtitle: 'SIM and device identity',
          icon: CupertinoIcons.person_crop_square,
          child: _IdentityCard(snapshot: snapshot),
        ),
      _DashboardSection.settings => _PagePanel(
          title: 'Settings',
          subtitle: 'Configure router IP and dashboard preferences',
          icon: CupertinoIcons.settings,
          child: _SettingsCard(
            host: host,
            refreshIntervalSeconds: refreshIntervalSeconds,
            splitCellId: splitCellId,
            onHostChanged: onHostChanged,
            onRefreshIntervalChanged: onRefreshIntervalChanged,
            onSplitCellIdChanged: onSplitCellIdChanged,
          ),
        ),
    };
  }
}

class _PagePanel extends StatelessWidget {
  const _PagePanel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.headerActions,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final Widget? headerActions;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 640;
            if (isNarrow && headerActions != null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
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
                  const SizedBox(height: 12),
                  headerActions!,
                ],
              );
            }
            return Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
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
                if (headerActions != null) ...<Widget>[
                  const SizedBox(width: 12),
                  headerActions!,
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        child,
      ],
    );
  }
}

class _CellIdBadge extends StatelessWidget {
  const _CellIdBadge({
    required this.snapshot,
    required this.splitCellId,
  });

  final RouterSnapshot snapshot;
  final bool splitCellId;

  String _formattedCellId() {
    RouterMetric? cellIdMetric;
    for (final m in snapshot.metrics) {
      if (m.label.toLowerCase() == 'cell id') {
        cellIdMetric = m;
        break;
      }
    }
    if (cellIdMetric == null) return 'Cell ID: N/A';

    var lteVal = cellIdMetric.valueFor(CellularLayer.lte);
    var nr5gVal = cellIdMetric.valueFor(CellularLayer.nr5g);

    if (splitCellId) {
      if (lteVal != '-') lteVal = _formatCellIdString(lteVal, is5g: false);
      if (nr5gVal != '-') nr5gVal = _formatCellIdString(nr5gVal, is5g: true);
    }

    if (lteVal != '-' && nr5gVal != '-' && lteVal != nr5gVal) {
      return 'Cell ID: $lteVal / $nr5gVal';
    } else if (lteVal != '-') {
      return 'Cell ID: $lteVal';
    } else if (nr5gVal != '-') {
      return 'Cell ID: $nr5gVal';
    }
    return 'Cell ID: N/A';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.outlineVariant.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(CupertinoIcons.number, size: 14, color: colors.primary),
          const SizedBox(width: 8),
          SelectableText(
            _formattedCellId(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricsDropdown extends StatelessWidget {
  const _MetricsDropdown({
    required this.selectedMetrics,
    required this.onChanged,
  });

  final Set<String> selectedMetrics;
  final ValueChanged<Set<String>> onChanged;

  String _formatLabel() {
    if (selectedMetrics.length == 4) return 'Metrics: All (4/4)';
    if (selectedMetrics.isEmpty) return 'Metrics: None (0/4)';
    final sorted = ['RSSI', 'RSRP', 'RSRQ', 'SINR'].where(selectedMetrics.contains).toList();
    return 'Metrics: ${sorted.join(", ")}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      tooltip: 'Select metrics',
      onSelected: (metricKey) {
        final updated = Set<String>.from(selectedMetrics);
        if (updated.contains(metricKey)) {
          updated.remove(metricKey);
        } else {
          updated.add(metricKey);
        }
        onChanged(updated);
      },
      itemBuilder: (context) => <PopupMenuEntry<String>>[
        for (final m in <String>['RSSI', 'RSRP', 'RSRQ', 'SINR'])
          CheckedPopupMenuItem<String>(
            value: m,
            checked: selectedMetrics.contains(m),
            child: Text(m, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: colors.outlineVariant.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(CupertinoIcons.slider_horizontal_3, size: 14, color: colors.primary),
            const SizedBox(width: 8),
            Text(
              _formatLabel(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(width: 6),
            Icon(CupertinoIcons.chevron_down, size: 13, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _TechModeDropdown extends StatelessWidget {
  const _TechModeDropdown({
    required this.mode,
    required this.onChanged,
  });

  final String mode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.outlineVariant.withOpacity(0.5)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: mode,
          isDense: true,
          icon: const Icon(CupertinoIcons.chevron_down, size: 13),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
          items: const [
            DropdownMenuItem(
              value: 'Both (4G & 5G)',
              child: Text('Both (4G & 5G)'),
            ),
            DropdownMenuItem(
              value: '4G LTE Only',
              child: Text('4G LTE Only'),
            ),
            DropdownMenuItem(
              value: '5G NR Only',
              child: Text('5G NR Only'),
            ),
          ],
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
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

class _SignalPage extends StatelessWidget {
  const _SignalPage({
    required this.history,
    required this.snapshot,
    this.selectedMetrics,
    this.techMode,
  });

  final List<SignalMetricSample> history;
  final RouterSnapshot snapshot;
  final Set<String>? selectedMetrics;
  final String? techMode;

  @override
  Widget build(BuildContext context) {
    final activeMetrics = selectedMetrics ?? {'RSSI', 'RSRP', 'RSRQ', 'SINR'};
    final mode = techMode ?? 'Both (4G & 5G)';
    final show4g = mode == 'Both (4G & 5G)' || mode == '4G LTE Only';
    final show5g = mode == 'Both (4G & 5G)' || mode == '5G NR Only';

    const metricConfigs = <(String, String, String)>[
      ('RSSI', 'RSSI (Received Signal Strength)', 'dBm'),
      ('RSRP', 'RSRP (Reference Signal Received Power)', 'dBm'),
      ('RSRQ', 'RSRQ (Reference Signal Received Quality)', 'dB'),
      ('SINR', 'SINR (Signal to Interference & Noise)', 'dB'),
    ];

    final visibleConfigs = metricConfigs
        .where((c) => activeMetrics.contains(c.$1))
        .toList();

    if (visibleConfigs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
          ),
        ),
        child: const Center(
          child: Text(
            'No metrics selected. Select metrics to display graphs.',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoColumns = constraints.maxWidth > 800;

        if (useTwoColumns) {
          final rows = <Widget>[];
          for (var i = 0; i < visibleConfigs.length; i += 2) {
            final first = visibleConfigs[i];
            final second = (i + 1 < visibleConfigs.length) ? visibleConfigs[i + 1] : null;

            rows.add(
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: _MetricGraphCard(
                      metricKey: first.$1,
                      title: first.$2,
                      unit: first.$3,
                      history: history,
                      show4g: show4g,
                      show5g: show5g,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: second != null
                        ? _MetricGraphCard(
                            metricKey: second.$1,
                            title: second.$2,
                            unit: second.$3,
                            history: history,
                            show4g: show4g,
                            show5g: show5g,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            );
            if (i + 2 < visibleConfigs.length) {
              rows.add(const SizedBox(height: 16));
            }
          }
          return Column(children: rows);
        } else {
          return Column(
            children: [
              for (var i = 0; i < visibleConfigs.length; i++) ...[
                _MetricGraphCard(
                  metricKey: visibleConfigs[i].$1,
                  title: visibleConfigs[i].$2,
                  unit: visibleConfigs[i].$3,
                  history: history,
                  show4g: show4g,
                  show5g: show5g,
                ),
                if (i < visibleConfigs.length - 1) const SizedBox(height: 16),
              ],
            ],
          );
        }
      },
    );
  }
}

class _MetricGraphCard extends StatelessWidget {
  const _MetricGraphCard({
    required this.title,
    required this.metricKey,
    required this.unit,
    required this.history,
    required this.show4g,
    required this.show5g,
  });

  final String title;
  final String metricKey;
  final String unit;
  final List<SignalMetricSample> history;
  final bool show4g;
  final bool show5g;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final latest = history.isNotEmpty ? history.last : null;
    final lteVal = latest?.getValue(metricKey, is5g: false);
    final nr5gVal = latest?.getValue(metricKey, is5g: true);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outlineVariant.withOpacity(0.4)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Flexible(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (show4g) ...<Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          '4G: ${lteVal != null ? "${lteVal.toStringAsFixed(0)}$unit" : "N/A"}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF00A83B),
                          ),
                        ),
                      ),
                      if (show5g) const SizedBox(width: 6),
                    ],
                    if (show5g) ...<Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0E7FF),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          '5G: ${nr5gVal != null ? "${nr5gVal.toStringAsFixed(0)}$unit" : "N/A"}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF003BFF),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 240,
              width: double.infinity,
              child: CustomPaint(
                painter: _MetricLineChartPainter(
                  metricKey: metricKey,
                  unit: unit,
                  history: history,
                  show4g: show4g,
                  show5g: show5g,
                  gridColor: colors.outlineVariant.withOpacity(0.3),
                  labelColor: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricLineChartPainter extends CustomPainter {
  _MetricLineChartPainter({
    required this.metricKey,
    required this.unit,
    required this.history,
    required this.show4g,
    required this.show5g,
    required this.gridColor,
    required this.labelColor,
  });

  final String metricKey;
  final String unit;
  final List<SignalMetricSample> history;
  final bool show4g;
  final bool show5g;
  final Color gridColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    const chartLeft = 42.0;
    final chartRight = size.width - 15.0;
    const chartTop = 15.0;
    final chartBottom = size.height - 25.0;
    final chartWidth = chartRight - chartLeft;
    final chartHeight = chartBottom - chartTop;

    if (chartWidth <= 0 || chartHeight <= 0) return;

    final now = history.isNotEmpty ? history.last.timestamp : DateTime.now();

    var pointsSource = history;
    if (pointsSource.length == 1) {
      final single = pointsSource.first;
      pointsSource = [
        SignalMetricSample(
          timestamp: now.subtract(const Duration(seconds: 60)),
          rssiLte: single.rssiLte,
          rssiNr5g: single.rssiNr5g,
          rsrpLte: single.rsrpLte,
          rsrpNr5g: single.rsrpNr5g,
          rsrqLte: single.rsrqLte,
          rsrqNr5g: single.rsrqNr5g,
          sinrLte: single.sinrLte,
          sinrNr5g: single.sinrNr5g,
        ),
        single,
      ];
    }

    double defaultMin;
    double defaultMax;
    switch (metricKey.toUpperCase()) {
      case 'RSSI':
        defaultMin = -110;
        defaultMax = -40;
        break;
      case 'RSRP':
        defaultMin = -130;
        defaultMax = -60;
        break;
      case 'RSRQ':
        defaultMin = -24;
        defaultMax = 0;
        break;
      case 'SINR':
        defaultMin = -10;
        defaultMax = 30;
        break;
      default:
        defaultMin = -100;
        defaultMax = 0;
    }

    double minY = defaultMin;
    double maxY = defaultMax;

    final allVals = <double>[];
    for (final s in pointsSource) {
      if (show4g) {
        final v = s.getValue(metricKey, is5g: false);
        if (v != null) allVals.add(v);
      }
      if (show5g) {
        final v = s.getValue(metricKey, is5g: true);
        if (v != null) allVals.add(v);
      }
    }

    if (allVals.isNotEmpty) {
      final sampleMin = allVals.reduce((a, b) => a < b ? a : b);
      final sampleMax = allVals.reduce((a, b) => a > b ? a : b);
      if (sampleMin < minY) minY = (sampleMin - 5).floorToDouble();
      if (sampleMax > maxY) maxY = (sampleMax + 5).ceilToDouble();
    }

    if (minY == maxY) {
      minY -= 5;
      maxY += 5;
    }

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const numYDivisions = 3;
    for (var i = 0; i <= numYDivisions; i++) {
      final yRatio = i / numYDivisions;
      final y = chartBottom - (yRatio * chartHeight);
      canvas.drawLine(Offset(chartLeft, y), Offset(chartRight, y), gridPaint);

      final val = minY + (yRatio * (maxY - minY));
      final textSpan = TextSpan(
        text: val.round().toString(),
        style: TextStyle(fontSize: 10, color: labelColor),
      );
      final tp = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(chartLeft - tp.width - 6, y - (tp.height / 2)));
    }

    final xLabels = <(double, String)>[
      (0.0, '-60s'),
      (0.25, '-45s'),
      (0.5, '-30s'),
      (0.75, '-15s'),
      (1.0, 'Now'),
    ];

    for (final (ratio, label) in xLabels) {
      final x = chartLeft + (ratio * chartWidth);
      canvas.drawLine(Offset(x, chartTop), Offset(x, chartBottom), gridPaint);

      final textSpan = TextSpan(
        text: label,
        style: TextStyle(fontSize: 10, color: labelColor, fontWeight: FontWeight.w500),
      );
      final tp = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      final textX = (x - (tp.width / 2)).clamp(chartLeft, chartRight - tp.width);
      tp.paint(canvas, Offset(textX, chartBottom + 6));
    }

    void drawSeries(bool is5g, Color color) {
      final points = <Offset>[];
      for (final sample in pointsSource) {
        final val = sample.getValue(metricKey, is5g: is5g);
        if (val == null) continue;
        final age = now.difference(sample.timestamp).inMilliseconds / 1000.0;
        final x = chartRight - ((age / 60.0) * chartWidth);
        final clampedX = x.clamp(chartLeft, chartRight);
        final yRatio = (val - minY) / (maxY - minY);
        final y = chartBottom - (yRatio * chartHeight);
        final clampedY = y.clamp(chartTop, chartBottom);
        points.add(Offset(clampedX, clampedY));
      }

      if (points.isEmpty) return;

      if (points.length == 1) {
        final p = points.first;
        points.insert(0, Offset(chartLeft, p.dy));
      }

      final linePath = Path();
      final fillPath = Path();

      linePath.moveTo(points.first.dx, points.first.dy);
      fillPath.moveTo(points.first.dx, chartBottom);
      fillPath.lineTo(points.first.dx, points.first.dy);

      for (var i = 0; i < points.length - 1; i++) {
        final p0 = points[i];
        final p1 = points[i + 1];
        final controlX1 = p0.dx + (p1.dx - p0.dx) / 2;
        final controlY1 = p0.dy;
        final controlX2 = p0.dx + (p1.dx - p0.dx) / 2;
        final controlY2 = p1.dy;
        linePath.cubicTo(controlX1, controlY1, controlX2, controlY2, p1.dx, p1.dy);
        fillPath.cubicTo(controlX1, controlY1, controlX2, controlY2, p1.dx, p1.dy);
      }

      fillPath.lineTo(points.last.dx, chartBottom);
      fillPath.close();

      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withOpacity(0.18),
            color.withOpacity(0.0),
          ],
        ).createShader(Rect.fromLTRB(chartLeft, chartTop, chartRight, chartBottom));

      canvas.drawPath(fillPath, fillPaint);

      final linePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = color
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(linePath, linePaint);

      final lastPoint = points.last;
      final outerDot = Paint()..color = color;
      final innerDot = Paint()..color = Colors.white;

      canvas.drawCircle(lastPoint, 4.5, outerDot);
      canvas.drawCircle(lastPoint, 2.0, innerDot);
    }

    if (show4g) drawSeries(false, const Color(0xFF00A83B));
    if (show5g) drawSeries(true, const Color(0xFF003BFF));
  }

  @override
  bool shouldRepaint(covariant _MetricLineChartPainter oldDelegate) {
    return oldDelegate.history != history ||
        oldDelegate.show4g != show4g ||
        oldDelegate.show5g != show5g ||
        oldDelegate.metricKey != metricKey;
  }
}

class _SettingsCard extends StatefulWidget {
  const _SettingsCard({
    required this.host,
    required this.refreshIntervalSeconds,
    required this.splitCellId,
    required this.onHostChanged,
    required this.onRefreshIntervalChanged,
    required this.onSplitCellIdChanged,
  });

  final String host;
  final double refreshIntervalSeconds;
  final bool splitCellId;
  final ValueChanged<String> onHostChanged;
  final ValueChanged<double> onRefreshIntervalChanged;
  final ValueChanged<bool> onSplitCellIdChanged;

  @override
  State<_SettingsCard> createState() => _SettingsCardState();
}

class _SettingsCardState extends State<_SettingsCard> {
  late final TextEditingController _hostController;

  static const _intervalOptions = <double>[0.25, 0.5, 1.0, 2.0, 5.0, 10.0];

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController(text: widget.host);
  }

  @override
  void didUpdateWidget(covariant _SettingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.host != widget.host && _hostController.text != widget.host) {
      _hostController.text = widget.host;
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    super.dispose();
  }

  void _saveHost() {
    final newHost = _hostController.text.trim();
    if (newHost.isNotEmpty) {
      widget.onHostChanged(newHost);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Router IP updated to $newHost'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
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
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(CupertinoIcons.antenna_radiowaves_left_right, color: colors.primary, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  'Router Connection',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Router IP Address',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Enter the gateway IP address of your LTE/5G router (Default: 192.168.8.1).",
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _hostController,
                    decoration: InputDecoration(
                      hintText: '192.168.8.1',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                          color: colors.outlineVariant,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                          color: colors.outlineVariant.withOpacity(0.6),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                          color: colors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _saveHost(),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _saveHost,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text('Save'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Divider(
              height: 1,
              thickness: 1,
              color: colors.outlineVariant.withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(CupertinoIcons.timer, color: colors.primary, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  'Polling & Refresh',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Update Frequency',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Select how often the dashboard automatically polls the router for metrics (Default: 1s).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<double>(
              value: widget.refreshIntervalSeconds,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: colors.outlineVariant,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: colors.outlineVariant.withOpacity(0.6),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: colors.primary,
                    width: 1.5,
                  ),
                ),
              ),
              items: _intervalOptions.map((seconds) {
                final label = seconds < 1 ? '${seconds}s' : '${seconds.toInt()}s';
                return DropdownMenuItem<double>(
                  value: seconds,
                  child: Text(label),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  widget.onRefreshIntervalChanged(val);
                }
              },
            ),
            const SizedBox(height: 24),
            Divider(
              height: 1,
              thickness: 1,
              color: colors.outlineVariant.withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(CupertinoIcons.slider_horizontal_3, color: colors.primary, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  'Cell Identity Formatting',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Split Cell ID',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Show LTE and 5G Cell ID as eNB/gNB ID–Sector ID.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Switch(
                  value: widget.splitCellId,
                  onChanged: widget.onSplitCellIdChanged,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.networkType,
    required this.metrics,
    required this.lastUpdated,
    required this.onRefresh,
    this.isMobile = false,
    this.onToggleSidebar,
    this.menuAnimation,
  });

  final String networkType;
  final List<RouterMetric> metrics;
  final DateTime? lastUpdated;
  final VoidCallback onRefresh;
  final bool isMobile;
  final VoidCallback? onToggleSidebar;
  final Animation<double>? menuAnimation;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final badgeStyle = _getNetworkBadgeStyle(networkType, colors);

    int? primaryRsrp;
    for (final m in metrics) {
      if (m.label.toUpperCase() == 'RSRP') {
        final nr5gVal = int.tryParse(m.nr5g.replaceAll(RegExp(r'[^0-9-]'), ''));
        if (nr5gVal != null && nr5gVal != 0) {
          primaryRsrp = nr5gVal;
          break;
        }
        final lteVal = int.tryParse(m.lte.replaceAll(RegExp(r'[^0-9-]'), ''));
        if (lteVal != null && lteVal != 0) {
          primaryRsrp = lteVal;
          break;
        }
      }
    }
    final signalBars = _calculateSignalBars(primaryRsrp);

    return Container(
      padding: EdgeInsets.fromLTRB(
          isMobile ? 12 : 24, 12, isMobile ? 12 : 20, 12),
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
          if (isMobile) ...<Widget>[
            IconButton(
              tooltip: (menuAnimation?.value ?? 0) > 0.5
                  ? 'Close navigation'
                  : 'Open navigation',
              onPressed: onToggleSidebar,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.all(4),
                hoverColor: colors.primary.withOpacity(0.08),
                highlightColor: Colors.transparent,
              ),
              icon: AnimatedIcon(
                icon: AnimatedIcons.menu_close,
                progress: menuAnimation ?? const AlwaysStoppedAnimation(0.0),
                size: 22,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
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
                const SizedBox(height: 4),
                _StatusChip(
                  signalBars: signalBars,
                  label: badgeStyle.$1,
                  backgroundColor: badgeStyle.$2,
                  foregroundColor: badgeStyle.$3,
                  borderColor: badgeStyle.$4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                tooltip: 'Refresh',
                onPressed: onRefresh,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.all(3),
                  backgroundColor:
                      colors.surfaceContainerHighest.withOpacity(0.6),
                  hoverColor: colors.primary.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                    side: BorderSide(
                      color: colors.outlineVariant.withOpacity(0.3),
                    ),
                  ),
                ),
                icon: Icon(
                  CupertinoIcons.refresh,
                  size: 13,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                lastUpdated != null
                    ? 'Last Synced: ${_formatClock(lastUpdated!)}'
                    : '',
                style: TextStyle(
                  fontSize: 10,
                  color: colors.outline,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

int _calculateSignalBars(int? rsrp) {
  if (rsrp == null) return 0;
  if (rsrp >= -85) return 5;
  if (rsrp >= -95) return 4;
  if (rsrp >= -105) return 3;
  if (rsrp >= -115) return 2;
  if (rsrp >= -125) return 1;
  return 0;
}

class _SignalBarsIcon extends StatelessWidget {
  const _SignalBarsIcon({
    required this.bars,
    required this.color,
  });

  final int bars;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 12,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(5, (index) {
          final isActive = index < bars;
          final height = 4.8 + (index * 1.8);
          return Container(
            width: 2.8,
            height: height,
            decoration: BoxDecoration(
              color: isActive ? color : color.withOpacity(0.3),
              borderRadius: BorderRadius.circular(1.5),
            ),
          );
        }),
      ),
    );
  }
}

(String, Color, Color, Color) _getNetworkBadgeStyle(
  String rawNetworkType,
  ColorScheme colors,
) {
  final upper = rawNetworkType.trim().toUpperCase();
  if (upper.isEmpty || upper == '-' || upper == 'NONE' || upper == 'NO SERVICE') {
    return (
      'No Service',
      const Color(0xFFFEE2E2),
      const Color(0xFFDC2626),
      const Color(0xFFFCA5A5),
    );
  }
  if (upper.contains('5G')) {
    return (
      rawNetworkType,
      const Color(0xFFE0E7FF), // light background
      const Color(0xFF003BFF), // very saturated blue
      const Color(0xFF4D73FF), // secondary blue
    );
  }
  if (upper.contains('4G') || upper.contains('LTE')) {
    return (
      rawNetworkType,
      const Color(0xFFD1FAE5), // light green
      const Color(0xFF00A83B), // saturated green
      const Color(0xFF4ADE80), // secondary green
    );
  }
  return (
    rawNetworkType,
    colors.surfaceContainerHighest.withOpacity(0.6),
    colors.onSurfaceVariant,
    colors.outlineVariant.withOpacity(0.3),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.signalBars,
    required this.label,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
  });

  final int signalBars;
  final String label;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bg = backgroundColor ?? colors.surfaceContainerHighest.withOpacity(0.6);
    final fg = foregroundColor ?? colors.onSurfaceVariant;
    final border = borderColor ?? colors.outlineVariant.withOpacity(0.3);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _SignalBarsIcon(bars: signalBars, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
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
    required this.rows,
  });

  final List<_InfoRowData> rows;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
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
      rows: <_InfoRowData>[
        _InfoRowData('Runtime', system.formattedUptime),
        _InfoRowData('Firmware', system.firmwareVersion),
      ],
    );
  }
}

class _SignalTable extends StatelessWidget {
  const _SignalTable({
    required this.metrics,
    this.splitCellId = false,
  });

  final List<RouterMetric> metrics;
  final bool splitCellId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
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
        borderRadius: BorderRadius.circular(10),
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
            for (var idx = 0; idx < metrics.length; idx++) ...<TableRow>[
              () {
                final metric = metrics[idx];
                final isCellId = metric.label.toLowerCase() == 'cell id';
                var lteVal = metric.valueFor(CellularLayer.lte);
                var nr5gVal = metric.valueFor(CellularLayer.nr5g);
                if (splitCellId && isCellId) {
                  if (lteVal != '-') {
                    lteVal = _formatCellIdString(lteVal, is5g: false);
                  }
                  if (nr5gVal != '-') {
                    nr5gVal = _formatCellIdString(nr5gVal, is5g: true);
                  }
                }
                return TableRow(
                  decoration: BoxDecoration(
                    color: idx.isEven
                        ? Colors.transparent
                        : colors.surfaceContainerHighest.withOpacity(0.2),
                    border: Border(
                      bottom: BorderSide(
                        color: colors.outlineVariant.withOpacity(0.2),
                      ),
                    ),
                  ),
                  children: <Widget>[
                    _TableCell(metric.label),
                    _TableCell(lteVal),
                    _TableCell(nr5gVal),
                  ],
                );
              }(),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatCellIdString(String raw, {required bool is5g}) {
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
            borderRadius: BorderRadius.circular(10),
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
                    CupertinoIcons.wifi_slash,
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
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(CupertinoIcons.refresh),
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
