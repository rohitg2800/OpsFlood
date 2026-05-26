// lib/screens/monitors_screen.dart
// OpsFlood — MonitorsScreen v3.2
// Uses WrdStationWithHistory: NA stations show past readings with
// a PAST DATA badge + staleness timestamp instead of blank cards.
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
                  'Live: ${app.liveCount}  ·  Past: ${app.pastDataCount}  ·  Total: ${app.totalMonitored}',
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
    if (app.loading && app.wrdWithHistory.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.tealAccent));
    }
    if (app.wrdWithHistory.isEmpty) {
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
    // Summary legend row
    return Column(
      children: [
        _LegendRow(app: app),
        Expanded(
          child: RefreshIndicator(
            color: Colors.tealAccent,
            backgroundColor: const Color(0xFF0D1B2A),
            onRefresh: () => app.refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              itemCount: app.wrdWithHistory.length,
              itemBuilder: (ctx, i) =>
                  _WrdStationCard(sw: app.wrdWithHistory[i], ctx: ctx),
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  final AppStateService app;
  const _LegendRow({required this.app});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF0D1B2A),
      child: Row(
        children: [
          _Dot(Colors.tealAccent),
          const SizedBox(width: 4),
          Text('${app.liveCount} Live',
              style: const TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(width: 16),
          _Dot(Colors.amberAccent),
          const SizedBox(width: 4),
          Text('${app.pastDataCount} Past',
              style: const TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(width: 16),
          _Dot(Colors.white24),
          const SizedBox(width: 4),
          Text('${app.blindCount} No Data',
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot(this.color);
  @override
  Widget build(BuildContext context) =>
      Container(width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

// ── Station Card (handles Live / Past / Blind) ────────────────────────────
class _WrdStationCard extends StatelessWidget {
  final WrdStationWithHistory sw;
  final BuildContext          ctx;
  const _WrdStationCard({required this.sw, required this.ctx});

  Color _labelColor(String label) {
    final l = label.replaceAll('*', '');
    switch (l) {
      case 'CRITICAL':    return Colors.red;
      case 'HIGH':        return Colors.orange;
      case 'MODERATE':    return Colors.amber;
      case 'LOW':         return Colors.tealAccent;
      case 'NA':          return Colors.white38;
      case 'PAST':        return Colors.amberAccent;
      case 'PRE-MONSOON': return Colors.blueGrey;
      default:            return Colors.white24;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLive     = sw.isLive;
    final hasPast    = sw.hasPastData;
    final riskLabel  = sw.riskLabel;
    final riskColor  = _labelColor(riskLabel);
    final riverColor = _kRiverColors[sw.station.river] ?? Colors.tealAccent;
    final pct        = sw.effectivePct;

    // Border colour: live=risk-tinted, past=amber-tinted, blind=white12
    final borderColor = isLive
        ? riskColor.withOpacity(0.35)
        : hasPast
            ? Colors.amberAccent.withOpacity(0.25)
            : Colors.white12;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // River colour strip
          Container(
            width: 4, height: 68,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: riverColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Main content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: site name + level badge + data-source badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        sw.station.site,
                        style: TextStyle(
                          color: isLive
                              ? Colors.white
                              : hasPast
                                  ? Colors.white70
                                  : Colors.white38,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    // Data-source badge
                    _DataBadge(isLive: isLive, hasPast: hasPast,
                        staleLabel: sw.staleLabel),
                    const SizedBox(width: 6),
                    // Level value
                    Text(
                      sw.displayLevel,
                      style: TextStyle(
                        color: isLive
                            ? riskColor
                            : hasPast
                                ? Colors.amberAccent
                                : Colors.white24,
                        fontSize: isLive ? 16 : 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                // Row 2: river · district
                Row(
                  children: [
                    Text(sw.station.river,
                        style: TextStyle(
                            color: riverColor.withOpacity(0.85),
                            fontSize: 10,
                            fontWeight: FontWeight.w500)),
                    const Text(' · ',
                        style: TextStyle(color: Colors.white24, fontSize: 10)),
                    Expanded(
                      child: Text(
                        sw.station.district.isEmpty
                            ? 'Bihar'
                            : sw.station.district,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Row 3: DL / WL / HFL chips + risk label
                Row(
                  children: [
                    _MetaChip('DL',  sw.displayDanger,  Colors.orange),
                    const SizedBox(width: 6),
                    _MetaChip('WL',  sw.displayWarning, Colors.amber),
                    const SizedBox(width: 6),
                    if (sw.displayHfl != '—')
                      _MetaChip('HFL', sw.displayHfl, Colors.purple.shade300),
                    const Spacer(),
                    // Risk label chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: riskColor.withOpacity(0.13),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        riskLabel,
                        style: TextStyle(
                          color: riskColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                // Row 4: level gauge bar (live or past)
                if (pct != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: (pct / 120).clamp(0.0, 1.0),
                            backgroundColor: Colors.white10,
                            valueColor: AlwaysStoppedAnimation(
                              isLive ? riskColor : Colors.amberAccent,
                            ),
                            minHeight: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        sw.displayPct,
                        style: TextStyle(
                          color: isLive ? riskColor : Colors.amberAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
                // Row 5: trend + diff (live or past)
                if (sw.displayTrend != null ||
                    sw.displayDiff != '—') ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (sw.displayTrend != null)
                        _TrendChip(sw.displayTrend!,
                            stale: hasPast && !isLive),
                      if (sw.displayDiff != '—') ...[
                        const SizedBox(width: 6),
                        Text(
                          sw.displayDiff,
                          style: TextStyle(
                            color: hasPast && !isLive
                                ? Colors.amberAccent.withOpacity(0.7)
                                : Colors.white54,
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
          // Predict CTA
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

// ── Data-source badge widget ──────────────────────────────────────────────────────
class _DataBadge extends StatelessWidget {
  final bool   isLive;
  final bool   hasPast;
  final String staleLabel;
  const _DataBadge({
    required this.isLive,
    required this.hasPast,
    required this.staleLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (isLive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.tealAccent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text('LIVE',
            style: TextStyle(
                color: Colors.tealAccent,
                fontSize: 8,
                fontWeight: FontWeight.bold)),
      );
    }
    if (hasPast) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.amberAccent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.amberAccent.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history_rounded,
                color: Colors.amberAccent, size: 8),
            const SizedBox(width: 3),
            Text(
              'PAST · $staleLabel',
              style: const TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 8,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text('NA',
          style: TextStyle(color: Colors.white38, fontSize: 8)),
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
    final grouped = <String, List<WrdStationWithHistory>>{};
    for (final sw in app.wrdWithHistory) {
      grouped.putIfAbsent(sw.station.river, () => []).add(sw);
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
                      '${app.liveCount} live · ${app.pastDataCount} past · ${app.totalMonitored} total',
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
  final String                        river;
  final List<WrdStationWithHistory>   stations;
  const _BasinCard({required this.river, required this.stations});

  @override
  Widget build(BuildContext context) {
    final color  = _kRiverColors[river] ?? Colors.tealAccent;
    final live   = stations.where((s) => s.isLive).toList();
    final past   = stations.where((s) => s.hasPastData).toList();
    final atRisk = stations.where((s) {
      final l = s.riskLabel.replaceAll('*', '');
      return l == 'HIGH' || l == 'CRITICAL';
    }).toList();
    final effective = stations.where((s) => s.effectivePct != null).toList();
    final avgPct = effective.isEmpty
        ? 0.0
        : effective
                .map((s) => s.effectivePct ?? 0.0)
                .reduce((a, b) => a + b) /
            effective.length;

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
                  decoration: BoxDecoration(
                      color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(river,
                  style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(
                '${live.length} live  ·  ${past.length} past  ·  ${stations.length} total',
                style: const TextStyle(
                    color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
          if (effective.isNotEmpty) ...[
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
                  'Avg ${avgPct.toStringAsFixed(0)}% of DL  (live+past)',
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
              child: Text(
                'No readings yet — danger levels available',
                style: TextStyle(color: Colors.white24, fontSize: 11),
              ),
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
        past:   i == 0 ? app.pastDataCount : (app.pastDataCount + (i % 2)),
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
  final int live, past, total, alerts;
  final bool isLast;
  const _CycleEntry({
    required this.time, required this.live, required this.past,
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
                      color: isFirst
                          ? Colors.tealAccent
                          : Colors.white12,
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
                                margin:
                                    const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.tealAccent
                                      .withOpacity(0.15),
                                  borderRadius:
                                      BorderRadius.circular(4),
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
                          '${cycle.live} live · ${cycle.past} past · '
                          '${cycle.total} total · '
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
                      cycle.alerts > 0
                          ? '${cycle.alerts} ⚠'
                          : '✓ Safe',
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
            style:
                TextStyle(color: color.withOpacity(0.9), fontSize: 10)),
      ],
    );
  }
}

class _TrendChip extends StatelessWidget {
  final String trend;
  final bool   stale;
  const _TrendChip(this.trend, {this.stale = false});

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
    final color = stale
        ? Colors.amberAccent.withOpacity(0.7)
        : rising
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
