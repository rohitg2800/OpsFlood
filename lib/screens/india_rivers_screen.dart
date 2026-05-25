// lib/screens/india_rivers_screen.dart
// OpsFlood — India Rivers (merged Live Gauges + CWC Stations)
//
// Tab 0 — Live Gauges : OpsFlood backend via Riverpod liveLevelsProvider
//          State/city/risk/search filters + RiverLevelVisualizer + sparkline
// Tab 1 — CWC Stations: RealTimeRiverService telemetry, ML risk badges,
//          stale/NO_DATA handling, Add City flow

import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../constants.dart';
import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
import '../models/river_station.dart';
import '../providers/flood_providers.dart';
import '../services/real_time_river_service.dart';
import '../services/state_data_prefetcher.dart'; // Bihar WRD auto-prefetch
import '../theme/river_theme.dart';
import '../widgets/river_level_visualizer.dart';

// ── palette (shared) ──────────────────────────────────────────────────────────────
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

// ── Screen ────────────────────────────────────────────────────────────────────────────
class IndiaRiversScreen extends ConsumerStatefulWidget {
  const IndiaRiversScreen({super.key});
  @override
  ConsumerState<IndiaRiversScreen> createState() => _IndiaRiversScreenState();
}

class _IndiaRiversScreenState extends ConsumerState<IndiaRiversScreen>
    with TickerProviderStateMixin {

  // ── tab controller (2 tabs) ──────────────────────────────────────────
  late final TabController       _tab;
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulse;

  // ── Live Gauges filter state ─────────────────────────────────────────
  String  _selectedState = 'All India';
  String? _selectedCity;
  String  _searchQuery   = '';
  String  _riskFilter    = 'ALL';
  final TextEditingController _searchCtrl = TextEditingController();

  // ── CWC Stations state ───────────────────────────────────────────────
  final _cwcSvc         = RealTimeRiverService();
  final _cwcSearchCtrl  = TextEditingController();
  List<LiveRiverResult> _cwcResults    = [];
  bool                  _cwcLoading    = true;
  bool                  _cwcRefreshing = false;
  bool                  _cwcSortByRisk = false;
  String                _cwcError      = '';
  String                _cwcFilterState = '';
  Timer?                _cwcTimer;
  String                _addCityName   = '';
  bool                  _adding        = false;
  List<String>          _suggestions   = [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _fetchCwc();
    _cwcTimer = Timer.periodic(
        AppConstants.pollingInterval, (_) => _fetchCwc(silent: true));

    // Warm Bihar WRD cache immediately on screen open.
    // One HTTP call fetches all 103 stations so every Bihar city card
    // loads instantly without individual network requests.
    StateDataPrefetcher.prefetchState('Bihar');
  }

  @override
  void dispose() {
    _tab.dispose();
    _pulseCtrl.dispose();
    _searchCtrl.dispose();
    _cwcSearchCtrl.dispose();
    _cwcTimer?.cancel();
    super.dispose();
  }

  // ── CWC fetch ───────────────────────────────────────────────────────────
  Future<void> _fetchCwc({bool silent = false}) async {
    if (!mounted) return;
    setState(() {
      if (!silent) { _cwcLoading = true; }
      else         { _cwcRefreshing = true; }
      _cwcError = '';
    });
    try {
      final r = await _cwcSvc.fetchAll();
      if (!mounted) return;
      setState(() {
        _cwcResults    = r;
        _cwcLoading    = false;
        _cwcRefreshing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cwcError      = e.toString();
        _cwcLoading    = false;
        _cwcRefreshing = false;
      });
    }
  }

  // ── CWC helpers ─────────────────────────────────────────────────────────
  List<LiveRiverResult> get _cwcList {
    var l = List<LiveRiverResult>.from(_cwcResults);
    if (_cwcFilterState.isNotEmpty) {
      l = l.where((r) => r.station.state == _cwcFilterState).toList();
    }
    if (_cwcSortByRisk) {
      l.sort((a, b) {
        final rc = b.station.riskScore.compareTo(a.station.riskScore);
        return rc != 0 ? rc : (b.mlFloodProb ?? 0).compareTo(a.mlFloodProb ?? 0);
      });
    }
    return l;
  }

  int get _cwcLive   => _cwcResults.where((r) => r.source != 'NO_DATA').length;
  int get _cwcAtRisk => _cwcResults.where((r) =>
      r.station.dangerClass != DangerClass.normal && r.source != 'NO_DATA').length;

  List<String> get _cwcStateList {
    final seen = <String>{};
    final out  = <String>[];
    for (final r in _cwcResults) {
      if (seen.add(r.station.state)) out.add(r.station.state);
    }
    out.sort();
    return out;
  }

  void _cwcSearch(String q) {
    if (q.isEmpty) { setState(() => _suggestions = []); return; }
    final lq     = q.toLowerCase();
    final loaded = _cwcResults.map((r) => r.station.city.toLowerCase()).toSet();
    setState(() {
      _suggestions = AppConstants.monitoredCities
          .map((m) => m['city'] as String)
          .where((c) =>
              c.toLowerCase().contains(lq) &&
              !loaded.contains(c.toLowerCase()))
          .take(8).toList();
    });
  }

  Future<void> _addCity(String name) async {
    final nm = name.trim();
    if (nm.isEmpty) return;
    if (_cwcResults.any((r) =>
        r.station.city.toLowerCase() == nm.toLowerCase())) {
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
      final result = await _cwcSvc.fetchCity(
        city:  mc['city']  as String,
        state: mc['state'] as String,
        river: mc['river'] as String,
      );
      if (!mounted) return;
      setState(() {
        _cwcResults.insert(0, result);
        _adding      = false;
        _addCityName = '';
        _cwcSearchCtrl.clear();
        _suggestions = [];
      });
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
      backgroundColor:
          isError ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Live Gauges helpers ──────────────────────────────────────────────
  List<FloodData> _filteredLevels(List<FloodData> levels) {
    return levels.where((d) {
      final stateMatch =
          _selectedState == 'All India' || d.state == _selectedState;
      final cityMatch = _selectedCity == null || d.city == _selectedCity;
      final riskMatch = _riskFilter == 'ALL' || d.riskLevel == _riskFilter;
      final q        = _searchQuery.toLowerCase();
      final textMatch = q.isEmpty ||
          d.city.toLowerCase().contains(q) ||
          (d.riverName ?? '').toLowerCase().contains(q) ||
          d.state.toLowerCase().contains(q);
      return stateMatch && cityMatch && riskMatch && textMatch;
    }).toList();
  }

  List<String> _stateList(List<FloodData> levels) {
    final seen = <String>{};
    final out  = <String>['All India'];
    for (final d in levels) {
      if (seen.add(d.state)) out.add(d.state);
    }
    return out;
  }

  Color _riskColor(String risk) {
    switch (risk) {
      case 'CRITICAL': return const Color(0xFFEF4444);
      case 'HIGH':     return const Color(0xFFF97316);
      case 'MODERATE': return const Color(0xFFD4A843);
      default:         return const Color(0xFF22C55E);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // liveLevelsProvider is Provider<List<FloodData>> — NOT AsyncValue.
    // Watch it directly; it is never null (starts as empty list).
    final levels = ref.watch(liveLevelsProvider);

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  // ── Tab 0: Live Gauges ─────────────────────────────────
                  levels.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF00B4C8)))
                    : Builder(builder: (_) {
                        final filtered = _filteredLevels(levels);
                        return Column(
                          children: [
                            _buildLiveFilters(levels),
                            Expanded(child: _buildLiveList(filtered)),
                          ],
                        );
                      }),
                  // ── Tab 1: CWC Stations ────────────────────────────────
                  _buildCwcTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
      child: Row(
        children: [
          const Icon(Icons.water_drop_rounded,
              color: Color(0xFF00B4C8), size: 22),
          const SizedBox(width: 8),
          const Text('India Rivers',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  letterSpacing: -0.5)),
          const Spacer(),
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E)
                    .withValues(alpha: 0.1 + _pulse.value * 0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFF22C55E)
                        .withValues(alpha: 0.5 + _pulse.value * 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF22C55E)
                          .withValues(alpha: _pulse.value),
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text('LIVE',
                      style: TextStyle(
                          color: Color(0xFF22C55E),
                          fontWeight: FontWeight.w700,
                          fontSize: 10)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab bar ───────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
      child: TabBar(
        controller: _tab,
        indicatorColor: _kTeal,
        labelColor: _kTeal,
        unselectedLabelColor: _kGoldDark,
        labelStyle:
            const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.bar_chart_rounded, size: 16),
                const SizedBox(width: 5),
                const Text('Live Gauges'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.sensors_rounded, size: 16),
                const SizedBox(width: 5),
                const Text('CWC Stations'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Live Gauges: filter bar ──────────────────────────────────────────
  Widget _buildLiveFilters(List<FloodData> levels) {
    final states = _stateList(levels);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          // search
          TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search city, river, state…',
              hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
              prefixIcon:
                  const Icon(Icons.search, color: Color(0xFF6A7E98), size: 18),
              filled: true,
              fillColor: _kSurface,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
          const SizedBox(height: 8),
          // risk chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['ALL', 'CRITICAL', 'HIGH', 'MODERATE', 'LOW']
                  .map((r) {
                final active = _riskFilter == r;
                final c = r == 'CRITICAL'
                    ? const Color(0xFFEF4444)
                    : r == 'HIGH'
                        ? const Color(0xFFF97316)
                        : r == 'MODERATE'
                            ? const Color(0xFFD4A843)
                            : r == 'LOW'
                                ? const Color(0xFF22C55E)
                                : _kTeal;
                return GestureDetector(
                  onTap: () => setState(() => _riskFilter = r),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: active
                          ? c.withValues(alpha: 0.18)
                          : _kSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: active
                              ? c.withValues(alpha: 0.55)
                              : Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Text(r,
                        style: TextStyle(
                            color: active ? c : const Color(0xFF6A7E98),
                            fontSize: 11,
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.w500)),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),
          // state chips — tapping any state fires a prefetch for that state
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: states.map((s) {
                final active = _selectedState == s;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedState = s;
                      _selectedCity  = null;
                    });
                    // Prefetch live gauge data for the selected state.
                    // For Bihar this warms all 13 cities in one HTTP call;
                    // for other states it is a no-op until their scraper is added.
                    StateDataPrefetcher.prefetchState(s);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: active
                          ? _kTeal.withValues(alpha: 0.15)
                          : _kSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: active
                              ? _kTeal.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Text(s,
                        style: TextStyle(
                            color: active ? _kTeal : const Color(0xFF6A7E98),
                            fontSize: 11,
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.w500)),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveList(List<FloodData> filtered) {
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                color: Colors.white.withValues(alpha: 0.2), size: 48),
            const SizedBox(height: 12),
            Text('No matching stations',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 14)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      itemCount: filtered.length,
      itemBuilder: (_, i) => _LiveGaugeCard(data: filtered[i]),
    );
  }

  Widget _buildCwcTab() {
    if (_cwcLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF00B4C8)));
    }
    if (_cwcError.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Color(0xFFEF4444), size: 40),
            const SizedBox(height: 12),
            Text(_cwcError,
                style: const TextStyle(
                    color: Color(0xFFEF4444), fontSize: 13)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _fetchCwc,
              child: const Text('Retry',
                  style: TextStyle(color: Color(0xFF00B4C8))),
            ),
          ],
        ),
      );
    }
    final list = _cwcList;
    return Column(
      children: [
        _buildCwcHeader(list),
        _buildCwcAddCity(),
        Expanded(
          child: ListView.builder(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            itemCount: list.length,
            itemBuilder: (_, i) => _CwcStationCard(result: list[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildCwcHeader(List<LiveRiverResult> list) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          Text('${_cwcLive} live',
              style: const TextStyle(
                  color: Color(0xFF22C55E),
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
          const SizedBox(width: 10),
          if (_cwcAtRisk > 0)
            Text('$_cwcAtRisk at risk',
                style: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
          const Spacer(),
          if (_cwcRefreshing)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF00B4C8)),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: Color(0xFF6A7E98), size: 18),
            onPressed: _fetchCwc,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: Icon(
              _cwcSortByRisk
                  ? Icons.sort_rounded
                  : Icons.sort_by_alpha_rounded,
              color: _cwcSortByRisk
                  ? const Color(0xFF00B4C8)
                  : const Color(0xFF6A7E98),
              size: 18,
            ),
            onPressed: () => setState(() => _cwcSortByRisk = !_cwcSortByRisk),
            tooltip: 'Sort by risk',
          ),
        ],
      ),
    );
  }

  Widget _buildCwcAddCity() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cwcSearchCtrl,
                  style:
                      const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Add city…',
                    hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 13),
                    prefixIcon: const Icon(Icons.add_location_alt_rounded,
                        color: Color(0xFF6A7E98), size: 18),
                    filled: true,
                    fillColor: _kSurface,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (v) {
                    _addCityName = v;
                    _cwcSearch(v);
                  },
                  onSubmitted: _addCity,
                ),
              ),
              const SizedBox(width: 8),
              _adding
                  ? const SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Color(0xFF00B4C8)),
                    )
                  : IconButton(
                      icon: const Icon(Icons.add_rounded,
                          color: Color(0xFF00B4C8), size: 22),
                      onPressed: () => _addCity(_addCityName),
                    ),
            ],
          ),
          if (_suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: _kSurface2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(
                children: _suggestions.map((s) {
                  return InkWell(
                    onTap: () {
                      _cwcSearchCtrl.text = s;
                      _addCityName        = s;
                      setState(() => _suggestions = []);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              color: Color(0xFF6A7E98), size: 15),
                          const SizedBox(width: 8),
                          Text(s,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Live Gauge Card ────────────────────────────────────────────────────────────────────
class _LiveGaugeCard extends StatelessWidget {
  const _LiveGaugeCard({required this.data});
  final FloodData data;

  @override
  Widget build(BuildContext context) {
    final risk  = data.riskLevel ?? 'LOW';
    final color = risk == 'CRITICAL' ? const Color(0xFFEF4444)
        : risk == 'HIGH'     ? const Color(0xFFF97316)
        : risk == 'MODERATE' ? const Color(0xFFD4A843)
        : const Color(0xFF22C55E);
    final pct   = data.dangerLevel > 0
        ? (data.currentLevel / data.dangerLevel).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1520),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.city,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                        '${data.state} • ${data.riverName ?? 'River'}',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: color.withValues(alpha: 0.35)),
                ),
                child: Text(risk,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 10)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 5,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _stat('Level', '${data.currentLevel.toStringAsFixed(2)} m'),
              const SizedBox(width: 16),
              _stat('Danger', '${data.dangerLevel.toStringAsFixed(2)} m'),
              if (data.flowRate != null) ...[
                const SizedBox(width: 16),
                _stat('Flow', '${data.flowRate!.toStringAsFixed(0)} m³/s'),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 10)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12)),
        ],
      );
}

// ── CWC Station Card ──────────────────────────────────────────────────────────────────
class _CwcStationCard extends StatelessWidget {
  const _CwcStationCard({required this.result});
  final LiveRiverResult result;

  @override
  Widget build(BuildContext context) {
    final s      = result.station;
    final dc     = s.dangerClass;
    final color  = dc == DangerClass.extreme ? const Color(0xFFEF4444)
        : dc == DangerClass.severe      ? const Color(0xFFF97316)
        : dc == DangerClass.aboveNormal ? const Color(0xFFD4A843)
        : const Color(0xFF22C55E);
    final noData = result.source == 'NO_DATA';

    final levelStr   = result.currentLevel?.toStringAsFixed(2) ?? '—';
    final warningStr = s.warning.toStringAsFixed(2);
    final dangerStr  = s.danger.toStringAsFixed(2);

    return Opacity(
      opacity: noData ? 0.55 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0C1520),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.city,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(
                          '${s.state} • ${s.river}',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 11)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: color.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    noData ? 'NO DATA' : dc.name.toUpperCase(),
                    style: TextStyle(
                        color: color,
                        fontSize: 9,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            if (!noData) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  _stat('Level',   '$levelStr m'),
                  const SizedBox(width: 14),
                  _stat('Warning', '$warningStr m'),
                  const SizedBox(width: 14),
                  _stat('Danger',  '$dangerStr m'),
                ],
              ),
              if (result.mlFloodProb != null) ...[
                const SizedBox(height: 6),
                Text(
                  'ML flood prob: ${(result.mlFloodProb! * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 10)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12)),
        ],
      );
}
