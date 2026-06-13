// lib/screens/dashboard_screen.dart
// OpsFlood — Dashboard with full 3-D UI system
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';
import '../providers/flood_provider.dart';
import '../providers/alert_provider.dart';
import 'city_detail_screen.dart';
import 'alerts_screen.dart';
import 'monitors_screen.dart';
import 'predict_screen.dart';
import 'bihar_river_map_screen.dart';
import 'sos_screen.dart';
import 'weather_screen.dart';
import 'news_feed_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(
        const Duration(minutes: 10), (_) => _refresh());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final fp = context.read<FloodProvider>();
    await fp.refresh();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t  = RiverColors.of(context);
    final fp = context.watch<FloodProvider>();
    final ap = context.watch<AlertProvider>();

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: RefreshIndicator(
        color: t.accent,
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── App Bar ──────────────────────────────────────────────────
            Td3AppBar(
              title: 'OpsFlood Bihar',
              subtitle: 'Live Flood Intelligence',
              actions: [
                IconButton(
                  icon: Icon(Icons.sos_rounded,
                      color: t.danger, size: 26),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const SosScreen())),
                ),
                IconButton(
                  icon: Icon(Icons.notifications_rounded,
                      color: t.textSecondary, size: 22),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const AlertsScreen())),
                ),
                const SizedBox(width: 4),
              ],
            ),

            // ── Body ─────────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([

                  // ── Quick-stat row ────────────────────────────────────
                  _StatRow(fp: fp, ap: ap),
                  const SizedBox(height: 20),

                  // ── Alert banner (danger / warning) ───────────────────
                  if (ap.hasCritical) ...[_AlertBanner(ap: ap),
                    const SizedBox(height: 20)],

                  // ── Quick-action grid ─────────────────────────────────
                  const Td3SectionHeader('Quick Actions'),
                  const SizedBox(height: 10),
                  _QuickActions(),
                  const SizedBox(height: 20),

                  // ── Top at-risk cities ────────────────────────────────
                  const Td3SectionHeader('At-Risk Cities'),
                  const SizedBox(height: 10),
                  _AtRiskCities(fp: fp),
                  const SizedBox(height: 20),

                  // ── Live stations strip ───────────────────────────────
                  const Td3SectionHeader('Live Stations'),
                  const SizedBox(height: 10),
                  _LiveStrip(fp: fp),
                  const SizedBox(height: 20),

                  // ── News ticker ───────────────────────────────────────
                  const Td3SectionHeader('Latest News'),
                  const SizedBox(height: 10),
                  _NewsTicker(),

                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatRow  —  4 KPI tiles
// ─────────────────────────────────────────────────────────────────────────────

class _StatRow extends StatelessWidget {
  final FloodProvider fp;
  final AlertProvider ap;
  const _StatRow({required this.fp, required this.ap});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Row(
      children: [
        Expanded(
          child: Td3StatTile(
            value: '${fp.stationCount}',
            label: 'STATIONS LIVE',
            valueColor: t.accent,
            icon: Icons.sensors_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Td3StatTile(
            value: '${ap.dangerCount}',
            label: 'DANGER',
            valueColor: t.danger,
            icon: Icons.warning_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Td3StatTile(
            value: '${ap.warningCount}',
            label: 'WARNING',
            valueColor: t.warning,
            icon: Icons.error_outline_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Td3StatTile(
            value: '${ap.normalCount}',
            label: 'NORMAL',
            valueColor: t.safe,
            icon: Icons.check_circle_outline_rounded,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AlertBanner
// ─────────────────────────────────────────────────────────────────────────────

class _AlertBanner extends StatelessWidget {
  final AlertProvider ap;
  const _AlertBanner({required this.ap});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Td3Card(
      color: t.danger.withValues(alpha: 0.10),
      accentColor: t.danger,
      elevation: Td3.elevHigh,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: t.danger.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.warning_amber_rounded,
                  color: t.danger, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CRITICAL FLOOD ALERT',
                      style: TextStyle(
                          color: t.danger,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8)),
                  Text(
                    '${ap.dangerCount} station(s) above danger level',
                    style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            Td3Badge(
                label: 'LIVE',
                color: t.danger,
                icon: Icons.circle,
                fontSize: 8),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _QuickActions  —  2×3 action grid
// ─────────────────────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    final actions = [
      (
        'River Map',
        Icons.map_rounded,
        t.accent,
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const BiharRiverMapScreen()))
      ),
      (
        'Predict',
        Icons.auto_graph_rounded,
        t.warning,
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PredictScreen()))
      ),
      (
        'Monitors',
        Icons.water_rounded,
        t.info,
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const MonitorsScreen()))
      ),
      (
        'Weather',
        Icons.cloud_rounded,
        const Color(0xFF5B7FD6),
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const WeatherScreen()))
      ),
      (
        'Alerts',
        Icons.notifications_rounded,
        t.danger,
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AlertsScreen()))
      ),
      (
        'SOS',
        Icons.sos_rounded,
        t.danger,
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SosScreen()))
      ),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.1,
      children: actions.map((a) {
        final (label, icon, color, onTap) = a;
        return Td3Card(
          accentColor: color,
          elevation: Td3.elevMid,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AtRiskCities
// ─────────────────────────────────────────────────────────────────────────────

class _AtRiskCities extends StatelessWidget {
  final FloodProvider fp;
  const _AtRiskCities({required this.fp});

  @override
  Widget build(BuildContext context) {
    final t      = RiverColors.of(context);
    final cities = fp.topAtRiskCities.take(5).toList();
    if (cities.isEmpty) {
      return Td3Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text('No at-risk cities',
                style: TextStyle(
                    color: t.textSecondary, fontSize: 13)),
          ),
        ),
      );
    }
    return Column(
      children: cities.map((city) {
        final pct   = city.riskPercent.clamp(0.0, 1.0);
        final color = pct > 0.8
            ? t.danger
            : pct > 0.5
                ? t.warning
                : t.safe;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Td3Card(
            accentColor: color,
            elevation: Td3.elevLow,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      CityDetailScreen(city: city)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          city.name,
                          style: TextStyle(
                              color: t.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      Td3Chip(
                        label: city.statusLabel,
                        color: color,
                        fontSize: 9,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(pct * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Td3ProgressBar(
                      value: pct, fillColor: color, height: 8),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _LiveStrip  —  horizontal scrollable station cards
// ─────────────────────────────────────────────────────────────────────────────

class _LiveStrip extends StatelessWidget {
  final FloodProvider fp;
  const _LiveStrip({required this.fp});

  @override
  Widget build(BuildContext context) {
    final t        = RiverColors.of(context);
    final stations = fp.liveStations.take(10).toList();
    if (stations.isEmpty) {
      return SizedBox(
        height: 90,
        child: Center(
          child: Text('Loading stations…',
              style: TextStyle(color: t.textSecondary)),
        ),
      );
    }
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: stations.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (ctx, i) {
          final s     = stations[i];
          final color = s.statusColor(t);
          return SizedBox(
            width: 120,
            child: Td3Card(
              accentColor: color,
              elevation: Td3.elevMid,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Td3Badge(
                        label: s.statusLabel,
                        color: color,
                        fontSize: 7),
                    const SizedBox(height: 6),
                    Text(
                      s.site,
                      style: TextStyle(
                          color: t.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.river,
                      style: TextStyle(
                          color: t.textSecondary,
                          fontSize: 9),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Text(
                      '${s.level.toStringAsFixed(2)} m',
                      style: TextStyle(
                          color: color,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          shadows: [
                            Shadow(
                                color: color.withValues(alpha: 0.3),
                                blurRadius: 6)
                          ]),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NewsTicker
// ─────────────────────────────────────────────────────────────────────────────

class _NewsTicker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Td3Card(
      elevation: Td3.elevLow,
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const NewsFeedScreen())),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Td3Badge(
                label: 'NEWS',
                color: t.info,
                icon: Icons.newspaper_rounded,
                fontSize: 8),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Tap to read the latest flood news & updates',
                style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: t.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }
}
