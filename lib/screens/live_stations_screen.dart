// lib/screens/live_stations_screen.dart
// LiveStationsScreen v4  —  FloodSeverityHelper + SparklineChart + sort/filter
// AdMob interstitial (ca-app-pub-6001698589023170/6530780174) shown on back-press
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/intl.dart';

import '../l10n/context_l10n.dart';
import '../models/flood_data.dart';
import '../providers/flood_providers.dart';
import '../theme/river_theme.dart';
import '../utils/flood_severity_helper.dart';
import '../widgets/sparkline_chart.dart';
import 'city_detail_screen.dart';

// ── Ad Unit ID ───────────────────────────────────────────────────────────────
const String _kInterstitialAdUnitId = 'ca-app-pub-6001698589023170/6530780174';

enum _SortMode { severity, level, name, updated }

class LiveStationsScreen extends ConsumerStatefulWidget {
  const LiveStationsScreen({super.key});

  @override
  ConsumerState<LiveStationsScreen> createState() => _LiveStationsScreenState();
}

class _LiveStationsScreenState extends ConsumerState<LiveStationsScreen> {
  InterstitialAd? _interstitialAd;
  String _query = '';
  _SortMode _sort = _SortMode.severity;
  String? _stateFilter; // null = all states

  @override
  void initState() {
    super.initState();
    _loadInterstitial();
  }

  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: _kInterstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialAd!.setImmersiveMode(true);
        },
        onAdFailedToLoad: (_) => _interstitialAd = null,
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (_interstitialAd != null) {
      await _interstitialAd!.show();
      _interstitialAd = null;
      _loadInterstitial();
    }
    return true;
  }

  @override
  void dispose() {
    _interstitialAd?.dispose();
    super.dispose();
  }

  List<FloodData> _process(List<FloodData> all) {
    var list = all.where((fd) {
      if (_stateFilter != null && fd.state != _stateFilter) return false;
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return fd.city.toLowerCase().contains(q) ||
          fd.state.toLowerCase().contains(q) ||
          fd.district.toLowerCase().contains(q) ||
          (fd.riverName?.toLowerCase().contains(q) ?? false);
    }).toList();

    switch (_sort) {
      case _SortMode.severity:
        list.sort((a, b) =>
            FloodSeverityHelper.fromString(b.status).index -
            FloodSeverityHelper.fromString(a.status).index);
      case _SortMode.level:
        list.sort((a, b) => b.currentLevel.compareTo(a.currentLevel));
      case _SortMode.name:
        list.sort((a, b) => a.city.compareTo(b.city));
      case _SortMode.updated:
        list.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final s        = context.l10n;
    final all      = ref.watch(liveLevelsProvider);
    final stations = _process(all);

    final states = all.map((e) => e.state).toSet().toList()..sort();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: AppPalette.abyss0,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── App Bar ──────────────────────────────────────────────────
            SliverAppBar(
              pinned: true,
              floating: false,
              expandedHeight: 100,
              backgroundColor: AppPalette.abyss0,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              iconTheme:
                  const IconThemeData(color: AppPalette.textWhite),
              flexibleSpace: FlexibleSpaceBar(
                titlePadding:
                    const EdgeInsets.only(left: 56, bottom: 14),
                title: Text(
                  s.liveData,
                  style: const TextStyle(
                    color: AppPalette.textWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                background: Container(
                  decoration: AppPalette.scaffoldDecoration(),
                ),
              ),
            ),

            // ── Search bar ───────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: TextField(
                  style: const TextStyle(
                      color: AppPalette.textWhite, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search city, district, river…',
                    hintStyle: const TextStyle(
                        color: AppPalette.textGrey, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppPalette.gold, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded,
                                size: 18, color: AppPalette.textGrey),
                            onPressed: () =>
                                setState(() => _query = ''),
                          )
                        : null,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
            ),

            // ── Sort + State filter chips ─────────────────────────────────
            SliverToBoxAdapter(
              child: SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    // Sort chips
                    for (final mode in _SortMode.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _FilterChip(
                          label: _sortLabel(mode),
                          selected: _sort == mode,
                          onTap: () => setState(() => _sort = mode),
                        ),
                      ),
                    const VerticalDivider(
                        width: 16, color: AppPalette.abyssStroke),
                    // State filter chips
                    _FilterChip(
                      label: 'All States',
                      selected: _stateFilter == null,
                      onTap: () =>
                          setState(() => _stateFilter = null),
                    ),
                    for (final st in states)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: _FilterChip(
                          label: st,
                          selected: _stateFilter == st,
                          onTap: () =>
                              setState(() => _stateFilter = st),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── Station count ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  '${stations.length} station${stations.length == 1 ? '' : 's'}'
                  '${_stateFilter != null ? ' in $_stateFilter' : ''}',
                  style: const TextStyle(
                      color: AppPalette.textGrey,
                      fontSize: 11,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ),

            // ── List / empty ──────────────────────────────────────────────
            stations.isEmpty
                ? SliverFillRemaining(
                    child: _EmptyStations(label: s.noStationsFound),
                  )
                : SliverPadding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _StationTile(
                          data: stations[i],
                          onTap: () => Navigator.pushNamed(
                            ctx,
                            CityDetailScreen.route,
                            arguments: stations[i].city,
                          ),
                        ),
                        childCount: stations.length,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  String _sortLabel(_SortMode m) => switch (m) {
    _SortMode.severity => '⚡ Severity',
    _SortMode.level    => '📏 Level',
    _SortMode.name     => '🔤 Name',
    _SortMode.updated  => '🕐 Recent',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Station Tile  (now with inline sparkline)
// ─────────────────────────────────────────────────────────────────────────────

class _StationTile extends ConsumerWidget {
  final FloodData data;
  final VoidCallback onTap;
  const _StationTile({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sev   = FloodSeverityHelper.fromString(data.status);
    final color = FloodSeverityHelper.color(sev);
    final fill  = (data.capacityPercent / 100).clamp(0.0, 1.0);

    // Pull trend snapshots from service for sparkline
    final rt      = ref.watch(realTimeServiceProvider);
    final trend   = rt.trendForCity(data.city);
    final hasData = trend.length >= 2;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        decoration: BoxDecoration(
          color: AppPalette.abyss2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: FloodSeverityHelper.cardBorder(sev), width: 0.9),
          boxShadow: [
            BoxShadow(
              color: FloodSeverityHelper.glowColor(sev),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Top row ─────────────────────────────────────────────────
            Row(
              children: [
                // Status icon
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.10),
                    border: Border.all(
                        color: color.withValues(alpha: 0.30)),
                  ),
                  child: Icon(FloodSeverityHelper.icon(sev),
                      color: color, size: 18),
                ),
                const SizedBox(width: 10),
                // Name + meta
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.city,
                        style: const TextStyle(
                          color: AppPalette.textWhite,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if ((data.riverName ?? '').isNotEmpty)
                            data.riverName!,
                          if (data.district.isNotEmpty)
                            data.district
                          else if (data.state.isNotEmpty)
                            data.state,
                        ].join(' · '),
                        style: const TextStyle(
                          color: AppPalette.textGrey,
                          fontSize: 10,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Level + badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${data.currentLevel.toStringAsFixed(2)} m',
                      style: TextStyle(
                        color: color,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 3),
                    _RiskBadge(
                        label: FloodSeverityHelper.label(sev),
                        color: color),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 9),

            // ── Sparkline OR level bar ───────────────────────────────────
            if (hasData)
              SparklineChart(
                snapshots: trend,
                warningLevel: data.warningLevel,
                dangerLevel: data.dangerLevel,
                color: color,
                height: 42,
              )
            else
              _LevelBar(fill: fill, color: color),

            const SizedBox(height: 7),

            // ── Stats row ────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _mini('W ${data.warningLevel.toStringAsFixed(1)} m',
                    AppPalette.warning),
                _mini('D ${data.dangerLevel.toStringAsFixed(1)} m',
                    AppPalette.danger),
                _mini('${data.effectiveRainfallMm.toStringAsFixed(1)} mm',
                    AppPalette.gold),
                Text(
                  DateFormat('HH:mm')
                      .format(data.lastUpdated.toLocal()),
                  style: const TextStyle(
                      color: AppPalette.textDim, fontSize: 9),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _mini(String t, Color c) => Text(t,
      style: TextStyle(
          color: c, fontSize: 9, fontWeight: FontWeight.w600));
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter Chip
// ─────────────────────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? AppPalette.gold.withValues(alpha: 0.15)
                : AppPalette.abyss2,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? AppPalette.gold
                  : AppPalette.abyssStroke,
              width: selected ? 1.2 : 0.8,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? AppPalette.gold
                  : AppPalette.textGrey,
              fontSize: 11,
              fontWeight: selected
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Level Bar (fallback when no trend data)
// ─────────────────────────────────────────────────────────────────────────────

class _LevelBar extends StatelessWidget {
  final double fill;
  final Color color;
  const _LevelBar({required this.fill, required this.color});

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Container(
            height: 5,
            decoration: BoxDecoration(
              color: AppPalette.abyss4,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          FractionallySizedBox(
            widthFactor: fill,
            child: Container(
              height: 5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.40), color],
                ),
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(
                      color: color.withValues(alpha: 0.40),
                      blurRadius: 4),
                ],
              ),
            ),
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Risk Badge
// ─────────────────────────────────────────────────────────────────────────────

class _RiskBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _RiskBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 8,
                fontWeight: FontWeight.w900)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyStations extends StatelessWidget {
  final String label;
  const _EmptyStations({required this.label});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppPalette.gold.withValues(alpha: 0.10),
                  AppPalette.abyss2,
                ]),
                border: Border.all(
                    color: AppPalette.gold.withValues(alpha: 0.20)),
              ),
              child: const Icon(Icons.sensors_off_rounded,
                  color: AppPalette.gold, size: 32),
            ),
            const SizedBox(height: 16),
            Text(label,
                style: const TextStyle(
                  color: AppPalette.textGrey,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      );
}
