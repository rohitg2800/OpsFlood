// lib/screens/live_stations_screen.dart
// LiveStationsScreen v6  — FULLY THEME-AWARE (RiverColors)
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

const String _kInterstitialAdUnitId = 'ca-app-pub-6001698589023170/6530780174';

enum _SortMode { severity, level, name, updated }

class LiveStationsScreen extends ConsumerStatefulWidget {
  const LiveStationsScreen({super.key});

  @override
  ConsumerState<LiveStationsScreen> createState() => _LiveStationsScreenState();
}

class _LiveStationsScreenState extends ConsumerState<LiveStationsScreen> {
  InterstitialAd? _interstitialAd;
  String    _query       = '';
  _SortMode _sort        = _SortMode.severity;
  String?   _stateFilter;
  String?   _expanded;

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
    final t        = RiverColors.of(context);
    final s        = context.l10n;
    final all      = ref.watch(liveLevelsProvider);
    final stations = _process(all);
    final states   = all.map((e) => e.state).toSet().toList()..sort();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: t.scaffoldBg,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              floating: false,
              expandedHeight: 100,
              backgroundColor: t.navBg,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: t.textPrimary),
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 56, bottom: 14),
                title: Text(
                  s.liveData,
                  style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                background: Container(color: t.navBg),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: TextField(
                  style: TextStyle(color: t.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search city, district, river…',
                    hintStyle: TextStyle(
                        color: t.textSecondary, fontSize: 13),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: t.accent, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.close_rounded,
                                size: 18, color: t.textSecondary),
                            onPressed: () =>
                                setState(() => _query = ''),
                          )
                        : null,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final mode in _SortMode.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _FilterChip(
                          label: _sortLabel(mode),
                          selected: _sort == mode,
                          onTap: () => setState(() => _sort = mode),
                        ),
                      ),
                    VerticalDivider(
                        width: 16, color: t.stroke),
                    _FilterChip(
                      label: 'All States',
                      selected: _stateFilter == null,
                      onTap: () => setState(() => _stateFilter = null),
                    ),
                    for (final st in states)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: _FilterChip(
                          label: st,
                          selected: _stateFilter == st,
                          onTap: () => setState(() => _stateFilter = st),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  '${stations.length} station${stations.length == 1 ? '' : 's'}'
                  '${_stateFilter != null ? ' in $_stateFilter' : ''}',
                  style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ),
            stations.isEmpty
                ? const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyStations(),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _StationCard(
                          data:       stations[i],
                          isExpanded: _expanded == stations[i].city,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _expanded =
                                _expanded == stations[i].city
                                    ? null
                                    : stations[i].city);
                          },
                          onDetailTap: () => Navigator.pushNamed(
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

class _StationCard extends ConsumerWidget {
  final FloodData    data;
  final bool         isExpanded;
  final VoidCallback onTap;
  final VoidCallback onDetailTap;
  const _StationCard({
    required this.data,
    required this.isExpanded,
    required this.onTap,
    required this.onDetailTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t      = RiverColors.of(context);
    final sev    = FloodSeverityHelper.fromString(data.status);
    final color  = FloodSeverityHelper.color(sev);
    final fill   = (data.capacityPercent / 100).clamp(0.0, 1.0);
    final isCrit = sev == FloodSeverity.critical || sev == FloodSeverity.danger;

    final rt       = ref.watch(realTimeServiceProvider);
    final trend    = rt.trendForCity(data.city);
    final hasTrend = trend.length >= 2;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        decoration: BoxDecoration(
          color: isExpanded
              ? color.withValues(alpha: 0.06)
              : t.cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isExpanded || isCrit
                ? color.withValues(alpha: isExpanded ? 0.40 : 0.20)
                : t.stroke,
            width: isExpanded ? 1.5 : 0.9,
          ),
          boxShadow: (isExpanded || isCrit)
              ? [
                  BoxShadow(
                    color: color.withValues(
                        alpha: isExpanded ? 0.12 : 0.06),
                    blurRadius: 14,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 42, height: 42,
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.city,
                        style: TextStyle(
                          color: t.textPrimary,
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
                        style: TextStyle(
                          color: t.textSecondary,
                          fontSize: 10,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
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
            if (hasTrend)
              SparklineChart(
                snapshots:    trend,
                warningLevel: data.warningLevel,
                dangerLevel:  data.dangerLevel,
                color:        color,
                height:       42,
              )
            else
              _LevelBar(fill: fill, color: color),
            const SizedBox(height: 7),
            if (!isExpanded)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _mini('W ${data.warningLevel.toStringAsFixed(1)} m',
                      AppPalette.warning),
                  _mini('D ${data.dangerLevel.toStringAsFixed(1)} m',
                      AppPalette.danger),
                  _mini(
                      '${data.effectiveRainfallMm.toStringAsFixed(1)} mm',
                      AppPalette.gold),
                  Text(
                    DateFormat('HH:mm')
                        .format(data.lastUpdated.toLocal()),
                    style: TextStyle(
                        color: t.textSecondary.withValues(alpha: 0.5),
                        fontSize: 9),
                  ),
                ],
              ),
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              child: isExpanded
                  ? _ExpandPanel(
                      data:       data,
                      color:      color,
                      onDetailTap: onDetailTap,
                    )
                  : const SizedBox.shrink(),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Center(
                child: AnimatedRotation(
                  turns:    isExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 260),
                  child: Icon(
                    Icons.expand_more_rounded,
                    color: t.textSecondary.withValues(alpha: 0.45),
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mini(String tx, Color c) => Text(tx,
      style: TextStyle(
          color: c, fontSize: 9, fontWeight: FontWeight.w600));
}

class _ExpandPanel extends StatelessWidget {
  final FloodData    data;
  final Color        color;
  final VoidCallback onDetailTap;
  const _ExpandPanel({
    required this.data,
    required this.color,
    required this.onDetailTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 1,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent,
                color.withValues(alpha: 0.25),
                Colors.transparent,
              ]),
            ),
          ),
          Row(children: [
            Expanded(child: _ThresholdPill(
                label: 'Safe',
                value: '${data.safeLevel.toStringAsFixed(1)} m',
                color: AppPalette.safe)),
            const SizedBox(width: 8),
            Expanded(child: _ThresholdPill(
                label: 'Warning',
                value: '${data.warningLevel.toStringAsFixed(1)} m',
                color: AppPalette.warning)),
            const SizedBox(width: 8),
            Expanded(child: _ThresholdPill(
                label: 'Danger',
                value: '${data.dangerLevel.toStringAsFixed(1)} m',
                color: AppPalette.danger)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _InfoTile(
              icon:  Icons.grain_rounded,
              label: 'Rainfall',
              value: '${data.effectiveRainfallMm.toStringAsFixed(1)} mm',
              color: AppPalette.gold,
            )),
            const SizedBox(width: 8),
            Expanded(child: _InfoTile(
              icon:  Icons.speed_rounded,
              label: 'Flow Rate',
              value: data.flowRate != null
                  ? '${data.flowRate!.toStringAsFixed(0)} m³/s' : '—',
              color: AppPalette.cyan,
            )),
          ]),
          const SizedBox(height: 8),
          _GapBar(
              current: data.currentLevel,
              danger:  data.dangerLevel,
              color:   color),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onDetailTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: color.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.open_in_new_rounded,
                      color: color, size: 13),
                  const SizedBox(width: 6),
                  Text('Full Details',
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      )),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatusBadge(status: data.status),
                Text(
                  DateFormat('dd MMM HH:mm')
                      .format(data.lastUpdated.toLocal()),
                  style: TextStyle(
                      color: t.textSecondary.withValues(alpha: 0.5),
                      fontSize: 9.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThresholdPill extends StatelessWidget {
  final String label, value;
  final Color  color;
  const _ThresholdPill(
      {required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
        decoration: BoxDecoration(
          color:        color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w800),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: t.textSecondary.withValues(alpha: 0.5), fontSize: 8)),
        ]));
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String   label, value;
  final Color    color;
  const _InfoTile(
      {required this.icon, required this.label,
       required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color:        t.chipBg,
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: t.stroke),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis),
                Text(label,
                    style: TextStyle(
                        color: t.textSecondary.withValues(alpha: 0.6),
                        fontSize: 8.5)),
              ],
            ),
          ),
        ]));
  }
}

class _GapBar extends StatelessWidget {
  final double current, danger;
  final Color  color;
  const _GapBar(
      {required this.current, required this.danger, required this.color});
  @override
  Widget build(BuildContext context) {
    final t   = RiverColors.of(context);
    final gap     = (danger - current).clamp(0.0, danger);
    final isAbove = current >= danger;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color:        t.chipBg,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: t.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isAbove
                ? '⚠ ${(current - danger).abs().toStringAsFixed(2)} m above danger'
                : '${gap.toStringAsFixed(2)} m to danger level',
            style: TextStyle(
              fontSize: 10,
              color: isAbove ? AppPalette.critical : t.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Stack(children: [
            Container(
                height: 5,
                decoration: BoxDecoration(
                    color: t.stroke,
                    borderRadius: BorderRadius.circular(3))),
            FractionallySizedBox(
              widthFactor:
                  (current / danger.clamp(1.0, double.infinity))
                      .clamp(0.0, 1.0),
              child: Container(
                height: 5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [color.withValues(alpha: 0.4), color]),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 4),
                  ],
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    final isLive = ['LIVE', 'REAL', 'CRITICAL', 'DANGER', 'WARNING', 'SAFE']
        .contains(status.toUpperCase());
    final c = isLive ? AppPalette.safe : RiverColors.of(context).textSecondary.withValues(alpha: 0.4);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 5, height: 5,
            decoration:
                BoxDecoration(shape: BoxShape.circle, color: c)),
        const SizedBox(width: 4),
        Text(status.toUpperCase(),
            style: TextStyle(
              color: c, fontSize: 8, fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            )),
      ]),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String     label;
  final bool       selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? t.accent.withValues(alpha: 0.15)
                : t.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? t.accent : t.stroke,
              width: selected ? 1.2 : 0.8,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? t.accent : t.textSecondary,
              fontSize: 11,
              fontWeight:
                  selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ));
  }
}

class _LevelBar extends StatelessWidget {
  final double fill;
  final Color  color;
  const _LevelBar({required this.fill, required this.color});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Stack(
        children: [
          Container(
            height: 5,
            decoration: BoxDecoration(
              color: t.chipBg,
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
        ]);
  }
}

class _RiskBadge extends StatelessWidget {
  final String label;
  final Color  color;
  const _RiskBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color:        color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(6),
          border:       Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 8,
                fontWeight: FontWeight.w900)),
      );
}

class _EmptyStations extends StatelessWidget {
  const _EmptyStations();

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final availH  = constraints.maxHeight;
        final showIcon = availH > 80;
        final iconSize = (availH * 0.35).clamp(24.0, 72.0);
        final boxSize  = iconSize + 16;

        return Center(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showIcon) ...[
                    Container(
                      width: boxSize, height: boxSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          t.accent.withValues(alpha: 0.10),
                          t.cardBg,
                        ]),
                        border: Border.all(
                            color: t.accent.withValues(alpha: 0.20)),
                      ),
                      child: Icon(Icons.sensors_off_rounded,
                          color: t.accent, size: iconSize * 0.48),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    context.l10n.noStationsFound,
                    style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
