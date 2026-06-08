// lib/screens/monitors_screen.dart
// OpsFlood — Monitors Screen  ·  PREMIUM REDESIGN  v3
//
// v3 crash-fix (IntrinsicHeight + GridView.count):
//   • _StationCard: replaced IntrinsicHeight ← Row with Stack so the
//     left accent bar can stretch without asking a viewport for intrinsics.
//   • _ExpandedDetail: replaced GridView.count(shrinkWrap: true) with
//     _DataGrid — a plain Column of Row<Expanded> tiles. No viewport.
//   • _WxGrid: same treatment — Column of 3-column Rows, no GridView.
//   • _DataTile: fixed height (72 px) via SizedBox instead of aspect ratio.
// ignore_for_file: avoid_function_literals_in_foreach_calls
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../extensions/build_context_extensions.dart';
import '../models/river_station.dart';
import '../models/weather_data.dart';
import '../providers/real_time_river_provider.dart';
import '../providers/weather_provider.dart';
import '../theme/river_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

enum _RiskBucket { critical, severe, elevated, normal }

_RiskBucket _bucket(RiverStation s) {
  switch (s.dangerClass) {
    case DangerClass.extreme:     return _RiskBucket.critical;
    case DangerClass.severe:      return _RiskBucket.severe;
    case DangerClass.aboveNormal: return _RiskBucket.elevated;
    default:                      return _RiskBucket.normal;
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

  String _search = '';
  String _sortKey = 'level';
  _RiskBucket? _filterBucket;

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

  List<RiverStation> _process(List<RiverStation> raw) {
    var list = raw.where((s) {
      if (_filterBucket != null && _bucket(s) != _filterBucket) return false;
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      return s.station.toLowerCase().contains(q) ||
          s.river.toLowerCase().contains(q) ||
          s.city.toLowerCase().contains(q) ||
          s.state.toLowerCase().contains(q);
    }).toList();

    list.sort((a, b) {
      if (_sortKey == 'name')     return a.station.compareTo(b.station);
      if (_sortKey == 'capacity') return b.progressPct.compareTo(a.progressPct);
      return b.current.compareTo(a.current);
    });
    return list;
  }

  Map<_RiskBucket, int> _counts(List<RiverStation> data) {
    final m = <_RiskBucket, int>{};
    for (final s in data) {
      final b = _bucket(s);
      m[b] = (m[b] ?? 0) + 1;
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final allData = ref.watch(mergedStationsProvider);
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
                if (data.isEmpty)
                  SliverFillRemaining(child: _NoResults(rc: rc))
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _StationCard(
                        station: data[i],
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
// Premium App Bar
// ─────────────────────────────────────────────────────────────────────────────

class _PremiumAppBar extends StatelessWidget {
  final RiverColors rc;
  final List<RiverStation> allData;
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
            _SearchSortBar(
              rc: rc,
              search: search,
              sortKey: sortKey,
              onSearch: onSearch,
              onSort: onSort,
            ),
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
// Hero Summary
// ─────────────────────────────────────────────────────────────────────────────

class _HeroSummary extends StatelessWidget {
  final RiverColors rc;
  final List<RiverStation> allData;
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
    final total  = allData.length;
    final avgCap = total == 0
        ? 0.0
        : allData.map((s) => s.progressPct).reduce((a, b) => a + b) / total;
    final critCount = counts[_RiskBucket.critical] ?? 0;
    final sevCount  = counts[_RiskBucket.severe]   ?? 0;
    final elvCount  = counts[_RiskBucket.elevated] ?? 0;
    final norCount  = counts[_RiskBucket.normal]   ?? 0;
    final hasCwc = allData.any((s) => s.dataSource?.contains('CWC') ?? false);
    final sourceLabel = hasCwc ? 'Live CWC+WRD data' : 'Live WRD data';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 64, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                        Icon(Icons.sensors_rounded, size: 12, color: rc.accent),
                        const SizedBox(width: 4),
                        Text('$total stations · $sourceLabel',
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
          AnimatedBuilder(
            animation: heroCtrl,
            builder: (_, __) => Row(
              children: [
                _KpiCounter(rc: rc, label: 'CRITICAL', value: critCount, anim: heroCtrl, color: AppPalette.danger),
                _KpiDivider(rc: rc),
                _KpiCounter(rc: rc, label: 'SEVERE',   value: sevCount,  anim: heroCtrl, color: AppPalette.warning),
                _KpiDivider(rc: rc),
                _KpiCounter(rc: rc, label: 'ELEVATED', value: elvCount,  anim: heroCtrl, color: AppPalette.amber),
                _KpiDivider(rc: rc),
                _KpiCounter(rc: rc, label: 'NORMAL',   value: norCount,  anim: heroCtrl, color: AppPalette.safe),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AnimatedBuilder(
            animation: heroCtrl,
            builder: (_, __) => _RiskDistBar(
              rc: rc, counts: counts, total: total, anim: heroCtrl,
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ── Isolated clock ────────────────────────────────────────────────────────────
class _ClockWidget extends StatefulWidget {
  final RiverColors rc;
  const _ClockWidget({required this.rc});
  @override
  State<_ClockWidget> createState() => _ClockWidgetState();
}
class _ClockWidgetState extends State<_ClockWidget> {
  late Timer _timer;
  String _time = _fmt(DateTime.now());
  static String _fmt(DateTime d) => DateFormat('HH:mm:ss').format(d);
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

// ── KPI counter ────────────────────────────────────────────────────────────────
class _KpiCounter extends StatelessWidget {
  final RiverColors rc;
  final String label;
  final int value;
  final Animation<double> anim;
  final Color color;
  const _KpiCounter({required this.rc, required this.label, required this.value, required this.anim, required this.color});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text('${(value * anim.value).round()}',
              style: TextStyle(
                color: color, fontSize: 22, fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
              )),
          Text(label,
              style: TextStyle(color: rc.textSecondary, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
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

// ── Risk distribution bar ──────────────────────────────────────────────────────
class _RiskDistBar extends StatelessWidget {
  final RiverColors rc;
  final Map<_RiskBucket, int> counts;
  final int total;
  final Animation<double> anim;
  const _RiskDistBar({required this.rc, required this.counts, required this.total, required this.anim});

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const SizedBox.shrink();
    final buckets = [_RiskBucket.critical, _RiskBucket.severe, _RiskBucket.elevated, _RiskBucket.normal];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.bar_chart_rounded, size: 12, color: rc.textSecondary),
          const SizedBox(width: 4),
          Text('Risk Distribution', style: TextStyle(color: rc.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: LayoutBuilder(builder: (ctx, box) {
              return Row(
                children: buckets.map((b) {
                  final cnt  = counts[b] ?? 0;
                  final frac = (cnt / total * anim.value).clamp(0.0, 1.0);
                  if (frac == 0) return const SizedBox.shrink();
                  return Container(width: box.maxWidth * frac, color: _bucketColor(b));
                }).toList(),
              );
            }),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12, runSpacing: 4,
          children: buckets.map((b) {
            final cnt = counts[b] ?? 0;
            if (cnt == 0) return const SizedBox.shrink();
            return Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 8, height: 8, margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(color: _bucketColor(b), shape: BoxShape.circle)),
              Text('${_bucketLabel(b)} $cnt',
                  style: TextStyle(color: rc.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
            ]);
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
  final String search, sortKey;
  final ValueChanged<String> onSearch, onSort;
  const _SearchSortBar({required this.rc, required this.search, required this.sortKey, required this.onSearch, required this.onSort});

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
                hintText: 'Search stations, rivers…',
                hintStyle: TextStyle(color: rc.textSecondary, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, size: 18, color: rc.textSecondary),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                filled: true, fillColor: rc.cardBg,
              ),
            ),
          ),
          const SizedBox(width: 8),
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
      decoration: BoxDecoration(color: rc.cardBg, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _SortBtn(rc: rc, label: 'Lvl', key_: 'level',    current: current, onSort: onSort),
        _SortBtn(rc: rc, label: 'Cap', key_: 'capacity', current: current, onSort: onSort),
        _SortBtn(rc: rc, label: 'A-Z', key_: 'name',     current: current, onSort: onSort),
      ]),
    );
  }
}

class _SortBtn extends StatelessWidget {
  final RiverColors rc;
  final String label, key_, current;
  final ValueChanged<String> onSort;
  const _SortBtn({required this.rc, required this.label, required this.key_, required this.current, required this.onSort});
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
            style: TextStyle(color: active ? rc.accent : rc.textSecondary, fontSize: 11,
                fontWeight: active ? FontWeight.w800 : FontWeight.w500)),
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
  const _RiskFilterChips({required this.rc, required this.counts, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final buckets = [_RiskBucket.critical, _RiskBucket.severe, _RiskBucket.elevated, _RiskBucket.normal];
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
                color: isOn ? color.withValues(alpha: 0.18) : rc.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isOn ? color.withValues(alpha: 0.6) : rc.stroke, width: isOn ? 1.5 : 1),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_bucketIcon(b), size: 12, color: isOn ? color : rc.textSecondary),
                const SizedBox(width: 5),
                Text(_bucketLabel(b),
                    style: TextStyle(color: isOn ? color : rc.textSecondary, fontSize: 11,
                        fontWeight: isOn ? FontWeight.w800 : FontWeight.w500, letterSpacing: 0.3)),
                if (cnt > 0) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: isOn ? color.withValues(alpha: 0.25) : rc.stroke,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('$cnt', style: TextStyle(color: isOn ? color : rc.textSecondary, fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                ],
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Station Card
// FIX: replaced IntrinsicHeight+Row with Stack so the accent bar can
//      stretch to full card height without requiring intrinsic layout pass.
// ─────────────────────────────────────────────────────────────────────────────

class _StationCard extends ConsumerStatefulWidget {
  final RiverStation station;
  final int index;
  final AnimationController entryCtrl;
  final RiverColors rc;

  const _StationCard({required this.station, required this.index, required this.entryCtrl, required this.rc});

  @override
  ConsumerState<_StationCard> createState() => _StationCardState();
}

class _StationCardState extends ConsumerState<_StationCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _arcCtrl;

  RiverStation get s  => widget.station;
  RiverColors  get rc => widget.rc;

  _RiskBucket  get _bk  => _bucket(s);
  Color        get _col => _bucketColor(_bk);

  double get _lvlPct => s.progressPct.clamp(0.0, 100.0);
  double get _capPct => s.progressPct.clamp(0.0, 100.0);

  List<double> get _sparkline {
    final seed = s.station.hashCode;
    final base = _capPct;
    return List.generate(7, (i) {
      final noise = (math.sin(seed + i * 1.7) * 15).clamp(-15.0, 15.0);
      return (base + noise).clamp(0.0, 100.0);
    })..last = _capPct;
  }

  @override
  void initState() {
    super.initState();
    _arcCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final delay = (widget.index * 0.05).clamp(0.0, 0.8);
      Future.delayed(Duration(milliseconds: (delay * 1000).round()), () {
        if (mounted) _arcCtrl.forward();
      });
    });
  }

  @override
  void dispose() { _arcCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final weatherState = ref.watch(weatherProvider);
    final hasWx = weatherState.current != null;

    return AnimatedBuilder(
      animation: widget.entryCtrl,
      builder: (_, child) {
        final delay = (widget.index * 0.04).clamp(0.0, 0.7);
        final p = ((widget.entryCtrl.value - delay) / (1.0 - delay)).clamp(0.0, 1.0);
        return Opacity(
          opacity: p,
          child: Transform.translate(offset: Offset(0, 24 * (1 - p)), child: child),
        );
      },
      child: GestureDetector(
        onTap: () { HapticFeedback.selectionClick(); },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          decoration: BoxDecoration(
            color: rc.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _col.withValues(alpha: _expanded ? 0.40 : 0.20), width: _expanded ? 1.5 : 1.0),
            boxShadow: [BoxShadow(color: _col.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
          ),
          // ✅ Stack replaces IntrinsicHeight+Row — accent bar uses
          //    Positioned.fill so it never triggers intrinsic layout.
          child: Stack(
            children: [
              // Left accent bar — stretches to whatever height the Column needs
              Positioned(
                left: 0, top: 0, bottom: 0,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: _col,
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20), bottomLeft: Radius.circular(20))),
                ),
              ),
              // Card content shifted right by accent bar width
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row
                    Row(children: [
                      AnimatedBuilder(
                        animation: _arcCtrl,
                        builder: (_, __) => SizedBox(
                          width: 48, height: 48,
                          child: CustomPaint(
                            painter: _MiniArcPainter(
                              value: (_lvlPct / 100 * _arcCtrl.value).clamp(0, 1),
                              color: _col, track: rc.stroke, strokeWidth: 5,
                            ),
                            child: Center(
                              child: Text(
                                '${(_lvlPct * _arcCtrl.value).toStringAsFixed(0)}%',
                                style: TextStyle(color: _col, fontSize: 11, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.station,
                                style: TextStyle(color: rc.textPrimary, fontSize: 14, fontWeight: FontWeight.w800),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(
                              [s.river, s.city, s.state].where((v) => v.isNotEmpty).join('  ·  '),
                              style: TextStyle(color: rc.textSecondary, fontSize: 11),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${s.current.toStringAsFixed(2)} m',
                            style: TextStyle(color: rc.textPrimary, fontSize: 14, fontWeight: FontWeight.w900,
                                fontFeatures: const [FontFeature.tabularFigures()]),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _col.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _col.withValues(alpha: 0.30)),
                            ),
                            child: Text(_bucketLabel(_bk),
                                style: TextStyle(color: _col, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: AnimatedRotation(
                          turns: _expanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 280),
                          child: Icon(Icons.expand_more_rounded, size: 20, color: rc.textSecondary),
                        ),
                        onPressed: () { HapticFeedback.selectionClick(); setState(() => _expanded = !_expanded); },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ]),

                    const SizedBox(height: 10),

                    // Sparkline + capacity bar
                    Row(children: [
                      SizedBox(width: 72, height: 28,
                          child: CustomPaint(painter: _SparklinePainter(points: _sparkline, color: _col))),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text('Capacity', style: TextStyle(color: rc.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                              Text('${_capPct.toStringAsFixed(0)}%',
                                  style: TextStyle(color: _col, fontSize: 11, fontWeight: FontWeight.w800,
                                      fontFeatures: const [FontFeature.tabularFigures()])),
                            ]),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                height: 7, color: rc.stroke,
                                child: AnimatedBuilder(
                                  animation: _arcCtrl,
                                  builder: (_, __) => FractionallySizedBox(
                                    widthFactor: (_capPct / 100 * _arcCtrl.value).clamp(0, 1),
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(6),
                                        gradient: LinearGradient(colors: [AppPalette.safe, _col]),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Row(children: [
                              _MiniChip(label: 'W ${s.warning.toStringAsFixed(1)}m', color: AppPalette.warning),
                              const SizedBox(width: 6),
                              _MiniChip(label: 'D ${s.danger.toStringAsFixed(1)}m',  color: AppPalette.danger),
                              const SizedBox(width: 6),
                              _MiniChip(label: s.dataSource ?? 'LIVE',               color: rc.accent, icon: Icons.sensors_rounded),
                            ]),
                          ],
                        ),
                      ),
                    ]),

                    if (!_expanded && hasWx) ...[
                      const SizedBox(height: 8),
                      _WxPillRow(wx: weatherState),
                    ],

                    if (_expanded) ...[
                      const SizedBox(height: 10),
                      _ExpandedDetail(rc: rc, station: s, wx: hasWx ? weatherState : null),
                    ],
                  ],
                ),
              ),
            ],
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
        color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[ Icon(icon, size: 9, color: color), const SizedBox(width: 3) ],
        Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Weather pills row
// ─────────────────────────────────────────────────────────────────────────────

class _WxPillRow extends StatelessWidget {
  final WeatherData wx;
  const _WxPillRow({required this.wx});
  @override
  Widget build(BuildContext context) {
    final pills = [
      ('${wx.tempC.toStringAsFixed(1)}°C',       Icons.thermostat_rounded,  AppPalette.amber),
      ('${wx.humidity}%',                         Icons.water_drop_rounded,  AppPalette.cyan),
      ('${wx.windKph.toStringAsFixed(0)} km/h',   Icons.air_rounded,         AppPalette.safe),
      ('${wx.rainfall7dMm.toStringAsFixed(0)}mm', Icons.grain_rounded,       AppPalette.cyan),
    ];
    return Wrap(spacing: 6, runSpacing: 4,
        children: pills.map((p) => _WxPill(label: p.$1, icon: p.$2, color: p.$3)).toList());
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
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Expanded detail panel
// FIX: GridView.count(shrinkWrap: true) replaced with _DataGrid — a plain
//      Column of 3-column Rows. No viewport = no intrinsic-height crash.
// ─────────────────────────────────────────────────────────────────────────────

class _ExpandedDetail extends StatelessWidget {
  final RiverColors rc;
  final RiverStation station;
  final WeatherData? wx;
  const _ExpandedDetail({required this.rc, required this.station, this.wx});

  @override
  Widget build(BuildContext context) {
    final s   = station;
    final bk  = _bucket(s);
    final col = _bucketColor(bk);

    final stationTiles = [
      _DataTile(rc: rc, icon: Icons.waves_rounded,         label: 'Current',  value: '${s.current.toStringAsFixed(2)} m',     color: col,                   highlight: true),
      _DataTile(rc: rc, icon: Icons.warning_amber_rounded, label: 'Warning',  value: '${s.warning.toStringAsFixed(2)} m',     color: AppPalette.warning),
      _DataTile(rc: rc, icon: Icons.dangerous_rounded,     label: 'Danger',   value: '${s.danger.toStringAsFixed(2)} m',      color: AppPalette.danger),
      _DataTile(rc: rc, icon: Icons.height_rounded,        label: 'HFL',      value: '${s.hfl.toStringAsFixed(2)} m',         color: AppPalette.critical),
      _DataTile(rc: rc, icon: Icons.percent_rounded,       label: 'Progress', value: '${s.progressPct.toStringAsFixed(1)}%',  color: rc.accent),
      _DataTile(rc: rc, icon: Icons.sensors_rounded,       label: 'Source',   value: s.dataSource ?? '—',                    color: rc.textSecondary),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: rc.stroke, height: 1),
        const SizedBox(height: 12),
        _SectionLabel(rc: rc, label: 'STATION STATS', icon: Icons.sensors_rounded),
        const SizedBox(height: 8),
        // ✅ No GridView — manual 3-column rows
        _DataGrid(tiles: stationTiles, gap: 8),
        if (wx != null) ...[
          const SizedBox(height: 14),
          _SectionLabel(rc: rc, label: 'WEATHER DATA', icon: Icons.cloud_rounded),
          const SizedBox(height: 8),
          _WxGrid(rc: rc, wx: wx!),
        ],
      ],
    );
  }
}

// ── Manual 3-column grid — no viewport ───────────────────────────────────────
class _DataGrid extends StatelessWidget {
  final List<Widget> tiles;
  final double gap;
  const _DataGrid({required this.tiles, this.gap = 8});

  @override
  Widget build(BuildContext context) {
    // Chunk into rows of 3
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 3) {
      final rowItems = tiles.sublist(i, math.min(i + 3, tiles.length));
      // Pad to 3 so the last row aligns
      while (rowItems.length < 3) rowItems.add(const SizedBox.shrink());
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rowItems.map((w) => Expanded(child: w)).toList(),
      ));
      if (i + 3 < tiles.length) rows.add(SizedBox(height: gap));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final RiverColors rc;
  final String label;
  final IconData icon;
  const _SectionLabel({required this.rc, required this.label, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 13, color: rc.accent),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(color: rc.textSecondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
    ]);
  }
}

// ── Data tile — fixed height, no aspect ratio ─────────────────────────────────
class _DataTile extends StatelessWidget {
  final RiverColors rc;
  final IconData icon;
  final String label, value;
  final Color color;
  final bool highlight;
  const _DataTile({required this.rc, required this.icon, required this.label, required this.value, required this.color, this.highlight = false});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: highlight ? color.withValues(alpha: 0.12) : rc.scaffoldBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: highlight ? color.withValues(alpha: 0.35) : rc.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()]),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(label, style: TextStyle(color: rc.textSecondary, fontSize: 10, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── Weather grid — also uses _DataGrid, no GridView ───────────────────────────
class _WxGrid extends StatelessWidget {
  final RiverColors rc;
  final WeatherData wx;
  const _WxGrid({required this.rc, required this.wx});
  @override
  Widget build(BuildContext context) {
    final indexColor = wx.rainfallIndex > 70 ? AppPalette.danger
        : wx.rainfallIndex > 45 ? AppPalette.warning : AppPalette.cyan;
    final tiles = [
      _DataTile(rc: rc, icon: Icons.thermostat_rounded,        label: 'Temperature', value: '${wx.tempC.toStringAsFixed(1)}°C',                               color: AppPalette.amber,           highlight: wx.tempC > 38),
      _DataTile(rc: rc, icon: Icons.device_thermostat_rounded,  label: 'Feels Like',  value: '${(wx.current?.feelsLikeC ?? wx.tempC).toStringAsFixed(1)}°C',   color: AppPalette.amber),
      _DataTile(rc: rc, icon: Icons.water_drop_rounded,         label: 'Humidity',    value: '${wx.humidity}%',                                                color: const Color(0xFF64B5F6),    highlight: wx.humidity > 85),
      _DataTile(rc: rc, icon: Icons.grain_rounded,              label: '7-Day Rain',  value: '${wx.rainfall7dMm.toStringAsFixed(1)} mm',                       color: AppPalette.cyan,            highlight: wx.rainfall7dMm > 100),
      _DataTile(rc: rc, icon: Icons.analytics_rounded,          label: 'Rain Index',  value: '${wx.rainfallIndex.toStringAsFixed(0)}/100',                     color: indexColor,                 highlight: wx.rainfallIndex > 45),
      _DataTile(rc: rc, icon: Icons.umbrella_rounded,           label: 'Precip Prob', value: '${wx.maxPrecipProb.toStringAsFixed(0)}%',                        color: AppPalette.amber,           highlight: wx.maxPrecipProb > 70),
      _DataTile(rc: rc, icon: Icons.air_rounded,                label: 'Wind Speed',  value: '${wx.windKph.toStringAsFixed(0)} km/h',                          color: const Color(0xFF64B5F6)),
      _DataTile(rc: rc, icon: Icons.wb_sunny_rounded,           label: 'UV Index',    value: (wx.current?.uvIndex ?? 0).toStringAsFixed(1),                    color: AppPalette.amber),
      _DataTile(rc: rc, icon: Icons.water_rounded,              label: 'Precip Now',  value: '${wx.precipMm.toStringAsFixed(1)} mm',                           color: AppPalette.cyan),
    ];
    return _DataGrid(tiles: tiles, gap: 8);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Painters
// ─────────────────────────────────────────────────────────────────────────────

class _MiniArcPainter extends CustomPainter {
  final double value;
  final Color  color, track;
  final double strokeWidth;
  const _MiniArcPainter({required this.value, required this.color, required this.track, this.strokeWidth = 6});

  @override
  void paint(Canvas canvas, Size size) {
    const start = math.pi * 0.75;
    const sweep = math.pi * 1.5;
    final cx = size.width / 2; final cy = size.height / 2;
    final radius = math.min(cx, cy) - strokeWidth / 2;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);
    canvas.drawArc(rect, start, sweep, false,
        Paint()..color = track..style = PaintingStyle.stroke..strokeWidth = strokeWidth..strokeCap = StrokeCap.round);
    if (value > 0) {
      canvas.drawArc(rect, start, sweep * value, false,
          Paint()
            ..shader = SweepGradient(colors: [color.withValues(alpha: 0.5), color], startAngle: start, endAngle: start + sweep)
                .createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius))
            ..style = PaintingStyle.stroke..strokeWidth = strokeWidth..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_MiniArcPainter old) => old.value != value || old.color != color;
}

class _SparklinePainter extends CustomPainter {
  final List<double> points;
  final Color color;
  const _SparklinePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final minV = points.reduce(math.min); final maxV = points.reduce(math.max);
    final range = (maxV - minV).clamp(1.0, double.infinity);
    final step  = size.width / (points.length - 1);
    double xOf(int i) => i * step;
    double yOf(double v) => size.height - ((v - minV) / range * size.height);
    final path = Path()..moveTo(xOf(0), yOf(points[0]));
    for (var i = 1; i < points.length; i++) {
      final x0 = xOf(i - 1); final y0 = yOf(points[i - 1]);
      final x1 = xOf(i);     final y1 = yOf(points[i]);
      path.cubicTo(x0 + (x1 - x0) * 0.5, y0, x0 + (x1 - x0) * 0.5, y1, x1, y1);
    }
    final fillPath = Path.from(path)
      ..lineTo(xOf(points.length - 1), size.height)..lineTo(0, size.height)..close();
    canvas.drawPath(fillPath, Paint()
      ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0.0)])
          .createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill);
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5..strokeCap = StrokeCap.round);
    canvas.drawCircle(Offset(xOf(points.length - 1), yOf(points.last)), 3, Paint()..color = color);
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
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.sensors_off_rounded, size: 48, color: rc.textSecondary),
        const SizedBox(height: 16),
        Text('Connecting to live data…', style: TextStyle(color: rc.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: rc.accent)),
      ]),
    );
  }
}

class _NoResults extends StatelessWidget {
  final RiverColors rc;
  const _NoResults({required this.rc});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.search_off_rounded, size: 44, color: rc.textSecondary),
        const SizedBox(height: 12),
        Text('No stations match your filters.', style: TextStyle(color: rc.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('Try a different search or reset the risk filter.',
            style: TextStyle(color: rc.textSecondary.withValues(alpha: 0.6), fontSize: 12)),
      ]),
    );
  }
}
