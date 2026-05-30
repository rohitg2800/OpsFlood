// lib/screens/river_monitor_screen.dart
// OpsFlood — River Monitor v5.0  (threshold alerts merged)
//
// TABS:
//   0 — Stations   (CWC live telemetry + GloFAS threshold overlay)
//   1 — Alerts     (inline ThresholdAlertService breach list)
//   2 — Add City
//   3 — India Map
//
// COMPOSITE RISK SCORE (0–100):
//   score = 0.45 × cwcPct  +  0.35 × gloFasPct  +  0.20 × mlProb
//   where:
//     cwcPct    = (current - warning) / (hfl - warning) × 100  [clamped 0–100]
//     gloFasPct = ThresholdAlert.fillPercent                    [0–150 → clamp 0–100]
//     mlProb    = r.mlFloodProb × 100                           [0–100]
//
// The composite drives a unified RiskBand (Safe / Elevated / High / Critical)
// shown prominently on every card.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../constants.dart';
import '../models/river_station.dart';
import '../models/threshold_alert.dart';
import '../providers/alerts_provider.dart';
import '../services/real_time_river_service.dart';
import '../services/threshold_alert_service.dart';
import 'india_river_explorer_screen.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kBg        = Color(0xFF060B12);
const _kSurface   = Color(0xFF0C1520);
const _kSurface2  = Color(0xFF111D2B);
const _kGold      = Color(0xFFD4A843);
const _kGoldLight = Color(0xFFF0C96A);
const _kGoldDark  = Color(0xFF8A6A1A);
const _kTeal      = Color(0xFF00B4C8);
const _kBorder    = Color(0x22D4A843);

const _dcColors = {
  DangerClass.normal:      Color(0xFF22C55E),
  DangerClass.aboveNormal: Color(0xFFD4A843),
  DangerClass.severe:      Color(0xFFF97316),
  DangerClass.extreme:     Color(0xFFEF4444),
};

// ── Composite Risk Band ───────────────────────────────────────────────────────
enum RiskBand { safe, elevated, high, critical }

extension RiskBandX on RiskBand {
  String get label => switch (this) {
    RiskBand.safe     => 'SAFE',
    RiskBand.elevated => 'ELEVATED',
    RiskBand.high     => 'HIGH',
    RiskBand.critical => 'CRITICAL',
  };
  Color get color => switch (this) {
    RiskBand.safe     => const Color(0xFF22C55E),
    RiskBand.elevated => const Color(0xFFD4A843),
    RiskBand.high     => const Color(0xFFF97316),
    RiskBand.critical => const Color(0xFFEF4444),
  };
}

/// Composite risk score (0–100) and band.
/// Weights: CWC gauge 45%, GloFAS discharge 35%, ML flood prob 20%.
class RiskCompute {
  final double score;      // 0–100
  final RiskBand band;
  final double cwcPct;     // CWC contribution raw %
  final double gloFasPct;  // GloFAS contribution raw %
  final double mlPct;      // ML prob raw %

  const RiskCompute({
    required this.score,
    required this.band,
    required this.cwcPct,
    required this.gloFasPct,
    required this.mlPct,
  });

  /// [cwcCurrent], [cwcWarning], [cwcHfl] in metres MSL (from CWC telemetry).
  /// [alert] from ThresholdAlertService (may be null if no breach).
  /// [mlFloodProb] 0–1 from ML model.
  factory RiskCompute.compute({
    required double cwcCurrent,
    required double cwcWarning,
    required double cwcHfl,
    ThresholdAlert? alert,
    double? mlFloodProb,
  }) {
    // ── CWC gauge pct: fraction of the gap between warning level and HFL ──
    // If current < warning → 0.  If current > hfl → 100.
    double cwcPct = 0;
    if (cwcWarning > 0 && cwcHfl > cwcWarning) {
      cwcPct = ((cwcCurrent - cwcWarning) / (cwcHfl - cwcWarning) * 100)
          .clamp(0.0, 100.0);
    } else if (cwcHfl > 0) {
      // Fallback: plain % of HFL
      cwcPct = (cwcCurrent / cwcHfl * 100).clamp(0.0, 100.0);
    }

    // ── GloFAS fill % (ThresholdAlert.fillPercent: 0–150+, clamp to 100) ──
    final gloFasPct = alert != null
        ? alert.fillPercent.clamp(0.0, 100.0)
        : 0.0;

    // ── ML flood probability → % ──────────────────────────────────────────
    final mlPct = ((mlFloodProb ?? 0) * 100).clamp(0.0, 100.0);

    // ── Weighted composite ────────────────────────────────────────────────
    final score = (0.45 * cwcPct + 0.35 * gloFasPct + 0.20 * mlPct)
        .clamp(0.0, 100.0);

    // ── Band thresholds ───────────────────────────────────────────────────
    final band = score >= 75 ? RiskBand.critical
               : score >= 50 ? RiskBand.high
               : score >= 25 ? RiskBand.elevated
               : RiskBand.safe;

    return RiskCompute(
      score: score, band: band,
      cwcPct: cwcPct, gloFasPct: gloFasPct, mlPct: mlPct,
    );
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────
class RiverMonitorScreen extends ConsumerStatefulWidget {
  const RiverMonitorScreen({super.key});
  @override
  ConsumerState<RiverMonitorScreen> createState() => _RiverMonitorScreenState();
}

class _RiverMonitorScreenState extends ConsumerState<RiverMonitorScreen>
    with TickerProviderStateMixin {

  // 4 tabs: Stations | Alerts | Add City | India Map
  late final TabController      _tab;
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulse;

  final _svc        = RealTimeRiverService();
  final _searchCtrl = TextEditingController();

  List<LiveRiverResult> _results    = [];
  bool                  _loading    = true;
  bool                  _refreshing = false;
  bool                  _sortByRisk = false;
  String                _error      = '';
  String                _filterState = '';
  Timer?                _timer;

  String       _addCityName = '';
  bool         _adding      = false;
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _fetchAll();
    _timer = Timer.periodic(
        AppConstants.pollingInterval, (_) => _fetchAll(silent: true));
  }

  @override
  void dispose() {
    _tab.dispose();
    _pulseCtrl.dispose();
    _searchCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // ── Fetch ─────────────────────────────────────────────────────────────────
  Future<void> _fetchAll({bool silent = false}) async {
    if (!mounted) return;
    setState(() {
      if (!silent) _loading = true;
      else         _refreshing = true;
      _error = '';
    });
    try {
      final results = await _svc.fetchAll();
      if (!mounted) return;
      setState(() {
        _results    = results;
        _loading    = false;
        _refreshing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error      = e.toString();
        _loading    = false;
        _refreshing = false;
      });
    }
  }

  // ── Alert lookup by city name ─────────────────────────────────────────────
  ThresholdAlert? _alertFor(LiveRiverResult r) {
    final alerts = ThresholdAlertService.instance.currentAlerts;
    final cityLower = r.station.city.toLowerCase();
    try {
      return alerts.firstWhere((a) =>
          a.cityName.toLowerCase() == cityLower ||
          a.cityId.toLowerCase().contains(cityLower));
    } catch (_) {
      return null;
    }
  }

  // ── Filtered + sorted list ────────────────────────────────────────────────
  List<LiveRiverResult> get _list {
    var l = List<LiveRiverResult>.from(_results);
    if (_filterState.isNotEmpty) {
      l = l.where((r) => r.station.state == _filterState).toList();
    }
    if (_sortByRisk) {
      // Sort by composite risk score (descending)
      l.sort((a, b) {
        final rA = RiskCompute.compute(
          cwcCurrent: a.station.current,
          cwcWarning: a.station.warning,
          cwcHfl:     a.station.hfl,
          alert:      _alertFor(a),
          mlFloodProb: a.mlFloodProb,
        ).score;
        final rB = RiskCompute.compute(
          cwcCurrent: b.station.current,
          cwcWarning: b.station.warning,
          cwcHfl:     b.station.hfl,
          alert:      _alertFor(b),
          mlFloodProb: b.mlFloodProb,
        ).score;
        return rB.compareTo(rA);
      });
    }
    return l;
  }

  int get _liveCount => _results.where((r) => r.source != 'NO_DATA').length;
  int get _atRisk    => _results.where((r) =>
      r.station.dangerClass != DangerClass.normal && r.source != 'NO_DATA').length;
  int get _noData    => _results.where((r) => r.source == 'NO_DATA').length;

  List<String> get _stateList {
    final seen = <String>{};
    final out  = <String>[];
    for (final r in _results) {
      if (seen.add(r.station.state)) out.add(r.station.state);
    }
    out.sort();
    return out;
  }

  // ── Add city helpers ──────────────────────────────────────────────────────
  void _onSearch(String q) {
    if (q.isEmpty) { setState(() => _suggestions = []); return; }
    final lq = q.toLowerCase();
    final alreadyLoaded = _results.map((r) => r.station.city.toLowerCase()).toSet();
    setState(() {
      _suggestions = AppConstants.monitoredCities
          .map((m) => m['city'] as String)
          .where((c) =>
              c.toLowerCase().contains(lq) &&
              !alreadyLoaded.contains(c.toLowerCase()))
          .take(8).toList();
    });
  }

  Future<void> _addCity(String name) async {
    final nm = name.trim();
    if (nm.isEmpty) return;
    if (_results.any((r) => r.station.city.toLowerCase() == nm.toLowerCase())) {
      _snack('$nm already in list', isError: true); return;
    }
    final mc = AppConstants.monitoredCities.firstWhere(
      (m) => (m['city'] as String).toLowerCase() == nm.toLowerCase(),
      orElse: () => <String, dynamic>{},
    );
    if (mc.isEmpty) { _snack('City not in CWC registry', isError: true); return; }

    setState(() => _adding = true);
    HapticFeedback.lightImpact();
    try {
      final result = await _svc.fetchCity(
        city:  mc['city']  as String,
        state: mc['state'] as String,
        river: mc['river'] as String,
      );
      if (!mounted) return;
      setState(() {
        _results.insert(0, result);
        _adding = false;
        _addCityName = '';
        _searchCtrl.clear();
        _suggestions = [];
      });
      _tab.animateTo(0);
      _snack('${mc['city']} added · ${result.source}');
    } catch (e) {
      setState(() => _adding = false);
      _snack('Failed: $e', isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final alertsBadge = ref.watch(alertBadgeCountProvider);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _kBg,
        body: SafeArea(
          child: Column(children: [
            _header(),
            _tabBar(alertsBadge),
            if (_refreshing)
              LinearProgressIndicator(
                backgroundColor: _kGold.withOpacity(0.08),
                valueColor: const AlwaysStoppedAnimation(_kGold),
                minHeight: 2,
              ),
            if (_error.isNotEmpty) _errorBanner(),
            Expanded(child: TabBarView(
              controller: _tab,
              children: [
                _stationsTab(),
                _alertsTab(),
                _addCityTab(),
                const IndiaRiverExplorerScreen(),
              ],
            )),
          ]),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _header() => Container(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [_kGold.withOpacity(0.09), _kTeal.withOpacity(0.05), _kBg]),
      border: Border(bottom: BorderSide(color: _kGold.withOpacity(0.18), width: 0.8)),
    ),
    child: Row(children: [
      Container(
        width: 46, height: 46,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [_kGold, _kGoldDark],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: _kGold.withOpacity(0.35), blurRadius: 16, spreadRadius: 2)],
        ),
        child: const Icon(Icons.water_rounded, color: Color(0xFF060B12), size: 26),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ShaderMask(
          shaderCallback: (b) => const LinearGradient(
              colors: [_kGoldLight, _kGold]).createShader(b),
          child: const Text('River Monitor', style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w900,
              color: Colors.white, letterSpacing: 0.5)),
        ),
        const Text('CWC + GloFAS · OpsFlood AI',
            style: TextStyle(fontSize: 10, color: Color(0xFF7B8A99), letterSpacing: 0.4)),
      ])),
      AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _kTeal.withOpacity(0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kTeal.withOpacity(0.35 * _pulse.value)),
            boxShadow: [BoxShadow(color: _kTeal.withOpacity(0.12 * _pulse.value), blurRadius: 10)],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 7, height: 7,
              decoration: BoxDecoration(
                color: _kTeal.withOpacity(_pulse.value),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: _kTeal.withOpacity(0.7), blurRadius: 6)],
              ),
            ),
            const SizedBox(width: 5),
            Text('$_liveCount LIVE',
                style: const TextStyle(
                    color: _kTeal, fontSize: 10, fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
      const SizedBox(width: 8),
      _GoldChip(label: '${_list.length}', sublabel: 'shown'),
      const SizedBox(width: 6),
      _GoldChip(
        label: '$_atRisk',
        sublabel: 'at risk',
        color: _atRisk > 0 ? const Color(0xFFF97316) : null,
      ),
      if (_noData > 0) ...[
        const SizedBox(width: 6),
        _GoldChip(label: '$_noData', sublabel: 'no data',
            color: const Color(0xFF7B8A99)),
      ],
    ]),
  );

  // ── Tab bar (4 tabs) ──────────────────────────────────────────────────────
  Widget _tabBar(int alertsBadge) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
    child: Container(
      height: 44,
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: TabBar(
        controller: _tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
              colors: [_kGold, _kGoldDark],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: _kGold.withOpacity(0.3), blurRadius: 8)],
        ),
        labelColor: const Color(0xFF060B12),
        unselectedLabelColor: const Color(0xFF7B8A99),
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        tabs: [
          const Tab(text: 'Stations'),
          Tab(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Text('Alerts', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                if (alertsBadge > 0)
                  Positioned(
                    right: -10, top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                          color: Color(0xFFEF4444), shape: BoxShape.circle),
                      child: Text('$alertsBadge',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 8,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
              ],
            ),
          ),
          const Tab(text: 'Add City'),
          const Tab(text: 'Map'),
        ],
      ),
    ),
  );

  // ── Error banner ──────────────────────────────────────────────────────────
  Widget _errorBanner() => Container(
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFEF4444).withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
    ),
    child: Row(children: [
      const Icon(Icons.wifi_off_rounded, size: 16, color: Color(0xFFEF4444)),
      const SizedBox(width: 8),
      const Expanded(child: Text('API error — showing last cached data',
          style: TextStyle(color: Color(0xFFEF4444), fontSize: 11))),
      GestureDetector(
        onTap: _fetchAll,
        child: const Text('Retry', style: TextStyle(
            color: _kGold, fontSize: 11, fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline, decorationColor: _kGold)),
      ),
    ]),
  );

  // ── Stations tab ──────────────────────────────────────────────────────────
  Widget _stationsTab() {
    if (_loading) return _shimmer();
    return RefreshIndicator(
      color: _kGold, backgroundColor: _kSurface2,
      onRefresh: _fetchAll,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _filterSortBar()),
          SliverToBoxAdapter(child: _legend()),
          SliverToBoxAdapter(child: _riskMathNote()),
          SliverList(delegate: SliverChildBuilderDelegate(
            (ctx, i) {
              final r = _list[i];
              return _LiveCard(
                key:    ValueKey('${r.station.city}_${r.station.state}'),
                result: r,
                index:  i,
                alert:  _alertFor(r),
                onDelete: () => setState(() => _results.remove(r)),
              );
            },
            childCount: _list.length,
          )),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  // ── Alerts tab (inline from ThresholdAlertService) ────────────────────────
  Widget _alertsTab() {
    final provider = ref.watch(alertsProvider);
    final alerts   = provider.filtered;
    final critical = provider.critical;
    final loading  = provider.loading;

    // Mark seen when tab is active
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_tab.index == 1) provider.markAllSeen();
    });

    return Column(
      children: [
        // critical banner
        if (critical.isNotEmpty)
          Container(
            width: double.infinity,
            color: const Color(0xFFF44336),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(children: [
              const Icon(Icons.crisis_alert, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                '${critical.length} station${critical.length > 1 ? "s" : ""} '
                'at or above Danger level',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold,
                    fontSize: 12),
              ),
            ]),
          ),

        // toolbar row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Text('${alerts.length} alert${alerts.length != 1 ? "s" : ""}',
                  style: const TextStyle(
                      color: Color(0xFF7B8A99), fontSize: 12)),
              const Spacer(),
              if (loading)
                const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(_kGold)))
              else
                GestureDetector(
                  onTap: () => ref.read(alertsProvider).refresh(),
                  child: const _FilterPill(
                      icon: Icons.refresh_rounded,
                      label: 'Refresh', active: false),
                ),
              const SizedBox(width: 8),
              _AlertFilterMenu(provider: provider),
            ],
          ),
        ),

        // list
        Expanded(
          child: alerts.isEmpty
              ? Center(
                  child: loading
                      ? const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(_kGold))
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline,
                                size: 56,
                                color: const Color(0xFF22C55E).withOpacity(0.5)),
                            const SizedBox(height: 12),
                            const Text('All rivers within safe levels',
                                style: TextStyle(
                                    color: Color(0xFF7B8A99), fontSize: 14)),
                          ],
                        ),
                )
              : RefreshIndicator(
                  color: _kGold,
                  backgroundColor: _kSurface2,
                  onRefresh: () => ref.read(alertsProvider).refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                    itemCount: alerts.length,
                    itemBuilder: (_, i) => _AlertRow(alert: alerts[i]),
                  ),
                ),
        ),
      ],
    );
  }

  // ── Filter + sort bar ─────────────────────────────────────────────────────
  Widget _filterSortBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
    child: Row(children: [
      Text('${_list.length} / ${_results.length}',
          style: const TextStyle(fontSize: 12, color: Color(0xFF7B8A99))),
      const SizedBox(width: 6),
      const Text('stations',
          style: TextStyle(fontSize: 11, color: Color(0xFF3A4A58))),
      const Spacer(),
      GestureDetector(
        onTap: () async {
          final states = ['All States', ..._stateList];
          final picked = await showModalBottomSheet<String>(
            context: context,
            backgroundColor: _kSurface,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            builder: (_) => ListView(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 0, 10),
                  child: Text('Filter by State', style: TextStyle(
                      color: _kGoldLight, fontSize: 14, fontWeight: FontWeight.w800)),
                ),
                ...states.map((st) => ListTile(
                  dense: true,
                  title: Text(st, style: TextStyle(
                      color: st == (_filterState.isEmpty ? 'All States' : _filterState)
                          ? _kGold : Colors.white,
                      fontSize: 13,
                      fontWeight: st == (_filterState.isEmpty ? 'All States' : _filterState)
                          ? FontWeight.w800 : FontWeight.w400)),
                  trailing: st == (_filterState.isEmpty ? 'All States' : _filterState)
                      ? const Icon(Icons.check_rounded, color: _kGold, size: 16) : null,
                  onTap: () => Navigator.pop(context, st),
                )),
              ],
            ),
          );
          if (picked != null) {
            setState(() => _filterState = picked == 'All States' ? '' : picked);
          }
        },
        child: _FilterPill(
          icon: Icons.filter_list_rounded,
          label: _filterState.isNotEmpty ? _filterState.split(' ').first : 'State',
          active: _filterState.isNotEmpty,
        ),
      ),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: () => setState(() => _sortByRisk = !_sortByRisk),
        child: _FilterPill(
          icon: Icons.sort_rounded,
          label: _sortByRisk ? 'Risk ↓' : 'Sort',
          active: _sortByRisk,
        ),
      ),
    ]),
  );

  Widget _legend() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
    child: Wrap(spacing: 12, runSpacing: 4, children: [
      _LegendDot(color: _dcColors[DangerClass.normal]!,      label: 'Normal'),
      _LegendDot(color: _dcColors[DangerClass.aboveNormal]!, label: 'Above Normal'),
      _LegendDot(color: _dcColors[DangerClass.severe]!,      label: 'Severe'),
      _LegendDot(color: _dcColors[DangerClass.extreme]!,     label: 'Extreme'),
      const _LegendDot(color: Color(0xFF818CF8), label: 'GloFAS breach'),
    ]),
  );

  Widget _riskMathNote() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _kGold.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kGold.withOpacity(0.12)),
      ),
      child: const Text(
        'Risk Score = 45% CWC gauge + 35% GloFAS discharge + 20% AI flood prob',
        style: TextStyle(color: Color(0xFF7B8A99), fontSize: 9, letterSpacing: 0.2),
        textAlign: TextAlign.center,
      ),
    ),
  );

  Widget _shimmer() => ListView.builder(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
    itemCount: 10,
    itemBuilder: (_, i) => _ShimmerCard(delay: i * 80),
  );

  // ── Add city tab ──────────────────────────────────────────────────────────
  Widget _addCityTab() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 3, height: 22,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [_kGold, _kGoldDark],
                begin: Alignment.topCenter, end: Alignment.bottomCenter),
            borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 10),
        const Text('Add City to Monitor',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
      ]),
      const SizedBox(height: 6),
      const Padding(
        padding: EdgeInsets.only(left: 13),
        child: Text(
          'Live CWC data fetched immediately. '
          'If the station has no live reading, it will show NO DATA — never a fake value.',
          style: TextStyle(fontSize: 11, color: Color(0xFF7B8A99), height: 1.5)),
      ),
      const SizedBox(height: 20),
      Container(
        decoration: BoxDecoration(
          color: _kSurface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
          boxShadow: [BoxShadow(color: _kGold.withOpacity(0.06), blurRadius: 12)],
        ),
        child: TextField(
          controller: _searchCtrl,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          onChanged: (v) { _addCityName = v; _onSearch(v); },
          decoration: InputDecoration(
            hintText: 'Search city  e.g. Patna, Guwahati…',
            hintStyle: const TextStyle(color: Color(0xFF3A4A58), fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded, color: _kGold, size: 20),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded,
                        color: Color(0xFF7B8A99), size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() { _addCityName = ''; _suggestions = []; });
                    })
                : null,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _kGold, width: 1.5)),
            filled: true, fillColor: Colors.transparent,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
      if (_suggestions.isNotEmpty) ...[
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _kSurface2, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kBorder),
          ),
          child: Column(children: _suggestions.asMap().entries.map((e) {
            final city = e.value;
            final mc   = AppConstants.monitoredCities.firstWhere(
              (m) => m['city'] == city, orElse: () => {});
            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                _searchCtrl.text = city;
                setState(() { _addCityName = city; _suggestions = []; });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: e.key < _suggestions.length - 1
                    ? BoxDecoration(border: Border(bottom:
                        BorderSide(color: _kGold.withOpacity(0.08))))
                    : null,
                child: Row(children: [
                  Container(width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: _kGold.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(9)),
                    child: const Icon(Icons.water_rounded, color: _kGold, size: 16)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(city, style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                      Text('${mc['state'] ?? ''} · ${mc['river'] ?? ''}',
                          style: const TextStyle(
                              color: Color(0xFF7B8A99), fontSize: 10),
                          overflow: TextOverflow.ellipsis),
                    ],
                  )),
                  const Icon(Icons.add_circle_outline_rounded, color: _kGold, size: 18),
                ]),
              ),
            );
          }).toList()),
        ),
      ],
      const SizedBox(height: 20),
      GestureDetector(
        onTap: (_addCityName.trim().isEmpty || _adding) ? null : () => _addCity(_addCityName),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 54,
          decoration: BoxDecoration(
            gradient: (_addCityName.trim().isEmpty || _adding)
                ? LinearGradient(colors: [
                    Colors.white.withOpacity(0.05),
                    Colors.white.withOpacity(0.05)
                  ])
                : const LinearGradient(
                    colors: [_kGoldLight, _kGold, _kGoldDark],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
            boxShadow: (_addCityName.trim().isEmpty || _adding) ? []
                : [BoxShadow(
                    color: _kGold.withOpacity(0.35), blurRadius: 18, spreadRadius: 2)],
          ),
          child: Center(child: _adding
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(Color(0xFF060B12))))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add_location_alt_rounded, size: 20,
                    color: _addCityName.trim().isEmpty
                        ? const Color(0xFF3A4A58) : const Color(0xFF060B12)),
                const SizedBox(width: 8),
                Text('Fetch Live & Add',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: _addCityName.trim().isEmpty
                            ? const Color(0xFF3A4A58) : const Color(0xFF060B12))),
              ]),
          ),
        ),
      ),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kTeal.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kTeal.withOpacity(0.2)),
        ),
        child: const Column(children: [
          Row(children: [
            Text('🛰', style: TextStyle(fontSize: 14)),
            SizedBox(width: 8),
            Text('4-Source Live Pipeline',
                style: TextStyle(
                    color: _kGold, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
          SizedBox(height: 6),
          Text(
            'SOURCE 1: CWC Telemetry (gauge height, m MSL)  →  '
            'SOURCE 2: GloFAS Discharge (m³/s, threshold alerts)  →  '
            'SOURCE 3: OpsFlood Live Levels  →  '
            'SOURCE 4: CWC Flood Forecasting Service.\n\n'
            'Risk Score blends all sources. Never shows synthetic values.',
            style: TextStyle(
                color: Color(0xFF7B8A99), fontSize: 11, height: 1.5),
          ),
        ]),
      ),
    ]),
  );
}

// ── Live Station Card (with threshold alert overlay) ──────────────────────────
class _LiveCard extends StatefulWidget {
  final LiveRiverResult result;
  final int             index;
  final VoidCallback    onDelete;
  final ThresholdAlert? alert;     // may be null if GloFAS has no data for this city
  const _LiveCard({
    super.key,
    required this.result,
    required this.index,
    required this.onDelete,
    this.alert,
  });
  @override State<_LiveCard> createState() => _LiveCardState();
}

class _LiveCardState extends State<_LiveCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 500 + (widget.index % 20) * 60));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    Future.delayed(
        Duration(milliseconds: (widget.index % 20) * 60),
        () { if (mounted) _ctrl.forward(); });
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final r  = widget.result;
    final s  = r.station;
    final dc = s.dangerClass;
    final a  = widget.alert;

    // ── Composite risk ──────────────────────────────────────────────────────
    final risk = RiskCompute.compute(
      cwcCurrent:  s.current,
      cwcWarning:  s.warning,
      cwcHfl:      s.hfl,
      alert:       a,
      mlFloodProb: r.mlFloodProb,
    );

    if (r.source == 'NO_DATA') {
      return FadeTransition(
        opacity: _anim,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _kSurface.withOpacity(0.4),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF2A3A4A)),
          ),
          child: Row(children: [
            const Icon(Icons.signal_wifi_off_rounded,
                size: 20, color: Color(0xFF3A4A58)),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.city, style: const TextStyle(
                    color: Color(0xFF7B8A99),
                    fontWeight: FontWeight.w700, fontSize: 14)),
                Text('${s.river} · ${s.state}',
                    style: const TextStyle(color: Color(0xFF3A4A58), fontSize: 10)),
              ],
            )),
            // Even NO_DATA cards show GloFAS alert if available
            if (a != null) ...[
              _AlertLevelBadge(level: a.level),
              const SizedBox(width: 6),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF3A4A58).withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF3A4A58))),
              child: const Text('NO DATA',
                  style: TextStyle(
                      color: Color(0xFF7B8A99),
                      fontSize: 9, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: widget.onDelete,
              child: const Icon(Icons.remove_circle_outline,
                  size: 16, color: Color(0xFF3A4A58))),
          ]),
        ),
      );
    }

    final cwcCol = _dcColors[dc]!;
    final pct    = s.progressPct;

    return FadeTransition(
      opacity: _anim,
      child: SlideTransition(
        position: Tween<Offset>(
            begin: const Offset(0.06, 0), end: Offset.zero).animate(_anim),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(18),
            // Border colour driven by composite risk band
            border: Border.all(color: risk.band.color.withOpacity(0.28)),
            boxShadow: [
              BoxShadow(
                  color: risk.band.color.withOpacity(0.07), blurRadius: 16,
                  offset: const Offset(0, 4)),
              BoxShadow(color: _kGold.withOpacity(0.04), blurRadius: 24),
            ],
          ),
          child: Column(children: [

            // ── Header row ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                        colors: [cwcCol.withOpacity(0.35), cwcCol.withOpacity(0.05)]),
                    shape: BoxShape.circle,
                    border: Border.all(color: cwcCol.withOpacity(0.45), width: 1.5),
                  ),
                  child: Icon(_dcIcon(dc), color: cwcCol, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(child: Text(s.city,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800, fontSize: 15),
                          overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 6),
                      _SourceBadge(source: r.source, confidence: r.confidence),
                      if (r.isStale) ...[
                        const SizedBox(width: 4),
                        const _StaleBadge(),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    Text('${s.river}  ·  ${s.state}',
                        style: const TextStyle(
                            color: Color(0xFF7B8A99), fontSize: 11),
                        overflow: TextOverflow.ellipsis),
                  ],
                )),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  // CWC danger class badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: cwcCol.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: cwcCol.withOpacity(0.4))),
                    child: Text(dc.label,
                        style: TextStyle(
                            color: cwcCol, fontSize: 10,
                            fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 4),
                  // Composite risk band badge
                  _RiskBandBadge(risk: risk),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: widget.onDelete,
                    child: const Icon(Icons.remove_circle_outline,
                        size: 16, color: Color(0xFF3A4A58))),
                ]),
              ]),
            ),

            // ── CWC gauge bar ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: AnimatedBuilder(
                animation: _anim,
                builder: (_, __) => Column(children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(child: Text(
                          '${s.current.toStringAsFixed(2)} m',
                          style: TextStyle(
                              color: cwcCol, fontSize: 18,
                              fontWeight: FontWeight.w900),
                          overflow: TextOverflow.ellipsis)),
                      Text('HFL ${s.hfl.toStringAsFixed(1)} m',
                          style: const TextStyle(
                              color: Color(0xFF7B8A99), fontSize: 10)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // CWC gauge height bar
                  Stack(children: [
                    Container(height: 7, decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(4))),
                    if (s.hfl > 0 && s.warning > 0)
                      Positioned(
                        left: (s.warning / s.hfl).clamp(0.0, 1.0) *
                            (MediaQuery.of(context).size.width - 60),
                        top: 0, bottom: 0,
                        child: Container(
                            width: 1.5,
                            color: _kGold.withOpacity(0.5))),
                    FractionallySizedBox(
                      widthFactor: (pct * _anim.value).clamp(0.0, 1.0),
                      child: Container(
                        height: 7,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: [cwcCol.withOpacity(0.7), cwcCol],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [BoxShadow(
                              color: cwcCol.withOpacity(0.5), blurRadius: 6)],
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _mini('W ${s.warning.toStringAsFixed(1)}', _kGold),
                      _mini('D ${s.danger.toStringAsFixed(1)}',
                          const Color(0xFFF97316)),
                      _mini('${(pct * 100).toStringAsFixed(0)}% of HFL',
                          const Color(0xFF7B8A99)),
                    ],
                  ),
                ]),
              ),
            ),

            // ── GloFAS threshold section (only if alert exists) ──────────────
            if (a != null) ...[
              const SizedBox(height: 8),
              Divider(height: 1,
                  color: const Color(0xFF818CF8).withOpacity(0.2),
                  indent: 14, endIndent: 14),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                child: Column(children: [
                  Row(children: [
                    const Text('🛰 GloFAS',
                        style: TextStyle(
                            color: Color(0xFF818CF8), fontSize: 10,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    _AlertLevelBadge(level: a.level),
                    const SizedBox(width: 8),
                    Icon(a.trend.icon, color: a.trend.color, size: 14),
                    const SizedBox(width: 4),
                    Text(a.trend.name,
                        style: TextStyle(
                            color: a.trend.color, fontSize: 9,
                            fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text(
                      '${a.currentValue.toStringAsFixed(1)} ${a.unitLabel}  '
                      '(${a.breachMargin >= 0 ? '+' : ''}'
                      '${a.breachMargin.toStringAsFixed(1)} vs ${a.level.label})',
                      style: const TextStyle(
                          color: Color(0xFF7B8A99), fontSize: 9),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  // GloFAS fill bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (a.fillPercent / 100).clamp(0.0, 1.0),
                      backgroundColor:
                          const Color(0xFF818CF8).withOpacity(0.10),
                      valueColor: AlwaysStoppedAnimation<Color>(a.level.color),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _mini('WL ${a.warningLevel.toStringAsFixed(0)}',
                          const Color(0xFFD4A843)),
                      _mini('DL ${a.dangerLevel.toStringAsFixed(0)}',
                          const Color(0xFFF97316)),
                      _mini('HFL ${a.hfl.toStringAsFixed(0)}',
                          const Color(0xFF818CF8)),
                      _mini('${a.fillPercent.toStringAsFixed(0)}% fill',
                          const Color(0xFF7B8A99)),
                    ],
                  ),
                ]),
              ),
            ],

            // ── Composite risk score bar ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
              child: Column(children: [
                Divider(height: 1,
                    color: _kGold.withOpacity(0.08), indent: 0, endIndent: 0),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('⚡ Composite Risk',
                        style: TextStyle(
                            color: Color(0xFF7B8A99), fontSize: 10,
                            fontWeight: FontWeight.w600)),
                    Text('${risk.score.toStringAsFixed(1)} / 100',
                        style: TextStyle(
                            color: risk.band.color, fontSize: 10,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: AnimatedBuilder(
                    animation: _anim,
                    builder: (_, __) => LinearProgressIndicator(
                      value: (risk.score / 100 * _anim.value).clamp(0.0, 1.0),
                      backgroundColor: risk.band.color.withOpacity(0.10),
                      valueColor: AlwaysStoppedAnimation<Color>(risk.band.color),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _mini('CWC ${risk.cwcPct.toStringAsFixed(0)}%',
                        cwcCol),
                    if (a != null)
                      _mini('GloFAS ${risk.gloFasPct.toStringAsFixed(0)}%',
                          const Color(0xFF818CF8)),
                    if (r.mlFloodProb != null)
                      _mini('AI ${risk.mlPct.toStringAsFixed(0)}%',
                          _kTeal),
                  ],
                ),
              ]),
            ),

            // ── ML row ───────────────────────────────────────────────────────
            if (r.mlRiskLevel != null) ...[
              Divider(height: 1,
                  color: _kGold.withOpacity(0.08), indent: 14, endIndent: 14),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                child: Row(children: [
                  const Text('🤖 AI',
                      style: TextStyle(fontSize: 10, color: _kTeal)),
                  const SizedBox(width: 6),
                  _mlRiskBadge(r.mlRiskLevel!),
                  if (r.mlFloodProb != null) ...[
                    const SizedBox(width: 8),
                    Text('${(r.mlFloodProb! * 100).toStringAsFixed(0)}% flood prob',
                        style: const TextStyle(
                            color: Color(0xFF7B8A99), fontSize: 10)),
                  ],
                  const Spacer(),
                  Text('conf ${(r.confidence * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                          color: Color(0xFF3A4A58), fontSize: 9)),
                ]),
              ),
            ],

            // ── Pills ────────────────────────────────────────────────────────
            const SizedBox(height: 4),
            Divider(height: 1,
                color: _kGold.withOpacity(0.08), indent: 14, endIndent: 14),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                if (s.trend != null)
                  _Pill(icon: _ti(s.trend!), label: s.trend!, color: _tc(s.trend!)),
                if (s.rainfallLastHour != null && s.rainfallLastHour! > 0)
                  _Pill(icon: '🌧',
                      label: '${s.rainfallLastHour!.toStringAsFixed(1)} mm/hr',
                      color: const Color(0xFF60A5FA)),
                if (s.flowRate != null && s.flowRate! > 0)
                  _Pill(icon: '💧',
                      label: '${s.flowRate!.toStringAsFixed(0)} m³/s',
                      color: _kTeal),
                if (s.liveStatus != null)
                  _Pill(icon: '📡', label: s.liveStatus!, color: _sc(s.liveStatus!)),
                if (s.lastUpdated != null)
                  _Pill(icon: '🕐', label: _shortTime(s.lastUpdated!),
                      color: r.isStale
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF7B8A99)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _mini(String t, Color c) => Text(t,
      style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.w600));

  Widget _mlRiskBadge(String risk) {
    final Color c;
    switch (risk) {
      case 'CRITICAL': c = const Color(0xFFEF4444); break;
      case 'SEVERE':   c = const Color(0xFFF97316); break;
      case 'MODERATE': c = const Color(0xFFD4A843); break;
      default:         c = const Color(0xFF22C55E);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withOpacity(0.4))),
      child: Text(risk,
          style: TextStyle(
              color: c, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }

  IconData _dcIcon(DangerClass dc) {
    switch (dc) {
      case DangerClass.normal:      return Icons.check_circle_outline;
      case DangerClass.aboveNormal: return Icons.warning_amber_rounded;
      case DangerClass.severe:      return Icons.error_outline_rounded;
      case DangerClass.extreme:     return Icons.crisis_alert_rounded;
    }
  }

  String _ti(String t) =>
      t == 'RISING' ? '↑' : t == 'FALLING' ? '↓' : '→';
  Color  _tc(String t) => t == 'RISING'
      ? const Color(0xFFEF4444)
      : t == 'FALLING' ? const Color(0xFF22C55E) : const Color(0xFF7B8A99);
  Color  _sc(String s) => s == 'CRITICAL'
      ? const Color(0xFFEF4444)
      : s == 'WARNING' ? const Color(0xFFF59E0B) : const Color(0xFF22C55E);

  String _shortTime(String ts) {
    try {
      final dt = DateTime.tryParse(ts);
      if (dt == null) return ts.length > 16 ? ts.substring(11, 16) : ts;
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
      if (diff.inHours   < 24)  return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return ts.length > 16 ? ts.substring(11, 16) : ts;
    }
  }
}

// ── Alert row (compact, for the Alerts tab) ───────────────────────────────────
class _AlertRow extends StatelessWidget {
  final ThresholdAlert alert;
  const _AlertRow({required this.alert});

  @override
  Widget build(BuildContext context) {
    final col = alert.level.color;
    final ts  = DateFormat('dd MMM HH:mm').format(alert.timestamp.toLocal());
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: col.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(alert.level.icon, color: col, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(alert.cityName,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800,
                    fontSize: 14)),
          ),
          if (alert.isNew)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                  color: col, borderRadius: BorderRadius.circular(4)),
              child: const Text('NEW',
                  style: TextStyle(
                      color: Colors.white, fontSize: 9,
                      fontWeight: FontWeight.w800)),
            ),
        ]),
        const SizedBox(height: 4),
        Text('${alert.state} · ${alert.river}',
            style: const TextStyle(color: Color(0xFF7B8A99), fontSize: 10)),
        const SizedBox(height: 8),
        // Fill bar
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: (alert.fillPercent / 100).clamp(0.0, 1.0),
            backgroundColor: col.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation<Color>(col),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${alert.currentValue.toStringAsFixed(1)} ${alert.unitLabel}',
                style: TextStyle(
                    color: col, fontSize: 12, fontWeight: FontWeight.w800)),
            Text('DL ${alert.dangerLevel.toStringAsFixed(1)}',
                style: const TextStyle(
                    color: Color(0xFFF97316), fontSize: 10)),
            Row(children: [
              Icon(alert.trend.icon, size: 12, color: alert.trend.color),
              const SizedBox(width: 3),
              Text(alert.trend.name,
                  style: TextStyle(
                      color: alert.trend.color, fontSize: 9,
                      fontWeight: FontWeight.w600)),
            ]),
            Text(ts,
                style: const TextStyle(
                    color: Color(0xFF3A4A58), fontSize: 9)),
          ],
        ),
      ]),
    );
  }
}

// ── Alert level badge ─────────────────────────────────────────────────────────
class _AlertLevelBadge extends StatelessWidget {
  final AlertLevel level;
  const _AlertLevelBadge({required this.level});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: level.color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: level.color.withOpacity(0.4))),
    child: Text(level.label,
        style: TextStyle(
            color: level.color, fontSize: 9, fontWeight: FontWeight.w800)),
  );
}

// ── Composite risk band badge ─────────────────────────────────────────────────
class _RiskBandBadge extends StatelessWidget {
  final RiskCompute risk;
  const _RiskBandBadge({required this.risk});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: risk.band.color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: risk.band.color.withOpacity(0.35))),
    child: Text('${risk.band.label} ${risk.score.toStringAsFixed(0)}',
        style: TextStyle(
            color: risk.band.color, fontSize: 8, fontWeight: FontWeight.w800)),
  );
}

// ── Alert filter menu (for Alerts tab) ───────────────────────────────────────
class _AlertFilterMenu extends StatelessWidget {
  final AlertsProvider provider;
  const _AlertFilterMenu({required this.provider});
  @override
  Widget build(BuildContext context) {
    final hasFilter = provider.filterLevel != null || provider.filterDistrict != null;
    return PopupMenuButton<String>(
      icon: Icon(Icons.filter_list_rounded,
          size: 18,
          color: hasFilter ? _kGold : const Color(0xFF7B8A99)),
      onSelected: (val) {
        if (val == 'clear') { provider.clearFilters(); return; }
        final level = AlertLevel.values.where((l) => l.name == val).firstOrNull;
        if (level != null) provider.setFilterLevel(level);
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'clear', child: Text('Clear filters')),
        const PopupMenuDivider(),
        ...AlertLevel.values.reversed
            .where((l) => l != AlertLevel.normal)
            .map((l) => PopupMenuItem(
                  value: l.name,
                  child: Row(children: [
                    Icon(l.icon, color: l.color, size: 16),
                    const SizedBox(width: 8),
                    Text(l.label),
                  ]),
                )),
      ],
    );
  }
}

// ── Source badge ──────────────────────────────────────────────────────────────
class _SourceBadge extends StatelessWidget {
  final String source;
  final double confidence;
  const _SourceBadge({required this.source, required this.confidence});
  @override Widget build(BuildContext context) {
    final (label, color) = switch (source) {
      'TELEMETRY'   => ('CWC', const Color(0xFF00B4C8)),
      'LIVE_LEVELS' => ('LIVE', const Color(0xFF22C55E)),
      'CWC_FFS'     => ('FFS',  const Color(0xFFD4A843)),
      _             => ('???',  const Color(0xFF7B8A99)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.35))),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 8, fontWeight: FontWeight.w800)),
    );
  }
}

class _StaleBadge extends StatelessWidget {
  const _StaleBadge();
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(0xFFEF4444).withOpacity(0.10),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.35))),
    child: const Text('STALE',
        style: TextStyle(
            color: Color(0xFFEF4444), fontSize: 8, fontWeight: FontWeight.w800)),
  );
}

// ── Shimmer ───────────────────────────────────────────────────────────────────
class _ShimmerCard extends StatefulWidget {
  final int delay;
  const _ShimmerCard({required this.delay});
  @override State<_ShimmerCard> createState() => _ShimmerCardState();
}
class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;
  @override void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
    _anim = Tween<double>(begin: -2, end: 2)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0C1520),
            Color.lerp(const Color(0xFF0C1520), const Color(0xFF1A2A3A),
                (_anim.value + 2) / 4)!,
            const Color(0xFF0C1520),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1A2A3A)),
      ),
    ),
  );
}

// ── Small reusable widgets ────────────────────────────────────────────────────

class _GoldChip extends StatelessWidget {
  final String label;
  final String sublabel;
  final Color? color;
  const _GoldChip({required this.label, required this.sublabel, this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: (color ?? _kGold).withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: (color ?? _kGold).withOpacity(0.25))),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: TextStyle(
          color: color ?? _kGold, fontSize: 13, fontWeight: FontWeight.w900)),
      Text(sublabel, style: const TextStyle(
          color: Color(0xFF3A4A58), fontSize: 8)),
    ]),
  );
}

class _FilterPill extends StatelessWidget {
  final IconData icon;
  final String   label;
  final bool     active;
  const _FilterPill({required this.icon, required this.label, required this.active});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: active ? _kGold.withOpacity(0.15) : _kSurface2,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
          color: active ? _kGold.withOpacity(0.5) : const Color(0xFF1A2A3A))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: active ? _kGold : const Color(0xFF7B8A99)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(
          color: active ? _kGold : const Color(0xFF7B8A99),
          fontSize: 11, fontWeight: FontWeight.w700)),
    ]),
  );
}

class _LegendDot extends StatelessWidget {
  final Color  color;
  final String label;
  const _LegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 7, height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(color: Color(0xFF7B8A99), fontSize: 9)),
  ]);
}

class _Pill extends StatelessWidget {
  final String icon;
  final String label;
  final Color  color;
  const _Pill({required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.2))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(icon, style: const TextStyle(fontSize: 10)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(
          color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    ]),
  );
}
