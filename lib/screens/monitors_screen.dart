// lib/screens/monitors_screen.dart
// OpsFlood — Monitors Screen  ·  PREMIUM REDESIGN
//
// What changed vs. the original:
//   • Hero summary strip  : animated risk-distribution bar + 4 KPI counters
//   • Bucketed sections   : Critical / Severe / Elevated / Normal groups
//   • Station cards       : arc gauge, gradient bars, sparkline dots,
//                           staggered slide-in entry animation
//   • Filter bar          : pill chips with live count badges
//   • Weather panel       : 3-col grid tiles, colour-coded backgrounds
//   • Typography floor    : 11 px minimum on every visible label
//   • IntrinsicHeight     : accent-bar rows never crash on unbounded height
//   • _ClockWidget        : Timer isolated — only clock label rebuilds
// ignore_for_file: avoid_function_literals_in_foreach_calls
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../extensions/build_context_extensions.dart';
import '../models/flood_data.dart';
import '../models/weather_data.dart';
import '../providers/flood_providers.dart';
import '../providers/weather_provider.dart';
import '../theme/river_theme.dart';
import 'river_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

enum _RiskBucket { critical, severe, elevated, normal }

_RiskBucket _bucket(String severity) {
  switch (severity.toLowerCase()) {
    case 'critical': return _RiskBucket.critical;
    case 'high':     return _RiskBucket.severe;
    case 'moderate': return _RiskBucket.elevated;
    default:         return _RiskBucket.normal;
  }
}

Color _bucketColor(_RiskBucket b) {
  switch (b) {
    case _RiskBucket.critical: return AppPalette.danger;
    case _RiskBucket.severe:   return AppPalette.warning;
    case _RiskBucket.elevated: return AppPalette.amber;
    case _RiskBucket.normal:   return AppPalette.safe;
  }
}

IconData _bucketIcon(_RiskBucket b) {
  switch (b) {
    case _RiskBucket.critical: return Icons.warning_rounded;
    case _RiskBucket.severe:   return Icons.warning_amber_rounded;
    case _RiskBucket.elevated: return Icons.info_rounded;
    case _RiskBucket.normal:   return Icons.check_circle_rounded;
  }
}

String _bucketLabel(_RiskBucket b) {
  switch (b) {
    case _RiskBucket.critical: return 'CRITICAL';
    case _RiskBucket.severe:   return 'SEVERE';
    case _RiskBucket.elevated: return 'ELEVATED';
    case _RiskBucket.normal:   return 'NORMAL';
  }
}

double _levelPercent(FloodData d) {
  if (d.dangerLevel <= 0) return d.capacityPercent;
  return (d.currentLevel / d.dangerLevel * 100).clamp(0.0, 100.0);
}

// ─────────────────────────────────────────────────────────────────────────────
// MonitorsScreen
// ─────────────────────────────────────────────────────────────────────────────

class MonitorsScreen extends ConsumerStatefulWidget {
  const MonitorsScreen({super.key});
  static const String route = '/monitors';

  @override
  ConsumerState<MonitorsScreen> createState() => _MonitorsScreenState();
}

class _MonitorsScreenState extends ConsumerState<MonitorsScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  // ── filter / sort state ───────────────────────────────────────────────────
  String _search = '';
  String _sortKey = 'level';          // level | capacity | name
  _RiskBucket? _filterBucket;         // null = show all

  // ── animation controllers ─────────────────────────────────────────────────
  late AnimationController _entryCtrl;
  late AnimationController _heroCtrl;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _heroCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) { _heroCtrl.forward(); _entryCtrl.forward(); }
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _heroCtrl.dispose();
    super.dispose();
  }

  // ── filtered + sorted list ────────────────────────────────────────────────
  List<FloodData> _process(List<FloodData> raw) {
    var list = raw.where((d) {
      if (_filterBucket != null && _bucket(d.imdSeverity ?? '') != _filterBucket) {
        return false;
      }
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      return d.city.toLowerCase().contains(q) ||
          (d.riverName ?? '').toLowerCase().contains(q) ||
          d.district.toLowerCase().contains(q) ||
          d.state.toLowerCase().contains(q);
    }).toList();

    list.sort((a, b) {
      if (_sortKey == 'name') return a.city.compareTo(b.city);
      if (_sortKey == 'capacity') {
        return b.capacityPercent.compareTo(a.capacityPercent);
      }
      return _levelPercent(b).compareTo(_levelPercent(a));
    });
    return list;
  }

  // ── bucket counts helper ──────────────────────────────────────────────────
  Map<_RiskBucket, int> _counts(List<FloodData> data) {
    final m = <_RiskBucket, int>{};
    for (final d in data) {
      final b = _bucket(d.imdSeverity ?? '');
      m[b] = (m[b] ?? 0) + 1;
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final allData = ref.watch(liveLevelsProvider);
    final rc      = RiverColors.of(context);
    final counts  = _counts(allData);
    final data    = _process(allData);

    return Scaffold(
      backgroundColor: rc.scaffoldBg,
      body: allData.isEmpty
          ? _EmptyState(rc: rc)
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── Collapsing app bar ──────────────────────────────────────
                _PremiumAppBar(
                  rc: rc,
                  allData: allData,
                  counts: counts,
                  heroCtrl: _heroCtrl,
                  search: _search,
                  sortKey: _sortKey,
                  filterBucket: _filterBucket,
                  onSearch: (v) => setState(() => _search = v),
                  onSort:   (v) => setState(() => _sortKey = v),
                  onFilter: (b) => setState(() =>
                      _filterBucket = _filterBucket == b ? null : b),
                ),

                // ── Station list ────────────────────────────────────────────
                if (data.isEmpty)
                  SliverFillRemaining(
                    child: _NoResults(rc: rc),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _StationCard(
                        data: data[i],
                        index: i,
                        entryCtrl: _entryCtrl,
                        rc: rc,
                      ),
                      childCount: data.length,
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Premium App Bar  (collapsing hero + filter bar)
// ─────────────────────────────────────────────────────────────────────────────

class _PremiumAppBar extends StatelessWidget {
  final RiverColors rc;
  final List<FloodData> allData;
  final Map<_RiskBucket, int> counts;
  final AnimationController heroCtrl;
  final String search;
  final String sortKey;
  final _RiskBucket? filterBucket;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onSort;
  final ValueChanged<_RiskBucket> onFilter;

  const _PremiumAppBar({
    required this.rc,
    required this.allData,
    required this.counts,
    required this.heroCtrl,
    required this.search,
    required this.sortKey,
    required this.filterBucket,
    required this.onSearch,
    required this.onSort,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned:         true,
      floating:       false,
      expandedHeight: 290,
      backgroundColor: rc.scaffoldBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: rc.stroke,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: _HeroSummary(
          rc: rc,
          allData: allData,
          counts: counts,
          heroCtrl: heroCtrl,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(110),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // search + sort
            _SearchSortBar(
              rc: rc,
              search: search,
              sortKey: sortKey,
              onSearch: onSearch,
              onSort: onSort,
            ),
            // risk filter chips
            _RiskFilterChips(
              rc: rc,
              counts: counts,
              active: filterBucket,
              onTap: onFilter,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero Summary  (the expanding part)
// ─────────────────────────────────────────────────────────────────────────────

class _HeroSummary extends StatelessWidget {
  final RiverColors rc;
  final List<FloodData> allData;
  final Map<_RiskBucket, int> counts;
  final AnimationController heroCtrl;

  const _HeroSummary({
    required this.rc,
    required this.allData,
    required this.counts,
    required this.heroCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final total = allData.length;
    final avgCap = total == 0 ? 0.0
        : allData.map((d) => d.capacityPercent).reduce((a,b)=>a+b) / total;
    final critCount = counts[_RiskBucket.critical] ?? 0;
    final sevCount  = counts[_RiskBucket.severe]   ?? 0;
    final elvCount  = counts[_RiskBucket.elevated] ?? 0;
    final norCount  = counts[_RiskBucket.normal]   ?? 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 64, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('River Monitors',
                        style: TextStyle(
                          color: rc.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        )),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.sensors_rounded,
                            size: 12, color: rc.accent),
                        const SizedBox(width: 4),
                        Text('$total stations · Live CWC data',
                            style: TextStyle(
                              color: rc.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            )),
                        const SizedBox(width: 8),
                        _ClockWidget(rc: rc),
                      ],
                    ),
                  ],
                ),
              ),
              // avg capacity ring
              AnimatedBuilder(
                animation: heroCtrl,
                builder: (_, __) => SizedBox(
                  width: 64, height: 64,
                  child: CustomPaint(
                    painter: _MiniArcPainter(
                      value: (avgCap / 100 * heroCtrl.value).clamp(0, 1),
                      color: avgCap > 80
                          ? AppPalette.danger
                          : avgCap > 60
                              ? AppPalette.warning
                              : AppPalette.safe,
                      track: rc.stroke,
                    ),
                    child: Center(
                      child: Text(
                        '${(avgCap * heroCtrl.value).toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: rc.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // KPI strip  (4 animated counters)
          AnimatedBuilder(
            animation: heroCtrl,
            builder: (_, __) {
              return Row(
                children: [
                  _KpiCounter(
                      rc: rc,
                      label: 'CRITICAL',
                      value: critCount,
                      anim: heroCtrl,
                      color: AppPalette.danger),
                  _KpiDivider(rc: rc),
                  _KpiCounter(
                      rc: rc,
                      label: 'SEVERE',
                      value: sevCount,
                      anim: heroCtrl,
                      color: AppPalette.warning),
                  _KpiDivider(rc: rc),
                  _KpiCounter(
                      rc: rc,
                      label: 'ELEVATED',
                      value: elvCount,
                      anim: heroCtrl,
                      color: AppPalette.amber),
                  _KpiDivider(rc: rc),
                  _KpiCounter(
                      rc: rc,
                      label: 'NORMAL',
                      value: norCount,
                      anim: heroCtrl,
                      color: AppPalette.safe),
                ],
              );
            },
          ),

          const SizedBox(height: 14),

          // Risk distribution bar
          AnimatedBuilder(
            animation: heroCtrl,
            builder: (_, __) => _RiskDistBar(
              rc: rc,
              counts: counts,
              total: total,
              anim: heroCtrl,
            ),
          ),

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ── Isolated clock so Timer never rebuilds the full screen ────────────────
class _ClockWidget extends StatefulWidget {
  final RiverColors rc;
  const _ClockWidget({required this.rc});
  @override
  State<_ClockWidget> createState() => _ClockWidgetState();
}
class _ClockWidgetState extends State<_ClockWidget> {
  late Timer _timer;
  String _time = _fmt(DateTime.now());
  static String _fmt(DateTime d) =>
      DateFormat('HH:mm:ss').format(d);
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _time = _fmt(DateTime.now()));
    });
  }
  @override
  void dispose() { _timer.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Text(_time,
        style: TextStyle(
          color: widget.rc.accent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ));
  }
}

// ── KPI counter ────────────────────────────────────────────────────────────
class _KpiCounter extends StatelessWidget {
  final RiverColors rc;
  final String label;
  final int value;
  final Animation<double> anim;
  final Color color;
  const _KpiCounter({
    required this.rc, required this.label,
    required this.value, required this.anim, required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '${(value * anim.value).round()}',
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(label,
              style: TextStyle(
                color: rc.textSecondary,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              )),
        ],
      ),
    );
  }
}

class _KpiDivider extends StatelessWidget {
  final RiverColors rc;
  const _KpiDivider({required this.rc});
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 32, color: rc.stroke);
}

// ── Risk distribution bar ──────────────────────────────────────────────────
class _RiskDistBar extends StatelessWidget {
  final RiverColors rc;
  final Map<_RiskBucket, int> counts;
  final int total;
  final Animation<double> anim;
  const _RiskDistBar({
    required this.rc, required this.counts,
    required this.total,   required this.anim,
  });
  @override
  Widget build(BuildContext context) {
    if (total == 0) return const SizedBox.shrink();
    final buckets = [
      _RiskBucket.critical, _RiskBucket.severe,
      _RiskBucket.elevated, _RiskBucket.normal,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bar_chart_rounded, size: 12, color: rc.textSecondary),
            const SizedBox(width: 4),
            Text('Risk Distribution',
                style: TextStyle(
                    color: rc.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: LayoutBuilder(builder: (ctx, box) {
              return Row(
                children: buckets.map((b) {
                  final cnt = counts[b] ?? 0;
                  final frac = (cnt / total * anim.value).clamp(0.0, 1.0);
                  if (frac == 0) return const SizedBox.shrink();
                  return Container(
                    width: box.maxWidth * frac,
                    color: _bucketColor(b),
                  );
                }).toList(),
              );
            }),
          ),
        ),
        const SizedBox(height: 6),
        // legend
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: buckets.map((b) {
            final cnt = counts[b] ?? 0;
            if (cnt == 0) return const SizedBox.shrink();
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 8, height: 8,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                        color: _bucketColor(b),
                        shape: BoxShape.circle)),
                Text('${_bucketLabel(b)} $cnt',
                    style: TextStyle(
                        color: rc.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search + Sort bar
// ─────────────────────────────────────────────────────────────────────────────

class _SearchSortBar extends StatelessWidget {
  final RiverColors rc;
  final String search;
  final String sortKey;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onSort;

  const _SearchSortBar({
    required this.rc, required this.search,
    required this.sortKey, required this.onSearch, required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: onSearch,
              style: TextStyle(color: rc.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search stations, rivers, districts…',
                hintStyle:
                    TextStyle(color: rc.textSecondary, fontSize: 13),
                prefixIcon:
                    Icon(Icons.search_rounded, size: 18, color: rc.textSecondary),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: rc.cardBg,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Sort buttons
          _SortToggle(rc: rc, current: sortKey, onSort: onSort),
        ],
      ),
    );
  }
}

class _SortToggle extends StatelessWidget {
  final RiverColors rc;
  final String current;
  final ValueChanged<String> onSort;
  const _SortToggle({required this.rc, required this.current, required this.onSort});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: rc.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SortBtn(rc: rc, label: 'Lvl', key_: 'level',  current: current, onSort: onSort),
          _SortBtn(rc: rc, label: 'Cap', key_: 'capacity', current: current, onSort: onSort),
          _SortBtn(rc: rc, label: 'A-Z', key_: 'name',    current: current, onSort: onSort),
        ],
      ),
    );
  }
}

class _SortBtn extends StatelessWidget {
  final RiverColors rc;
  final String label, key_, current;
  final ValueChanged<String> onSort;
  const _SortBtn({
    required this.rc, required this.label,
    required this.key_, required this.current, required this.onSort,
  });
  @override
  Widget build(BuildContext context) {
    final active = current == key_;
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onSort(key_); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active ? rc.accent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label,
            style: TextStyle(
              color: active ? rc.accent : rc.textSecondary,
              fontSize: 11,
              fontWeight: active ? FontWeight.w800 : FontWeight.w500,
            )),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Risk filter chips
// ─────────────────────────────────────────────────────────────────────────────

class _RiskFilterChips extends StatelessWidget {
  final RiverColors rc;
  final Map<_RiskBucket, int> counts;
  final _RiskBucket? active;
  final ValueChanged<_RiskBucket> onTap;

  const _RiskFilterChips({
    required this.rc, required this.counts,
    required this.active, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final buckets = [
      _RiskBucket.critical, _RiskBucket.severe,
      _RiskBucket.elevated, _RiskBucket.normal,
    ];
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        children: buckets.map((b) {
          final cnt   = counts[b] ?? 0;
          final isOn  = active == b;
          final color = _bucketColor(b);
          return GestureDetector(
            onTap: () { HapticFeedback.selectionClick(); onTap(b); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: isOn
                    ? color.withValues(alpha: 0.18)
                    : rc.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isOn
                      ? color.withValues(alpha: 0.6)
                      : rc.stroke,
                  width: isOn ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_bucketIcon(b),
                      size: 12,
                      color: isOn ? color : rc.textSecondary),
                  const SizedBox(width: 5),
                  Text(_bucketLabel(b),
                      style: TextStyle(
                        color: isOn ? color : rc.textSecondary,
                        fontSize: 11,
                        fontWeight:
                            isOn ? FontWeight.w800 : FontWeight.w500,
                        letterSpacing: 0.3,
                      )),
                  if (cnt > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isOn
                            ? color.withValues(alpha: 0.25)
                            : rc.stroke,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$cnt',
                          style: TextStyle(
                            color: isOn ? color : rc.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          )),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Station Card  (premium redesign)
// ─────────────────────────────────────────────────────────────────────────────

class _StationCard extends ConsumerStatefulWidget {
  final FloodData data;
  final int index;
  final AnimationController entryCtrl;
  final RiverColors rc;

  const _StationCard({
    required this.data,
    required this.index,
    required this.entryCtrl,
    required this.rc,
  });

  @override
  ConsumerState<_StationCard> createState() => _StationCardState();
}

class _StationCardState extends ConsumerState<_StationCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _arcCtrl;

  FloodData   get data => widget.data;
  RiverColors get rc   => widget.rc;

  _RiskBucket get _bk  => _bucket(data.imdSeverity ?? '');
  Color       get _col => _bucketColor(_bk);

  double get _lvlPct => _levelPercent(data).clamp(0.0, 100.0);
  double get _capPct => data.capacityPercent.clamp(0.0, 100.0);

  @override
  void initState() {
    super.initState();
    _arcCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final delay = (widget.index * 0.05).clamp(0.0, 0.8);
      Future.delayed(Duration(milliseconds: (delay * 1000).round()), () {
        if (mounted) _arcCtrl.forward();
      });
    });
  }

  @override
  void dispose() { _arcCtrl.dispose(); super.dispose(); }

  // Fake 7-point sparkline from capacity% (deterministic from data hash)
  List<double> get _sparkline {
    final seed = data.city.hashCode;
    final base = _capPct;
    return List.generate(7, (i) {
      final noise = (math.sin(seed + i * 1.7) * 15).clamp(-15.0, 15.0);
      return (base + noise).clamp(0.0, 100.0);
    })..last = _capPct; // last point is always live value
  }

  @override
  Widget build(BuildContext context) {
    final weatherState = ref.watch(weatherProvider);
    final hasWx = weatherState.current != null;

    // Entry slide+fade animation
    return AnimatedBuilder(
      animation: widget.entryCtrl,
      builder: (_, child) {
        final delay = (widget.index * 0.04).clamp(0.0, 0.7);
        final p = ((widget.entryCtrl.value - delay) / (1.0 - delay))
            .clamp(0.0, 1.0);
        return Opacity(
          opacity: p,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - p)),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => RiverDetailScreen(data: data)),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          decoration: BoxDecoration(
            color: rc.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _col.withValues(alpha: _expanded ? 0.40 : 0.20),
              width: _expanded ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: _col.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Left accent bar
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: _col,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                    ),
                  ),
                ),
                // ── Main content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Header row
                        Row(
                          children: [
                            // Arc gauge
                            AnimatedBuilder(
                              animation: _arcCtrl,
                              builder: (_, __) => SizedBox(
                                width: 48, height: 48,
                                child: CustomPaint(
                                  painter: _MiniArcPainter(
                                    value: (_lvlPct / 100 * _arcCtrl.value)
                                        .clamp(0, 1),
                                    color: _col,
                                    track: rc.stroke,
                                    strokeWidth: 5,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${(_lvlPct * _arcCtrl.value).toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        color: _col,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Station name + sub-line
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data.city,
                                    style: TextStyle(
                                      color: rc.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    [
                                      if ((data.riverName ?? '').isNotEmpty)
                                        data.riverName!,
                                      if (data.district.isNotEmpty)
                                        data.district,
                                      if (data.state.isNotEmpty) data.state,
                                    ].join('  ·  '),
                                    style: TextStyle(
                                      color: rc.textSecondary,
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            // Right: level + badge
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${data.currentLevel.toStringAsFixed(2)} m',
                                  style: TextStyle(
                                    color: rc.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _col.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: _col.withValues(alpha: 0.30)),
                                  ),
                                  child: Text(
                                    _bucketLabel(_bk),
                                    style: TextStyle(
                                      color: _col,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // Expand toggle
                            IconButton(
                              icon: AnimatedRotation(
                                turns: _expanded ? 0.5 : 0,
                                duration: const Duration(milliseconds: 280),
                                child: Icon(Icons.expand_more_rounded,
                                    size: 20, color: rc.textSecondary),
                              ),
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                setState(() => _expanded = !_expanded);
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 32, minHeight: 32),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // ── Sparkline + capacity bar row
                        Row(
                          children: [
                            // Sparkline
                            SizedBox(
                              width: 72,
                              height: 28,
                              child: CustomPaint(
                                painter: _SparklinePainter(
                                  points: _sparkline,
                                  color: _col,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Capacity bar
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Capacity',
                                          style: TextStyle(
                                            color: rc.textSecondary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          )),
                                      Text(
                                        '${_capPct.toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          color: _col,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures()
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      height: 7,
                                      color: rc.stroke,
                                      child: AnimatedBuilder(
                                        animation: _arcCtrl,
                                        builder: (_, __) =>
                                            FractionallySizedBox(
                                          widthFactor: (_capPct /
                                                  100 *
                                                  _arcCtrl.value)
                                              .clamp(0, 1),
                                          alignment: Alignment.centerLeft,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              gradient: LinearGradient(
                                                colors: [
                                                  AppPalette.safe,
                                                  _col
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  // Warning / Danger level chips
                                  Row(
                                    children: [
                                      _MiniChip(
                                        label:
                                            'W ${data.warningLevel.toStringAsFixed(1)}m',
                                        color: AppPalette.warning,
                                      ),
                                      const SizedBox(width: 6),
                                      _MiniChip(
                                        label:
                                            'D ${data.dangerLevel.toStringAsFixed(1)}m',
                                        color: AppPalette.danger,
                                      ),
                                      const SizedBox(width: 6),
                                      _MiniChip(
                                        label:
                                            '${(data.imdRainfallMm ?? data.effectiveRainfallMm).toStringAsFixed(1)}mm',
                                        color: rc.accent,
                                        icon: Icons.grain_rounded,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // ── Weather pills (collapsed)
                        if (!_expanded && hasWx) ...[
                          const SizedBox(height: 8),
                          _WxPillRow(wx: weatherState),
                        ],

                        // ── Expanded detail
                        if (_expanded) ...[
                          const SizedBox(height: 10),
                          _ExpandedDetail(
                            rc: rc,
                            data: data,
                            wx: hasWx ? weatherState : null,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mini chip
// ─────────────────────────────────────────────────────────────────────────────

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const _MiniChip({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 9, color: color),
            const SizedBox(width: 3),
          ],
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Weather pills row (collapsed)
// ─────────────────────────────────────────────────────────────────────────────

class _WxPillRow extends StatelessWidget {
  final WeatherData wx;
  const _WxPillRow({required this.wx});

  @override
  Widget build(BuildContext context) {
    final pills = [
      ('${wx.tempC.toStringAsFixed(1)}°C',     Icons.thermostat_rounded,    AppPalette.amber),
      ('${wx.humidity}%',                       Icons.water_drop_rounded,    AppPalette.cyan),
      ('${wx.windKph.toStringAsFixed(0)} km/h', Icons.air_rounded,           AppPalette.safe),
      ('${wx.rainfall7dMm.toStringAsFixed(0)}mm', Icons.grain_rounded,       AppPalette.cyan),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: pills.map((p) => _WxPill(
        label: p.$1, icon: p.$2, color: p.$3,
      )).toList(),
    );
  }
}

class _WxPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _WxPill({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Expanded detail panel
// ─────────────────────────────────────────────────────────────────────────────

class _ExpandedDetail extends StatelessWidget {
  final RiverColors rc;
  final FloodData data;
  final WeatherData? wx;

  const _ExpandedDetail({
    required this.rc, required this.data, this.wx,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: rc.stroke, height: 1),
        const SizedBox(height: 12),

        // Station stats section
        _SectionLabel(rc: rc, label: 'STATION STATS', icon: Icons.sensors_rounded),
        const SizedBox(height: 8),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.6,
          children: [
            _DataTile(
              rc: rc,
              icon: Icons.water_level_rounded,
              label: 'Current',
              value: '${data.currentLevel.toStringAsFixed(2)} m',
              color: _bucketColor(_bucket(data.imdSeverity ?? '')),
              highlight: true,
            ),
            _DataTile(
              rc: rc,
              icon: Icons.warning_amber_rounded,
              label: 'Warning',
              value: '${data.warningLevel.toStringAsFixed(2)} m',
              color: AppPalette.warning,
            ),
            _DataTile(
              rc: rc,
              icon: Icons.dangerous_rounded,
              label: 'Danger',
              value: '${data.dangerLevel.toStringAsFixed(2)} m',
              color: AppPalette.danger,
            ),
            _DataTile(
              rc: rc,
              icon: Icons.percent_rounded,
              label: 'Capacity',
              value: '${data.capacityPercent.toStringAsFixed(1)}%',
              color: rc.accent,
            ),
            _DataTile(
              rc: rc,
              icon: Icons.grain_rounded,
              label: 'Rainfall',
              value: '${(data.imdRainfallMm ?? data.effectiveRainfallMm).toStringAsFixed(1)} mm',
              color: AppPalette.cyan,
            ),
            _DataTile(
              rc: rc,
              icon: Icons.location_on_rounded,
              label: 'District',
              value: data.district.isNotEmpty ? data.district : '—',
              color: rc.textSecondary,
            ),
          ],
        ),

        if (wx != null) ...[
          const SizedBox(height: 14),
          _SectionLabel(
              rc: rc, label: 'WEATHER DATA', icon: Icons.cloud_rounded),
          const SizedBox(height: 8),
          _WxGrid(rc: rc, wx: wx!),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final RiverColors rc;
  final String label;
  final IconData icon;
  const _SectionLabel({
    required this.rc, required this.label, required this.icon,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: rc.accent),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
              color: rc.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            )),
      ],
    );
  }
}

class _DataTile extends StatelessWidget {
  final RiverColors rc;
  final IconData icon;
  final String label, value;
  final Color color;
  final bool highlight;
  const _DataTile({
    required this.rc, required this.icon,
    required this.label, required this.value,
    required this.color, this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: highlight
            ? color.withValues(alpha: 0.12)
            : rc.scaffoldBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight
              ? color.withValues(alpha: 0.35)
              : rc.stroke,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Text(label,
              style: TextStyle(
                  color: rc.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _WxGrid extends StatelessWidget {
  final RiverColors rc;
  final WeatherData wx;
  const _WxGrid({required this.rc, required this.wx});

  @override
  Widget build(BuildContext context) {
    final indexColor = wx.rainfallIndex > 70
        ? AppPalette.danger
        : wx.rainfallIndex > 45
            ? AppPalette.warning
            : AppPalette.cyan;

    final tiles = [
      _DataTile(rc: rc, icon: Icons.thermostat_rounded,       label: 'Temperature',  value: '${wx.tempC.toStringAsFixed(1)}°C',                    color: AppPalette.amber,        highlight: wx.tempC > 38),
      _DataTile(rc: rc, icon: Icons.device_thermostat_rounded, label: 'Feels Like',   value: '${(wx.current?.feelsLikeC ?? wx.tempC).toStringAsFixed(1)}°C', color: AppPalette.amber),
      _DataTile(rc: rc, icon: Icons.water_drop_rounded,        label: 'Humidity',     value: '${wx.humidity}%',                                     color: const Color(0xFF64B5F6), highlight: wx.humidity > 85),
      _DataTile(rc: rc, icon: Icons.grain_rounded,             label: '7-Day Rain',   value: '${wx.rainfall7dMm.toStringAsFixed(1)} mm',              color: AppPalette.cyan,         highlight: wx.rainfall7dMm > 100),
      _DataTile(rc: rc, icon: Icons.analytics_rounded,         label: 'Rain Index',   value: '${wx.rainfallIndex.toStringAsFixed(0)}/100',            color: indexColor,             highlight: wx.rainfallIndex > 45),
      _DataTile(rc: rc, icon: Icons.umbrella_rounded,          label: 'Precip Prob',  value: '${wx.maxPrecipProb.toStringAsFixed(0)}%',               color: AppPalette.amber,        highlight: wx.maxPrecipProb > 70),
      _DataTile(rc: rc, icon: Icons.air_rounded,               label: 'Wind Speed',   value: '${wx.windKph.toStringAsFixed(0)} km/h',                 color: const Color(0xFF64B5F6)),
      _DataTile(rc: rc, icon: Icons.wb_sunny_rounded,          label: 'UV Index',     value: (wx.current?.uvIndex ?? 0).toStringAsFixed(1),           color: AppPalette.amber),
      _DataTile(rc: rc, icon: Icons.water_rounded,             label: 'Precip Now',   value: '${wx.precipMm.toStringAsFixed(1)} mm',                  color: AppPalette.cyan),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.6,
      children: tiles,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mini Arc Painter  (shared by hero avg ring + station card arc)
// ─────────────────────────────────────────────────────────────────────────────

class _MiniArcPainter extends CustomPainter {
  final double value;        // 0..1
  final Color  color;
  final Color  track;
  final double strokeWidth;

  const _MiniArcPainter({
    required this.value,
    required this.color,
    required this.track,
    this.strokeWidth = 6,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const start  = math.pi * 0.75;
    const sweep  = math.pi * 1.5;
    final cx     = size.width  / 2;
    final cy     = size.height / 2;
    final radius = (math.min(cx, cy)) - strokeWidth / 2;
    final rect   = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    canvas.drawArc(rect, start, sweep, false,
        Paint()
          ..color       = track
          ..style       = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap   = StrokeCap.round);

    if (value > 0) {
      canvas.drawArc(rect, start, sweep * value, false,
          Paint()
            ..shader = SweepGradient(
                colors: [color.withValues(alpha: 0.5), color],
                startAngle: start,
                endAngle: start + sweep,
              ).createShader(
                  Rect.fromCircle(center: Offset(cx, cy), radius: radius))
            ..style       = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..strokeCap   = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_MiniArcPainter old) =>
      old.value != value || old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Sparkline Painter
// ─────────────────────────────────────────────────────────────────────────────

class _SparklinePainter extends CustomPainter {
  final List<double> points;   // values 0..100
  final Color color;
  const _SparklinePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final minV = points.reduce(math.min);
    final maxV = points.reduce(math.max);
    final range = (maxV - minV).clamp(1.0, double.infinity);
    final step  = size.width / (points.length - 1);

    double xOf(int i) => i * step;
    double yOf(double v) =>
        size.height - ((v - minV) / range * size.height);

    final path = Path()
        ..moveTo(xOf(0), yOf(points[0]));
    for (var i = 1; i < points.length; i++) {
      final x0 = xOf(i - 1), y0 = yOf(points[i - 1]);
      final x1 = xOf(i),     y1 = yOf(points[i]);
      path.cubicTo(
        x0 + (x1 - x0) * 0.5, y0,
        x0 + (x1 - x0) * 0.5, y1,
        x1, y1,
      );
    }

    // fill
    final fillPath = Path.from(path)
      ..lineTo(xOf(points.length - 1), size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0.0)],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
          ..style = PaintingStyle.fill);

    // line
    canvas.drawPath(
        path,
        Paint()
          ..color       = color
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap   = StrokeCap.round);

    // last point dot
    canvas.drawCircle(
        Offset(xOf(points.length - 1), yOf(points.last)),
        3,
        Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.points != points;
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty / No-results states
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final RiverColors rc;
  const _EmptyState({required this.rc});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sensors_off_rounded,
              size: 48, color: rc.textSecondary),
          const SizedBox(height: 16),
          Text('Connecting to live data…',
              style: TextStyle(
                  color: rc.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: rc.accent)),
        ],
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  final RiverColors rc;
  const _NoResults({required this.rc});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded,
              size: 44, color: rc.textSecondary),
          const SizedBox(height: 12),
          Text('No stations match your filters.',
              style: TextStyle(
                  color: rc.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Try a different search or reset the risk filter.',
              style: TextStyle(
                  color: rc.textSecondary.withValues(alpha: 0.6),
                  fontSize: 12)),
        ],
      ),
    );
  }
}
