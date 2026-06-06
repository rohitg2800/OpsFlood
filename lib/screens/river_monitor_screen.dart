// lib/screens/river_monitor_screen.dart
// RiverMonitorScreen v3 — wired to live CWC befiqr data
// Shows merged list: CwcStations (befiqr live) + legacy FloodData
// CWC stations are shown first, sorted by risk score descending.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flood_data.dart';
import '../providers/cwc_provider.dart';
import '../providers/flood_providers.dart';
import '../services/befiqr_cwc_service.dart';
import '../theme/river_theme.dart';
import '../utils/flood_severity_helper.dart';
import '../widgets/live_alert_banner.dart';
import '../widgets/severity_legend.dart';
import '../widgets/shimmer_loader.dart';
import '../widgets/station_status_strip.dart';
import '../widgets/theme_picker_sheet.dart';

class RiverMonitorScreen extends ConsumerStatefulWidget {
  const RiverMonitorScreen({super.key});
  @override
  ConsumerState<RiverMonitorScreen> createState() => _RiverMonitorScreenState();
}

class _RiverMonitorScreenState extends ConsumerState<RiverMonitorScreen> {
  String _query = '';
  final _scrollCtrl = ScrollController();
  bool _showFab = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      final should = _scrollCtrl.offset > 200;
      if (should != _showFab) setState(() => _showFab = should);
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── CWC filtering ────────────────────────────────────────────────────────
  List<CwcStation> _filteredCwc(List<CwcStation> stations) {
    if (_query.isEmpty) return stations;
    final q = _query.toLowerCase();
    return stations.where((s) =>
        s.site.toLowerCase().contains(q) ||
        s.river.toLowerCase().contains(q)).toList();
  }

  // ── Legacy FloodData filtering (kept for non-Bihar stations) ─────────────
  List<FloodData> _filteredLegacy(List<FloodData> levels) {
    if (_query.isEmpty) return levels;
    final q = _query.toLowerCase();
    return levels.where((fd) =>
        fd.city.toLowerCase().contains(q) ||
        fd.state.toLowerCase().contains(q) ||
        (fd.riverName?.toLowerCase().contains(q) ?? false) ||
        fd.district.toLowerCase().contains(q)).toList();
  }

  Map<FloodSeverity, int> _counts(
      List<CwcStation> cwc, List<FloodData> legacy) {
    final m = <FloodSeverity, int>{};
    for (final s in FloodSeverity.values) m[s] = 0;
    // Count CWC stations
    for (final s in cwc) {
      final sev = _cwcSeverity(s);
      m[sev] = (m[sev] ?? 0) + 1;
    }
    // Count legacy
    for (final fd in legacy) {
      final sev = FloodSeverityHelper.fromString(fd.status);
      m[sev] = (m[sev] ?? 0) + 1;
    }
    return m;
  }

  FloodSeverity _cwcSeverity(CwcStation s) {
    if (s.isDanger)   return FloodSeverity.danger;
    if (s.isWarning)  return FloodSeverity.warning;
    if (s.isElevated) return FloodSeverity.watch;
    return FloodSeverity.normal;
  }

  List<CwcStation> _cwcAlerts(List<CwcStation> stations) =>
      stations.where((s) => s.isDanger || s.isWarning).take(3).toList();

  @override
  Widget build(BuildContext context) {
    // Live CWC data
    final cwcAsync  = ref.watch(cwcStationsProvider);
    // Legacy realtime
    final rt        = ref.watch(realTimeServiceProvider);
    final legacy    = rt.liveLevels;
    final isLoading = rt.isLoading && legacy.isEmpty &&
        cwcAsync is AsyncLoading;

    final cwcStations = cwcAsync.valueOrNull ?? [];
    // Sort by risk score desc (highest risk first)
    final sortedCwc = [...cwcStations]
      ..sort((a, b) => BefiqrCwcService.riskScore(b)
          .compareTo(BefiqrCwcService.riskScore(a)));

    final filteredCwc    = _filteredCwc(sortedCwc);
    final filteredLegacy = _filteredLegacy(legacy);
    final totalCount     = filteredCwc.length + filteredLegacy.length;

    return Scaffold(
      backgroundColor: AppPalette.abyss0,
      floatingActionButton: AnimatedScale(
        scale: _showFab ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: FloatingActionButton.small(
          backgroundColor: AppPalette.gold,
          foregroundColor: AppPalette.abyss0,
          onPressed: () => _scrollCtrl.animateTo(
            0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          ),
          child: const Icon(Icons.keyboard_arrow_up_rounded),
        ),
      ),
      body: CustomScrollView(
        controller: _scrollCtrl,
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Sliver AppBar ──────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            floating: false,
            expandedHeight: 110,
            backgroundColor: AppPalette.abyss0,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            actions: [
              // CWC live indicator
              cwcAsync.when(
                data: (_) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Tooltip(
                    message: 'CWC live data active',
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppPalette.safe.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppPalette.safe.withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sensors_rounded,
                              color: AppPalette.safe, size: 11),
                          SizedBox(width: 4),
                          Text('CWC LIVE',
                              style: TextStyle(
                                  color: AppPalette.safe,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                  ),
                ),
                loading: () => const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5, color: AppPalette.cyan),
                  ),
                ),
                error: (_, __) => const Icon(
                    Icons.cloud_off_rounded,
                    color: AppPalette.amber, size: 18),
              ),
              IconButton(
                icon: const Icon(Icons.palette_outlined, size: 20),
                color: AppPalette.gold,
                tooltip: 'Theme',
                onPressed: () => ThemePickerSheet.show(context),
              ),
              const SizedBox(width: 4),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 14),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.waves_rounded,
                      color: AppPalette.gold, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'River Monitor',
                    style: TextStyle(
                      color: AppPalette.textWhite,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
              background: Container(
                  decoration: AppPalette.scaffoldDecoration()),
            ),
          ),

          // ── Search bar ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: TextField(
                style: const TextStyle(
                    color: AppPalette.textWhite, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search site, river or district…',
                  hintStyle: const TextStyle(
                      color: AppPalette.textGrey, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppPalette.gold, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded,
                              size: 18, color: AppPalette.textGrey),
                          onPressed: () => setState(() => _query = ''),
                        )
                      : null,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
          ),

          // ── Status strip (merged counts) ───────────────────────────────
          SliverToBoxAdapter(
            child: StationStatusStrip(
              counts: isLoading ? {} : _counts(sortedCwc, legacy),
              lastSynced: isLoading ? null : rt.lastFetchTime,
              isLoading: isLoading,
              onTap: (sev) => setState(() {
                _query = FloodSeverityHelper.label(sev);
              }),
            ),
          ),

          // ── CWC Alert banners ──────────────────────────────────────────
          if (!isLoading && _query.isEmpty && cwcStations.isNotEmpty)
            SliverToBoxAdapter(
              child: LiveAlertBannerStack(
                alerts: _cwcAlerts(sortedCwc)
                    .map((s) => LiveAlertBanner(
                          message:
                              '${s.site}: ${s.statusLabel} — '
                              '${s.gap.abs().toStringAsFixed(2)} m '
                              '${s.isDanger ? "above" : "below"} danger',
                          subMessage:
                              '${s.river} · Bihar CWC',
                          severity: _cwcSeverity(s),
                          onTap: () {},
                        ))
                    .toList(),
              ),
            ),

          // ── Legend ────────────────────────────────────────────────────
          if (!isLoading)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SeverityLegend.compact(),
                    const SizedBox(width: 6),
                    Text(
                      'Tap chip to filter',
                      style: TextStyle(
                          fontSize: 10,
                          color:
                              AppPalette.textGrey.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
            ),

          // ── Count header ──────────────────────────────────────────────
          if (!isLoading && totalCount > 0)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  _query.isEmpty
                      ? '${cwcStations.length} CWC stations  ·  '
                        '${legacy.length} live stations'
                      : '$totalCount result${totalCount == 1 ? '' : 's'} for "$_query"',
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppPalette.textGrey,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ),

          // ── Shimmer ───────────────────────────────────────────────────
          if (isLoading)
            SliverToBoxAdapter(
              child: ShimmerLoader.stationList(count: 6),
            )

          // ── CWC stations (primary, live) ───────────────────────────────
          else if (filteredCwc.isNotEmpty) ...[
            if (_query.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Row(
                    children: [
                      Icon(Icons.sensors_rounded,
                          color: AppPalette.cyan, size: 12),
                      SizedBox(width: 6),
                      Text('CWC Bihar — Live',
                          style: TextStyle(
                              color: AppPalette.cyan,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5)),
                    ],
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _CwcCard(station: filteredCwc[i]),
                  childCount: filteredCwc.length,
                ),
              ),
            ),
          ],

          // ── Legacy stations (secondary) ────────────────────────────────
          if (filteredLegacy.isNotEmpty) ...[
            if (_query.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    children: [
                      Icon(Icons.language_rounded,
                          color: AppPalette.gold, size: 12),
                      SizedBox(width: 6),
                      Text('All India — Live',
                          style: TextStyle(
                              color: AppPalette.gold,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5)),
                    ],
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _RiverCard(data: filteredLegacy[i]),
                  childCount: filteredLegacy.length,
                ),
              ),
            ),
          ],

          if (!isLoading && totalCount == 0)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search_off_rounded,
                        color: AppPalette.textDim, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      _query.isEmpty
                          ? 'No live data available.'
                          : 'No results for "$_query".',
                      style: const TextStyle(
                          color: AppPalette.textGrey, fontSize: 14),
                    ),
                    if (_query.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => setState(() => _query = ''),
                        child: const Text('Clear search',
                            style:
                                TextStyle(color: AppPalette.gold)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CWC Station Card (befiqr live)
// ─────────────────────────────────────────────────────────────────────────────

class _CwcCard extends StatelessWidget {
  final CwcStation station;
  const _CwcCard({required this.station});

  Color get _statusColor {
    if (station.isDanger)  return AppPalette.critical;
    if (station.isWarning) return AppPalette.danger;
    if (station.isElevated) return AppPalette.amber;
    return AppPalette.safe;
  }

  @override
  Widget build(BuildContext context) {
    final color     = _statusColor;
    final riskScore = BefiqrCwcService.riskScore(station);
    final pct       = station.fillFraction;
    // warning tick at 97% of danger
    final warnPct   = 0.97;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppPalette.abyss1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.30), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 0),
            child: Row(
              children: [
                // Arc gauge
                _ArcGauge(
                  percent: pct,
                  warnAt:  warnPct,
                  color:   color,
                  size:    72,
                  centerLabel:
                      '${(pct * 100).toStringAsFixed(0)}%',
                  subLabel: 'fill',
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        station.site,
                        style: const TextStyle(
                            color: AppPalette.textWhite,
                            fontSize: 17,
                            fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.waves_rounded,
                              size: 13, color: AppPalette.gold),
                          const SizedBox(width: 4),
                          Text('${station.river}  ·  Bihar',
                              style: const TextStyle(
                                  color: AppPalette.textGrey,
                                  fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6, runSpacing: 4,
                        children: [
                          _Badge(
                            label: station.statusLabel,
                            bg: color.withValues(alpha: 0.15),
                            fg: color,
                          ),
                          _Badge(
                            label: 'Risk ${riskScore.toStringAsFixed(0)}%',
                            bg: AppPalette.gold.withValues(alpha: 0.10),
                            fg: AppPalette.gold,
                          ),
                          _Badge(
                            label: 'CWC',
                            bg: AppPalette.cyan.withValues(alpha: 0.08),
                            fg: AppPalette.cyan,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          Divider(
              color: AppPalette.abyssStroke,
              height: 1,
              indent: 14,
              endIndent: 14),
          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _StatChip(
                  icon:   Icons.height_rounded,
                  label:  'Level',
                  value:  '${station.currentLevel.toStringAsFixed(2)} m',
                  accent: color,
                ),
                const SizedBox(width: 8),
                _StatChip(
                  icon:   Icons.stream_rounded,
                  label:  'Danger',
                  value:  '${station.dangerLevel.toStringAsFixed(2)} m',
                  accent: AppPalette.danger,
                ),
                const SizedBox(width: 8),
                _StatChip(
                  icon:   Icons.trending_down_rounded,
                  label:  'Gap',
                  value:  '${station.gap.toStringAsFixed(2)} m',
                  accent: station.isDanger
                      ? AppPalette.critical
                      : AppPalette.safe,
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Level bar
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: _LevelBar(
              current: station.currentLevel,
              warning: station.dangerLevel * 0.97,
              danger:  station.dangerLevel,
              color:   color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Legacy River Card (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _RiverCard extends StatelessWidget {
  final FloodData data;
  const _RiverCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final severity = FloodSeverityHelper.fromString(data.status);
    final color    = FloodSeverityHelper.color(severity);
    final pct      = (data.capacityPercent / 100).clamp(0.0, 1.0);
    final warnPct  = data.dangerLevel > 0
        ? (data.warningLevel / data.dangerLevel).clamp(0.0, 1.0)
        : 0.65;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppPalette.abyss1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: FloodSeverityHelper.cardBorder(severity), width: 1),
        boxShadow: [
          BoxShadow(
              color: FloodSeverityHelper.glowColor(severity),
              blurRadius: 20,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 0),
            child: Row(
              children: [
                _ArcGauge(
                  percent: pct,
                  warnAt:  warnPct,
                  color:   color,
                  size:    72,
                  centerLabel:
                      '${data.capacityPercent.toStringAsFixed(0)}%',
                  subLabel: 'fill',
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data.city,
                          style: const TextStyle(
                              color: AppPalette.textWhite,
                              fontSize: 18,
                              fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.waves_rounded,
                              size: 13, color: AppPalette.gold),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${data.riverName ?? 'N/A'}  ·  ${data.state}',
                              style: const TextStyle(
                                  color: AppPalette.textGrey,
                                  fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6, runSpacing: 4,
                        children: [
                          _Badge(
                            label: FloodSeverityHelper.label(severity),
                            bg: color.withValues(alpha: 0.18),
                            fg: color,
                          ),
                          _Badge(
                            label: data.status,
                            bg: AppPalette.gold.withValues(alpha: 0.10),
                            fg: AppPalette.gold,
                          ),
                          if (data.imdSeverity != null)
                            _Badge(
                              label: 'IMD ● ${data.imdSeverity}',
                              bg: _imdColor(data.imdSeverity!)
                                  .withValues(alpha: 0.15),
                              fg: _imdColor(data.imdSeverity!),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Divider(
              color: AppPalette.abyssStroke,
              height: 1,
              indent: 14,
              endIndent: 14),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _StatChip(
                    icon: Icons.height_rounded,
                    label: 'Level',
                    value: '${data.currentLevel.toStringAsFixed(2)} m',
                    accent: color),
                const SizedBox(width: 8),
                _StatChip(
                    icon: Icons.warning_amber_rounded,
                    label: 'Warning',
                    value: '${data.warningLevel.toStringAsFixed(1)} m',
                    accent: AppPalette.warning),
                const SizedBox(width: 8),
                _StatChip(
                    icon: Icons.water_drop_outlined,
                    label: 'Rain 24h',
                    value:
                        '${data.effectiveRainfallMm.toStringAsFixed(1)} mm',
                    accent: AppPalette.gold),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _StatChip(
                    icon: Icons.stream_rounded,
                    label: 'Danger',
                    value: '${data.dangerLevel.toStringAsFixed(1)} m',
                    accent: AppPalette.danger),
                const SizedBox(width: 8),
                _StatChip(
                    icon: Icons.speed_rounded,
                    label: 'Flow',
                    value: data.flowRate != null
                        ? '${(data.flowRate! / 1000).toStringAsFixed(1)}k m³/s'
                        : 'N/A',
                    accent: data.flowRate != null
                        ? AppPalette.safe
                        : AppPalette.textGrey),
                const SizedBox(width: 8),
                _StatChip(
                    icon: Icons.access_time_rounded,
                    label: 'Updated',
                    value: _timeAgo(data.lastUpdated),
                    accent: AppPalette.textGrey),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: _LevelBar(
              current: data.currentLevel,
              warning: data.warningLevel,
              danger:  data.dangerLevel,
              color:   color,
            ),
          ),
        ],
      ),
    );
  }

  Color _imdColor(String s) {
    switch (s.toUpperCase()) {
      case 'RED':    return AppPalette.critical;
      case 'ORANGE': return AppPalette.warning;
      case 'YELLOW': return const Color(0xFFFFEE58);
      default:       return AppPalette.textGrey;
    }
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1)  return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ArcGauge extends StatelessWidget {
  final double percent, warnAt, size;
  final Color  color;
  final String centerLabel, subLabel;
  const _ArcGauge({
    required this.percent, required this.warnAt,
    required this.color,   required this.size,
    required this.centerLabel, required this.subLabel,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
        width: size, height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(size, size),
              painter: _ArcPainter(
                  percent: percent, warnAt: warnAt, color: color),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(centerLabel,
                    style: TextStyle(
                        color: color, fontSize: 14,
                        fontWeight: FontWeight.w800, height: 1.1)),
                Text(subLabel,
                    style: const TextStyle(
                        color: AppPalette.textGrey,
                        fontSize: 9, letterSpacing: 0.5)),
              ],
            ),
          ],
        ),
      );
}

class _ArcPainter extends CustomPainter {
  final double percent, warnAt;
  final Color  color;
  const _ArcPainter({
    required this.percent, required this.warnAt, required this.color});
  static const _start = math.pi * 0.75;
  static const _sweep = math.pi * 1.5;
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final outer = size.width / 2 - 4;
    final rect  = Rect.fromCircle(center: Offset(cx, cy), radius: outer);
    canvas.drawArc(rect, _start, _sweep, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round
          ..color = AppPalette.abyss2);
    if (percent > 0) {
      canvas.drawArc(
          rect, _start, _sweep * percent.clamp(0, 1), false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8
            ..strokeCap = StrokeCap.round
            ..shader = SweepGradient(
              startAngle: _start,
              endAngle:   _start + _sweep,
              colors: [color.withValues(alpha: 0.5), color],
            ).createShader(rect));
    }
    final wAngle = _start + _sweep * warnAt;
    final tickR  = outer + 3;
    canvas.drawLine(
      Offset(cx + (outer - 10) * math.cos(wAngle),
             cy + (outer - 10) * math.sin(wAngle)),
      Offset(cx + tickR * math.cos(wAngle),
             cy + tickR * math.sin(wAngle)),
      Paint()
        ..color = AppPalette.warning
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    if (percent > 0.01) {
      final dAngle = _start + _sweep * percent;
      final dotC   = Offset(
          cx + outer * math.cos(dAngle),
          cy + outer * math.sin(dAngle));
      canvas.drawCircle(dotC, 4, Paint()..color = color);
      canvas.drawCircle(dotC, 4,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
    }
  }
  @override
  bool shouldRepaint(_ArcPainter o) =>
      o.percent != percent || o.color != color;
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String   label, value;
  final Color    accent;
  const _StatChip({
    required this.icon, required this.label,
    required this.value, required this.accent,
  });
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: accent.withValues(alpha: 0.18), width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 13, color: accent),
              const SizedBox(height: 3),
              Text(value,
                  style: TextStyle(
                      color: accent, fontSize: 12,
                      fontWeight: FontWeight.w700, height: 1.1),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(label,
                  style: const TextStyle(
                      color: AppPalette.textGrey,
                      fontSize: 9, height: 1.2)),
            ],
          ),
        ),
      );
}

class _Badge extends StatelessWidget {
  final String label;
  final Color  bg, fg;
  const _Badge({
    required this.label, required this.bg, required this.fg});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                color: fg, fontSize: 10,
                fontWeight: FontWeight.w700, letterSpacing: 0.4)),
      );
}

class _LevelBar extends StatelessWidget {
  final double current, warning, danger;
  final Color  color;
  const _LevelBar({
    required this.current, required this.warning,
    required this.danger,  required this.color,
  });
  @override
  Widget build(BuildContext context) {
    final pct  = danger > 0 ? (current / danger).clamp(0.0, 1.0) : 0.0;
    final wPct = danger > 0 ? (warning / danger).clamp(0.0, 1.0) : 0.65;
    return Column(
      children: [
        LayoutBuilder(builder: (_, box) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 10,
                  color: AppPalette.abyss2,
                  child: FractionallySizedBox(
                    widthFactor: pct,
                    alignment: Alignment.centerLeft,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(
                          colors: [
                            color.withValues(alpha: 0.55),
                            color,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: box.maxWidth * wPct - 1,
                top: -3,
                child: Container(
                  width: 2.5, height: 16,
                  decoration: BoxDecoration(
                    color: AppPalette.warning,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          );
        }),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${current.toStringAsFixed(1)} m',
                style: const TextStyle(
                    fontSize: 10, color: AppPalette.textGrey)),
            Text('⚠ ${warning.toStringAsFixed(1)} m',
                style: TextStyle(
                    fontSize: 10, color: AppPalette.warning)),
            Text('🔴 ${danger.toStringAsFixed(1)} m',
                style: TextStyle(
                    fontSize: 10, color: AppPalette.danger)),
          ],
        ),
      ],
    );
  }
}
