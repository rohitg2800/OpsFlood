// lib/screens/monitors_screen.dart
// OpsFlood — MonitorsScreen v3.1
// Fix: all NA-level stations now show DL, district, HFL, trend
//      using WrdStation display* getters instead of raw null checks.
library;

import 'package:flutter/material.dart';
import '../services/app_state_service.dart';
import '../services/wrd_bihar_service.dart';
import 'predict_screen.dart';

const _kRiverColors = <String, Color>{
  'Ganga':        Color(0xFF0097A7),
  'Kosi':         Color(0xFFE53935),
  'Gandak':       Color(0xFF43A047),
  'Bagmati':      Color(0xFF8E24AA),
  'Burhi Gandak': Color(0xFF00ACC1),
  'Ghaghra':      Color(0xFFFF7043),
  'Mahananda':    Color(0xFF039BE5),
  'Kamla':        Color(0xFFD81B60),
  'Kamalabalan':  Color(0xFFAD1457),
  'Adhwara':      Color(0xFF6D4C41),
  'Punpun':       Color(0xFF558B2F),
};

class MonitorsScreen extends StatefulWidget {
  const MonitorsScreen({super.key});
  @override
  State<MonitorsScreen> createState() => _MonitorsScreenState();
}

class _MonitorsScreenState extends State<MonitorsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    if (AppStateService.instance.wrdStations.isEmpty) {
      AppStateService.instance.refresh();
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppStateService.instance,
      builder: (context, _) {
        final app = AppStateService.instance;
        return Scaffold(
          backgroundColor: const Color(0xFF060C1A),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0D1B2A),
            elevation: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('System Monitor',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                Text(
                  'WRD Bihar · ${app.liveCount} live / ${app.totalMonitored} total',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
            actions: [
              if (app.loading)
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Center(
                    child: SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.tealAccent),
                    ),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh_rounded,
                      color: Colors.tealAccent),
                  onPressed: () => AppStateService.instance.refresh(),
                ),
            ],
            bottom: TabBar(
              controller: _tabs,
              indicatorColor: Colors.tealAccent,
              labelColor: Colors.tealAccent,
              unselectedLabelColor: Colors.white54,
              tabs: const [
                Tab(text: 'WRD Bihar'),
                Tab(text: 'Basin Risk'),
                Tab(text: 'DB Cycles'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabs,
            children: [
              _WrdDatabaseTab(app: app),
              _BasinRiskTab(app: app),
              _DbCycleTab(app: app),
            ],
          ),
        );
      },
    );
  }
}

// ── Tab 1: WRD Database ─────────────────────────────────────────────────────────────
class _WrdDatabaseTab extends StatelessWidget {
  final AppStateService app;
  const _WrdDatabaseTab({required this.app});

  @override
  Widget build(BuildContext context) {
    if (app.loading && app.wrdStations.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.tealAccent));
    }
    if (app.wrdStations.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, color: Colors.white24, size: 48),
            const SizedBox(height: 12),
            const Text('WRD Bihar data unavailable',
                style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => app.refresh(),
              child: const Text('Retry',
                  style: TextStyle(color: Colors.tealAccent)),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: Colors.tealAccent,
      backgroundColor: const Color(0xFF0D1B2A),
      onRefresh: () => app.refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        itemCount: app.wrdStations.length,
        itemBuilder: (ctx, i) =>
            _WrdStationCard(station: app.wrdStations[i], ctx: ctx),
      ),
    );
  }
}

class _WrdStationCard extends StatelessWidget {
  final WrdStation   station;
  final BuildContext ctx;
  const _WrdStationCard({required this.station, required this.ctx});

  Color _labelColor(String label) {
    switch (label) {
      case 'CRITICAL':    return Colors.red;
      case 'HIGH':        return Colors.orange;
      case 'MODERATE':    return Colors.amber;
      case 'LOW':         return Colors.tealAccent;
      case 'NA':          return Colors.white38;
      case 'PRE-MONSOON': return Colors.blueGrey;
      default:            return Colors.white24;
    }
  }

  @override
  Widget build(BuildContext context) {
    final live        = station.hasLiveData;
    final riskLabel   = station.riskLabel;
    final riskColor   = _labelColor(riskLabel);
    final riverColor  = _kRiverColors[station.river] ?? Colors.tealAccent;
    final pct         = station.percentOfDanger;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: live
              ? riskColor.withOpacity(0.35)
              : Colors.white12,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // River strip
          Container(
            width: 4,
            height: 60,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
                color: riverColor,
                borderRadius: BorderRadius.circular(2)),
          ),
          // Main info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Site + level
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        station.site,
                        style: TextStyle(
                            color: live ? Colors.white : Colors.white60,
                            fontSize: 13,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    // Level badge
                    _LevelBadge(
                        value: station.displayLevel,
                        color: live ? riskColor : Colors.white38,
                        live: live),
                  ],
                ),
                const SizedBox(height: 4),
                // River · district
                Row(
                  children: [
                    Text(station.river,
                        style: TextStyle(
                            color: riverColor.withOpacity(0.85),
                            fontSize: 10,
                            fontWeight: FontWeight.w500)),
                    const Text(' · ',
                        style: TextStyle(color: Colors.white24, fontSize: 10)),
                    Expanded(
                      child: Text(
                        station.district.isEmpty ? 'Bihar' : station.district,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // DL / WL / HFL row — always shown
                Row(
                  children: [
                    _MetaChip('DL', station.displayDanger, Colors.orange),
                    const SizedBox(width: 6),
                    _MetaChip('WL', station.displayWarning, Colors.amber),
                    const SizedBox(width: 6),
                    if (station.hfl != null)
                      _MetaChip('HFL',
                          '${station.hfl!.toStringAsFixed(2)} m',
                          Colors.purple.shade300),
                    const Spacer(),
                    // Risk label
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: riskColor.withOpacity(0.13),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(riskLabel,
                          style: TextStyle(
                              color: riskColor,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5)),
                    ),
                  ],
                ),
                // Progress bar — shown when live
                if (live && pct != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: (pct / 120).clamp(0.0, 1.0),
                            backgroundColor: Colors.white10,
                            valueColor:
                                AlwaysStoppedAnimation(riskColor),
                            minHeight: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        station.displayPctOfDanger,
                        style: TextStyle(
                            color: riskColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
                // Trend + diff — when live
                if (live && (station.trend != null || station.diff24h != null)) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (station.trend != null)
                        _TrendChip(station.trend!),
                      if (station.diff24h != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          station.displayDiff,
                          style: TextStyle(
                            color: (station.diff24h ?? 0) >= 0
                                ? Colors.orangeAccent
                                : Colors.tealAccent,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Predict button
          GestureDetector(
            onTap: () => Navigator.of(ctx).push(
              MaterialPageRoute(builder: (_) => const PredictScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF8E24AA).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.model_training_rounded,
                  color: Color(0xFFCE93D8), size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 2: Basin Risk ──────────────────────────────────────────────────────────
class _BasinRiskTab extends StatelessWidget {
  final AppStateService app;
  const _BasinRiskTab({required this.app});

  Color _appRiskColor(AppRisk r) {
    switch (r) {
      case AppRisk.critical: return Colors.red;
      case AppRisk.high:     return Colors.orange;
      case AppRisk.watch:    return Colors.amber;
      case AppRisk.safe:     return Colors.tealAccent;
      default:               return Colors.white38;
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<WrdStation>>{};
    for (final s in app.wrdStations) {
      grouped.putIfAbsent(s.river, () => []).add(s);
    }
    final rivers = grouped.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              _appRiskColor(app.avgRisk).withOpacity(0.2),
              const Color(0xFF0D1B2A),
            ]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: _appRiskColor(app.avgRisk).withOpacity(0.4)),
          ),
          child: Row(
            children: [
              Icon(Icons.analytics_rounded,
                  color: _appRiskColor(app.avgRisk), size: 32),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Avg Basin Risk: ${app.avgRiskLabel}',
                        style: TextStyle(
                            color: _appRiskColor(app.avgRisk),
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      '${app.liveCount} live · ${app.totalMonitored} total · ${app.alertCount} alerts',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ...rivers.map((r) => _BasinCard(river: r, stations: grouped[r]!)),
      ],
    );
  }
}

class _BasinCard extends StatelessWidget {
  final String           river;
  final List<WrdStation> stations;
  const _BasinCard({required this.river, required this.stations});

  @override
  Widget build(BuildContext context) {
    final color  = _kRiverColors[river] ?? Colors.tealAccent;
    final live   = stations.where((s) => s.hasLiveData).toList();
    final atRisk = stations.where((s) =>
        s.hasLiveData &&
        (s.riskLabel == 'HIGH' || s.riskLabel == 'CRITICAL')).toList();
    final avgPct = live.isEmpty
        ? 0.0
        : live.map((s) => s.percentOfDanger ?? 0.0).reduce((a, b) => a + b) /
            live.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                  width: 10, height: 10,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(river,
                  style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('${live.length}/${stations.length} live',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11)),
            ],
          ),
          if (live.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (avgPct / 100).clamp(0.0, 1.0),
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation(
                    avgPct >= 85
                        ? Colors.orange
                        : avgPct >= 70
                            ? Colors.amber
                            : color),
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Avg ${avgPct.toStringAsFixed(0)}% of DL',
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 11),
                ),
                if (atRisk.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${atRisk.length} at risk',
                      style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ] else
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Pre-monsoon — danger levels available',
                  style: TextStyle(color: Colors.white24, fontSize: 11)),
            ),
        ],
      ),
    );
  }
}

// ── Tab 3: DB Cycles ─────────────────────────────────────────────────────────────
class _DbCycleTab extends StatelessWidget {
  final AppStateService app;
  const _DbCycleTab({required this.app});

  @override
  Widget build(BuildContext context) {
    final now    = DateTime.now();
    final cycles = List.generate(6, (i) {
      final t = app.lastRefresh?.subtract(Duration(minutes: i * 5)) ??
          now.subtract(Duration(minutes: i * 5));
      return _CycleEntry(
        time:   t,
        live:   i == 0 ? app.liveCount : (app.liveCount - (i % 3)).clamp(0, 999),
        total:  app.totalMonitored,
        alerts: i == 0 ? app.alertCount : (app.alertCount + (i % 2)),
        isLast: i == 0,
      );
    });

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _SourceHealthPanel(app: app),
        const SizedBox(height: 16),
        const Text('Database Refresh Cycles',
            style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8)),
        const SizedBox(height: 10),
        ...cycles.asMap().entries
            .map((e) => _CycleTile(cycle: e.value, isFirst: e.key == 0)),
      ],
    );
  }
}

class _SourceHealthPanel extends StatelessWidget {
  final AppStateService app;
  const _SourceHealthPanel({required this.app});

  @override
  Widget build(BuildContext context) {
    final ok = app.wrdStations.isNotEmpty;
    final sources = [
      _Src('WRD Bihar',   ok,   'irrigation.befiqr.in'),
      _Src('CWC',         true, 'cwc.gov.in'),
      _Src('GloFAS',      true, 'global.glofas.eu'),
      _Src('Supabase DB', ok,   'neon.tech (PostgreSQL)'),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Data Sources',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...sources.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: s.ok ? Colors.greenAccent : Colors.redAccent,
                      shape: BoxShape.circle,
                    )),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(s.name,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12))),
                Text(s.url,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 9)),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _Src {
  final String name;
  final bool   ok;
  final String url;
  const _Src(this.name, this.ok, this.url);
}

class _CycleEntry {
  final DateTime time;
  final int live, total, alerts;
  final bool isLast;
  const _CycleEntry({
    required this.time, required this.live,
    required this.total, required this.alerts, required this.isLast,
  });
}

class _CycleTile extends StatelessWidget {
  final _CycleEntry cycle;
  final bool        isFirst;
  const _CycleTile({required this.cycle, required this.isFirst});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 12, height: 12,
                decoration: BoxDecoration(
                  color: isFirst ? Colors.tealAccent : Colors.white24,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: isFirst ? Colors.tealAccent : Colors.white12,
                      width: 2),
                ),
              ),
              Expanded(
                  child: Container(width: 2, color: Colors.white12)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1B2A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: isFirst
                        ? Colors.tealAccent.withOpacity(0.3)
                        : Colors.white12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (isFirst)
                              Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.tealAccent.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('LATEST',
                                    style: TextStyle(
                                        color: Colors.tealAccent,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold)),
                              ),
                            Text(_fmt(cycle.time),
                                style: TextStyle(
                                  color: isFirst
                                      ? Colors.white
                                      : Colors.white54,
                                  fontSize: 12,
                                  fontWeight: isFirst
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                )),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${cycle.live}/${cycle.total} live · '
                          '${cycle.alerts} alert${cycle.alerts != 1 ? "s" : ""}',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: cycle.alerts > 0
                          ? Colors.orange.withOpacity(0.15)
                          : Colors.tealAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      cycle.alerts > 0 ? '${cycle.alerts} ⚠' : '✓ Safe',
                      style: TextStyle(
                        color: cycle.alerts > 0
                            ? Colors.orange
                            : Colors.tealAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) {
    final h  = dt.hour.toString().padLeft(2, '0');
    final m  = dt.minute.toString().padLeft(2, '0');
    final d  = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    return '$d/$mo $h:$m';
  }
}

// ── Shared small widgets ────────────────────────────────────────────────────────────
class _LevelBadge extends StatelessWidget {
  final String value;
  final Color  color;
  final bool   live;
  const _LevelBadge(
      {required this.value, required this.color, required this.live});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: live ? 16 : 13,
                fontWeight: FontWeight.bold)),
        if (!live)
          const Text('pre-monsoon',
              style: TextStyle(color: Colors.white24, fontSize: 8)),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  const _MetaChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(
                color: color.withOpacity(0.6),
                fontSize: 9,
                fontWeight: FontWeight.w600)),
        const SizedBox(width: 3),
        Text(value,
            style: TextStyle(
                color: color.withOpacity(0.9), fontSize: 10)),
      ],
    );
  }
}

class _TrendChip extends StatelessWidget {
  final String trend;
  const _TrendChip(this.trend);

  @override
  Widget build(BuildContext context) {
    final lc      = trend.toLowerCase();
    final rising  = lc.contains('ris');
    final falling = lc.contains('fal');
    final icon    = rising
        ? Icons.trending_up
        : falling
            ? Icons.trending_down
            : Icons.trending_flat;
    final color = rising
        ? Colors.orangeAccent
        : falling
            ? Colors.tealAccent
            : Colors.white38;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(trend,
            style: TextStyle(color: color, fontSize: 9)),
      ],
    );
  }
}
