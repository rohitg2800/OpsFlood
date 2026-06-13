// lib/screens/alerts_screen.dart  — 3-D UI rebuild
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';
import '../providers/alert_provider.dart';
import '../models/flood_alert.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t  = RiverColors.of(context);
    final ap = context.watch<AlertProvider>();

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          Td3AppBar(
            title: 'Flood Alerts',
            subtitle: '${ap.activeAlerts.length} active',
            leading: Navigator.canPop(ctx)
                ? IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        color: t.textPrimary, size: 18),
                    onPressed: () => Navigator.pop(ctx),
                  )
                : null,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Td3Badge(
                  label: '${ap.dangerCount} DANGER',
                  color: t.danger,
                  icon: Icons.warning_rounded,
                  fontSize: 8,
                ),
              ),
            ],
          ),
        ],
        body: Column(
          children: [
            // Tab bar
            Container(
              color: t.cardBg,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  _tab3D(context, 0, 'ALL', ap.activeAlerts.length, t.accent),
                  const SizedBox(width: 8),
                  _tab3D(context, 1, 'DANGER', ap.dangerCount, t.danger),
                  const SizedBox(width: 8),
                  _tab3D(context, 2, 'WARNING', ap.warningCount, t.warning),
                ],
              ),
            ),
            const Td3Divider(),
            // List
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _AlertList(alerts: ap.activeAlerts),
                  _AlertList(
                      alerts: ap.activeAlerts
                          .where((a) => a.level == AlertLevel.danger)
                          .toList()),
                  _AlertList(
                      alerts: ap.activeAlerts
                          .where((a) => a.level == AlertLevel.warning)
                          .toList()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tab3D(
      BuildContext ctx, int idx, String label, int count, Color color) {
    final selected = _tab.index == idx;
    return GestureDetector(
      onTap: () => setState(() => _tab.animateTo(idx)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: selected
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.18),
                    color.withValues(alpha: 0.08)
                  ],
                ),
                border: Td3.depthBorder(
                  topColor: color.withValues(alpha: 0.30),
                  bottomColor: Td3.edgeMid,
                ),
                boxShadow: Td3.cardShadow(color, elev: Td3.elevLow),
              )
            : null,
        child: Row(
          children: [
            Text(label,
                style: TextStyle(
                    color: selected ? color : RiverColors.of(ctx).textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5)),
            const SizedBox(width: 4),
            if (count > 0)
              Td3Chip(
                  label: '$count', color: color, fontSize: 9),
          ],
        ),
      ),
    );
  }
}

class _AlertList extends StatelessWidget {
  final List<FloodAlert> alerts;
  const _AlertList({required this.alerts});

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    if (alerts.isEmpty) {
      return Center(
          child: Text('No alerts',
              style: TextStyle(color: t.textSecondary)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: alerts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final a = alerts[i];
        final color = a.level == AlertLevel.danger ? t.danger : t.warning;
        return Td3Card(
          accentColor: color,
          elevation: Td3.elevMid,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    a.level == AlertLevel.danger
                        ? Icons.warning_rounded
                        : Icons.error_outline_rounded,
                    color: color,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(a.site,
                                style: TextStyle(
                                    color: t.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700)),
                          ),
                          Td3Chip(
                              label: a.level.name.toUpperCase(),
                              color: color,
                              fontSize: 9),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(a.river,
                          style: TextStyle(
                              color: t.textSecondary,
                              fontSize: 11)),
                      const SizedBox(height: 6),
                      Td3ProgressBar(
                        value: a.levelPercent,
                        fillColor: color,
                        height: 6,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${a.currentLevel.toStringAsFixed(2)} m  /  danger at ${a.dangerLevel.toStringAsFixed(2)} m',
                        style: TextStyle(
                            color: t.textSecondary,
                            fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
