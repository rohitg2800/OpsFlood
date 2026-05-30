// lib/screens/live_stations_screen.dart
//
// OpsFlood — Live Stations Screen
//
// Displays all stations tracked by LiveFetchEngine in a searchable,
// filterable card list. Data is read directly from the singleton’s
// `liveLevels` (List<FloodData>) — no extra API calls.
//
// Each card shows:
//   ─ Station name + state/river
//   ─ Risk badge (CRITICAL / HIGH / MODERATE / LOW)
//   ─ Gauge level vs danger (when available from WRD Bihar)
//   ─ GloFAS discharge (m³/s)
//   ─ 24 h rainfall
//   ─ Data source badge (Live / Partial / Pre-monsoon)
library;

import 'package:flutter/material.dart';
import '../models/flood_data.dart';
import '../services/live_fetch_engine.dart';

class LiveStationsScreen extends StatefulWidget {
  const LiveStationsScreen({super.key});

  @override
  State<LiveStationsScreen> createState() => _LiveStationsScreenState();
}

class _LiveStationsScreenState extends State<LiveStationsScreen> {
  final LiveFetchEngine _engine = LiveFetchEngine();

  String _filter   = 'ALL';   // ALL / CRITICAL / HIGH / MODERATE / LOW
  String _query    = '';
  bool   _loading  = false;

  static const _kFilters = ['ALL', 'CRITICAL', 'HIGH', 'MODERATE', 'LOW'];

  @override
  void initState() {
    super.initState();
    _engine.onStateChanged = _onEngineUpdate;
    _loading = _engine.liveLevels.isEmpty;
    if (_loading) _engine.refreshData();
  }

  @override
  void dispose() {
    // Only clear if we set it (guard against other screens sharing the callback)
    if (_engine.onStateChanged == _onEngineUpdate) {
      _engine.onStateChanged = null;
    }
    super.dispose();
  }

  void _onEngineUpdate() {
    if (mounted) setState(() => _loading = _engine.isLoading && _engine.liveLevels.isEmpty);
  }

  List<FloodData> get _filtered {
    var list = _engine.liveLevels;
    if (_filter != 'ALL') {
      list = list.where((s) => s.riskLevel == _filter).toList();
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((s) =>
          s.city.toLowerCase().contains(q) ||
          s.riverName.toLowerCase().contains(q) ||
          s.state.toLowerCase().contains(q)).toList();
    }
    // Sort: CRITICAL first, then HIGH, MODERATE, LOW
    const order = {'CRITICAL': 0, 'HIGH': 1, 'MODERATE': 2, 'LOW': 3};
    list.sort((a, b) =>
        (order[a.riskLevel] ?? 4).compareTo(order[b.riskLevel] ?? 4));
    return list;
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final stations = _filtered;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        elevation: 0,
        titleSpacing: 0,
        title: _buildSearchBar(),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: _engine.isLoading
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.tealAccent,
                    ),
                  )
                : const Icon(Icons.refresh, color: Colors.tealAccent),
            onPressed: _engine.isLoading
                ? null
                : () async {
                    setState(() => _loading = true);
                    await _engine.refreshData();
                    if (mounted) setState(() => _loading = false);
                  },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _buildFilterChips(),
        ),
      ),
      body: Column(
        children: [
          _buildSummaryBar(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.tealAccent))
                : stations.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        color: Colors.tealAccent,
                        backgroundColor: const Color(0xFF0D1B2A),
                        onRefresh: () => _engine.refreshData(),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                          itemCount: stations.length,
                          itemBuilder: (_, i) => _StationCard(
                            data: stations[i],
                            index: i,
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // ── Search bar ───────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: SizedBox(
        height: 36,
        child: TextField(
          style: const TextStyle(color: Colors.white, fontSize: 14),
          cursorColor: Colors.tealAccent,
          decoration: InputDecoration(
            hintText: 'Search station, river, state…',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
            prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
            filled: true,
            fillColor: Colors.white10,
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (v) => setState(() => _query = v.trim()),
        ),
      ),
    );
  }

  // ── Filter chips ─────────────────────────────────────────────────────────────

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: _kFilters.map((f) {
          final selected = _filter == f;
          final color    = _filterColor(f);
          final count    = f == 'ALL'
              ? _engine.liveLevels.length
              : _engine.liveLevels.where((s) => s.riskLevel == f).length;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filter = f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? color.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? color : Colors.white24,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      f,
                      style: TextStyle(
                        color: selected ? color : Colors.white54,
                        fontSize: 11,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: selected ? color.withOpacity(0.25) : Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          color: selected ? color : Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Summary bar ──────────────────────────────────────────────────────────────

  Widget _buildSummaryBar() {
    final all      = _engine.liveLevels;
    final critical = all.where((s) => s.riskLevel == 'CRITICAL').length;
    final high     = all.where((s) => s.riskLevel == 'HIGH').length;
    final withFlow = all.where((s) => (s.flowRate ?? 0) > 0).length;
    final withLevel= all.where((s) => s.currentLevel > 0).length;

    return Container(
      color: const Color(0xFF0D1B2A),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _pill('${all.length}', 'Stations', Colors.tealAccent),
          const SizedBox(width: 8),
          if (critical > 0) ...[
            _pill('$critical', 'Critical', Colors.red),
            const SizedBox(width: 8),
          ],
          if (high > 0) ...[
            _pill('$high', 'High', Colors.orange),
            const SizedBox(width: 8),
          ],
          const Spacer(),
          Text(
            '$withLevel level · $withFlow flow',
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _pill(String count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(count,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(color: color.withOpacity(0.8), fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.water_drop_outlined, color: Colors.white24, size: 48),
          const SizedBox(height: 12),
          Text(
            _query.isNotEmpty || _filter != 'ALL'
                ? 'No stations match your filter'
                : 'No station data yet',
            style: const TextStyle(color: Colors.white38),
          ),
        ],
      ),
    );
  }

  Color _filterColor(String f) {
    switch (f) {
      case 'CRITICAL': return Colors.red;
      case 'HIGH':     return Colors.orange;
      case 'MODERATE': return Colors.amber;
      case 'LOW':      return Colors.tealAccent;
      default:         return Colors.white54;
    }
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Station Card
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _StationCard extends StatelessWidget {
  final FloodData data;
  final int       index;

  const _StationCard({required this.data, required this.index});

  @override
  Widget build(BuildContext context) {
    final risk     = data.riskLevel;
    final color    = _riskColor(risk);
    final hasLevel = data.currentLevel > 0;
    final hasDanger= data.dangerLevel > 0;
    final hasFlow  = (data.flowRate ?? 0) > 0;
    final pct      = (hasLevel && hasDanger)
        ? (data.currentLevel / data.dangerLevel).clamp(0.0, 1.2)
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row 1: name + risk badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Index circle
                Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withOpacity(0.4)),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                          color: color, fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.city,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${data.riverName} · ${data.state}',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                // Risk badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withOpacity(0.5)),
                  ),
                  child: Text(
                    risk,
                    style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Row 2: level / flow / rain metrics
            Row(
              children: [
                if (hasLevel) ...[
                  _metric(
                    icon: Icons.water,
                    label: 'Level',
                    value: '${data.currentLevel.toStringAsFixed(2)} m',
                    color: color,
                  ),
                  const SizedBox(width: 12),
                ],
                if (hasDanger) ...[
                  _metric(
                    icon: Icons.warning_amber_rounded,
                    label: 'Danger',
                    value: '${data.dangerLevel.toStringAsFixed(1)} m',
                    color: Colors.white38,
                  ),
                  const SizedBox(width: 12),
                ],
                if (hasFlow) ...[
                  _metric(
                    icon: Icons.water_drop_outlined,
                    label: 'Flow',
                    value: _formatFlow(data.flowRate!),
                    color: Colors.lightBlueAccent,
                  ),
                  const SizedBox(width: 12),
                ],
                if ((data.rainfall24h ?? 0) > 0)
                  _metric(
                    icon: Icons.grain,
                    label: 'Rain 24h',
                    value: '${data.rainfall24h!.toStringAsFixed(1)} mm',
                    color: Colors.cyanAccent,
                  ),
              ],
            ),

            // ── Row 3: gauge bar (only if level + danger available)
            if (pct != null) ...[
              const SizedBox(height: 10),
              _GaugeBar(
                fraction: pct / 1.2,
                color: color,
                dangerFrac: 1.0 / 1.2,
                warningFrac: data.warningLevel > 0
                    ? (data.warningLevel / data.dangerLevel).clamp(0.0, 1.0) / 1.2
                    : null,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '${(pct * 100).toStringAsFixed(0)}% of danger level',
                    style: TextStyle(color: color.withOpacity(0.8), fontSize: 10),
                  ),
                  const Spacer(),
                  if (data.currentLevel > data.dangerLevel)
                    Text(
                      '${(data.currentLevel - data.dangerLevel).toStringAsFixed(2)}m ABOVE danger',
                      style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    )
                  else if (hasDanger)
                    Text(
                      '${(data.dangerLevel - data.currentLevel).toStringAsFixed(2)}m below danger',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 10),
                    ),
                ],
              ),
            ],

            // ── Row 4: source chip + last updated
            const SizedBox(height: 8),
            Row(
              children: [
                _sourceChip(data.status),
                const Spacer(),
                Text(
                  _timeAgo(data.lastUpdated),
                  style: const TextStyle(color: Colors.white24, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: color.withOpacity(0.7)),
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(
                    color: color.withOpacity(0.6), fontSize: 9)),
          ],
        ),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _sourceChip(String status) {
    final live   = status.toLowerCase() == 'live';
    final color  = live ? Colors.tealAccent : Colors.white38;
    final label  = live ? '• LIVE' : status.toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.w600)),
    );
  }

  String _formatFlow(double q) {
    if (q >= 1000) return '${(q / 1000).toStringAsFixed(1)}k m³/s';
    return '${q.toStringAsFixed(0)} m³/s';
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  Color _riskColor(String risk) {
    switch (risk) {
      case 'CRITICAL': return Colors.red;
      case 'HIGH':     return Colors.orange;
      case 'MODERATE': return Colors.amber;
      case 'LOW':      return Colors.tealAccent;
      default:         return Colors.white38;
    }
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Reusable Gauge Bar
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _GaugeBar extends StatelessWidget {
  final double  fraction;    // fill width 0.0–1.0 (already normalized for 1.2x scale)
  final Color   color;
  final double  dangerFrac;  // where to draw the danger tick
  final double? warningFrac;

  const _GaugeBar({
    required this.fraction,
    required this.color,
    required this.dangerFrac,
    this.warningFrac,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        FractionallySizedBox(
          widthFactor: fraction.clamp(0.0, 1.0),
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        if (warningFrac != null)
          FractionallySizedBox(
            widthFactor: warningFrac!.clamp(0.0, 1.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(width: 2, height: 6, color: Colors.amber),
            ),
          ),
        FractionallySizedBox(
          widthFactor: dangerFrac.clamp(0.0, 1.0),
          child: Align(
            alignment: Alignment.centerRight,
            child: Transform.translate(
              offset: const Offset(0, -2),
              child: Container(width: 2, height: 10, color: Colors.redAccent),
            ),
          ),
        ),
      ],
    );
  }
}
