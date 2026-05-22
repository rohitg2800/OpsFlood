// lib/screens/india_rivers_screen.dart
// OpsFlood — India Rivers (merged Live Gauges + CWC Stations)
//
// Tab 0 — Live Gauges : OpsFlood backend via Riverpod liveLevelsProvider
//          State/city/risk/search filters + FloodGauge + sparkline
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
import '../widgets/flood_gauge.dart';
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

  // ── tab controller (2 tabs) ───────────────────────────────────────────────
  late final TabController      _tab;
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulse;

  // ── Live Gauges filter state ──────────────────────────────────────────────
  String _selectedState = 'All India';
  String? _selectedCity;
  String _searchQuery  = '';
  String _riskFilter   = 'ALL';
  final TextEditingController _searchCtrl = TextEditingController();

  // ── CWC Stations state ────────────────────────────────────────────────────
  final _cwcSvc        = RealTimeRiverService();
  final _cwcSearchCtrl = TextEditingController();
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

  // ── CWC fetch ─────────────────────────────────────────────────────────────
  Future<void> _fetchCwc({bool silent = false}) async {
    if (!mounted) return;
    setState(() {
      if (!silent) _cwcLoading = true;
      else         _cwcRefreshing = true;
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

  // ── CWC helpers ───────────────────────────────────────────────────────────
  List<LiveRiverResult> get _cwcList {
    var l = List<LiveRiverResult>.from(_cwcResults);
    if (_cwcFilterState.isNotEmpty)
      l = l.where((r) => r.station.state == _cwcFilterState).toList();
    if (_cwcSortByRisk)
      l.sort((a, b) {
        final rc = b.station.riskScore.compareTo(a.station.riskScore);
        return rc != 0 ? rc : (b.mlFloodProb ?? 0).compareTo(a.mlFloodProb ?? 0);
      });
    return l;
  }

  int get _cwcLive    => _cwcResults.where((r) => r.source != 'NO_DATA').length;
  int get _cwcAtRisk  => _cwcResults.where((r) =>
      r.station.dangerClass != DangerClass.normal && r.source != 'NO_DATA').length;
  int get _cwcNoData  => _cwcResults.where((r) => r.source == 'NO_DATA').length;

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
    final lq = q.toLowerCase();
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
        _adding = false;
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
      backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Live Gauges helpers ───────────────────────────────────────────────────
  List<FloodData> _filteredLevels(List<FloodData> levels) {
    return levels.where((d) {
      final stateMatch = _selectedState == 'All India' || d.state == _selectedState;
      final cityMatch  = _selectedCity == null || d.city == _selectedCity;
      final riskMatch  = _riskFilter == 'ALL' || d.riskLevel == _riskFilter;
      final q = _searchQuery.toLowerCase();
      final textMatch  = q.isEmpty ||
          d.city.toLowerCase().contains(q) ||
          (d.riverName ?? '').toLowerCase().contains(q) ||
          d.state.toLowerCase().contains(q);
      return stateMatch && cityMatch && riskMatch && textMatch;
    }).toList()
      ..sort((a, b) => b.capacityPercent.compareTo(a.capacityPercent));
  }

  List<String> get _citiesForState {
    if (_selectedState == 'All India') return [];
    return AppConstants.monitoredCities
        .where((m) => m['state'] == _selectedState)
        .map<String>((m) => m['city'] as String)
        .toSet()
        .toList()
      ..sort();
  }

  Color _riskColor(String risk) {
    final rc = RiverColors.of(context);
    switch (risk) {
      case 'CRITICAL': return rc.riverCritical;
      case 'HIGH':     return rc.riverDanger;
      case 'MODERATE': return rc.riverWarning;
      default:         return rc.riverNormal;
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final liveLevels    = ref.watch(liveLevelsProvider);
    final lastFetchTime = ref.watch(lastFetchTimeProvider);
    final svc           = ref.read(realTimeProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _kBg,
        body: SafeArea(
          child: Column(children: [
            _header(liveLevels),
            _tabBar(),
            if (_cwcRefreshing)
              LinearProgressIndicator(
                backgroundColor: _kGold.withOpacity(0.08),
                valueColor: const AlwaysStoppedAnimation(_kGold),
                minHeight: 2,
              ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _liveGaugesTab(liveLevels, lastFetchTime, svc),
                  _cwcStationsTab(),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Shared header ─────────────────────────────────────────────────────────
  Widget _header(List<FloodData> levels) => Container(
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
          boxShadow: [BoxShadow(
              color: _kGold.withOpacity(0.35), blurRadius: 16, spreadRadius: 2)],
        ),
        child: const Icon(Icons.water_rounded, color: Color(0xFF060B12), size: 26),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ShaderMask(
          shaderCallback: (b) =>
              const LinearGradient(colors: [_kGoldLight, _kGold]).createShader(b),
          child: const Text('India Rivers',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                  color: Colors.white, letterSpacing: 0.5)),
        ),
        const Text('OpsFlood · CWC Live Telemetry',
            style: TextStyle(fontSize: 10, color: Color(0xFF7B8A99), letterSpacing: 0.4)),
      ])),
      // Live Gauges count
      AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _kTeal.withOpacity(0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kTeal.withOpacity(0.35 * _pulse.value)),
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
            Text('${levels.length} LIVE',
                style: const TextStyle(
                    color: _kTeal, fontSize: 10, fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
      const SizedBox(width: 6),
      _GoldChip(label: '$_cwcLive', sublabel: 'CWC'),
      if (_cwcAtRisk > 0) ...[
        const SizedBox(width: 6),
        _GoldChip(label: '$_cwcAtRisk', sublabel: 'at risk',
            color: const Color(0xFFF97316)),
      ],
    ]),
  );

  // ── Tab bar ───────────────────────────────────────────────────────────────
  Widget _tabBar() => Padding(
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
        labelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        tabs: const [
          Tab(text: '  Live Gauges  '),
          Tab(text: '  CWC Stations  '),
        ],
      ),
    ),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 0 — Live Gauges (OpsFlood backend via Riverpod)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _liveGaugesTab(
    List<FloodData> levels,
    DateTime? lastFetchTime,
    dynamic svc,
  ) {
    final rc   = RiverColors.of(context);
    final rows = _filteredLevels(levels);

    return Column(children: [
      // ── filter bar ─────────────────────────────────────────────────────
      Container(
        color: _kBg,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(children: [
          // Search
          Container(
            decoration: BoxDecoration(
              color: _kSurface2, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBorder),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search city, river, state…',
                hintStyle: const TextStyle(color: Color(0xFF3A4A58), fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: _kGold, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded,
                            color: Color(0xFF7B8A99), size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
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
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // State + city dropdowns
          Row(children: [
            Expanded(
              child: _GoldDropdown(
                value: _selectedState,
                items: AppConstants.indianStates,
                hint: 'State',
                onChanged: (v) => setState(() {
                  _selectedState = v ?? 'All India';
                  _selectedCity  = null;
                }),
              ),
            ),
            if (_citiesForState.isNotEmpty) ...[
              const SizedBox(width: 8),
              Expanded(
                child: _GoldDropdown(
                  value: _selectedCity,
                  items: ['All Cities', ..._citiesForState],
                  hint: 'City',
                  onChanged: (v) => setState(() {
                    _selectedCity =
                        (v == null || v == 'All Cities') ? null : v;
                  }),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 8),
          // Risk filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['ALL', 'LOW', 'MODERATE', 'HIGH', 'CRITICAL']
                  .map((lvl) {
                final sel = _riskFilter == lvl;
                final c   = lvl == 'ALL' ? _kTeal : _riskColor(lvl);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _riskFilter = lvl),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? c.withOpacity(0.20) : Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: sel ? c : Colors.white.withOpacity(0.12),
                          width: sel ? 1.5 : 1.0,
                        ),
                      ),
                      child: Text(lvl,
                          style: TextStyle(
                              color: sel ? c : const Color(0xFF7B8A99),
                              fontWeight: sel
                                  ? FontWeight.w800 : FontWeight.w400,
                              fontSize: 12)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ]),
      ),

      // ── list ───────────────────────────────────────────────────────────
      Expanded(
        child: rows.isEmpty
            ? Center(
                child: Text('No rivers match the current filter.',
                    style: TextStyle(
                        color: rc.textSecondary, fontSize: 13)))
            : RefreshIndicator(
                color: _kGold,
                backgroundColor: _kSurface2,
                onRefresh: () => ref.read(realTimeProvider).refreshData(),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
                  itemCount: rows.length,
                  itemBuilder: (ctx, i) => _GaugeCard(
                    data:  rows[i],
                    svc:   svc,
                    lastFetch: lastFetchTime,
                  ),
                ),
              ),
      ),
    ]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 1 — CWC Stations (RealTimeRiverService)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _cwcStationsTab() {
    if (_cwcLoading) return _cwcShimmer();
    return RefreshIndicator(
      color: _kGold, backgroundColor: _kSurface2,
      onRefresh: _fetchCwc,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (_cwcError.isNotEmpty)
            SliverToBoxAdapter(child: _cwcErrorBanner()),
          SliverToBoxAdapter(child: _cwcFilterSortBar()),
          SliverToBoxAdapter(child: _cwcLegend()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: GestureDetector(
                onTap: () => _showAddCitySheet(),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [_kGoldLight, _kGold, _kGoldDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(
                        color: _kGold.withOpacity(0.30),
                        blurRadius: 14, spreadRadius: 1)],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_location_alt_rounded,
                          size: 18, color: Color(0xFF060B12)),
                      SizedBox(width: 8),
                      Text('Add City',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w800,
                              color: Color(0xFF060B12))),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverList(delegate: SliverChildBuilderDelegate(
            (ctx, i) {
              final r = _cwcList[i];
              return _CwcCard(
                key:      ValueKey('${r.station.city}_${r.station.state}'),
                result:   r,
                index:    i,
                onDelete: () => setState(() => _cwcResults.remove(r)),
              );
            },
            childCount: _cwcList.length,
          )),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _cwcErrorBanner() => Container(
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
        onTap: _fetchCwc,
        child: const Text('Retry', style: TextStyle(
            color: _kGold, fontSize: 11, fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline, decorationColor: _kGold)),
      ),
    ]),
  );

  Widget _cwcFilterSortBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
    child: Row(children: [
      Text('${_cwcList.length} / ${_cwcResults.length}',
          style: const TextStyle(fontSize: 12, color: Color(0xFF7B8A99))),
      const SizedBox(width: 6),
      const Text('stations',
          style: TextStyle(fontSize: 11, color: Color(0xFF3A4A58))),
      const Spacer(),
      GestureDetector(
        onTap: () async {
          final states = ['All States', ..._cwcStateList];
          final picked = await showModalBottomSheet<String>(
            context: context,
            backgroundColor: _kSurface,
            shape: const RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(20))),
            builder: (_) => ListView(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 0, 10),
                  child: Text('Filter by State',
                      style: TextStyle(
                          color: _kGoldLight,
                          fontSize: 14, fontWeight: FontWeight.w800)),
                ),
                ...states.map((st) => ListTile(
                  dense: true,
                  title: Text(st,
                      style: TextStyle(
                          color: st ==
                                  (_cwcFilterState.isEmpty
                                      ? 'All States'
                                      : _cwcFilterState)
                              ? _kGold
                              : Colors.white,
                          fontSize: 13,
                          fontWeight: st ==
                                  (_cwcFilterState.isEmpty
                                      ? 'All States'
                                      : _cwcFilterState)
                              ? FontWeight.w800
                              : FontWeight.w400)),
                  trailing: st ==
                          (_cwcFilterState.isEmpty
                              ? 'All States'
                              : _cwcFilterState)
                      ? const Icon(Icons.check_rounded,
                          color: _kGold, size: 16)
                      : null,
                  onTap: () => Navigator.pop(context, st),
                )),
              ],
            ),
          );
          if (picked != null)
            setState(() =>
                _cwcFilterState = picked == 'All States' ? '' : picked);
        },
        child: _FilterPill(
          icon: Icons.filter_list_rounded,
          label: _cwcFilterState.isNotEmpty
              ? _cwcFilterState.split(' ').first
              : 'State',
          active: _cwcFilterState.isNotEmpty,
        ),
      ),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: () => setState(() => _cwcSortByRisk = !_cwcSortByRisk),
        child: _FilterPill(
          icon: Icons.sort_rounded,
          label: _cwcSortByRisk ? 'By risk' : 'Sort',
          active: _cwcSortByRisk,
        ),
      ),
    ]),
  );

  Widget _cwcLegend() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    child: Wrap(spacing: 12, runSpacing: 4, children: [
      _LegendDot(color: _dcColors[DangerClass.normal]!,      label: 'Normal'),
      _LegendDot(color: _dcColors[DangerClass.aboveNormal]!, label: 'Above Normal'),
      _LegendDot(color: _dcColors[DangerClass.severe]!,      label: 'Severe'),
      _LegendDot(color: _dcColors[DangerClass.extreme]!,     label: 'Extreme'),
    ]),
  );

  Widget _cwcShimmer() => ListView.builder(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
    itemCount: 10,
    itemBuilder: (_, i) => _ShimmerCard(delay: i * 80),
  );

  // ── Add City sheet ────────────────────────────────────────────────────────
  void _showAddCitySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kSurface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Add City to Monitor',
                  style: TextStyle(
                      color: _kGoldLight,
                      fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text(
                'Live CWC data fetched immediately.\n'
                'NO DATA shown if gauge has no reading — never synthetic.',
                style: TextStyle(
                    color: Color(0xFF7B8A99), fontSize: 11, height: 1.5)),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: _kSurface2, borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kBorder),
                ),
                child: TextField(
                  controller: _cwcSearchCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  onChanged: (v) {
                    _addCityName = v;
                    _cwcSearch(v);
                    setSheet(() {});
                    setState(() {});
                  },
                  decoration: InputDecoration(
                    hintText: 'Search city  e.g. Patna, Guwahati…',
                    hintStyle: const TextStyle(
                        color: Color(0xFF3A4A58), fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: _kGold, size: 20),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: _kGold, width: 1.5)),
                    filled: true, fillColor: Colors.transparent,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              if (_suggestions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: _kSurface2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Column(
                    children: _suggestions.asMap().entries.map((e) {
                      final city = e.value;
                      final mc   = AppConstants.monitoredCities.firstWhere(
                          (m) => m['city'] == city, orElse: () => {});
                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          _cwcSearchCtrl.text = city;
                          setSheet(() => _suggestions = []);
                          setState(() {
                            _addCityName = city;
                            _suggestions = [];
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(children: [
                            Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                color: _kGold.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(9)),
                              child: const Icon(Icons.water_rounded,
                                  color: _kGold, size: 16)),
                            const SizedBox(width: 12),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(city, style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13)),
                                Text(
                                    '${mc['state'] ?? ''} · ${mc['river'] ?? ''}',
                                    style: const TextStyle(
                                        color: Color(0xFF7B8A99), fontSize: 10),
                                    overflow: TextOverflow.ellipsis),
                              ],
                            )),
                            const Icon(Icons.add_circle_outline_rounded,
                                color: _kGold, size: 18),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              GestureDetector(
                onTap: (_addCityName.trim().isEmpty || _adding)
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        await _addCity(_addCityName);
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: (_addCityName.trim().isEmpty || _adding)
                        ? LinearGradient(colors: [
                            Colors.white.withOpacity(0.05),
                            Colors.white.withOpacity(0.05)
                          ])
                        : const LinearGradient(
                            colors: [_kGoldLight, _kGold, _kGoldDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: _adding
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation(
                                    Color(0xFF060B12))))
                        : Row(mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_location_alt_rounded,
                                  size: 20,
                                  color: _addCityName.trim().isEmpty
                                      ? const Color(0xFF3A4A58)
                                      : const Color(0xFF060B12)),
                              const SizedBox(width: 8),
                              Text('Fetch Live & Add',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: _addCityName.trim().isEmpty
                                          ? const Color(0xFF3A4A58)
                                          : const Color(0xFF060B12))),
                            ]),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live Gauge Card (Tab 0 — OpsFlood backend)
// ─────────────────────────────────────────────────────────────────────────────
class _GaugeCard extends StatelessWidget {
  const _GaugeCard({
    required this.data,
    required this.svc,
    required this.lastFetch,
  });
  final FloodData data;
  final dynamic   svc;
  final DateTime? lastFetch;

  @override
  Widget build(BuildContext context) {
    final rc      = RiverColors.of(context);
    final history = svc.trendForCity(data.city) as List<RiverLevelSnapshot>;
    final danger  = data.capacityPercent >= 85.0;

    Color statusColor;
    switch (data.riskLevel) {
      case 'CRITICAL': statusColor = rc.riverCritical; break;
      case 'HIGH':     statusColor = rc.riverDanger;   break;
      case 'MODERATE': statusColor = rc.riverWarning;  break;
      default:         statusColor = rc.riverNormal;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: danger
              ? rc.riverDanger.withOpacity(0.65)
              : statusColor.withOpacity(0.28),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // City / river / state header
            Row(children: [
              Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                      color: statusColor, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data.city,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  Text('${data.riverName ?? 'River'} · ${data.state}',
                      style: TextStyle(
                          color: rc.textSecondary, fontSize: 12)),
                ],
              )),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: statusColor.withOpacity(0.5)),
                ),
                child: Text(data.riskLevel,
                    style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 11)),
              ),
            ]),
            const SizedBox(height: 12),
            // Visualizer + gauge
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
                  width: 96,
                  child: FloodGauge(
                    capacity: data.capacityPercent,
                    riskLevel: data.riskLevel,
                    size: 96,
                    label: '${data.capacityPercent.toStringAsFixed(0)}%',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Danger / warning chips
            Wrap(spacing: 6, runSpacing: 6, children: [
              _SmallChip(
                icon: Icons.warning_amber_rounded,
                text: 'Danger: ${data.dangerLevel.toStringAsFixed(1)} m',
                color: rc.riverDanger,
              ),
              _SmallChip(
                icon: Icons.timeline,
                text: 'Warning: ${data.warningLevel.toStringAsFixed(1)} m',
                color: rc.riverWarning,
              ),
            ]),
            const SizedBox(height: 10),
            // Sparkline
            SizedBox(
              height: 58,
              child: _Sparkline(
                history: history,
                warningLevel: data.warningLevel,
                dangerLevel: data.dangerLevel,
                lineColor: rc.sparklineColor,
              ),
            ),
            if (lastFetch != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Updated ${DateFormat('HH:mm').format(lastFetch!.toLocal())}',
                  style:
                      TextStyle(color: rc.textSecondary, fontSize: 10),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CWC Station Card (Tab 1)
// ─────────────────────────────────────────────────────────────────────────────
class _CwcCard extends StatefulWidget {
  final LiveRiverResult result;
  final int             index;
  final VoidCallback    onDelete;
  const _CwcCard({
    super.key,
    required this.result,
    required this.index,
    required this.onDelete,
  });
  @override State<_CwcCard> createState() => _CwcCardState();
}

class _CwcCardState extends State<_CwcCard>
    with SingleTickerProviderStateMixin {
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.city, style: const TextStyle(
                    color: Color(0xFF7B8A99),
                    fontWeight: FontWeight.w700, fontSize: 14)),
                Text('${s.river} · ${s.state}',
                    style: const TextStyle(
                        color: Color(0xFF3A4A58), fontSize: 10)),
              ],
            )),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF3A4A58).withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF3A4A58)),
              ),
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

    final col = _dcColors[dc]!;
    final pct = s.progressPct;

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
            border: Border.all(color: col.withOpacity(0.22)),
            boxShadow: [
              BoxShadow(
                  color: col.withOpacity(0.06), blurRadius: 16,
                  offset: const Offset(0, 4)),
              BoxShadow(color: _kGold.withOpacity(0.04), blurRadius: 24),
            ],
          ),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                        colors: [col.withOpacity(0.35), col.withOpacity(0.05)]),
                    shape: BoxShape.circle,
                    border: Border.all(color: col.withOpacity(0.45), width: 1.5),
                  ),
                  child: Icon(_dcIcon(dc), color: col, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: col.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: col.withOpacity(0.4))),
                    child: Text(dc.label,
                        style: TextStyle(
                            color: col, fontSize: 10,
                            fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: widget.onDelete,
                    child: const Icon(Icons.remove_circle_outline,
                        size: 16, color: Color(0xFF3A4A58))),
                ]),
              ]),
            ),
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
                              color: col, fontSize: 18,
                              fontWeight: FontWeight.w900),
                          overflow: TextOverflow.ellipsis)),
                      Text('HFL ${s.hfl.toStringAsFixed(1)} m',
                          style: const TextStyle(
                              color: Color(0xFF7B8A99), fontSize: 10)),
                    ],
                  ),
                  const SizedBox(height: 6),
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
                              colors: [col.withOpacity(0.7), col],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [BoxShadow(
                              color: col.withOpacity(0.5), blurRadius: 6)],
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
            if (r.mlRiskLevel != null) ...[
              const SizedBox(height: 8),
              Divider(height: 1,
                  color: _kGold.withOpacity(0.08), indent: 14, endIndent: 14),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                child: Row(children: [
                  const Text('\uD83E\uDD16 AI',
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
            const SizedBox(height: 6),
            Divider(height: 1,
                color: _kGold.withOpacity(0.08), indent: 14, endIndent: 14),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                if (s.trend != null)
                  _Pill(
                      icon: _ti(s.trend!), label: s.trend!,
                      color: _tc(s.trend!)),
                if (s.rainfallLastHour != null && s.rainfallLastHour! > 0)
                  _Pill(
                      icon: '\uD83C\uDF27',
                      label: '${s.rainfallLastHour!.toStringAsFixed(1)} mm/hr',
                      color: const Color(0xFF60A5FA)),
                if (s.flowRate != null && s.flowRate! > 0)
                  _Pill(
                      icon: '\uD83D\uDCA7',
                      label: '${s.flowRate!.toStringAsFixed(0)} m\u00B3/s',
                      color: _kTeal),
                if (s.liveStatus != null)
                  _Pill(
                      icon: '\uD83D\uDCE1',
                      label: s.liveStatus!,
                      color: _sc(s.liveStatus!)),
                if (s.lastUpdated != null)
                  _Pill(
                      icon: '\uD83D\uDD50',
                      label: _shortTime(s.lastUpdated!),
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
      t == 'RISING' ? '\u2191' : t == 'FALLING' ? '\u2193' : '\u2192';
  Color  _tc(String t) => t == 'RISING'
      ? const Color(0xFFEF4444)
      : t == 'FALLING' ? const Color(0xFF22C55E) : const Color(0xFFF59E0B);
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

// ─────────────────────────────────────────────────────────────────────────────
// Shared atoms
// ─────────────────────────────────────────────────────────────────────────────
class _SourceBadge extends StatelessWidget {
  final String source;
  final double confidence;
  const _SourceBadge({required this.source, required this.confidence});
  @override Widget build(BuildContext context) {
    final (label, color) = switch (source) {
      'TELEMETRY'   => ('CWC',  const Color(0xFF00B4C8)),
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
            color: Color(0xFFEF4444), fontSize: 8,
            fontWeight: FontWeight.w800)),
  );
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({
      required this.icon, required this.text, required this.color});
  final IconData icon;
  final String   text;
  final Color    color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _kSurface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(
              color: const Color(0xFF7B8A99), fontSize: 11)),
        ],
      ),
    );
  }
}

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
  final Color  lineColor;
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
    final clipped = pts.length > 24 ? pts.sublist(pts.length - 24) : pts;
    final spots = List.generate(
        clipped.length, (i) => FlSpot(i.toDouble(), clipped[i].level));
    return LineChart(LineChartData(
      minY: 0,
      gridData: const FlGridData(show: false),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(
          show: true,
          border: Border.all(color: lineColor.withOpacity(0.15))),
      lineBarsData: [
        LineChartBarData(
          spots: spots, isCurved: true, barWidth: 2,
          color: lineColor, dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
              show: true, color: lineColor.withOpacity(0.18)),
        ),
      ],
      extraLinesData: ExtraLinesData(horizontalLines: [
        HorizontalLine(
            y: warningLevel, color: const Color(0xFFF59E0B),
            strokeWidth: 1, dashArray: [4, 4]),
        HorizontalLine(
            y: dangerLevel, color: const Color(0xFFEF4444),
            strokeWidth: 1.1, dashArray: [5, 4]),
      ]),
    ));
  }
}

class _GoldDropdown extends StatelessWidget {
  const _GoldDropdown({
    required this.value, required this.items,
    required this.hint,  required this.onChanged,
  });
  final String?            value;
  final List<String>       items;
  final String             hint;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: _kSurface2,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _kBorder),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: items.contains(value) ? value : null,
        hint: Text(hint, style: const TextStyle(
            color: Color(0xFF7B8A99), fontSize: 13)),
        isExpanded: true,
        dropdownColor: _kSurface,
        iconEnabledColor: _kGold,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        items: items.map((s) =>
            DropdownMenuItem(value: s, child: Text(s))).toList(),
        onChanged: onChanged,
      ),
    ),
  );
}

class _FilterPill extends StatelessWidget {
  final IconData icon;
  final String   label;
  final bool     active;
  const _FilterPill({
      required this.icon, required this.label, required this.active});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: active ? _kGold.withOpacity(0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
          color: active ? _kGold.withOpacity(0.4) : const Color(0xFF2A3A4A)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13,
          color: active ? _kGold : const Color(0xFF7B8A99)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600,
          color: active ? _kGold : const Color(0xFF7B8A99))),
    ]),
  );
}

class _Pill extends StatelessWidget {
  final String icon, label;
  final Color  color;
  const _Pill({
      required this.icon, required this.label, required this.color});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.3))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(icon, style: const TextStyle(fontSize: 10)),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    ]),
  );
}

class _GoldChip extends StatelessWidget {
  final String label, sublabel;
  final Color? color;
  const _GoldChip({
      required this.label, required this.sublabel, this.color});
  @override Widget build(BuildContext context) {
    final c = color ?? _kGold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: c.withOpacity(0.10), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withOpacity(0.3))),
      child: Column(children: [
        Text(label, style: TextStyle(
            color: c, fontSize: 14,
            fontWeight: FontWeight.w900, height: 1.1)),
        Text(sublabel, style: const TextStyle(
            color: Color(0xFF7B8A99),
            fontSize: 8, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color; final String label;
  const _LegendDot({required this.color, required this.label});
  @override Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            color: color, shape: BoxShape.circle,
            boxShadow: [BoxShadow(
                color: color.withOpacity(0.5), blurRadius: 4)]),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(
            fontSize: 10, color: Color(0xFF7B8A99))),
      ]);
}

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
        vsync: this,
        duration: const Duration(milliseconds: 1400))..repeat();
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
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment(_anim.value - 1, 0),
          end:   Alignment(_anim.value + 1, 0),
          colors: [_kSurface, _kGold.withOpacity(0.07), _kSurface],
        ),
        border: Border.all(color: _kBorder),
      ),
    ),
  );
}
