// lib/screens/comparison_screen.dart
// OpsFlood — Module 11: Multi-station River Level Comparison Tool
//
// Features:
//  • Select up to 4 stations from a searchable list
//  • Overlay line chart showing level vs time for all selected stations
//  • Summary table: current level, danger %, trend arrow
//  • Danger threshold reference line on chart
//  • Export comparison as PDF (delegates to ExportService)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

// ---------------------------------------------------------------------------
// Stub models (replace with real imports from lib/models)
// ---------------------------------------------------------------------------

class CompStation {
  final String id;
  final String name;
  final String river;
  final double currentLevel;
  final double dangerLevel;
  final double warningLevel;
  final List<_LevelPoint> history; // last 24 h, hourly
  const CompStation({
    required this.id,
    required this.name,
    required this.river,
    required this.currentLevel,
    required this.dangerLevel,
    required this.warningLevel,
    required this.history,
  });

  double get dangerPct => (currentLevel / dangerLevel).clamp(0.0, 1.5);
  String get trendLabel {
    if (history.length < 2) return '=';
    final delta = history.last.level - history[history.length - 2].level;
    if (delta > 0.05) return '↑';
    if (delta < -0.05) return '↓';
    return '=';
  }
}

class _LevelPoint {
  final double x; // hour offset 0–23
  final double level;
  const _LevelPoint(this.x, this.level);
}

// ---------------------------------------------------------------------------
// Demo data (swap for Riverpod providers in production)
// ---------------------------------------------------------------------------

final _demoStations = [
  CompStation(
    id: 'GG001', name: 'Gandhi Ghat', river: 'Ganga',
    currentLevel: 51.2, dangerLevel: 55.0, warningLevel: 48.0,
    history: List.generate(24, (i) => _LevelPoint(i.toDouble(), 49.0 + i * 0.09)),
  ),
  CompStation(
    id: 'HB001', name: 'Harding Bridge', river: 'Ganga',
    currentLevel: 62.4, dangerLevel: 58.0, warningLevel: 54.0,
    history: List.generate(24, (i) => _LevelPoint(i.toDouble(), 58.0 + i * 0.18)),
  ),
  CompStation(
    id: 'KB001', name: 'Kosi Barrage', river: 'Kosi',
    currentLevel: 38.1, dangerLevel: 42.0, warningLevel: 38.5,
    history: List.generate(24, (i) => _LevelPoint(i.toDouble(), 36.0 + i * 0.088)),
  ),
  CompStation(
    id: 'BS001', name: 'Bagmati Sonepur', river: 'Bagmati',
    currentLevel: 44.9, dangerLevel: 48.0, warningLevel: 44.0,
    history: List.generate(24, (i) => _LevelPoint(i.toDouble(), 43.0 + i * 0.079)),
  ),
  CompStation(
    id: 'GP001', name: 'Gopalganj', river: 'Gandak',
    currentLevel: 29.5, dangerLevel: 33.0, warningLevel: 29.0,
    history: List.generate(24, (i) => _LevelPoint(i.toDouble(), 27.0 + i * 0.104)),
  ),
];

const _chartColors = [
  Color(0xFF4FC3F7),
  Color(0xFFFF6D00),
  Color(0xFF69F0AE),
  Color(0xFFFF4081),
];

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ComparisonScreen extends ConsumerStatefulWidget {
  const ComparisonScreen({super.key});

  @override
  ConsumerState<ComparisonScreen> createState() =>
      _ComparisonScreenState();
}

class _ComparisonScreenState
    extends ConsumerState<ComparisonScreen> {
  final _selected   = <CompStation>[];
  final _searchCtrl = TextEditingController();
  String _query     = '';

  List<CompStation> get _filtered => _demoStations
      .where((s) =>
          s.name.toLowerCase().contains(_query.toLowerCase()) ||
          s.river.toLowerCase().contains(_query.toLowerCase()))
      .toList();

  void _toggle(CompStation s) {
    setState(() {
      if (_selected.any((x) => x.id == s.id)) {
        _selected.removeWhere((x) => x.id == s.id);
      } else if (_selected.length < 4) {
        _selected.add(s);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 4 stations')),
        );
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Station Comparison'),
        actions: [
          if (_selected.isNotEmpty)
            IconButton(
              tooltip: 'Clear all',
              icon: const Icon(Icons.clear_all),
              onPressed: () => setState(_selected.clear),
            ),
        ],
      ),
      body: Column(
        children: [
          // ─ Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search station or river…',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),

          // ─ Station selector chips
          SizedBox(
            height: 54,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              children: _filtered.map((s) {
                final picked =
                    _selected.any((x) => x.id == s.id);
                final idx    = _selected.indexWhere((x) => x.id == s.id);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(s.name),
                    selected: picked,
                    selectedColor: picked
                        ? _chartColors[idx % 4].withOpacity(.3)
                        : null,
                    checkmarkColor:
                        picked ? _chartColors[idx % 4] : null,
                    onSelected: (_) => _toggle(s),
                  ),
                );
              }).toList(),
            ),
          ),

          if (_selected.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.compare_arrows,
                        size: 64,
                        color: theme.colorScheme.outline),
                    const SizedBox(height: 12),
                    Text('Select stations above to compare',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.outline)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Overlay chart
                    _buildChart(),
                    const SizedBox(height: 16),
                    // ── Summary table
                    _buildSummaryTable(theme),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Chart
  // ---------------------------------------------------------------------------

  Widget _buildChart() {
    final allLevels = _selected
        .expand((s) => s.history.map((p) => p.level))
        .toList();
    final minY = (allLevels.reduce((a, b) => a < b ? a : b) - 2)
        .floorToDouble();
    final maxY = (allLevels.reduce((a, b) => a > b ? a : b) + 2)
        .ceilToDouble();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 8),
              child: Text('24-hour Level Overlay',
                  style: Theme.of(context).textTheme.titleSmall),
            ),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minY: minY,
                  maxY: maxY,
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 6,
                        getTitlesWidget: (v, _) => Text(
                          '${v.toInt()}h',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (v, _) => Text(
                          v.toStringAsFixed(0),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    // danger reference
                    ..._selected.asMap().entries.map((e) {
                      final color = _chartColors[e.key % 4];
                      return LineChartBarData(
                        spots: e.value.history
                            .map((p) => FlSpot(p.x, p.level))
                            .toList(),
                        isCurved:      true,
                        color:         color,
                        barWidth:      2.5,
                        dotData: const FlDotData(show: false),
                      );
                    }),
                  ],
                  extraLinesData: ExtraLinesData(
                    horizontalLines: _selected
                        .asMap()
                        .entries
                        .map((e) => HorizontalLine(
                              y:         e.value.dangerLevel,
                              color:     _chartColors[e.key % 4]
                                  .withOpacity(.4),
                              strokeWidth: 1,
                              dashArray: [4, 4],
                            ))
                        .toList(),
                  ),
                ),
              ),
            ),
            // Legend
            Wrap(
              spacing: 12,
              children: _selected.asMap().entries.map((e) {
                final color = _chartColors[e.key % 4];
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        width: 12, height: 12,
                        color: color),
                    const SizedBox(width: 4),
                    Text(e.value.name,
                        style:
                            const TextStyle(fontSize: 11)),
                  ],
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Summary table
  // ---------------------------------------------------------------------------

  Widget _buildSummaryTable(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current Status',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(2),
                3: FlexColumnWidth(1),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(
                      color: theme.dividerColor))),
                  children: [
                    _th('Station'),
                    _th('Level (m)'),
                    _th('% of Danger'),
                    _th('Trend'),
                  ],
                ),
                ..._selected.asMap().entries.map((e) {
                  final s     = e.value;
                  final color = _chartColors[e.key % 4];
                  final pct   = (s.dangerPct * 100).toStringAsFixed(0);
                  final over  = s.dangerPct >= 1.0;
                  return TableRow(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 6),
                      child: Row(
                        children: [
                          Container(
                              width: 10, height: 10,
                              color: color),
                          const SizedBox(width: 6),
                          Flexible(
                              child: Text(s.name,
                                  style: const TextStyle(
                                      fontSize: 12))),
                        ],
                      ),
                    ),
                    _td(s.currentLevel.toStringAsFixed(2)),
                    _td(
                      '$pct%',
                      color: over
                          ? const Color(0xFFFF1744)
                          : const Color(0xFF4CAF50),
                    ),
                    _td(s.trendLabel),
                  ]);
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _th(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold)),
      );

  Widget _td(String text, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(text,
            style: TextStyle(
                fontSize: 12, color: color)),
      );
}
