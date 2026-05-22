// lib/screens/river_monitor_screen.dart
// OpsFlood — River Monitor v3.1  (Rolls-Royce dark-gold theme)
// FIXES v3.1:
//  1. _seedStations: seed current = wl (not wl*0.88) — accurate baseline
//  2. _findMatch: expands scorer to river_name, station sub-tokens, river key
//  3. _applyLive: reads water_level / gauge_reading / hfl_level variants;
//                 also applies live warning/danger/hfl when non-zero
//  4. _extractList: one extra recursion level to unwrap {data:{levels:[...]}}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants.dart';
import '../models/river_station.dart';
import '../services/api_service.dart';

// ─── Palette ────────────────────────────────────────────────────────────────
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

// ─── Screen ──────────────────────────────────────────────────────────────────
class RiverMonitorScreen extends StatefulWidget {
  const RiverMonitorScreen({super.key});
  @override
  State<RiverMonitorScreen> createState() => _RiverMonitorScreenState();
}

class _RiverMonitorScreenState extends State<RiverMonitorScreen>
    with TickerProviderStateMixin {

  late final TabController _tab;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  final _api        = ApiService();
  final _searchCtrl = TextEditingController();

  late List<RiverStation> _stations;
  bool   _loading    = true;
  bool   _refreshing = false;
  bool   _sortByRisk = false;
  String _error      = '';
  Timer? _timer;

  String       _addCityName  = '';
  bool         _adding       = false;
  List<String> _suggestions  = [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _stations = _seedStations();
    _fetchLive();
    _timer = Timer.periodic(
        AppConstants.pollingInterval, (_) => _fetchLive(silent: true));
  }

  @override
  void dispose() {
    _tab.dispose();
    _pulseCtrl.dispose();
    _searchCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // ── Seed from constants ──────────────────────────────────────────────────
  static const _defaultCities = [
    'Delhi','Patna','Guwahati','Prayagraj','Bhagalpur','Cuttack',
  ];

  List<RiverStation> _seedStations() {
    return _defaultCities.map((city) {
      final mc = AppConstants.monitoredCities.firstWhere(
        (m) => (m['city'] as String).toLowerCase() == city.toLowerCase(),
        orElse: () => <String,dynamic>{},
      );
      if (mc.isEmpty) return null;
      final dl = _fp(mc['danger_level']);
      final wl = _fp(mc['warning_level']);
      // FIX 1: seed current = wl (not wl*0.88) so the pre-live value is the
      // actual warning threshold baseline, not an arbitrary 12%-below value.
      // This prevents Patna from showing 41.89m before live data arrives.
      return RiverStation(
        city:    mc['city']  as String,
        state:   mc['state'] as String,
        river:   mc['river'] as String,
        station: '${mc['city']} CWC Gauge',
        current: wl > 0 ? wl : (dl > 0 ? dl * 0.85 : 0),
        warning: wl,
        danger:  dl,
        hfl:     dl > 0 ? dl * 1.10 : (wl > 0 ? wl * 1.25 : 10),
        dataSource: 'CONSTANTS',
      );
    }).whereType<RiverStation>().toList();
  }

  // ── Fetch live (3-tier) ──────────────────────────────────────────────────
  Future<void> _fetchLive({bool silent = false}) async {
    if (!mounted) return;
    setState(() {
      if (!silent) _loading = true;
      else         _refreshing = true;
      _error = '';
    });
    try {
      final tList = _extractList(await _api.getAllCwcStations());
      final lList = _extractList(await _api.getLiveLevels());
      if (!mounted) return;
      setState(() {
        _stations = _stations.map((s) {
          final t1 = _findMatch(tList, s.city, s.state, s.river);
          if (t1 != null) return _applyLive(s, t1, 'CWC_API');
          final t2 = _findMatch(lList, s.city, s.state, s.river);
          if (t2 != null) return _applyLive(s, t2, 'LIVE_LEVELS');
          return s;
        }).toList();
        _loading = _refreshing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = _refreshing = false; _error = e.toString(); });
    }
  }

  // FIX 2: _findMatch — expanded scorer:
  //  tier-0: station+state exact          → score 0
  //  tier-1: station only exact           → score 1
  //  tier-2: station substring match      → score 2
  //  tier-3: river_name match + state     → score 3  ← NEW
  //  tier-4: river_name match alone       → score 4  ← NEW
  //  tier-5: any token of station in city → score 5  ← NEW
  Map<String,dynamic>? _findMatch(
      List list, String city, String state, String river) {
    final lc = city.toLowerCase();
    final ls = state.toLowerCase();
    final lr = river.toLowerCase();
    Map<String,dynamic>? best; int bs = 99;

    for (final item in list.whereType<Map<String,dynamic>>()) {
      final sc = _s(item['station'] ?? item['city'] ?? item['stationName'] ?? item['name']);
      final st = _s(item['state_name'] ?? item['state'] ?? item['stateName']);
      final rv = _s(item['river_name'] ?? item['river'] ?? item['riverName']);

      int score = 99;

      // Tier 0 — exact city + state
      if (sc.contains(lc) && st.contains(ls))          score = 0;
      // Tier 1 — exact city only
      else if (sc.contains(lc))                         score = 1;
      // Tier 2 — city is substring of station name (e.g. lc='patna' in sc='patna bridge')
      else if (lc.contains(sc) && sc.length > 3)        score = 2;
      // Tier 3 — station name contains any word from city AND river matches ← NEW
      else if (_anyTokenMatch(sc, lc) && lr.isNotEmpty && rv.contains(lr)) score = 3;
      // Tier 4 — river name matches + state matches ← NEW
      else if (lr.isNotEmpty && rv.contains(lr) && st.contains(ls))        score = 4;
      // Tier 5 — any word token of station appears in city ← NEW
      else if (_anyTokenMatch(sc, lc))                  score = 5;

      if (score < bs) { bs = score; best = item; }
      if (bs == 0) break;
    }
    // Only return if we got a meaningful match (not just wildcard fallback)
    return bs <= 5 ? best : null;
  }

  /// Returns true if any whitespace-split token from [source] is contained
  /// in [target] (or vice-versa). Minimum token length of 4 to avoid noise.
  bool _anyTokenMatch(String source, String target) {
    for (final token in source.split(RegExp(r'[\s_\-]+'))) {
      if (token.length >= 4 && target.contains(token)) return true;
    }
    return false;
  }

  // FIX 3: _applyLive — reads all known level key variants;
  //         also applies live warning/danger/hfl when the API sends them.
  RiverStation _applyLive(RiverStation s, Map<String,dynamic> d, String src) {
    // Level — try every field name the backend might use
    final lv = _fp(
      d['river_level']   ??
      d['riverLevel']    ??
      d['current_level'] ??
      d['water_level']   ??   // ← was missing
      d['gauge_reading'] ??   // ← was missing
      d['currentLevel']  ??
      d['level'],
    );
    // Thresholds from live API (override static seed when non-zero)
    final wl = _fp(d['warning_level'] ?? d['warningLevel'] ?? d['wl']);
    final dl = _fp(d['danger_level']  ?? d['dangerLevel']  ?? d['dl']);
    final hl = _fp(d['hfl'] ?? d['hfl_level'] ?? d['highest_flood_level']);

    final rn = _fp(d['rainfall_last_hour'] ?? d['rainfall']);
    final fl = _fp(d['flow_rate'] ?? d['flowRate'] ?? d['discharge']);
    final tr = _s(d['trend']).toUpperCase();
    final st = _s(d['status']).toUpperCase();
    final up = _s(d['timestamp'] ?? d['updated_at'] ?? d['lastUpdated']);

    return s.copyWith(
      current:          lv > 0 ? lv : null,
      // FIX: pass live thresholds — copyWith now accepts them
      warning:          wl > 0 ? wl : null,
      danger:           dl > 0 ? dl : null,
      hfl:              hl > 0 ? hl : null,
      rainfallLastHour: rn > 0 ? rn : null,
      flowRate:         fl > 0 ? fl : null,
      trend:            tr.isNotEmpty ? tr : null,
      liveStatus:       st.isNotEmpty ? st : null,
      lastUpdated:      up.isNotEmpty ? up : null,
      dataSource:       src,
      isLive:           true,
    );
  }

  // FIX 4: _extractList — recurse one extra level so {data:{levels:[...]}}
  //         and similar nested payloads are unwrapped correctly.
  List _extractList(dynamic p) {
    if (p is List) return p;
    if (p is Map<String,dynamic>) {
      for (final k in ['data','levels','stations','results','items','records','telemetry']) {
        final v = p[k];
        if (v is List && v.isNotEmpty) return v;
        // ONE extra recursion: {data: {levels: [...]}}
        if (v is Map<String,dynamic>) {
          for (final k2 in ['data','levels','stations','results','items','records']) {
            final v2 = v[k2];
            if (v2 is List && v2.isNotEmpty) return v2;
          }
        }
      }
      // If the response itself looks like a single station record, wrap it
      if (p.containsKey('station') || p.containsKey('river_level') ||
          p.containsKey('stationName') || p.containsKey('gauge_reading')) {
        return [p];
      }
    }
    return [];
  }

  static double _fp(dynamic v) => v == null ? 0.0 : (double.tryParse(v.toString()) ?? 0.0);
  static String _s(dynamic v)  => (v?.toString() ?? '').trim().toLowerCase();

  // ── Add city ─────────────────────────────────────────────────────────────
  void _onSearch(String q) {
    if (q.isEmpty) { setState(() => _suggestions = []); return; }
    final lq = q.toLowerCase();
    setState(() {
      _suggestions = AppConstants.monitoredCities
          .map((m) => m['city'] as String)
          .where((c) => c.toLowerCase().contains(lq))
          .take(8).toList();
    });
  }

  Future<void> _addCity(String name) async {
    final nm = name.trim();
    if (nm.isEmpty) return;
    if (_stations.any((s) => s.city.toLowerCase() == nm.toLowerCase())) {
      _snack('$nm is already monitored', isError: true); return;
    }
    final mc = AppConstants.monitoredCities.firstWhere(
      (m) => (m['city'] as String).toLowerCase() == nm.toLowerCase(),
      orElse: () => <String,dynamic>{},
    );
    if (mc.isEmpty) { _snack('City not in CWC registry', isError: true); return; }

    setState(() => _adding = true);
    HapticFeedback.lightImpact();

    final dl = _fp(mc['danger_level']);
    final wl = _fp(mc['warning_level']);
    var ns = RiverStation(
      city:    mc['city']  as String,
      state:   mc['state'] as String,
      river:   mc['river'] as String,
      station: '${mc['city']} CWC Gauge',
      current: wl > 0 ? wl : (dl > 0 ? dl * 0.85 : 0),
      warning: wl, danger: dl,
      hfl:     dl > 0 ? dl * 1.10 : (wl > 0 ? wl * 1.25 : 10),
      dataSource: 'CONSTANTS',
    );
    try {
      final tList = _extractList(await _api.getAllCwcStations());
      final match = _findMatch(tList, nm, mc['state'] as String, mc['river'] as String? ?? '');
      if (match != null) ns = _applyLive(ns, match, 'CWC_API');
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _stations.insert(0, ns);
      _adding = false;
      _addCityName = '';
      _searchCtrl.clear();
      _suggestions = [];
    });
    _tab.animateTo(0);
    _snack('${mc['city']} added ✓');
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

  List<RiverStation> get _list {
    final l = List<RiverStation>.from(_stations);
    if (_sortByRisk) l.sort((a,b) => b.riskScore.compareTo(a.riskScore));
    return l;
  }
  int get _atRisk   => _stations.where((s) => s.dangerClass != DangerClass.normal).length;
  int get _liveCount => _stations.where((s) => s.isLive).length;

  // ─── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _kBg,
        body: SafeArea(
          child: Column(children: [
            _header(),
            _tabBar(),
            if (_refreshing)
              LinearProgressIndicator(
                backgroundColor: _kGold.withOpacity(0.08),
                valueColor: const AlwaysStoppedAnimation(_kGold),
                minHeight: 2),
            if (_error.isNotEmpty) _errorBanner(),
            Expanded(child: TabBarView(
              controller: _tab,
              children: [_stationsTab(), _addCityTab()],
            )),
          ]),
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────
  Widget _header() => Container(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
    decoration: BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [_kGold.withOpacity(0.09), _kTeal.withOpacity(0.05), _kBg]),
      border: Border(bottom: BorderSide(color: _kGold.withOpacity(0.18), width: 0.8)),
    ),
    child: Row(children: [
      Container(
        width: 46, height: 46,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_kGold, _kGoldDark],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: _kGold.withOpacity(0.35), blurRadius: 16, spreadRadius: 2)],
        ),
        child: const Icon(Icons.water_rounded, color: Color(0xFF060B12), size: 26),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ShaderMask(
          shaderCallback: (b) => const LinearGradient(colors: [_kGoldLight, _kGold]).createShader(b),
          child: const Text('River Monitor', style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
        ),
        const Text('CWC Live · OpsFlood Telemetry',
            style: TextStyle(fontSize: 10, color: Color(0xFF7B8A99), letterSpacing: 0.4)),
      ])),
      // Pulsing LIVE badge
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
                style: const TextStyle(color: _kTeal, fontSize: 10, fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
      const SizedBox(width: 8),
      _GoldChip(label: '${_stations.length}', sublabel: 'cities'),
      const SizedBox(width: 6),
      _GoldChip(label: '$_atRisk', sublabel: 'at risk',
          color: _atRisk > 0 ? const Color(0xFFF97316) : null),
    ]),
  );

  // ─── Tab bar ──────────────────────────────────────────────────────────────
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
          gradient: const LinearGradient(colors: [_kGold, _kGoldDark],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: _kGold.withOpacity(0.3), blurRadius: 8)],
        ),
        labelColor: const Color(0xFF060B12),
        unselectedLabelColor: const Color(0xFF7B8A99),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        tabs: const [Tab(text: '  Stations  '), Tab(text: '  Add City  ')],
      ),
    ),
  );

  // ─── Error banner ─────────────────────────────────────────────────────────
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
      const Expanded(child: Text('API error — showing cached data',
          style: TextStyle(color: Color(0xFFEF4444), fontSize: 11))),
      GestureDetector(
        onTap: _fetchLive,
        child: const Text('Retry', style: TextStyle(
            color: _kGold, fontSize: 11, fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline, decorationColor: _kGold)),
      ),
    ]),
  );

  // ─── Stations tab ─────────────────────────────────────────────────────────
  Widget _stationsTab() {
    if (_loading) return _shimmer();
    return RefreshIndicator(
      color: _kGold, backgroundColor: _kSurface2,
      onRefresh: _fetchLive,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _sortBar()),
          SliverToBoxAdapter(child: _legend()),
          SliverList(delegate: SliverChildBuilderDelegate(
            (ctx, i) {
              final s = _list[i];
              return _LiveCard(key: ValueKey('${s.city}_$i'),
                  station: s, index: i,
                  onDelete: () => setState(() => _stations.remove(s)));
            },
            childCount: _list.length,
          )),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _sortBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
    child: Row(children: [
      Text('${_stations.length} stations',
          style: const TextStyle(fontSize: 12, color: Color(0xFF7B8A99))),
      const Spacer(),
      const Icon(Icons.arrow_downward_rounded, size: 11, color: Color(0xFF3A4A58)),
      const SizedBox(width: 4),
      const Text('Pull to refresh',
          style: TextStyle(fontSize: 10, color: Color(0xFF3A4A58))),
      const SizedBox(width: 12),
      GestureDetector(
        onTap: () => setState(() => _sortByRisk = !_sortByRisk),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _sortByRisk ? _kGold.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _sortByRisk ? _kGold.withOpacity(0.4) : const Color(0xFF2A3A4A)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.sort_rounded, size: 13,
                color: _sortByRisk ? _kGold : const Color(0xFF7B8A99)),
            const SizedBox(width: 4),
            Text(_sortByRisk ? 'By risk' : 'Sort', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: _sortByRisk ? _kGold : const Color(0xFF7B8A99))),
          ]),
        ),
      ),
    ]),
  );

  Widget _legend() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    child: Wrap(spacing: 12, runSpacing: 4, children: [
      _LegendDot(color: _dcColors[DangerClass.normal]!,      label: 'Normal'),
      _LegendDot(color: _dcColors[DangerClass.aboveNormal]!, label: 'Above Normal'),
      _LegendDot(color: _dcColors[DangerClass.severe]!,      label: 'Severe'),
      _LegendDot(color: _dcColors[DangerClass.extreme]!,     label: 'Extreme'),
    ]),
  );

  Widget _shimmer() => ListView.builder(
    padding: const EdgeInsets.fromLTRB(16,12,16,32),
    itemCount: 5,
    itemBuilder: (_, i) => _ShimmerCard(delay: i * 120),
  );

  // ─── Add city tab ─────────────────────────────────────────────────────────
  Widget _addCityTab() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16,16,16,40),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 3, height: 22,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [_kGold, _kGoldDark],
                begin: Alignment.topCenter, end: Alignment.bottomCenter),
            borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 10),
        const Text('Add City to Monitor',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
      ]),
      const SizedBox(height: 6),
      const Padding(
        padding: EdgeInsets.only(left: 13),
        child: Text(
          'Type a city name — danger/warning/HFL auto-filled from CWC registry. No manual input needed.',
          style: TextStyle(fontSize: 11, color: Color(0xFF7B8A99), height: 1.5)),
      ),
      const SizedBox(height: 20),
      // Search field
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
            hintText: 'Search city  e.g. Patna, Kolhapur…',
            hintStyle: const TextStyle(color: Color(0xFF3A4A58), fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded, color: _kGold, size: 20),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, color: Color(0xFF7B8A99), size: 18),
                    onPressed: () { _searchCtrl.clear(); setState(() { _addCityName=''; _suggestions=[]; }); })
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _kGold, width: 1.5)),
            filled: true, fillColor: Colors.transparent,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            final mc = AppConstants.monitoredCities.firstWhere(
              (m) => m['city'] == city, orElse: () => {});
            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () { _searchCtrl.text = city; setState(() { _addCityName = city; _suggestions = []; }); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: e.key < _suggestions.length-1
                    ? BoxDecoration(border: Border(bottom: BorderSide(color: _kGold.withOpacity(0.08))))
                    : null,
                child: Row(children: [
                  Container(width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: _kGold.withOpacity(0.10), borderRadius: BorderRadius.circular(9)),
                    child: const Icon(Icons.water_rounded, color: _kGold, size: 16)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(city, style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                    Text('${mc['state'] ?? ''} · ${mc['river'] ?? ''}',
                        style: const TextStyle(color: Color(0xFF7B8A99), fontSize: 10),
                        overflow: TextOverflow.ellipsis),
                  ])),
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
                ? LinearGradient(colors: [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.05)])
                : const LinearGradient(colors: [_kGoldLight, _kGold, _kGoldDark],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
            boxShadow: (_addCityName.trim().isEmpty || _adding) ? []
                : [BoxShadow(color: _kGold.withOpacity(0.35), blurRadius: 18, spreadRadius: 2)],
          ),
          child: Center(child: _adding
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(
                strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(Color(0xFF060B12))))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add_location_alt_rounded, size: 20,
                    color: _addCityName.trim().isEmpty
                        ? const Color(0xFF3A4A58) : const Color(0xFF060B12)),
                const SizedBox(width: 8),
                Text('Add to Monitoring', style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.3,
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
          color: _kTeal.withOpacity(0.06), borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kTeal.withOpacity(0.2)),
        ),
        child: const Column(children: [
          Row(children: [
            Icon(Icons.auto_awesome_rounded, size: 14, color: _kGold),
            SizedBox(width: 8),
            Text('Smart Auto-Fill', style: TextStyle(
                color: _kGold, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
          SizedBox(height: 6),
          Text(
            'Danger, warning, and HFL are auto-pulled from the CWC registry (100+ cities). '
            'Live river level, trend, and rainfall are fetched from OpsFlood telemetry — no manual entry required.',
            style: TextStyle(color: Color(0xFF7B8A99), fontSize: 11, height: 1.5),
          ),
        ]),
      ),
    ]),
  );
}

// ─── Live Station Card ───────────────────────────────────────────────────────
class _LiveCard extends StatefulWidget {
  final RiverStation station;
  final int          index;
  final VoidCallback onDelete;
  const _LiveCard({super.key, required this.station, required this.index, required this.onDelete});
  @override State<_LiveCard> createState() => _LiveCardState();
}

class _LiveCardState extends State<_LiveCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: Duration(milliseconds: 600 + widget.index * 80));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    Future.delayed(Duration(milliseconds: widget.index * 80), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final s   = widget.station;
    final dc  = s.dangerClass;
    final col = _dcColors[dc]!;
    final pct = s.progressPct;

    return FadeTransition(
      opacity: _anim,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0.06,0), end: Offset.zero).animate(_anim),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: col.withOpacity(0.22)),
            boxShadow: [
              BoxShadow(color: col.withOpacity(0.06), blurRadius: 16, offset: const Offset(0,4)),
              BoxShadow(color: _kGold.withOpacity(0.04), blurRadius: 24),
            ],
          ),
          child: Column(children: [
            // Top row
            Padding(
              padding: const EdgeInsets.fromLTRB(14,14,14,10),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(colors: [col.withOpacity(0.35), col.withOpacity(0.05)]),
                    shape: BoxShape.circle,
                    border: Border.all(color: col.withOpacity(0.45), width: 1.5),
                  ),
                  child: Icon(_dcIcon(dc), color: col, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(s.city, style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                        overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 6),
                    s.isLive
                      ? Container(padding: const EdgeInsets.symmetric(horizontal:6,vertical:2),
                          decoration: BoxDecoration(color: _kTeal.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _kTeal.withOpacity(0.35))),
                          child: const Text('LIVE', style: TextStyle(
                              color: _kTeal, fontSize: 8, fontWeight: FontWeight.w800)))
                      : Container(padding: const EdgeInsets.symmetric(horizontal:6,vertical:2),
                          decoration: BoxDecoration(color: _kGold.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _kGold.withOpacity(0.30))),
                          child: const Text('CWC', style: TextStyle(
                              color: _kGold, fontSize: 8, fontWeight: FontWeight.w700))),
                  ]),
                  const SizedBox(height: 2),
                  Text('${s.river}  ·  ${s.state}', style: const TextStyle(
                      color: Color(0xFF7B8A99), fontSize: 11),
                      overflow: TextOverflow.ellipsis),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal:9,vertical:4),
                    decoration: BoxDecoration(
                      color: col.withOpacity(0.12), borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: col.withOpacity(0.4))),
                    child: Text(dc.label, style: TextStyle(
                        color: col, fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: widget.onDelete,
                    child: const Icon(Icons.remove_circle_outline, size: 16, color: Color(0xFF3A4A58))),
                ]),
              ]),
            ),
            // Animated bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: AnimatedBuilder(
                animation: _anim,
                builder: (_, __) => Column(children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(child: Text('${s.current.toStringAsFixed(2)} m', style: TextStyle(
                          color: col, fontSize: 18, fontWeight: FontWeight.w900),
                          overflow: TextOverflow.ellipsis)),
                      Text('HFL ${s.hfl.toStringAsFixed(1)} m', style: const TextStyle(
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
                        left: (s.warning/s.hfl).clamp(0.0,1.0) *
                            (MediaQuery.of(context).size.width - 60),
                        top: 0, bottom: 0,
                        child: Container(width: 1.5, color: _kGold.withOpacity(0.5)),
                      ),
                    FractionallySizedBox(
                      widthFactor: (pct * _anim.value).clamp(0.0,1.0),
                      child: Container(height: 7,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: [col.withOpacity(0.7), col],
                              begin: Alignment.centerLeft, end: Alignment.centerRight),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [BoxShadow(color: col.withOpacity(0.5), blurRadius: 6)],
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _mini('W ${s.warning.toStringAsFixed(1)}', _kGold),
                      _mini('D ${s.danger.toStringAsFixed(1)}', const Color(0xFFF97316)),
                      _mini('${(pct*100).toStringAsFixed(0)}% of HFL', const Color(0xFF7B8A99)),
                    ],
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 10),
            Divider(height: 1, color: _kGold.withOpacity(0.08), indent: 14, endIndent: 14),
            const SizedBox(height: 8),
            // Live data pills
            Padding(
              padding: const EdgeInsets.fromLTRB(14,0,14,12),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                if (s.trend != null)
                  _Pill(icon: _ti(s.trend!), label: s.trend!, color: _tc(s.trend!)),
                if (s.rainfallLastHour != null && s.rainfallLastHour! > 0)
                  _Pill(icon: '🌧', label: '${s.rainfallLastHour!.toStringAsFixed(1)} mm/hr',
                      color: const Color(0xFF60A5FA)),
                if (s.flowRate != null && s.flowRate! > 0)
                  _Pill(icon: '💧', label: '${s.flowRate!.toStringAsFixed(0)} m³/s', color: _kTeal),
                if (s.liveStatus != null)
                  _Pill(icon: '📡', label: s.liveStatus!, color: _sc(s.liveStatus!)),
                _Pill(icon: '🛰', label: s.dataSource ?? 'CWC', color: _kGold),
                if (!s.isLive)
                  _Pill(icon: '📋', label: 'Registry data', color: const Color(0xFF7B8A99)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _mini(String t, Color c) => Text(t,
      style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.w600));

  IconData _dcIcon(DangerClass dc) {
    switch (dc) {
      case DangerClass.normal:      return Icons.check_circle_outline;
      case DangerClass.aboveNormal: return Icons.warning_amber_rounded;
      case DangerClass.severe:      return Icons.error_outline_rounded;
      case DangerClass.extreme:     return Icons.crisis_alert_rounded;
    }
  }

  String _ti(String t) => t=='RISING' ? '↑' : t=='FALLING' ? '↓' : '→';
  Color  _tc(String t) => t=='RISING'
      ? const Color(0xFFEF4444) : t=='FALLING' ? const Color(0xFF22C55E) : const Color(0xFFF59E0B);
  Color  _sc(String s) => s=='CRITICAL'
      ? const Color(0xFFEF4444) : s=='WARNING' ? const Color(0xFFF59E0B) : const Color(0xFF22C55E);
}

// ─── Shimmer ──────────────────────────────────────────────────────────────────
class _ShimmerCard extends StatefulWidget {
  final int delay;
  const _ShimmerCard({required this.delay});
  @override State<_ShimmerCard> createState() => _ShimmerCardState();
}
class _ShimmerCardState extends State<_ShimmerCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;
  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
    _anim = Tween<double>(begin: -2, end: 2).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      margin: const EdgeInsets.fromLTRB(16,0,16,12),
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment(_anim.value-1, 0),
          end:   Alignment(_anim.value+1, 0),
          colors: [_kSurface, _kGold.withOpacity(0.07), _kSurface],
        ),
        border: Border.all(color: _kBorder),
      ),
    ),
  );
}

// ─── Atoms ────────────────────────────────────────────────────────────────────
class _Pill extends StatelessWidget {
  final String icon, label;
  final Color  color;
  const _Pill({required this.icon, required this.label, required this.color});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.3))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(icon, style: const TextStyle(fontSize: 10)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    ]),
  );
}

class _GoldChip extends StatelessWidget {
  final String label, sublabel;
  final Color? color;
  const _GoldChip({required this.label, required this.sublabel, this.color});
  @override Widget build(BuildContext context) {
    final c = color ?? _kGold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: c.withOpacity(0.10), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withOpacity(0.3))),
      child: Column(children: [
        Text(label, style: TextStyle(color: c, fontSize: 14, fontWeight: FontWeight.w900, height: 1.1)),
        Text(sublabel, style: const TextStyle(color: Color(0xFF7B8A99), fontSize: 8, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color; final String label;
  const _LegendDot({required this.color, required this.label});
  @override Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 8, height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 4)])),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF7B8A99))),
  ]);
}
