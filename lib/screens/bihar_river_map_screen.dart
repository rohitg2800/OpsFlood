// lib/screens/bihar_river_map_screen.dart
//
// OpsFlood — Bihar River Map Screen
//
// Shows all 31 WRD Bihar gauge stations grouped by river basin.
// Data sourced exclusively from WrdBiharService (irrigation.befiqr.in).
//
// UI DESIGN:
//   ─ River basin tabs (horizontal scroll)
//   ─ Station cards with live gauge bar (safety %, current vs danger)
//   ─ Color coding: GREEN=safe, YELLOW=watch, ORANGE=high, RED=critical
//   ─ NA stations shown dimmed with “Pre-monsoon / No reading” chip
//   ─ Summary header: total live / at-risk / na counts
//   ─ Pull-to-refresh triggers WrdBiharService.fetch(forceRefresh: true)
library;

import 'package:flutter/material.dart';
import '../services/wrd_bihar_service.dart';

// River display order (by hydrological importance in Bihar)
const _kRiverOrder = [
  'Ganga', 'Kosi', 'Gandak', 'Bagmati',
  'Burhi Gandak', 'Ghaghra', 'Mahananda',
  'Kamla', 'Kamalabalan', 'Adhwara', 'Punpun',
];

// River accent colors
const _kRiverColors = <String, Color>{
  'Ganga':       Color(0xFF0097A7),   // teal
  'Kosi':        Color(0xFFE53935),   // red (historically flood-prone)
  'Gandak':      Color(0xFF43A047),   // green
  'Bagmati':     Color(0xFF8E24AA),   // purple
  'Burhi Gandak':Color(0xFF00ACC1),   // cyan
  'Ghaghra':     Color(0xFFFF7043),   // deep orange
  'Mahananda':   Color(0xFF039BE5),   // blue
  'Kamla':       Color(0xFFD81B60),   // pink
  'Kamalabalan': Color(0xFFAD1457),   // dark pink
  'Adhwara':     Color(0xFF6D4C41),   // brown
  'Punpun':      Color(0xFF558B2F),   // light green
};

class BiharRiverMapScreen extends StatefulWidget {
  const BiharRiverMapScreen({super.key});

  @override
  State<BiharRiverMapScreen> createState() => _BiharRiverMapScreenState();
}

class _BiharRiverMapScreenState extends State<BiharRiverMapScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, List<WrdStation>> _grouped = {};
  bool _loading = true;
  String? _error;
  DateTime? _fetchedAt;
  int _selectedRiverIdx = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _kRiverOrder.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _selectedRiverIdx = _tabController.index);
      }
    });
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    setState(() {
      _loading = true;
      _error   = null;
    });
    try {
      final grouped = await WrdBiharService.instance
          .fetchGroupedByRiver();
      setState(() {
        _grouped   = grouped;
        _loading   = false;
        _fetchedAt = DateTime.now();
      });
    } catch (e) {
      setState(() {
        _error   = e.toString();
        _loading = false;
      });
    }
  }

  // ── Summary stats ────────────────────────────────────────────────────────────
  int get _totalStations => _grouped.values.fold(0, (s, v) => s + v.length);
  int get _liveCount     => _grouped.values
      .expand((v) => v).where((s) => s.hasLiveData).length;
  int get _atRiskCount   => _grouped.values
      .expand((v) => v)
      .where((s) => s.hasLiveData &&
          (s.riskLabel == 'HIGH' || s.riskLabel == 'CRITICAL')).length;
  int get _naCount       => _totalStations - _liveCount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bihar River Monitor',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'WRD Bihar — Central Flood Control Cell',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
        actions: [
          if (_fetchedAt != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text(
                  _timeAgo(_fetchedAt!),
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
            ),
          IconButton(
            icon: _loading
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.tealAccent,
                    ),
                  )
                : const Icon(Icons.refresh, color: Colors.tealAccent),
            onPressed: _loading ? null : () => _load(force: true),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: Colors.tealAccent,
          labelColor: Colors.tealAccent,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: _kRiverOrder.map((r) {
            final stations  = _grouped[r] ?? [];
            final liveCount = stations.where((s) => s.hasLiveData).length;
            final color     = _kRiverColors[r] ?? Colors.tealAccent;
            return Tab(
              child: Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(r),
                  if (stations.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: liveCount > 0
                            ? Colors.tealAccent.withOpacity(0.2)
                            : Colors.white12,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$liveCount/${stations.length}',
                        style: TextStyle(
                          fontSize: 10,
                          color: liveCount > 0 ? Colors.tealAccent : Colors.white38,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: Column(
        children: [
          _buildSummaryBar(),
          Expanded(
            child: _loading && _grouped.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.tealAccent),
                  )
                : _error != null && _grouped.isEmpty
                    ? _buildError()
                    : TabBarView(
                        controller: _tabController,
                        children: _kRiverOrder
                            .map((r) => _buildRiverTab(r))
                            .toList(),
                      ),
          ),
        ],
      ),
    );
  }

  // ── Summary bar ──────────────────────────────────────────────────────────────

  Widget _buildSummaryBar() {
    return Container(
      color: const Color(0xFF0D1B2A),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _summaryPill(
            icon: Icons.sensors,
            label: '$_liveCount Live',
            color: Colors.tealAccent,
          ),
          const SizedBox(width: 8),
          _summaryPill(
            icon: Icons.warning_amber_rounded,
            label: '$_atRiskCount At risk',
            color: _atRiskCount > 0 ? Colors.orangeAccent : Colors.white38,
          ),
          const SizedBox(width: 8),
          _summaryPill(
            icon: Icons.hourglass_empty,
            label: '$_naCount Pre-monsoon',
            color: Colors.white38,
          ),
          const Spacer(),
          Text(
            '$_totalStations stations',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _summaryPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11,
              fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ── River tab content ────────────────────────────────────────────────────────────

  Widget _buildRiverTab(String river) {
    final stations = _grouped[river] ?? [];
    final color    = _kRiverColors[river] ?? Colors.tealAccent;

    if (stations.isEmpty) {
      return Center(
        child: Text('No data for $river',
            style: const TextStyle(color: Colors.white38)),
      );
    }

    return RefreshIndicator(
      color: Colors.tealAccent,
      backgroundColor: const Color(0xFF0D1B2A),
      onRefresh: () => _load(force: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          _buildRiverHeader(river, stations, color),
          const SizedBox(height: 12),
          ...stations.map((s) => _buildStationCard(s, color)),
        ],
      ),
    );
  }

  Widget _buildRiverHeader(
      String river, List<WrdStation> stations, Color color) {
    final live    = stations.where((s) => s.hasLiveData).length;
    final atRisk  = stations.where((s) =>
        s.hasLiveData &&
        (s.riskLabel == 'HIGH' || s.riskLabel == 'CRITICAL')).length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 4, height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(river,
                    style: TextStyle(
                        color: color,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  '$live/${stations.length} live gauges'
                  '${atRisk > 0 ? ' · $atRisk at risk' : ''}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          if (atRisk > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.5)),
              ),
              child: Text(
                '⚠ $atRisk at risk',
                style: const TextStyle(
                    color: Colors.orange, fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStationCard(WrdStation station, Color riverColor) {
    final live       = station.hasLiveData;
    final cur        = station.currentLevel;
    final danger     = station.dangerLevel;
    final belowD     = station.belowDanger;
    final pct        = station.percentOfDanger;
    final risk       = station.riskLabel;
    final gaugeColor = live ? _riskColor(risk) : Colors.white24;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: live
              ? _riskColor(risk).withOpacity(0.4)
              : Colors.white12,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            station.site,
                            style: TextStyle(
                              color: live ? Colors.white : Colors.white54,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (live)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.tealAccent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'LIVE',
                                style: TextStyle(
                                    color: Colors.tealAccent,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'PRE-MONSOON',
                                style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 9,
                                    letterSpacing: 0.5),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        station.district.isNotEmpty
                            ? station.district
                            : station.river,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                // Current level display
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      live ? '${cur!.toStringAsFixed(2)} m' : '——',
                      style: TextStyle(
                        color: live ? gaugeColor : Colors.white24,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (live && pct != null)
                      Text(
                        '${pct.toStringAsFixed(0)}% of DL',
                        style: TextStyle(
                          color: gaugeColor.withOpacity(0.8),
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ],
            ),

            // ── Gauge bar (only when live)
            if (live && danger != null && danger > 0) ...[
              const SizedBox(height: 12),
              _buildGaugeBar(cur!, danger, station.warningLevel, gaugeColor),
              const SizedBox(height: 8),
              // Threshold row
              Row(
                children: [
                  _thresholdChip(
                    label: 'W ${station.warningLevel?.toStringAsFixed(1) ?? "-"}m',
                    color: Colors.amber,
                  ),
                  const SizedBox(width: 8),
                  _thresholdChip(
                    label: 'D ${danger.toStringAsFixed(1)}m',
                    color: Colors.deepOrange,
                  ),
                  const Spacer(),
                  if (belowD != null)
                    Text(
                      belowD >= 0
                          ? '${belowD.toStringAsFixed(2)}m below danger'
                          : '${belowD.abs().toStringAsFixed(2)}m ABOVE danger',
                      style: TextStyle(
                        color: belowD <= 0
                            ? Colors.redAccent
                            : belowD <= 1.0
                                ? Colors.orange
                                : Colors.white38,
                        fontSize: 10,
                        fontWeight: belowD <= 0
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                ],
              ),
            ],

            // ── NA explanation
            if (!live) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 13, color: Colors.white24),
                  const SizedBox(width: 4),
                  Text(
                    'No gauge reading — typical before monsoon (June+)',
                    style: const TextStyle(
                        color: Colors.white24, fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _thresholdChip(
                    label: 'D ${danger?.toStringAsFixed(1) ?? "-"}m',
                    color: Colors.white24,
                  ),
                  const SizedBox(width: 8),
                  _thresholdChip(
                    label: 'HFL ${station.hfl?.toStringAsFixed(1) ?? "-"}m',
                    color: Colors.white12,
                  ),
                ],
              ),
            ],

            // ── Trend + HFL row
            if (live && station.trend != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    station.trend!.toLowerCase().contains('ris')
                        ? Icons.trending_up
                        : station.trend!.toLowerCase().contains('fal')
                            ? Icons.trending_down
                            : Icons.trending_flat,
                    size: 14,
                    color: station.trend!.toLowerCase().contains('ris')
                        ? Colors.orangeAccent
                        : Colors.tealAccent,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    station.trend!,
                    style: TextStyle(
                      color: station.trend!.toLowerCase().contains('ris')
                          ? Colors.orangeAccent
                          : Colors.tealAccent,
                      fontSize: 11,
                    ),
                  ),
                  if (station.diff24h != null && station.diff24h != 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      '${station.diff24h! >= 0 ? "+" : ""}${station.diff24h!.toStringAsFixed(2)}m/24h',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 10),
                    ),
                  ],
                  const Spacer(),
                  if (station.hfl != null)
                    Text(
                      'HFL ${station.hfl!.toStringAsFixed(2)}m',
                      style: const TextStyle(
                          color: Colors.white24, fontSize: 10),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Gauge bar ──────────────────────────────────────────────────────────────────

  Widget _buildGaugeBar(
      double current, double danger, double? warning, Color color) {
    final pct         = (current / danger).clamp(0.0, 1.2);
    final warningPct  = warning != null ? (warning / danger).clamp(0.0, 1.0) : null;
    final dangerFrac  = (1.0 / 1.2);  // danger line at 83.3% of visual bar

    return Stack(
      children: [
        // Track
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        // Fill
        FractionallySizedBox(
          widthFactor: pct / 1.2,
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        // Warning marker
        if (warningPct != null)
          FractionallySizedBox(
            widthFactor: warningPct / 1.2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: 2, height: 8, color: Colors.amber,
              ),
            ),
          ),
        // Danger marker
        FractionallySizedBox(
          widthFactor: dangerFrac,
          child: Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 2, height: 12,
              color: Colors.redAccent,
              margin: const EdgeInsets.only(top: -2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _thresholdChip({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off, color: Colors.white24, size: 48),
          const SizedBox(height: 12),
          const Text('Could not reach WRD Bihar portal',
              style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _load(force: true),
            child: const Text('Retry',
                style: TextStyle(color: Colors.tealAccent)),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────────

  Color _riskColor(String risk) {
    switch (risk) {
      case 'CRITICAL': return Colors.red;
      case 'HIGH':     return Colors.orange;
      case 'MODERATE': return Colors.amber;
      case 'LOW':      return Colors.tealAccent;
      default:         return Colors.white38;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}
