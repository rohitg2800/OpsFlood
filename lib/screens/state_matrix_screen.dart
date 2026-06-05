// lib/screens/state_matrix_screen.dart
// StateMatrixScreen v2
//  - Riverpod live-data overlay on static stateSeverityMatrix
//  - Per-state live station count + worst live severity badge
//  - Sort by: A-Z | Live Risk | Station Count
//  - AppPalette theme tokens
//  - Bottom-sheet now shows live stations for that state
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ml/flood_engine.dart';
import '../models/flood_data.dart';
import '../providers/flood_providers.dart';
import '../theme/river_theme.dart';
import '../utils/flood_severity_helper.dart';

enum _Sort { alpha, risk, count }

class StateMatrixScreen extends ConsumerStatefulWidget {
  const StateMatrixScreen({super.key});

  @override
  ConsumerState<StateMatrixScreen> createState() =>
      _StateMatrixScreenState();
}

class _StateMatrixScreenState
    extends ConsumerState<StateMatrixScreen> {
  String _regionFilter = 'ALL';
  String _searchQuery  = '';
  _Sort  _sort         = _Sort.risk;

  static const _regionColors = {
    'PLAINS':    Color(0xFF2ECC71),
    'COASTAL':   Color(0xFF00B4D8),
    'HIMALAYAN': Color(0xFF9B59B6),
    'NORTHEAST': Color(0xFFF39C12),
    'ARID':      Color(0xFFE67E22),
    'ISLAND':    Color(0xFF1ABC9C),
    'URBAN_UT':  Color(0xFFE74C3C),
  };

  Color _regionColor(String r) =>
      _regionColors[r.toUpperCase()] ?? AppPalette.textGrey;

  /// Matches a state name (key from stateSeverityMatrix) against live data.
  List<FloodData> _liveForState(
      String stateKey, List<FloodData> live) {
    final k = stateKey.toLowerCase();
    return live
        .where((fd) => fd.state.toLowerCase().contains(k))
        .toList();
  }

  FloodSeverity _worstSeverity(List<FloodData> stations) {
    if (stations.isEmpty) return FloodSeverity.normal;
    return stations
        .map((fd) => FloodSeverityHelper.fromString(fd.status))
        .reduce((a, b) => a.index > b.index ? a : b);
  }

  List<MapEntry<String, StateEntry>> _filtered(
      List<FloodData> live) {
    var list = stateSeverityMatrix.entries.where((e) {
      final matchRegion = _regionFilter == 'ALL' ||
          e.value.region.toUpperCase() == _regionFilter;
      final matchSearch = _searchQuery.isEmpty ||
          e.key
              .toLowerCase()
              .contains(_searchQuery.toLowerCase());
      return matchRegion && matchSearch;
    }).toList();

    switch (_sort) {
      case _Sort.alpha:
        list.sort((a, b) => a.key.compareTo(b.key));
      case _Sort.risk:
        list.sort((a, b) {
          final sa = _worstSeverity(_liveForState(a.key, live));
          final sb = _worstSeverity(_liveForState(b.key, live));
          return sb.index - sa.index; // descending
        });
      case _Sort.count:
        list.sort((a, b) {
          final ca = _liveForState(a.key, live).length;
          final cb = _liveForState(b.key, live).length;
          return cb - ca; // descending
        });
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final live     = ref.watch(liveLevelsProvider);
    final filtered = _filtered(live);

    return Scaffold(
      backgroundColor: AppPalette.abyss0,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── App Bar ────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: AppPalette.abyss0,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppPalette.safe, Color(0xFF27AE60)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.map_outlined,
                      color: Colors.white, size: 17),
                ),
                const SizedBox(width: 10),
                const Text(
                  'State Matrix',
                  style: TextStyle(
                    color: AppPalette.textWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          // ── Search + filters ───────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: AppPalette.abyss0,
              padding:
                  const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Column(
                children: [
                  // Search field
                  TextField(
                    onChanged: (v) =>
                        setState(() => _searchQuery = v),
                    style: const TextStyle(
                        color: AppPalette.textWhite, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search state…',
                      hintStyle: const TextStyle(
                          color: AppPalette.textGrey, fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: AppPalette.gold, size: 20),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Region chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _chip('ALL', AppPalette.cyan),
                        ..._regionColors.entries.map(
                            (e) => _chip(e.key, e.value)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Sort chips
                  Row(
                    children: [
                      const Text('Sort:',
                          style: TextStyle(
                              color: AppPalette.textGrey,
                              fontSize: 11)),
                      const SizedBox(width: 8),
                      _sortChip('A-Z', _Sort.alpha),
                      const SizedBox(width: 6),
                      _sortChip('⚡ Risk', _Sort.risk),
                      const SizedBox(width: 6),
                      _sortChip('📍 Stations', _Sort.count),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Stats bar ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: Row(
                children: [
                  _statBadge(
                      '${filtered.length} States', AppPalette.cyan),
                  const SizedBox(width: 8),
                  _statBadge(
                      '${live.length} Live Stations',
                      AppPalette.gold),
                  const SizedBox(width: 8),
                  _statBadge(
                      '${live.where((fd) => FloodSeverityHelper.fromString(fd.status).index >= FloodSeverity.danger.index).length} Critical',
                      AppPalette.danger),
                ],
              ),
            ),
          ),

          // ── State cards ─────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final entry = filtered[i];
                  final liveStations =
                      _liveForState(entry.key, live);
                  return _StateCard(
                    entry: entry,
                    liveStations: liveStations,
                    regionColor: _regionColor(entry.value.region),
                    onTap: () => _showDetail(
                        ctx, entry.key, entry.value,
                        liveStations),
                  );
                },
                childCount: filtered.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    final sel = _regionFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _regionFilter = label),
      child: Container(
        margin: const EdgeInsets.only(right: 7),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: sel
              ? color.withValues(alpha: 0.20)
              : AppPalette.abyss2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: sel ? color : AppPalette.abyssStroke),
        ),
        child: Text(label,
            style: TextStyle(
                color: sel ? color : AppPalette.textGrey,
                fontSize: 11,
                fontWeight: sel
                    ? FontWeight.w700
                    : FontWeight.normal)),
      ),
    );
  }

  Widget _sortChip(String label, _Sort mode) {
    final sel = _sort == mode;
    return GestureDetector(
      onTap: () => setState(() => _sort = mode),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: sel
              ? AppPalette.gold.withValues(alpha: 0.15)
              : AppPalette.abyss2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: sel
                  ? AppPalette.gold
                  : AppPalette.abyssStroke),
        ),
        child: Text(label,
            style: TextStyle(
                color: sel ? AppPalette.gold : AppPalette.textGrey,
                fontSize: 10,
                fontWeight: sel
                    ? FontWeight.w700
                    : FontWeight.w500)),
      ),
    );
  }

  Widget _statBadge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      );

  void _showDetail(
    BuildContext context,
    String name,
    StateEntry e,
    List<FloodData> liveStations,
  ) {
    final color = _regionColor(e.region);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppPalette.abyss1,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.90,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.all(20),
          children: [
            // Handle
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppPalette.abyssStroke,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    name.split(' ')
                        .map((w) => w.isNotEmpty
                            ? w[0].toUpperCase() + w.substring(1)
                            : w)
                        .join(' '),
                    style: const TextStyle(
                        color: AppPalette.textWhite,
                        fontSize: 18,
                        fontWeight: FontWeight.w800),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: color.withValues(alpha: 0.4)),
                  ),
                  child: Text(e.region,
                      style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Threshold row
            Row(
              children: [
                _thresholdCell('Warning',
                    '${e.warningLevelM} m', AppPalette.warning),
                const SizedBox(width: 6),
                _thresholdCell('Danger',
                    '${e.dangerLevelM} m', AppPalette.danger),
                const SizedBox(width: 6),
                _thresholdCell('HFL',
                    '${e.hflM} m', AppPalette.critical),
              ],
            ),
            const SizedBox(height: 12),
            // Rivers
            if (e.primaryRivers.isNotEmpty) ...[
              const Text('Primary Rivers',
                  style: TextStyle(
                      color: AppPalette.textGrey, fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6, runSpacing: 6,
                children: e.primaryRivers
                    .map((r) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppPalette.cyan
                                .withValues(alpha: 0.10),
                            borderRadius:
                                BorderRadius.circular(6),
                            border: Border.all(
                                color: AppPalette.cyan
                                    .withValues(alpha: 0.30)),
                          ),
                          child: Text(r,
                              style: const TextStyle(
                                  color: AppPalette.cyan,
                                  fontSize: 12)),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
            ],
            // Vulnerable districts
            if (e.vulnerableDistricts.isNotEmpty) ...[
              const Text('Vulnerable Districts',
                  style: TextStyle(
                      color: AppPalette.textGrey, fontSize: 12)),
              const SizedBox(height: 4),
              Text(
                e.vulnerableDistricts.join(', '),
                style: const TextStyle(
                    color: AppPalette.textDim,
                    fontSize: 12,
                    height: 1.4),
              ),
              const SizedBox(height: 14),
            ],
            // Live stations for this state
            if (liveStations.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.sensors_rounded,
                      color: AppPalette.gold, size: 13),
                  const SizedBox(width: 5),
                  Text(
                    '${liveStations.length} Live Station'
                    '${liveStations.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                        color: AppPalette.textGrey,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...liveStations.take(6).map(
                  (fd) => _LiveStationRow(data: fd)),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _thresholdCell(
      String label, String value, Color color) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: color.withValues(alpha: 0.22)),
          ),
          child: Column(
            children: [
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              Text(label,
                  style: const TextStyle(
                      color: AppPalette.textGrey,
                      fontSize: 10)),
            ],
          ),
        ),
      );
}

// ── State Card ────────────────────────────────────────────────────────────────

class _StateCard extends StatelessWidget {
  final MapEntry<String, StateEntry> entry;
  final List<FloodData> liveStations;
  final Color regionColor;
  final VoidCallback onTap;

  const _StateCard({
    required this.entry,
    required this.liveStations,
    required this.regionColor,
    required this.onTap,
  });

  FloodSeverity get _worst {
    if (liveStations.isEmpty) return FloodSeverity.normal;
    return liveStations
        .map((fd) => FloodSeverityHelper.fromString(fd.status))
        .reduce((a, b) => a.index > b.index ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    final e      = entry.value;
    final name   = entry.key
        .split(' ')
        .map((w) =>
            w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : w)
        .join(' ');
    final worst  = _worst;
    final liveColor = liveStations.isEmpty
        ? AppPalette.textGrey
        : FloodSeverityHelper.color(worst);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppPalette.abyss1,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: liveStations.isEmpty
                ? AppPalette.abyssStroke
                : FloodSeverityHelper.cardBorder(worst),
            width: liveStations.isEmpty ? 0.8 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(name,
                      style: const TextStyle(
                          color: AppPalette.textWhite,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ),
                // Region badge
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: regionColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: regionColor.withValues(alpha: 0.38)),
                  ),
                  child: Text(e.region,
                      style: TextStyle(
                          color: regionColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w700)),
                ),
                // Live severity badge
                if (liveStations.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: liveColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: liveColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '${liveStations.length} ● ${FloodSeverityHelper.label(worst)}',
                      style: TextStyle(
                          color: liveColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                _cell('Warning', '${e.warningLevelM} m',
                    AppPalette.warning),
                const SizedBox(width: 5),
                _cell('Danger', '${e.dangerLevelM} m',
                    AppPalette.danger),
                const SizedBox(width: 5),
                _cell('HFL', '${e.hflM} m',
                    AppPalette.critical),
              ],
            ),
            if (e.primaryRivers.isNotEmpty) ...[
              const SizedBox(height: 7),
              Row(
                children: [
                  const Icon(Icons.water_rounded,
                      color: AppPalette.cyan, size: 12),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      e.primaryRivers.take(3).join(', '),
                      style: const TextStyle(
                          color: AppPalette.textGrey, fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cell(String label, String value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
                color: color.withValues(alpha: 0.20)),
          ),
          child: Column(
            children: [
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
              Text(label,
                  style: const TextStyle(
                      color: AppPalette.textGrey, fontSize: 9)),
            ],
          ),
        ),
      );
}

// ── Live Station Row (in bottom-sheet) ────────────────────────────────────────

class _LiveStationRow extends StatelessWidget {
  final FloodData data;
  const _LiveStationRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final sev   = FloodSeverityHelper.fromString(data.status);
    final color = FloodSeverityHelper.color(sev);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppPalette.abyss2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: FloodSeverityHelper.cardBorder(sev), width: 0.8),
      ),
      child: Row(
        children: [
          Icon(FloodSeverityHelper.icon(sev),
              color: color, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(data.city,
                style: const TextStyle(
                    color: AppPalette.textWhite,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
          Text('${data.currentLevel.toStringAsFixed(2)} m',
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
