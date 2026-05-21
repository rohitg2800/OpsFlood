import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants.dart';
import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
import '../services/real_time_service.dart';
import '../theme/river_theme.dart';
import '../widgets/flood_gauge.dart';
import '../widgets/river_level_visualizer.dart';

// ─────────────────────────────────────────────────────────
//  India River Explorer  – State → City → River drilldown
// ─────────────────────────────────────────────────────────

class IndiaRiverExplorerScreen extends StatefulWidget {
  const IndiaRiverExplorerScreen({super.key});

  @override
  State<IndiaRiverExplorerScreen> createState() =>
      _IndiaRiverExplorerScreenState();
}

class _IndiaRiverExplorerScreenState
    extends State<IndiaRiverExplorerScreen> {
  final RealTimeService _svc = RealTimeService();

  String _selectedState  = 'All India';
  String? _selectedCity;
  String _searchQuery    = '';
  String _riskFilter     = 'ALL';

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _svc.startPolling();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── helpers ────────────────────────────────────────────

  List<FloodData> get _filtered {
    final all = List<FloodData>.from(_svc.liveLevels);

    return all.where((d) {
      final stateMatch =
          _selectedState == 'All India' || d.state == _selectedState;
      final cityMatch =
          _selectedCity == null || d.city == _selectedCity;
      final riskMatch =
          _riskFilter == 'ALL' || d.riskLevel == _riskFilter;
      final q = _searchQuery.toLowerCase();
      final textMatch = q.isEmpty ||
          d.city.toLowerCase().contains(q) ||
          (d.riverName ?? '').toLowerCase().contains(q) ||
          d.state.toLowerCase().contains(q);
      return stateMatch && cityMatch && riskMatch && textMatch;
    }).toList()
      ..sort((a, b) => b.capacityPercent.compareTo(a.capacityPercent));
  }

  List<String> get _citiesForState {
    if (_selectedState == 'All India') return [];
    final cities = AppConstants.monitoredCities
        .where((m) => m['state'] == _selectedState)
        .map<String>((m) => m['city'] as String)
        .toSet()
        .toList();
    cities.sort();
    return cities;
  }

  Color _riskColor(String risk, BuildContext ctx) {
    final rc = RiverColors.of(ctx);
    switch (risk) {
      case 'CRITICAL': return rc.riverCritical;
      case 'HIGH':     return rc.riverDanger;
      case 'MODERATE': return rc.riverWarning;
      default:         return rc.riverNormal;
    }
  }

  // ── build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final rc  = RiverColors.of(context);
    final cs  = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: Text('India River Monitor',
            style: TextStyle(
              color: rc.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            )),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: rc.riverNormal),
            onPressed: _svc.refreshData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(rc, cs),
          Expanded(
            child: AnimatedBuilder(
              animation: _svc,
              builder: (_, __) {
                final rows = _filtered;
                if (rows.isEmpty) {
                  return Center(
                    child: Text('No rivers match the current filter.',
                        style: TextStyle(color: rc.textSecondary)),
                  );
                }
                return RefreshIndicator(
                  onRefresh: _svc.refreshData,
                  child: ListView.builder(
                    padding:
                        const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    itemCount: rows.length,
                    itemBuilder: (ctx, i) =>
                        _RiverCard(data: rows[i], svc: _svc),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(RiverColors rc, ColorScheme cs) {
    return Container(
      color: cs.surface,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _searchQuery = v),
            style: TextStyle(color: rc.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search city, river, state…',
              hintStyle: TextStyle(color: rc.textSecondary),
              prefixIcon:
                  Icon(Icons.search, color: rc.riverNormal),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: rc.textSecondary),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      })
                  : null,
              filled: true,
              fillColor: rc.cardBg,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // State dropdown + city dropdown in a row
          Row(
            children: [
              Expanded(
                child: _Dropdown(
                  value: _selectedState,
                  items: AppConstants.indianStates,
                  hint: 'State',
                  rc: rc,
                  cs: cs,
                  onChanged: (v) => setState(() {
                    _selectedState = v ?? 'All India';
                    _selectedCity  = null;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              if (_citiesForState.isNotEmpty)
                Expanded(
                  child: _Dropdown(
                    value: _selectedCity,
                    items: ['All Cities', ..._citiesForState],
                    hint: 'City',
                    rc: rc,
                    cs: cs,
                    onChanged: (v) => setState(() {
                      _selectedCity = (v == null || v == 'All Cities')
                          ? null
                          : v;
                    }),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Risk level chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final lvl in ['ALL', 'LOW', 'MODERATE', 'HIGH', 'CRITICAL'])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(lvl,
                          style: TextStyle(
                            fontSize: 11,
                            color: _riskFilter == lvl
                                ? Colors.white
                                : rc.textSecondary,
                          )),
                      selected: _riskFilter == lvl,
                      selectedColor: lvl == 'ALL'
                          ? rc.riverNormal
                          : _riskColor(lvl, context),
                      backgroundColor: rc.chipBg,
                      onSelected: (_) =>
                          setState(() => _riskFilter = lvl),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── River card ───────────────────────────────────────────

class _RiverCard extends StatelessWidget {
  const _RiverCard({required this.data, required this.svc});
  final FloodData data;
  final RealTimeService svc;

  @override
  Widget build(BuildContext context) {
    final rc      = RiverColors.of(context);
    final history = svc.trendForCity(data.city);
    final mon     = RiverMonitoring.fromFloodData(data, history);
    final danger  = mon.isDangerZone;

    Color statusColor;
    switch (data.riskLevel) {
      case 'CRITICAL': statusColor = rc.riverCritical; break;
      case 'HIGH':     statusColor = rc.riverDanger;   break;
      case 'MODERATE': statusColor = rc.riverWarning;  break;
      default:         statusColor = rc.riverNormal;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: rc.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: danger
              ? rc.riverDanger.withOpacity(0.7)
              : statusColor.withOpacity(0.28),
          width: danger ? 1.6 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                // Status dot
                Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.city,
                        style: TextStyle(
                          color: rc.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '${data.riverName ?? 'River'} · ${data.state}',
                        style: TextStyle(
                          color: rc.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    data.riskLevel,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Level visualiser + gauge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: RiverLevelVisualizer(
                    city: data.city,
                    river: data.riverName ?? 'River',
                    currentLevel: data.currentLevel,
                    safeLevel: data.safeLevel,
                    warningLevel: data.warningLevel,
                    dangerLevel: data.dangerLevel,
                    trend: data.status,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 100,
                  child: FloodGauge(
                    capacity: data.capacityPercent,
                    riskLevel: data.riskLevel,
                    size: 100,
                    label: '${data.capacityPercent.toStringAsFixed(0)}%',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Chips
            Wrap(
              spacing: 6, runSpacing: 6,
              children: [
                _Chip(icon: Icons.warning_amber_rounded,
                    text: 'Danger: ${data.dangerLevel.toStringAsFixed(1)} m',
                    color: rc.riverDanger),
                _Chip(icon: Icons.timeline,
                    text: 'Warning: ${data.warningLevel.toStringAsFixed(1)} m',
                    color: rc.riverWarning),
                if (data.expectedPeakLevel != null)
                  _Chip(icon: Icons.show_chart,
                      text:
                          'Peak: ${data.expectedPeakLevel!.toStringAsFixed(1)} m',
                      color: rc.riverNormal),
              ],
            ),
            const SizedBox(height: 10),
            // Sparkline
            SizedBox(
              height: 62,
              child: _Sparkline(
                history: history,
                warningLevel: data.warningLevel,
                dangerLevel: data.dangerLevel,
                lineColor: rc.sparklineColor,
              ),
            ),
            // Last update
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (danger)
                    Row(
                      children: [
                        Icon(Icons.notification_important,
                            color: rc.riverDanger, size: 14),
                        const SizedBox(width: 4),
                        Text('Critical threshold breached',
                            style: TextStyle(
                              color: rc.riverDanger,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            )),
                      ],
                    )
                  else
                    const SizedBox.shrink(),
                  if (svc.lastFetchTime != null)
                    Text(
                      'Updated ${DateFormat('HH:mm').format(svc.lastFetchTime!.toLocal())}',
                      style: TextStyle(
                          color: rc.textSecondary, fontSize: 10),
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

// ── Chip label ──────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.text,
    required this.color,
  });
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final rc = RiverColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: rc.chipBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(color: rc.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

// ── Sparkline ────────────────────────────────────────────

class _Sparkline extends StatelessWidget {
  const _Sparkline({
    required this.history,
    required this.warningLevel,
    required this.dangerLevel,
    required this.lineColor,
  });
  final List<RiverLevelSnapshot> history;
  final double warningLevel;
  final double dangerLevel;
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    final pts = List<RiverLevelSnapshot>.from(history)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (pts.length < 2) {
      return Center(
        child: Text('Chart builds after more live points',
            style: TextStyle(
                color: RiverColors.of(context).textSecondary,
                fontSize: 11)),
      );
    }

    final clipped =
        pts.length > 24 ? pts.sublist(pts.length - 24) : pts;
    final spots = List.generate(
        clipped.length,
        (i) => FlSpot(i.toDouble(), clipped[i].level));

    return LineChart(
      LineChartData(
        minY: 0,
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(
          show: true,
          border: Border.all(
              color: lineColor.withOpacity(0.15)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            barWidth: 2,
            color: lineColor,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: lineColor.withOpacity(0.18),
            ),
          ),
        ],
        extraLinesData: ExtraLinesData(horizontalLines: [
          HorizontalLine(
            y: warningLevel,
            color: const Color(0xFFF59E0B),
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
          HorizontalLine(
            y: dangerLevel,
            color: const Color(0xFFEF4444),
            strokeWidth: 1.1,
            dashArray: [5, 4],
          ),
        ]),
      ),
    );
  }
}

// ── Dropdown helper ──────────────────────────────────────

class _Dropdown extends StatelessWidget {
  const _Dropdown({
    required this.value,
    required this.items,
    required this.hint,
    required this.rc,
    required this.cs,
    required this.onChanged,
  });
  final String? value;
  final List<String> items;
  final String hint;
  final RiverColors rc;
  final ColorScheme cs;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: rc.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: rc.riverNormal.withOpacity(0.25)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : null,
          hint: Text(hint,
              style: TextStyle(
                  color: rc.textSecondary, fontSize: 13)),
          isExpanded: true,
          dropdownColor: rc.cardBg,
          iconEnabledColor: rc.riverNormal,
          style: TextStyle(color: rc.textPrimary, fontSize: 13),
          items: items
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
