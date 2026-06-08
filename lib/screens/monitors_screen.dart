// lib/screens/monitors_screen.dart
// OpsFlood — Monitors tab  (Riverpod v3)
// ignore_for_file: avoid_function_literals_in_foreach_calls
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../extensions/build_context_extensions.dart';
import '../models/flood_data.dart';
import '../models/weather_data.dart';
import '../providers/flood_providers.dart';
import '../providers/weather_provider.dart';
import '../theme/app_palette.dart';
import '../theme/river_theme.dart';
import 'river_detail_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Screen
// ═══════════════════════════════════════════════════════════════════════════

class MonitorsScreen extends ConsumerStatefulWidget {
  const MonitorsScreen({super.key});
  static const String route = '/monitors';
  @override
  ConsumerState<MonitorsScreen> createState() => _MonitorsScreenState();
}

class _MonitorsScreenState extends ConsumerState<MonitorsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String _search = '';
  String _sortKey = 'level'; // level | capacity | name
  bool _showCriticalOnly = false;

  List<FloodData> _sorted(List<FloodData> raw) {
    var list = raw.where((d) {
      if (_showCriticalOnly &&
          d.imdSeverity != 'critical' &&
          d.imdSeverity != 'high') return false;
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      return d.stationName.toLowerCase().contains(q) ||
          d.riverName.toString().toLowerCase().contains(q) ||
          d.district.toLowerCase().contains(q) ||
          d.state.toLowerCase().contains(q);
    }).toList();

    list.sort((a, b) {
      if (_sortKey == 'name') return a.stationName.compareTo(b.stationName);
      if (_sortKey == 'capacity') {
        final c = b.capacityPercent.compareTo(a.capacityPercent);
        return c != 0 ? c : b.capacityPercent.compareTo(a.capacityPercent);
      }
      // default: level percent
      final c = b.levelPercent.compareTo(a.levelPercent);
      return c != 0 ? c : b.capacityPercent.compareTo(a.capacityPercent);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final floodAsync = ref.watch(floodDataProvider);
    final theme      = ref.watch(riverThemeProvider);

    return Scaffold(
      backgroundColor: theme.bg,
      body: floodAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data: (allData) {
          final data = _sorted(
            allData.where((d) => d != null).cast<FloodData>().toList(),
          );
          return CustomScrollView(
            slivers: [
              _AppBar(
                search:           _search,
                sortKey:          _sortKey,
                showCriticalOnly: _showCriticalOnly,
                onSearch: (v) => setState(() => _search = v),
                onSort:   (v) => setState(() => _sortKey = v),
                onToggleCritical: () =>
                    setState(() => _showCriticalOnly = !_showCriticalOnly),
              ),
              if (data.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: Text('No stations match.')),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _StationCard(data: data[i]),
                    childCount: data.length,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// App Bar
// ═══════════════════════════════════════════════════════════════════════════

class _AppBar extends ConsumerWidget {
  final String   search;
  final String   sortKey;
  final bool     showCriticalOnly;
  final ValueChanged<String>  onSearch;
  final ValueChanged<String>  onSort;
  final VoidCallback          onToggleCritical;

  const _AppBar({
    required this.search,
    required this.sortKey,
    required this.showCriticalOnly,
    required this.onSearch,
    required this.onSort,
    required this.onToggleCritical,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme    = ref.watch(riverThemeProvider);
    final fetchAsync = ref.watch(floodDataProvider);
    final lastFetch  = fetchAsync.valueOrNull != null
        ? DateTime.now()
        : null;

    return SliverAppBar(
      backgroundColor: theme.bg,
      pinned:          true,
      expandedHeight:  140,
      flexibleSpace: FlexibleSpaceBar(
        background: Padding(
          padding: const EdgeInsets.fromLTRB(16, 60, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.monitors,
                style: TextStyle(
                  color:      theme.textPrimary,
                  fontSize:   26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                lastFetch != null
                    ? '${context.l10n.lastUpdated} ${_fmt(lastFetch)}'
                    : context.l10n.loading,
                style: TextStyle(color: theme.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: _SearchSortBar(
          search:           search,
          sortKey:          sortKey,
          showCriticalOnly: showCriticalOnly,
          onSearch:         onSearch,
          onSort:           onSort,
          onToggleCritical: onToggleCritical,
        ),
      ),
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// ═══════════════════════════════════════════════════════════════════════════
// Search + Sort bar
// ═══════════════════════════════════════════════════════════════════════════

class _SearchSortBar extends StatelessWidget {
  final String   search;
  final String   sortKey;
  final bool     showCriticalOnly;
  final ValueChanged<String>  onSearch;
  final ValueChanged<String>  onSort;
  final VoidCallback          onToggleCritical;

  const _SearchSortBar({
    required this.search,
    required this.sortKey,
    required this.showCriticalOnly,
    required this.onSearch,
    required this.onSort,
    required this.onToggleCritical,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: onSearch,
              decoration: InputDecoration(
                hintText:      'Search stations…',
                prefixIcon:    const Icon(Icons.search, size: 18),
                isDense:       true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:   BorderSide.none,
                ),
                filled:      true,
                fillColor:   AppPalette.surface2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _SortButton(current: sortKey, onSort: onSort),
          const SizedBox(width: 6),
          IconButton(
            onPressed: onToggleCritical,
            icon: Icon(
              Icons.warning_amber_rounded,
              color: showCriticalOnly ? AppPalette.danger : AppPalette.textDim,
            ),
            tooltip: 'Show critical only',
          ),
        ],
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  final String current;
  final ValueChanged<String> onSort;
  const _SortButton({required this.current, required this.onSort});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      initialValue: current,
      onSelected:   onSort,
      icon: const Icon(Icons.sort_rounded, size: 20),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'level',    child: Text('Sort: Level %')),
        PopupMenuItem(value: 'capacity', child: Text('Sort: Capacity %')),
        PopupMenuItem(value: 'name',     child: Text('Sort: Name')),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Station card
// ═══════════════════════════════════════════════════════════════════════════

class _StationCard extends ConsumerStatefulWidget {
  final FloodData data;
  const _StationCard({required this.data});

  @override
  ConsumerState<_StationCard> createState() => _StationCardState();
}

class _StationCardState extends ConsumerState<_StationCard> {
  bool _expanded = false;

  FloodData get data => widget.data;

  Color get _severityColor {
    switch (data.imdSeverity) {
      case 'critical': return AppPalette.danger;
      case 'high':     return AppPalette.amber;
      case 'moderate': return AppPalette.cyan;
      default:         return AppPalette.textDim;
    }
  }

  String get _severityLabel {
    switch (data.imdSeverity) {
      case 'critical': return 'CRITICAL';
      case 'high':     return 'HIGH';
      case 'moderate': return 'MODERATE';
      default:         return 'NORMAL';
    }
  }

  double get _levelPct  => data.levelPercent.clamp(0, 100);
  double get _capPct    => data.capacityPercent.clamp(0, 100);

  String get _subLine {
    final p = <String>[];
    if ((data.riverName ?? '').isNotEmpty) p.add(data.riverName ?? '');
    if (data.district.isNotEmpty)          p.add(data.district);
    if (data.state.isNotEmpty)             p.add(data.state);
    return p.join('  ·  ');
  }

  IconData _iconFor(String r) => switch (r) {
    'critical' => Icons.warning_rounded,
    'high'     => Icons.error_outline_rounded,
    _          => Icons.water_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final wxAsync  = ref.watch(weatherProvider(data.stationName));
    final hasWx    = wxAsync.valueOrNull != null;
    final isExpanded = _expanded;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.pushNamed(
          context,
          RiverDetailScreen.route,
          arguments: data,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve:    Curves.easeInOut,
        margin:   const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color:        AppPalette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _severityColor.withValues(alpha: 0.25),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset:     const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Header row ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
              child: Row(
                children: [
                  // severity icon
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color:        _severityColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _iconFor(data.imdSeverity ?? 'normal'),
                      color: _severityColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // station name + sub-line
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.stationName,
                          style: const TextStyle(
                            color:      AppPalette.textPrimary,
                            fontSize:   13,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_subLine.isNotEmpty)
                          Text(
                            _subLine,
                            style: const TextStyle(
                              color:    AppPalette.textDim,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  // severity badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color:        _severityColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _severityLabel,
                      style: TextStyle(
                        color:      _severityColor,
                        fontSize:   10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  // expand toggle
                  IconButton(
                    icon: AnimatedRotation(
                      turns:    isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 280),
                      child: const Icon(Icons.expand_more_rounded, size: 20),
                    ),
                    color:   AppPalette.textDim,
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() => _expanded = !_expanded);
                    },
                  ),
                ],
              ),
            ),

            // ── Level bar ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: _LevelBar(
                levelPct:   _levelPct,
                capPct:     _capPct,
                color:      _severityColor,
                warning:    data.warningLevel,
                danger:     data.dangerLevel,
                rain:       data.imdRainfallMm ?? data.effectiveRainfallMm,
                river:      data.riverName,
              ),
            ),

            // ── Pill row (collapsed) ────────────────────────────────
            if (hasWx && !isExpanded)
              _WxSummaryPills(wx: wxAsync.valueOrNull!),
            if (!hasWx && !isExpanded)
              const SizedBox(height: 10),

            // ── Expanded weather detail ─────────────────────────────
            if (isExpanded) _WxDetailPanel(wx: wxAsync.valueOrNull),

            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Level bar
// ═══════════════════════════════════════════════════════════════════════════

class _LevelBar extends StatelessWidget {
  final double  levelPct;
  final double  capPct;
  final Color   color;
  final double  warning;
  final double  danger;
  final double  rain;
  final String? river;

  const _LevelBar({
    required this.levelPct,
    required this.capPct,
    required this.color,
    required this.warning,
    required this.danger,
    required this.rain,
    this.river,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // numeric info row
          _LevelInfoRow(
            warning: warning,
            danger:  danger,
            rain:    rain,
            river:   river,
          ),
          const SizedBox(height: 6),
          // level bar
          _ProgressBar(pct: levelPct / 100, color: color, label: 'Level'),
          const SizedBox(height: 4),
          // capacity bar
          _ProgressBar(
            pct:   capPct / 100,
            color: AppPalette.cyan,
            label: 'Capacity',
          ),
          const SizedBox(height: 8),
        ],
      );
}

class _ProgressBar extends StatelessWidget {
  final double pct;
  final Color  color;
  final String label;
  const _ProgressBar(
      {required this.pct, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            '$label ${(pct * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
                color: AppPalette.textDim, fontSize: 10),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value:            pct.clamp(0, 1),
              backgroundColor:  AppPalette.surface2,
              valueColor:       AlwaysStoppedAnimation(color),
              minHeight:        6,
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Level info row
// ═══════════════════════════════════════════════════════════════════════════

class _LevelInfoRow extends StatelessWidget {
  final double  warning;
  final double  danger;
  final double  rain;
  final String? river;
  const _LevelInfoRow({
    required this.warning,
    required this.danger,
    required this.rain,
    this.river,
  });

  Widget _mini(String t, Color c) => Text(
        t,
        style: TextStyle(
            color: c, fontSize: 10, fontWeight: FontWeight.w600),
      );

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _mini('W ${warning.toStringAsFixed(1)} m', AppPalette.amber),
          if (river != null && river!.isNotEmpty)
            Flexible(child: _mini(river ?? '', AppPalette.textDim)),
          _mini('D ${danger.toStringAsFixed(1)} m', AppPalette.danger),
          _mini('${rain.toStringAsFixed(1)} mm', AppPalette.cyan),
        ],
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// Weather summary pills (collapsed)
// ═══════════════════════════════════════════════════════════════════════════

class _WxSummaryPills extends StatelessWidget {
  final WeatherData wx;
  const _WxSummaryPills({required this.wx});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Row(
        children: [
          _Pill('${wx.tempC.toStringAsFixed(1)}°C',
              Icons.thermostat_rounded, AppPalette.amber),
          const SizedBox(width: 6),
          _Pill('${wx.humidity}%',
              Icons.water_drop_rounded, AppPalette.cyan),
          const SizedBox(width: 6),
          _Pill('${wx.windKph.toStringAsFixed(0)} km/h',
              Icons.air_rounded, AppPalette.textDim),
          const SizedBox(width: 6),
          _Pill('${wx.rainfall7dMm.toStringAsFixed(0)} mm',
              Icons.grain_rounded, AppPalette.cyan),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String   label;
  final IconData icon;
  final Color    color;
  const _Pill(this.label, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Weather detail panel (expanded)
// ═══════════════════════════════════════════════════════════════════════════

class _WxDetailPanel extends StatelessWidget {
  final WeatherData? wx;
  const _WxDetailPanel({this.wx});

  @override
  Widget build(BuildContext context) {
    if (wx == null) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(
          child: Text(
            'Weather data unavailable',
            style: TextStyle(color: AppPalette.textDim, fontSize: 12),
          ),
        ),
      );
    }
    final indexColor = wx!.rainfallIndex > 70
        ? AppPalette.danger
        : wx!.rainfallIndex > 45
            ? AppPalette.amber
            : AppPalette.cyan;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(color: AppPalette.surface2, height: 16),
          // ── Row 1: temp / feels-like / humidity ─────────────────
          Row(children: [
            Expanded(child: _WxDetailTile(
              icon: Icons.thermostat_rounded, label: 'Temperature',
              value: '${wx!.tempC.toStringAsFixed(1)}°C',
              color: AppPalette.amber,
            )),
            const SizedBox(width: 8),
            Expanded(child: _WxDetailTile(
              icon: Icons.device_thermostat_rounded, label: 'Feels Like',
              value: '${(wx!.current?.feelsLikeC ?? wx!.tempC).toStringAsFixed(1)}°C',
              color: AppPalette.amber,
            )),
            const SizedBox(width: 8),
            Expanded(child: _WxDetailTile(
              icon: Icons.water_drop_rounded, label: 'Humidity',
              value: '${wx!.humidity}%',
              color: const Color(0xFF64B5F6),
            )),
          ]),
          const SizedBox(height: 8),
          // ── Row 2: 7-day rain / rain index / precip prob ─────────
          Row(children: [
            Expanded(child: _WxDetailTile(
              icon: Icons.grain_rounded, label: '7-Day Rain',
              value: '${wx!.rainfall7dMm.toStringAsFixed(1)} mm',
              color: AppPalette.cyan,
            )),
            const SizedBox(width: 8),
            Expanded(child: _WxDetailTile(
              icon: Icons.analytics_rounded, label: 'Rain Index',
              value: '${wx!.rainfallIndex.toStringAsFixed(0)}/100',
              color: indexColor,
              isHighlight: wx!.rainfallIndex > 45,
            )),
            const SizedBox(width: 8),
            Expanded(child: _WxDetailTile(
              icon: Icons.umbrella_rounded, label: 'Precip Prob',
              value: '${wx!.maxPrecipProb.toStringAsFixed(0)}%',
              color: AppPalette.amber,
            )),
          ]),
          const SizedBox(height: 8),
          // ── Row 3: wind / UV / now-precip ───────────────────────
          Row(children: [
            Expanded(child: _WxDetailTile(
              icon: Icons.air_rounded, label: 'Wind',
              value: '${wx!.windKph.toStringAsFixed(0)} km/h',
              color: const Color(0xFF64B5F6),
            )),
            const SizedBox(width: 8),
            Expanded(child: _WxDetailTile(
              icon: Icons.wb_sunny_rounded, label: 'UV Index',
              value: (wx!.current?.uvIndex ?? 0).toStringAsFixed(1),
              color: AppPalette.amber,
            )),
            const SizedBox(width: 8),
            Expanded(child: _WxDetailTile(
              icon: Icons.water_rounded, label: 'Now Precip',
              value: '${wx!.precipMm.toStringAsFixed(1)} mm',
              color: AppPalette.cyan,
            )),
          ]),
          const SizedBox(height: 8),
          // ── Row 4: flood metrics ─────────────────────────────────
          Row(children: [
            Expanded(child: _WxDetailTile(
              icon: Icons.speed_rounded, label: 'Flow Rate',
              value: wx!.precipMm != 0
                  ? '${wx!.precipMm.toStringAsFixed(0)} m³/s'
                  : '—',
              color: AppPalette.cyan,
            )),
            const SizedBox(width: 8),
            Expanded(child: _WxDetailTile(
              icon: Icons.grain_rounded, label: 'IMD Rain',
              value: '${wx!.rainfallIndex.toStringAsFixed(1)} mm',
              color: AppPalette.cyan,
            )),
            const SizedBox(width: 8),
            const Expanded(child: SizedBox()),
          ]),
        ],
      ),
    );
  }
}

class _WxDetailTile extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Color    color;
  final bool     isHighlight;
  const _WxDetailTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isHighlight
            ? color.withValues(alpha: 0.15)
            : AppPalette.surface2.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: isHighlight
            ? Border.all(color: color.withValues(alpha: 0.4))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color:      color,
              fontSize:   12,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color:    AppPalette.textDim,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}
