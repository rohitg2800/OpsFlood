// lib/screens/live_stations_screen.dart
// Bihar Flood Command — Live CWC Stations HUD v3
// Shows only Bihar CWC gauge stations with live water level, danger/warning/HFL.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/cwc_provider.dart';
import '../providers/flood_providers.dart';
import '../theme/river_theme.dart';

// Bihar CWC stations (CWC gauges inside Bihar boundary)
const _biharStations = [
  'Patna','Gandhi Ghat','Hathidah','Bhagalpur','Kahalgaon','Sultanganj',
  'Munger','Mokameh','Barh','Fatuha','Muzaffarpur','Sonpur','Hajipur',
  'Lalganj','Rosera','Dalsinghsarai','Khagaria','Birpur','Baltara',
  'Naugachia','Kursela','Bhimnagar','Jhanjharpur','Pandol','Hayaghat',
  'Benibad','Sitamarhi','Raxaul','Bagaha','Gopalganj','Siwan','Revelganj',
  'Dumraon','Koilwar','Arrah','Buxar','Dehri','Indrapuri',
];

const _biharRivers = [
  'Ganga','Kosi','Gandak','Bagmati','Kamla-Balan','Burhi Gandak',
  'Ghaghra','Son','Falgu','Phalgu','Punpun','Mahananda',
];

class LiveStationsScreen extends ConsumerStatefulWidget {
  static const route = '/live-stations';
  const LiveStationsScreen({super.key});
  @override
  ConsumerState<LiveStationsScreen> createState() => _LiveStationsScreenState();
}

class _LiveStationsScreenState extends ConsumerState<LiveStationsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Timer _clock;
  String _timeStr = '';
  String _riverFilter = 'ALL';
  String _riskFilter  = 'ALL';
  final _riskFilters  = ['ALL', 'CRITICAL', 'DANGER', 'WARNING', 'NORMAL'];

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this, duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _tick();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    setState(() => _timeStr = DateFormat('HH:mm:ss').format(DateTime.now()));
  }

  @override
  void dispose() {
    _pulse.dispose();
    _clock.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stationsAsync = ref.watch(cwcStationsProvider);
    return Scaffold(
      backgroundColor: AppPalette.abyss0,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: stationsAsync.when(
            data: (stations) => _buildStripStats(stations),
            loading: () => const SizedBox(height: 70),
            error: (_, __) => const SizedBox(height: 70),
          )),
          SliverToBoxAdapter(child: _buildFilterRow()),
        ],
        body: stationsAsync.when(
          data: (stations) {
            // Filter to Bihar only
            final biharOnly = stations.where((s) {
              final name = (s['name'] ?? s['station_name'] ?? '').toString();
              final river = (s['river'] ?? '').toString();
              return _biharStations.any(
                    (b) => name.toLowerCase().contains(b.toLowerCase())) ||
                  _biharRivers.any(
                    (r) => river.toLowerCase().contains(r.toLowerCase()));
            }).toList();

            // River filter
            final riverFiltered = _riverFilter == 'ALL'
                ? biharOnly
                : biharOnly.where((s) {
                    final r = (s['river'] ?? '').toString();
                    return r.toLowerCase().contains(_riverFilter.toLowerCase());
                  }).toList();

            // Risk filter
            final riskFiltered = _riskFilter == 'ALL'
                ? riverFiltered
                : riverFiltered.where((s) {
                    final lvl = _riskLevel(s).toUpperCase();
                    return lvl.contains(_riskFilter);
                  }).toList();

            if (riskFiltered.isEmpty) {
              return _NoSignal(label: 'NO STATIONS · CHECK FILTERS');
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: riskFiltered.length,
              itemBuilder: (_, i) => _StationCard(station: riskFiltered[i]),
            );
          },
          loading: () => Center(
              child: CircularProgressIndicator(
                  color: AppPalette.cyan, strokeWidth: 1.5)),
          error: (e, _) => _NoSignal(label: 'FEED ERROR · RETRY'),
        ),
      ),
    );
  }

  Widget _buildHeader() => Container(
    padding: const EdgeInsets.fromLTRB(16, 48, 16, 12),
    decoration: BoxDecoration(
      color: AppPalette.abyss0,
      border: Border(bottom: BorderSide(
          color: AppPalette.cyan.withValues(alpha: 0.15))),
    ),
    child: Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppPalette.cyan.withValues(alpha: 0.30)),
              color: AppPalette.abyss2,
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppPalette.cyan, size: 14),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('CWC LIVE STATIONS · BIHAR',
                  style: TextStyle(
                    color: AppPalette.cyan, fontSize: 13,
                    fontWeight: FontWeight.w800, letterSpacing: 2,
                  )),
              Text('SYS $_timeStr · CWC FEED ACTIVE',
                  style: const TextStyle(
                    color: AppPalette.textDim, fontSize: 9,
                    letterSpacing: 1,
                  )),
            ],
          ),
        ),
        AnimatedBuilder(
          animation: _pulse,
          builder: (_, __) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppPalette.safe.withValues(alpha: 0.08 + 0.06 * _pulse.value),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppPalette.safe.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppPalette.safe.withValues(alpha: 0.5 + 0.5 * _pulse.value),
                  ),
                ),
                const SizedBox(width: 5),
                const Text('ONLINE',
                    style: TextStyle(
                      color: AppPalette.safe, fontSize: 9,
                      fontWeight: FontWeight.w800, letterSpacing: 1.2,
                    )),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildStripStats(List<dynamic> stations) {
    final biharOnly = stations.where((s) {
      final name  = (s['name'] ?? s['station_name'] ?? '').toString();
      final river = (s['river'] ?? '').toString();
      return _biharStations.any(
              (b) => name.toLowerCase().contains(b.toLowerCase())) ||
          _biharRivers.any(
              (r) => river.toLowerCase().contains(r.toLowerCase()));
    }).toList();

    int critical = 0, danger = 0, warning = 0, normal = 0;
    for (final s in biharOnly) {
      final lvl = _riskLevel(s).toUpperCase();
      if (lvl.contains('CRITICAL')) critical++;
      else if (lvl.contains('DANGER')) danger++;
      else if (lvl.contains('WARNING')) warning++;
      else normal++;
    }
    final tiles = [
      ('CRITICAL', critical, AppPalette.critical),
      ('DANGER',   danger,   AppPalette.danger),
      ('WARNING',  warning,  AppPalette.amber),
      ('NORMAL',   normal,   AppPalette.safe),
      ('TOTAL',    biharOnly.length, AppPalette.cyan),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: tiles.map((t) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: t.$3.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: t.$3.withValues(alpha: 0.22)),
            ),
            child: Column(
              children: [
                Text('${t.$2}',
                    style: TextStyle(
                      color: t.$3, fontSize: 17,
                      fontWeight: FontWeight.w900,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    )),
                const SizedBox(height: 2),
                Text(t.$1,
                    style: const TextStyle(
                      color: AppPalette.textDim, fontSize: 6.5,
                      fontWeight: FontWeight.w700, letterSpacing: 0.5,
                    )),
              ],
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildFilterRow() {
    final rivers = ['ALL', ..._biharRivers];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Risk filter
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            children: _riskFilters.map((f) {
              final active = _riskFilter == f;
              final col = _colForRisk(f);
              return GestureDetector(
                onTap: () => setState(() => _riskFilter = f),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: active ? col.withValues(alpha: 0.14) : AppPalette.abyss2,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: active ? col : AppPalette.abyssStroke),
                  ),
                  child: Center(
                    child: Text(f,
                        style: TextStyle(
                          color: active ? col : AppPalette.textDim,
                          fontSize: 8.5, fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        )),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        // River filter
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
            children: rivers.map((r) {
              final active = _riverFilter == r;
              return GestureDetector(
                onTap: () => setState(() => _riverFilter = r),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: active
                        ? AppPalette.cyan.withValues(alpha: 0.12)
                        : AppPalette.abyss2,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: active ? AppPalette.cyan : AppPalette.abyssStroke),
                  ),
                  child: Center(
                    child: Text(r,
                        style: TextStyle(
                          color: active ? AppPalette.cyan : AppPalette.textDim,
                          fontSize: 8.5, fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        )),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  String _riskLevel(dynamic s) {
    try {
      return (s['risk_level'] ?? s['status'] ?? s['level'] ?? 'normal').toString();
    } catch (_) { return 'normal'; }
  }

  Color _colForRisk(String r) {
    switch (r) {
      case 'CRITICAL': return AppPalette.critical;
      case 'DANGER':   return AppPalette.danger;
      case 'WARNING':  return AppPalette.amber;
      case 'NORMAL':   return AppPalette.safe;
      default:         return AppPalette.cyan;
    }
  }
}

// ─── Station Card ─────────────────────────────────────────────────────────────
class _StationCard extends StatelessWidget {
  final dynamic station;
  const _StationCard({required this.station});

  String _f(String k, [String fb = '—']) {
    try {
      final v = (station as dynamic)[k];
      return v?.toString().isNotEmpty == true ? v.toString() : fb;
    } catch (_) { return fb; }
  }

  double? _d(String k) => double.tryParse(_f(k, ''));

  Color get _col {
    final lvl = _f('risk_level', _f('status', 'normal')).toLowerCase();
    if (lvl.contains('critical') || lvl.contains('extreme')) return AppPalette.critical;
    if (lvl.contains('danger')   || lvl.contains('high'))    return AppPalette.danger;
    if (lvl.contains('warning')  || lvl.contains('moderate'))return AppPalette.amber;
    return AppPalette.safe;
  }

  @override
  Widget build(BuildContext context) {
    final col      = _col;
    final name     = _f('name', _f('station_name', 'Station'));
    final river    = _f('river', '');
    final district = _f('district', _f('location', ''));
    final wl       = _d('water_level') ?? _d('level') ?? _d('current_level');
    final danger   = _d('danger_level');
    final warning  = _d('warning_level');
    final hfl      = _d('hfl') ?? _d('highest_flood_level');
    final updated  = _f('updated_at', _f('timestamp', ''));

    double capPct = 0;
    if (wl != null && danger != null && danger > 0) {
      capPct = (wl / danger * 100).clamp(0, 100);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppPalette.abyss2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: col.withValues(alpha: 0.20)),
      ),
      child: Column(
        children: [
          Container(
            height: 2,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              gradient: LinearGradient(
                  colors: [col.withValues(alpha: 0.85), col.withValues(alpha: 0)]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: col.withValues(alpha: 0.10),
                        border: Border.all(color: col.withValues(alpha: 0.28)),
                      ),
                      child: Icon(Icons.sensors_rounded, color: col, size: 14),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                color: AppPalette.textWhite,
                                fontSize: 12, fontWeight: FontWeight.w800,
                              )),
                          Row(
                            children: [
                              if (river.isNotEmpty) ...[
                                const Icon(Icons.water_rounded,
                                    color: AppPalette.cyan, size: 9),
                                const SizedBox(width: 2),
                                Text(river,
                                    style: const TextStyle(
                                      color: AppPalette.cyan,
                                      fontSize: 9.5, fontWeight: FontWeight.w600,
                                    )),
                                const SizedBox(width: 6),
                              ],
                              if (district.isNotEmpty)
                                Text(district,
                                    style: const TextStyle(
                                      color: AppPalette.textDim, fontSize: 9)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: col.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: col.withValues(alpha: 0.30)),
                      ),
                      child: Text(
                        _f('risk_level', _f('status', 'NORMAL')).toUpperCase(),
                        style: TextStyle(
                          color: col, fontSize: 7.5,
                          fontWeight: FontWeight.w900, letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Level metrics
                Row(
                  children: [
                    _Metric('WL', wl != null ? '${wl.toStringAsFixed(2)}m' : '—', AppPalette.cyan),
                    _Metric('DANGER', danger != null ? '${danger.toStringAsFixed(2)}m' : '—', AppPalette.critical),
                    _Metric('WARNING', warning != null ? '${warning.toStringAsFixed(2)}m' : '—', AppPalette.amber),
                    _Metric('HFL', hfl != null ? '${hfl.toStringAsFixed(2)}m' : '—', AppPalette.danger),
                  ].map((w) => Expanded(child: w)).toList(),
                ),
                if (wl != null && danger != null) ...[
                  const SizedBox(height: 8),
                  // Capacity bar
                  Row(
                    children: [
                      const Text('LEVEL',
                          style: TextStyle(
                            color: AppPalette.textDim, fontSize: 8,
                            letterSpacing: 0.8,
                          )),
                      const Spacer(),
                      Text('${capPct.toStringAsFixed(1)}% of DANGER',
                          style: TextStyle(
                            color: col, fontSize: 8,
                            fontWeight: FontWeight.w700,
                          )),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: capPct / 100,
                      backgroundColor: AppPalette.abyss4,
                      valueColor: AlwaysStoppedAnimation(col),
                      minHeight: 4,
                    ),
                  ),
                ],
                if (updated.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded,
                          color: AppPalette.textDim, size: 9),
                      const SizedBox(width: 3),
                      Text(updated,
                          style: const TextStyle(
                            color: AppPalette.textDim, fontSize: 8.5)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Metric(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value,
          style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          )),
      const SizedBox(height: 2),
      Text(label,
          style: const TextStyle(
            color: AppPalette.textDim, fontSize: 7.5,
            fontWeight: FontWeight.w600, letterSpacing: 0.5,
          )),
    ],
  );
}

class _NoSignal extends StatelessWidget {
  final String label;
  const _NoSignal({required this.label});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppPalette.cyan.withValues(alpha: 0.08),
            border: Border.all(color: AppPalette.cyan.withValues(alpha: 0.25)),
          ),
          child: const Icon(Icons.sensors_off_rounded, color: AppPalette.cyan, size: 28),
        ),
        const SizedBox(height: 12),
        Text(label,
            style: const TextStyle(
              color: AppPalette.textGrey, fontSize: 11,
              fontWeight: FontWeight.w700, letterSpacing: 1.5,
            )),
      ],
    ),
  );
}
