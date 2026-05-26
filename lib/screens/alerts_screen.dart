// lib/screens/alerts_screen.dart
// OpsFlood — AlertsScreen v3  (Flood Alert Command)
// New UI: severity bands (CRITICAL / HIGH / WATCH), WRD Bihar sourced,
// connected to predict window via deep-link. Shows discharge + level data.
library;

import 'package:flutter/material.dart';
import '../services/app_state_service.dart';
import '../services/wrd_bihar_service.dart';
import 'predict_screen.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  // Required by main.dart routes map
  static const String route = '/alerts';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppStateService.instance,
      builder: (context, _) {
        final app = AppStateService.instance;
        return Scaffold(
          backgroundColor: const Color(0xFF060C1A),
          body: CustomScrollView(
            slivers: [
              _buildAppBar(context, app),
              if (app.loading && app.activeAlerts.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.tealAccent),
                  ),
                )
              else if (app.activeAlerts.isEmpty)
                SliverFillRemaining(child: _EmptyAlerts())
              else
                SliverList(
                  delegate: SliverChildListDelegate([
                    _SeveritySummaryBar(app: app),
                    const SizedBox(height: 8),
                    if (app.criticalCount > 0) ..._section(
                        'CRITICAL', app.activeAlerts
                            .where((a) => a.risk == AppRisk.critical).toList(),
                        Colors.red, context),
                    if (app.highCount > 0) ..._section(
                        'HIGH RISK', app.activeAlerts
                            .where((a) => a.risk == AppRisk.high).toList(),
                        Colors.orange, context),
                    ..._section(
                        'WATCH', app.activeAlerts
                            .where((a) => a.risk == AppRisk.watch).toList(),
                        Colors.amber, context),
                    const SizedBox(height: 24),
                  ]),
                ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: const Color(0xFF0D1B2A),
            foregroundColor: Colors.tealAccent,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh'),
            onPressed: () => AppStateService.instance.refresh(),
          ),
        );
      },
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, AppStateService app) {
    return SliverAppBar(
      backgroundColor: const Color(0xFF060C1A),
      pinned: true,
      title: Row(
        children: [
          const Icon(Icons.notifications_active, color: Colors.tealAccent, size: 22),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Flood Alerts',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              Text(
                '${app.alertCount} active · WRD Bihar',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _section(String title, List<FloodAlertEntry> alerts,
      Color color, BuildContext context) {
    if (alerts.isEmpty) return [];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
        child: Row(
          children: [
            Container(width: 3, height: 16,
                color: color,
                margin: const EdgeInsets.only(right: 8)),
            Text(title,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6)),
              child: Text('${alerts.length}',
                  style: TextStyle(
                      color: color, fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
      ...alerts.map((a) => _AlertCard(alert: a, context: context)),
    ];
  }
}

class _SeveritySummaryBar extends StatelessWidget {
  final AppStateService app;
  const _SeveritySummaryBar({required this.app});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _pill('CRITICAL', '${app.criticalCount}', Colors.red),
          _pill('HIGH', '${app.highCount}', Colors.orange),
          _pill('WATCH',
              '${app.activeAlerts.where((a) => a.risk == AppRisk.watch).length}',
              Colors.amber),
          _pill('SOURCE', 'WRD BH', Colors.tealAccent),
        ],
      ),
    );
  }

  Widget _pill(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                color: Colors.white38, fontSize: 9, letterSpacing: 0.8)),
      ],
    );
  }
}

class _AlertCard extends StatelessWidget {
  final FloodAlertEntry alert;
  final BuildContext    context;
  const _AlertCard({required this.alert, required this.context});

  @override
  Widget build(BuildContext ctx) {
    final color = _riskColor(alert.risk);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.45)),
        boxShadow: alert.isCritical
            ? [
                BoxShadow(
                    color: color.withOpacity(0.15),
                    blurRadius: 12, spreadRadius: 1)
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(alert.station,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              alert.risk == AppRisk.critical
                                  ? '🚨 CRITICAL'
                                  : alert.risk == AppRisk.high
                                      ? '⚠ HIGH'
                                      : '👁 WATCH',
                              style: TextStyle(
                                  color: color,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('${alert.river} · ${alert.district}',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${alert.currentLevel.toStringAsFixed(2)}m',
                      style: TextStyle(
                          color: color,
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${alert.pct.toStringAsFixed(0)}% DL',
                      style: TextStyle(
                          color: color.withOpacity(0.7), fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (alert.pct / 120).clamp(0.0, 1.0),
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  alert.trend.toLowerCase().contains('ris')
                      ? Icons.trending_up
                      : alert.trend.toLowerCase().contains('fal')
                          ? Icons.trending_down
                          : Icons.trending_flat,
                  size: 14,
                  color: alert.trend.toLowerCase().contains('ris')
                      ? Colors.orangeAccent
                      : Colors.tealAccent,
                ),
                const SizedBox(width: 4),
                Text(alert.trend,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 10)),
                const Spacer(),
                Text('DL: ${alert.dangerLevel.toStringAsFixed(2)}m',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 10)),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    Navigator.of(ctx).push(MaterialPageRoute(
                      builder: (_) => const PredictScreen(),
                    ));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8E24AA).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFF8E24AA).withOpacity(0.5)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.model_training_rounded,
                            color: Color(0xFFCE93D8), size: 12),
                        SizedBox(width: 4),
                        Text('PREDICT',
                            style: TextStyle(
                                color: Color(0xFFCE93D8),
                                fontSize: 9,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _riskColor(AppRisk r) {
    switch (r) {
      case AppRisk.critical: return Colors.red;
      case AppRisk.high:     return Colors.orange;
      case AppRisk.watch:    return Colors.amber;
      default:               return Colors.white38;
    }
  }
}

class _EmptyAlerts extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: Colors.tealAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline,
                color: Colors.tealAccent, size: 44),
          ),
          const SizedBox(height: 16),
          const Text('No Active Alerts',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'All monitored stations are\nbelow warning thresholds.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
