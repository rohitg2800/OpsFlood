// lib/screens/alerts_screen.dart
//
// OpsFlood — AlertsScreen
// Full-screen list of live flood alerts grouped by State → City.
// Data source: AllIndiaAlertEngine (CWC + GloFAS + OpsFlood backend).
// Updates in real-time via ChangeNotifier listener.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/flood_data.dart';
import '../services/all_india_alert_engine.dart';
import '../theme/river_theme.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});
  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final AllIndiaAlertEngine _engine = AllIndiaAlertEngine();
  String _filterRisk = 'ALL'; // ALL | CRITICAL | HIGH | MODERATE
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _engine.addListener(_rebuild);
    if (_engine.allStations.isEmpty) _engine.refresh();
  }

  @override
  void dispose() {
    _engine.removeListener(_rebuild);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _rebuild() { if (mounted) setState(() {}); }

  // ── Filtered state list ────────────────────────────────────────────────────

  List<String> _visibleStates() {
    final q = _searchQuery.toLowerCase();
    return _engine.stateGroups.keys.where((state) {
      // filter by search
      if (q.isNotEmpty) {
        final match = state.toLowerCase().contains(q) ||
            (_engine.stateGroups[state] ?? []).any(
              (fd) => fd.city.toLowerCase().contains(q) ||
                      (fd.riverName ?? '').toLowerCase().contains(q));
        if (!match) return false;
      }
      // filter by risk
      if (_filterRisk != 'ALL') {
        final worst = _engine.stateRisk(state);
        if (_filterRisk == 'CRITICAL' && worst != 'CRITICAL') return false;
        if (_filterRisk == 'HIGH' &&
            worst != 'CRITICAL' && worst != 'HIGH') return false;
        if (_filterRisk == 'MODERATE' &&
            worst != 'CRITICAL' && worst != 'HIGH' && worst != 'MODERATE') return false;
      }
      return true;
    }).toList();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final states = _visibleStates()
      ..sort((a, b) {
        const r = {'CRITICAL': 4, 'HIGH': 3, 'MODERATE': 2, 'LOW': 1};
        return (r[_engine.stateRisk(b)] ?? 0) - (r[_engine.stateRisk(a)] ?? 0);
      });

    final totalCrit = _engine.allStations.where((f) => f.riskLevel == 'CRITICAL').length;
    final totalHigh = _engine.allStations.where((f) => f.riskLevel == 'HIGH').length;
    final totalMod  = _engine.allStations.where((f) => f.riskLevel == 'MODERATE').length;

    return Scaffold(
      backgroundColor: AppPalette.navy0,
      appBar: AppBar(
        backgroundColor: AppPalette.navy1,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('All-India Flood Alerts',
                style: TextStyle(
                  color: AppPalette.textWhite,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                )),
            if (_engine.lastPoll != null)
              Text(
                'Updated ${DateFormat("HH:mm").format(_engine.lastPoll!.toLocal())}',
                style: const TextStyle(
                    color: AppPalette.textGrey, fontSize: 10),
              ),
          ],
        ),
        actions: [
          if (_engine.isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 14),
              child: SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppPalette.cyan),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded,
                  color: AppPalette.textGrey, size: 20),
              onPressed: _engine.refresh,
            ),
        ],
      ),
      body: Column(
        children: [

          // ── Summary chips ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              children: [
                _SummaryChip('CRIT', totalCrit, AppPalette.critical,
                    selected: _filterRisk == 'CRITICAL',
                    onTap: () => setState(() => _filterRisk =
                        _filterRisk == 'CRITICAL' ? 'ALL' : 'CRITICAL')),
                const SizedBox(width: 8),
                _SummaryChip('HIGH', totalHigh, AppPalette.danger,
                    selected: _filterRisk == 'HIGH',
                    onTap: () => setState(() => _filterRisk =
                        _filterRisk == 'HIGH' ? 'ALL' : 'HIGH')),
                const SizedBox(width: 8),
                _SummaryChip('MOD', totalMod, AppPalette.warning,
                    selected: _filterRisk == 'MODERATE',
                    onTap: () => setState(() => _filterRisk =
                        _filterRisk == 'MODERATE' ? 'ALL' : 'MODERATE')),
                const Spacer(),
                Text('${_engine.allStations.length} stations · ${_engine.stateGroups.length} states',
                    style: const TextStyle(
                        color: AppPalette.textDim, fontSize: 10)),
              ],
            ),
          ),

          // ── Search bar ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: AppPalette.textWhite, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search state, city or river…',
                hintStyle: const TextStyle(
                    color: AppPalette.textDim, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppPalette.textGrey, size: 18),
                filled: true,
                fillColor: AppPalette.navy3,
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 10, horizontal: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded,
                            color: AppPalette.textGrey, size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

          // ── State list ────────────────────────────────────────────────────
          Expanded(
            child: _engine.isLoading && _engine.allStations.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                            color: AppPalette.cyan, strokeWidth: 2),
                        SizedBox(height: 14),
                        Text('Fetching all-India station data…',
                            style: TextStyle(
                                color: AppPalette.textGrey, fontSize: 13)),
                      ],
                    ),
                  )
                : states.isEmpty
                    ? const Center(
                        child: Text('No stations match your filter.',
                            style: TextStyle(
                                color: AppPalette.textGrey, fontSize: 13)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
                        itemCount: states.length,
                        itemBuilder: (ctx, i) => _StateSection(
                          state:   states[i],
                          cities:  _engine.citiesForState(states[i]),
                          risk:    _engine.stateRisk(states[i]),
                          query:   _searchQuery,
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ── State Section (expandable) ─────────────────────────────────────────────
class _StateSection extends StatefulWidget {
  final String         state;
  final List<FloodData> cities;
  final String         risk;
  final String         query;
  const _StateSection({
    required this.state, required this.cities,
    required this.risk,  required this.query,
  });
  @override
  State<_StateSection> createState() => _StateSectionState();
}

class _StateSectionState extends State<_StateSection> {
  bool _expanded = true; // expand CRITICAL/HIGH by default later

  @override
  void initState() {
    super.initState();
    _expanded = widget.risk == 'CRITICAL' || widget.risk == 'HIGH';
  }

  @override
  Widget build(BuildContext context) {
    final col = _riskColor(widget.risk);
    final critCities = widget.cities.where((c) => c.riskLevel == 'CRITICAL').length;
    final warnCities = widget.cities.where((c) =>
        c.riskLevel == 'HIGH' || c.riskLevel == 'MODERATE').length;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppPalette.navy2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: col.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                        color: col, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(widget.state,
                        style: const TextStyle(
                          color: AppPalette.textWhite,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        )),
                  ),
                  if (critCities > 0)
                    _MiniTag('$critCities CRIT', AppPalette.critical),
                  if (warnCities > 0) ...[
                    const SizedBox(width: 5),
                    _MiniTag('$warnCities WARN', AppPalette.warning),
                  ],
                  const SizedBox(width: 8),
                  Text('${widget.cities.length}',
                      style: const TextStyle(
                          color: AppPalette.textGrey, fontSize: 11)),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppPalette.textDim, size: 18,
                  ),
                ],
              ),
            ),
          ),

          // City rows
          if (_expanded) ...[
            const Divider(
                height: 1, color: AppPalette.navyStroke, thickness: 1),
            ...widget.cities.map((fd) => _CityRow(fd: fd, query: widget.query)),
          ],
        ],
      ),
    );
  }
}

// ── City Row ───────────────────────────────────────────────────────────────
class _CityRow extends StatelessWidget {
  final FloodData fd;
  final String    query;
  const _CityRow({required this.fd, required this.query});

  @override
  Widget build(BuildContext context) {
    final col     = _riskColor(fd.riskLevel);
    final hasLevel = fd.currentLevel > 0 && fd.dangerLevel > 0;
    final pct      = hasLevel
        ? (fd.currentLevel / fd.dangerLevel).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: const BoxDecoration(
        border: Border(
            bottom: BorderSide(color: AppPalette.navyStroke, width: 0.5)),
      ),
      child: Row(
        children: [
          // Risk colour stripe
          Container(
            width: 3, height: 38,
            decoration: BoxDecoration(
              color: col,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),

          // City + river name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fd.city,
                    style: const TextStyle(
                      color: AppPalette.textWhite,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    )),
                Text(
                  fd.riverName ?? fd.state,
                  style: const TextStyle(
                      color: AppPalette.textGrey, fontSize: 10),
                ),
                if (hasLevel) ...[
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value:           pct,
                      minHeight:       4,
                      backgroundColor: AppPalette.navy4,
                      valueColor:      AlwaysStoppedAnimation<Color>(col),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Level + risk badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                hasLevel
                    ? '${fd.currentLevel.toStringAsFixed(2)} m'
                    : fd.flowRate != null
                        ? '${fd.flowRate!.toStringAsFixed(0)} m³/s'
                        : '—',
                style: TextStyle(
                  color: col,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: col.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  fd.riskLevel,
                  style: TextStyle(
                    color: col,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (hasLevel)
                Text(
                  'DL ${fd.dangerLevel.toStringAsFixed(1)} m',
                  style: const TextStyle(
                      color: AppPalette.textDim, fontSize: 9),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Summary Chip ───────────────────────────────────────────────────────────
class _SummaryChip extends StatelessWidget {
  final String   label;
  final int      count;
  final Color    color;
  final bool     selected;
  final VoidCallback onTap;
  const _SummaryChip(this.label, this.count, this.color,
      {required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.22)
              : color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.8)
                : color.withValues(alpha: 0.25),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                )),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mini Tag ───────────────────────────────────────────────────────────────
class _MiniTag extends StatelessWidget {
  final String label;
  final Color  color;
  const _MiniTag(this.label, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4)),
    );
  }
}

Color _riskColor(String level) {
  switch (level) {
    case 'CRITICAL': return AppPalette.critical;
    case 'HIGH':     return AppPalette.danger;
    case 'MODERATE': return AppPalette.warning;
    default:         return AppPalette.safe;
  }
}
