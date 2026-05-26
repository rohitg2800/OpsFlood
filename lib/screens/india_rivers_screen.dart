// lib/screens/india_rivers_screen.dart
// OpsFlood — India Rivers v2 (compile-fixed)
// liveLevelsProvider is Provider<List<FloodData>> — NOT FutureProvider.
// Use ref.watch() directly, no .when().

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants.dart';
import '../models/flood_data.dart';
import '../models/river_station.dart';
import '../providers/flood_providers.dart';
import '../services/real_time_river_service.dart';
import '../theme/river_theme.dart';

class IndiaRiversScreen extends ConsumerStatefulWidget {
  const IndiaRiversScreen({super.key});
  @override
  ConsumerState<IndiaRiversScreen> createState() => _IndiaRiversScreenState();
}

class _IndiaRiversScreenState extends ConsumerState<IndiaRiversScreen>
    with TickerProviderStateMixin {

  late final TabController       _tab;
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulse;

  String  _selectedState = 'All India';
  String? _selectedCity;
  String  _searchQuery   = '';
  String  _riskFilter    = 'ALL';
  final TextEditingController _searchCtrl = TextEditingController();

  final _cwcSvc         = RealTimeRiverService();
  final _cwcSearchCtrl  = TextEditingController();
  List<LiveRiverResult> _cwcResults     = [];
  bool                  _cwcLoading     = true;
  bool                  _cwcRefreshing  = false;
  bool                  _cwcSortByRisk  = false;
  String                _cwcError       = '';
  String                _cwcFilterState = '';
  Timer?                _cwcTimer;
  String                _addCityName    = '';
  bool                  _adding         = false;
  List<String>          _suggestions    = [];

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

  Future<void> _fetchCwc({bool silent = false}) async {
    if (!mounted) return;
    setState(() {
      if (!silent) _cwcLoading = true;
      else _cwcRefreshing = true;
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

  List<LiveRiverResult> get _cwcList {
    var l = List<LiveRiverResult>.from(_cwcResults);
    if (_cwcFilterState.isNotEmpty) {
      l = l.where((r) => r.station.state == _cwcFilterState).toList();
    }
    if (_cwcSortByRisk) {
      l.sort((a, b) {
        final rc = b.station.riskScore.compareTo(a.station.riskScore);
        return rc != 0
            ? rc
            : (b.mlFloodProb ?? 0).compareTo(a.mlFloodProb ?? 0);
      });
    }
    return l;
  }

  void _cwcSearch(String q) {
    if (q.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    final lq     = q.toLowerCase();
    final loaded = _cwcResults.map((r) => r.station.city.toLowerCase()).toSet();
    setState(() {
      _suggestions = AppConstants.monitoredCities
          .map((m) => m['city'] as String)
          .where((c) =>
              c.toLowerCase().contains(lq) &&
              !loaded.contains(c.toLowerCase()))
          .take(8)
          .toList();
    });
  }

  Future<void> _addCity(String name) async {
    final nm = name.trim();
    if (nm.isEmpty) return;
    if (_cwcResults.any(
        (r) => r.station.city.toLowerCase() == nm.toLowerCase())) {
      _snack('$nm already in list', isError: true);
      return;
    }
    final mc = AppConstants.monitoredCities.firstWhere(
      (m) => (m['city'] as String).toLowerCase() == nm.toLowerCase(),
      orElse: () => <String, dynamic>{},
    );
    if (mc.isEmpty) {
      _snack('City not in CWC registry', isError: true);
      return;
    }
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
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  List<FloodData> _filteredLevels(List<FloodData> levels) {
    return levels.where((d) {
      final stateMatch =
          _selectedState == 'All India' || d.state == _selectedState;
      final cityMatch  = _selectedCity == null || d.city == _selectedCity;
      final riskMatch  = _riskFilter == 'ALL' || d.riskLevel == _riskFilter;
      final q          = _searchQuery.toLowerCase();
      final textMatch  = q.isEmpty ||
          d.city.toLowerCase().contains(q) ||
          (d.riverName ?? '').toLowerCase().contains(q) ||
          d.state.toLowerCase().contains(q);
      return stateMatch && cityMatch && riskMatch && textMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.abyss0,
      appBar: AppBar(
        backgroundColor: AppPalette.abyss1,
        title: const Text('India Rivers',
            style: TextStyle(color: AppPalette.textWhite)),
        bottom: TabBar(
          controller: _tab,
          labelColor: AppPalette.cyan,
          unselectedLabelColor: AppPalette.textGrey,
          indicatorColor: AppPalette.cyan,
          tabs: const [
            Tab(text: 'Live Gauges'),
            Tab(text: 'CWC Stations'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildLiveGaugesTab(),
          _buildCwcStationsTab(),
        ],
      ),
    );
  }

  // ── Tab 0: Live Gauges ────────────────────────────────────────────────────
  // liveLevelsProvider is Provider<List<FloodData>> — watch returns List directly
  Widget _buildLiveGaugesTab() {
    final levels   = ref.watch(liveLevelsProvider);
    final filtered = _filteredLevels(levels);
    return Column(
      children: [
        _SearchBar(searchCtrl: _searchCtrl, onChanged: (v) =>
            setState(() => _searchQuery = v)),
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text('No results',
                      style: TextStyle(color: AppPalette.textGrey)))
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _FloodDataTile(data: filtered[i]),
                ),
        ),
      ],
    );
  }

  // ── Tab 1: CWC Stations ───────────────────────────────────────────────────
  Widget _buildCwcStationsTab() {
    if (_cwcLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppPalette.cyan));
    }
    if (_cwcError.isNotEmpty) {
      return Center(
          child: Text('Error: $_cwcError',
              style: const TextStyle(color: AppPalette.textGrey)));
    }
    final list = _cwcList;
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (_, i) => _CwcTile(result: list[i]),
    );
  }
}

// ── Search bar ──────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController searchCtrl;
  final ValueChanged<String>  onChanged;
  const _SearchBar({required this.searchCtrl, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: searchCtrl,
        style: const TextStyle(color: AppPalette.textWhite),
        decoration: InputDecoration(
          hintText: 'Search city or river…',
          hintStyle: const TextStyle(color: AppPalette.textGrey),
          prefixIcon: const Icon(Icons.search, color: AppPalette.textGrey),
          filled: true,
          fillColor: AppPalette.abyss1,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

// ── FloodData tile ──────────────────────────────────────────────────────────
class _FloodDataTile extends StatelessWidget {
  final FloodData data;
  const _FloodDataTile({required this.data});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(data.city,
          style: const TextStyle(color: AppPalette.textWhite)),
      subtitle: Text('${data.state}  •  ${data.riverName ?? "—"}',
          style: const TextStyle(color: AppPalette.textGrey)),
      trailing: Text(
        '${data.currentLevel.toStringAsFixed(1)} m',
        style: const TextStyle(color: AppPalette.cyan),
      ),
    );
  }
}

// ── CWC tile ────────────────────────────────────────────────────────────────
class _CwcTile extends StatelessWidget {
  final LiveRiverResult result;
  const _CwcTile({required this.result});

  @override
  Widget build(BuildContext context) {
    final s = result.station;
    // Use result.reading?.level — LiveRiverResult has no .currentLevel getter
    final levelStr = result.reading?.level != null
        ? '${result.reading!.level.toStringAsFixed(1)} m'
        : '—';
    return ListTile(
      title: Text(s.city,
          style: const TextStyle(color: AppPalette.textWhite)),
      subtitle: Text('${s.state}  •  ${s.river}',
          style: const TextStyle(color: AppPalette.textGrey)),
      trailing: Text(
        levelStr,
        style: const TextStyle(
            color: AppPalette.amber, fontWeight: FontWeight.w600),
      ),
    );
  }
}
