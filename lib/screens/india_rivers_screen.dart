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

// ── palette (shared) ────────────────────────────────────────────────────────────────
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

// ── Screen ─────────────────────────────────────────────────────────────────────────
class IndiaRiversScreen extends ConsumerStatefulWidget {
  const IndiaRiversScreen({super.key});
  @override
  ConsumerState<IndiaRiversScreen> createState() => _IndiaRiversScreenState();
}

class _IndiaRiversScreenState extends ConsumerState<IndiaRiversScreen>
    with TickerProviderStateMixin {

  // ── tab controller (2 tabs) ──────────────────────────────────────────────
  late final TabController      _tab;
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulse;

  // ── Live Gauges filter state ──────────────────────────────────────────────
  String _selectedState = 'All India';
  String? _selectedCity;
  String _searchQuery  = '';
  String _riskFilter   = 'ALL';
  final TextEditingController _searchCtrl = TextEditingController();

  // ── CWC Stations state ───────────────────────────────────────────────────
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

  // ── CWC fetch ───────────────────────────────────────────────────────────────
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

  // ── CWC helpers ─────────────────────────────────────────────────────────────
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

  // ── Live Gauges helpers ──────────────────────────────────────────────────
  List<FloodData> _filteredLevels(List<FloodData> levels) {
    return levels.where((d) {
      final stateMatch = _selectedState == 'All India' || d.state == _selectedState;
      final cityMatch  = _selectedCity == null || d.city == _selectedCity;
      final riskMatch  = _riskFilter == 'ALL' || d.riskLevel == _riskFilter;
      final q = _searchQuery.toLowerCase();
      final textMatch  = q.isEmpty ||
          d.city.toLowerCase().contains(q) ||
          (d.riverName ?? '').toLowerCase().contains(q) ||
          d.state.toLowerCase().contains