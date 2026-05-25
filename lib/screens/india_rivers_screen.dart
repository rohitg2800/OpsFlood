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
import '../theme/river_theme.dart';
import '../widgets/river_level_visualizer.dart';

// ── palette (shared) ──────────────────────────────────────────────────────────
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

// ── Screen ────────────────────────────────────────────────────────────────────
class IndiaRiversScreen extends ConsumerStatefulWidget {
  const IndiaRiversScreen({super.key});
  @override
  ConsumerState<IndiaRiversScreen> createState() => _IndiaRiversScreenState();
}

class _IndiaRiversScreenState extends ConsumerState<IndiaRiversScreen>
    with TickerProviderStateMixin {

  // ── tab controller (2 tabs) ────────────────────────────────────────────────
  late final TabController       _tab;
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulse;

  // ── Live Gauges filter state ───────────────────────────────────────────────
  String  _selectedState = 'All India';
  String? _selectedCity;
  String  _searchQuery   = '';
  String  _riskFilter    = 'ALL';
  final TextEditingController _searchCtrl = TextEditingController();

  // ── CWC Stations state ─────────────────────────────────────────────────────
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

  // ── CWC fetch ──────────────────────────────────────────────────────────────
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

  // ── CWC helpers ────────────────────────────────────────────────────────────
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

  // ── Live Gauges helpers ────────────────────────────────────────────────────
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

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final lvAsync = ref.watch(liveLevelsProvider);

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
                  lvAsync.when(
                    loading: () => const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF00B4C8))),
                    error: (e, _) => Center(
                        child: Text('Error: $e',
                            style: const TextStyle(
                                color: Color(0xFFEF4444)))),
                    data: (levels) {
                      final filtered = _filteredLevels(levels);
                      return Column(
                        children: [
                          _buildLiveFilters(levels),
                          Expanded(child: _buildLiveList(filtered)),
                        ],
                      );
                    },
                  ),
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

  // ── Tab bar ────────────────────────────────────────────────────────────────
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

  // ── Live Gauges: filter bar ────────────────────────────────────────────────
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
          // state chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: states.map((s) {
                final active = _selectedState == s;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedState = s;
                    _selectedCity  = null;
                  }),
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

  // ── Live Gauges: list ──────────────────────────────────────────────────────
  Widget _buildLiveList(List<FloodData> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.water_drop_outlined,
                color: _kTeal.withValues(alpha: 0.4), size: 40),
            const SizedBox(height: 12),
            const Text('No matching stations',
                style: TextStyle(color: Color(0xFF6A7E98), fontSize: 14)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: items.length,
      itemBuilder: (ctx, i) => _LiveCard(item: items[i]),
    );
  }

  // ── CWC tab ────────────────────────────────────────────────────────────────
  Widget _buildCwcTab() {
    return Column(
      children: [
        // stats row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: [
              _CwcStat('${_cwcResults.length}', 'Total', _kTeal),
              const SizedBox(width: 10),
              _CwcStat('$_cwcLive', 'Live', const Color(0xFF22C55E)),
              const SizedBox(width: 10),
              _CwcStat('$_cwcAtRisk', 'At Risk', const Color(0xFFF97316)),
              const Spacer(),
              // sort toggle
              GestureDetector(
                onTap: () =>
                    setState(() => _cwcSortByRisk = !_cwcSortByRisk),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _cwcSortByRisk
                        ? _kGold.withValues(alpha: 0.15)
                        : _kSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: _cwcSortByRisk
                            ? _kGold.withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sort_rounded,
                          color:
                              _cwcSortByRisk ? _kGold : const Color(0xFF6A7E98),
                          size: 14),
                      const SizedBox(width: 4),
                      Text('By Risk',
                          style: TextStyle(
                              color: _cwcSortByRisk
                                  ? _kGold
                                  : const Color(0xFF6A7E98),
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // add city bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cwcSearchCtrl,
                  style:
                      const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Add city from CWC registry…',
                    hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 13),
                    prefixIcon: const Icon(Icons.add_location_alt_outlined,
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
                    setState(() => _addCityName = v);
                    _cwcSearch(v);
                  },
                  onSubmitted: _addCity,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _fetchCwc();
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _kSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: _cwcRefreshing
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF00B4C8)))
                      : const Icon(Icons.refresh_rounded,
                          color: Color(0xFF6A7E98), size: 18),
                ),
              ),
            ],
          ),
        ),
        // suggestions
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            decoration: BoxDecoration(
              color: _kSurface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              children: _suggestions
                  .map((s) => ListTile(
                        dense: true,
                        title: Text(s,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13)),
                        leading: const Icon(Icons.location_city,
                            color: Color(0xFF00B4C8), size: 16),
                        trailing: _adding
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF22C55E)))
                            : null,
                        onTap: () => _addCity(s),
                      ))
                  .toList(),
            ),
          ),
        // state filter
        if (_cwcStateList.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () =>
                      setState(() => _cwcFilterState = ''),
                  child: _StateChip(
                      label: 'All', active: _cwcFilterState.isEmpty),
                ),
                ..._cwcStateList.map((s) => GestureDetector(
                      onTap: () =>
                          setState(() => _cwcFilterState = s),
                      child: _StateChip(
                          label: s,
                          active: _cwcFilterState == s),
                    )),
              ],
            ),
          ),
        // list
        Expanded(
          child: _cwcLoading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF00B4C8)))
              : _cwcError.isNotEmpty
                  ? Center(
                      child: Text('Error: $_cwcError',
                          style: const TextStyle(
                              color: Color(0xFFEF4444))))
                  : _cwcList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.sensors_off,
                                  color:
                                      _kGold.withValues(alpha: 0.4),
                                  size: 36),
                              const SizedBox(height: 10),
                              const Text('No stations loaded',
                                  style: TextStyle(
                                      color: Color(0xFF6A7E98),
                                      fontSize: 13)),
                              const SizedBox(height: 6),
                              const Text(
                                  'Use the search bar above to add cities',
                                  style: TextStyle(
                                      color: Color(0xFF4A5A6A),
                                      fontSize: 11)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: _cwcList.length,
                          itemBuilder: (ctx, i) =>
                              _CwcCard(result: _cwcList[i]),
                        ),
        ),
      ],
    );
  }
}

// ── Live gauge card ────────────────────────────────────────────────────────────
class _LiveCard extends StatelessWidget {
  final FloodData item;
  const _LiveCard({required this.item});

  Color get _riskColor {
    switch (item.riskLevel) {
      case 'CRITICAL': return const Color(0xFFEF4444);
      case 'HIGH':     return const Color(0xFFF97316);
      case 'MODERATE': return const Color(0xFFD4A843);
      default:         return const Color(0xFF22C55E);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c   = _riskColor;
    final pct = item.capacityPercent / 100;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1520),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: c.withValues(alpha: 0.06),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── header row ───────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.city,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      '${item.state}${item.riverName != null ? ' · ${item.riverName}' : ''}',
                      style: const TextStyle(
                          color: Color(0xFF6A7E98), fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: c.withValues(alpha: 0.4)),
                ),
                child: Text(item.riskLevel,
                    style: TextStyle(
                        color: c,
                        fontWeight: FontWeight.w700,
                        fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ── RiverLevelVisualizer (new API) ───────────────────────────
          RiverLevelVisualizer(
            cityName: item.city,
            current:  item.currentLevel,
            warning:  item.warningLevel,
            danger:   item.dangerLevel,
            hfl:      item.dangerLevel,
            history:  const [],
          ),
          const SizedBox(height: 12),
          // ── capacity bar ─────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Capacity ${item.capacityPercent.toStringAsFixed(0)}%',
                  style: const TextStyle(
                      color: Color(0xFF6A7E98), fontSize: 10)),
              Text(
                'W: ${item.warningLevel.toStringAsFixed(1)} m  '
                'D: ${item.dangerLevel.toStringAsFixed(1)} m',
                style: const TextStyle(
                    color: Color(0xFF6A7E98), fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor:
                  Colors.white.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation<Color>(c),
            ),
          ),
        ],
      ),
    );
  }
}

// ── CWC station card ──────────────────────────────────────────────────────────
class _CwcCard extends StatelessWidget {
  final LiveRiverResult result;
  const _CwcCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final st  = result.station;
    final dc  = st.dangerClass;
    final col = _dcColors[dc] ?? const Color(0xFF22C55E);
    final hasLevel = result.currentLevel != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1520),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: col.withValues(alpha: 0.22)),
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
                    Text(st.city,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('${st.state} · ${st.river}',
                        style: const TextStyle(
                            color: Color(0xFF6A7E98), fontSize: 11)),
                  ],
                ),
              ),
              // source badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (result.source == 'NO_DATA'
                          ? const Color(0xFF6A7E98)
                          : col)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: (result.source == 'NO_DATA'
                              ? const Color(0xFF6A7E98)
                              : col)
                          .withValues(alpha: 0.35)),
                ),
                child: Text(
                  result.source == 'NO_DATA' ? 'NO DATA' : result.source,
                  style: TextStyle(
                      color: result.source == 'NO_DATA'
                          ? const Color(0xFF6A7E98)
                          : col,
                      fontSize: 9,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (hasLevel) ...
          [
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  '${result.currentLevel!.toStringAsFixed(2)} m',
                  style: TextStyle(
                      color: col,
                      fontWeight: FontWeight.w800,
                      fontSize: 18),
                ),
                const SizedBox(width: 8),
                Text(
                  dc == DangerClass.normal
                      ? 'Normal'
                      : dc == DangerClass.aboveNormal
                          ? 'Above Normal'
                          : dc == DangerClass.severe
                              ? 'Severe'
                              : 'Extreme',
                  style: TextStyle(
                      color: col.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
          if (result.mlFloodProb != null) ...
          [
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.auto_graph_rounded,
                    color: Color(0xFF8B5CF6), size: 13),
                const SizedBox(width: 4),
                Text(
                  'ML Flood Risk: ${(result.mlFloodProb! * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                      color: Color(0xFF8B5CF6),
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
          if (result.trend != null) ...
          [
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  result.trend == 'rising'
                      ? Icons.trending_up
                      : result.trend == 'falling'
                          ? Icons.trending_down
                          : Icons.trending_flat,
                  color: result.trend == 'rising'
                      ? const Color(0xFFEF4444)
                      : result.trend == 'falling'
                          ? const Color(0xFF22C55E)
                          : const Color(0xFF6A7E98),
                  size: 13,
                ),
                const SizedBox(width: 4),
                Text(
                  result.trend!,
                  style: TextStyle(
                      color: result.trend == 'rising'
                          ? const Color(0xFFEF4444)
                          : result.trend == 'falling'
                              ? const Color(0xFF22C55E)
                              : const Color(0xFF6A7E98),
                      fontSize: 11),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
class _CwcStat extends StatelessWidget {
  final String value;
  final String label;
  final Color  color;
  const _CwcStat(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 18)),
        Text(label,
            style: const TextStyle(
                color: Color(0xFF6A7E98), fontSize: 10)),
      ],
    );
  }
}

class _StateChip extends StatelessWidget {
  final String label;
  final bool   active;
  const _StateChip({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 8),
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFF00B4C8).withValues(alpha: 0.15)
            : const Color(0xFF0C1520),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: active
                ? const Color(0xFF00B4C8).withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.07)),
      ),
      child: Text(label,
          style: TextStyle(
              color: active
                  ? const Color(0xFF00B4C8)
                  : const Color(0xFF6A7E98),
              fontSize: 11,
              fontWeight:
                  active ? FontWeight.w700 : FontWeight.w500)),
    );
  }
}
