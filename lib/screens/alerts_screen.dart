import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants.dart';
import '../models/flood_data.dart';
import '../services/real_time_service.dart';
import '../widgets/animated_alert_badge.dart';
import '../widgets/river_level_visualizer.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final RealTimeService _service = RealTimeService();
  final Set<String> _dismissed = <String>{};

  String _filter = 'ALL';

  @override
  void initState() {
    super.initState();
    _service.startPolling();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09131D),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF123247), Color(0xFF09131D), Color(0xFF060A10)],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _service,
            builder: (context, _) {
              final levels = List<FloodData>.from(_service.liveLevels)
                ..sort(
                    (a, b) => b.capacityPercent.compareTo(a.capacityPercent));

              final baseAlerts = _service.criticalAlerts.isNotEmpty
                  ? _service.criticalAlerts
                  : _service.activeCriticalAlerts;

              final timelineAlerts = baseAlerts
                  .where((alert) => !_dismissed.contains(alert.id))
                  .where(
                      (alert) => _filter == 'ALL' || alert.severity == _filter)
                  .toList(growable: false)
                ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

              return RefreshIndicator(
                onRefresh: _service.refreshData,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Live Alerts',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _service.refreshData,
                          icon:
                              const Icon(Icons.refresh, color: Colors.white70),
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                    AnimatedAlertBadge(
                      count: timelineAlerts.length,
                      isCritical:
                          timelineAlerts.any((e) => e.severity == 'CRITICAL'),
                      label: 'Active Timeline Alerts',
                    ),
                    const SizedBox(height: 10),
                    if (!_service.isOnline || _service.isUsingCache)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.55)),
                        ),
                        child: const Text(
                          'Offline fallback active. Displaying cached critical alerts.',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 4),
                    const Text(
                      'Live River Gauges',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    ...levels.take(4).map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: RiverLevelVisualizer(
                              city: item.city,
                              river: item.riverName ?? 'River',
                              currentLevel: item.currentLevel,
                              safeLevel: item.safeLevel,
                              warningLevel: item.warningLevel,
                              dangerLevel: item.dangerLevel,
                              trend: item.status,
                            ),
                          ),
                        ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        'ALL',
                        'CRITICAL',
                        'HIGH',
                        'MODERATE',
                        'LOW',
                      ].map((severity) {
                        final selected = severity == _filter;
                        final color = _severityColor(severity);
                        return ChoiceChip(
                          selected: selected,
                          onSelected: (_) => setState(() => _filter = severity),
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                          selectedColor: color.withValues(alpha: 0.28),
                          side: BorderSide(color: color.withValues(alpha: 0.55)),
                          label: Text(
                            severity,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        );
                      }).toList(growable: false),
                    ),
                    const SizedBox(height: 14),
                    if (timelineAlerts.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: const Center(
                          child: Text(
                            'No alerts for selected severity',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      )
                    else
                      ...timelineAlerts.map((alert) {
                        final color = _severityColor(alert.severity);
                        final date = DateFormat('dd MMM | HH:mm')
                            .format(alert.timestamp.toLocal());

                        return Dismissible(
                          key: ValueKey(alert.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.delete_outline,
                                color: Colors.white),
                          ),
                          onDismissed: (_) {
                            setState(() => _dismissed.add(alert.id));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${alert.city} alert dismissed'),
                                action: SnackBarAction(
                                  label: 'UNDO',
                                  onPressed: () {
                                    setState(() => _dismissed.remove(alert.id));
                                  },
                                ),
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.09),
                              borderRadius: BorderRadius.circular(14),
                              border:
                                  Border.all(color: color.withValues(alpha: 0.55)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  children: [
                                    Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: color,
                                      ),
                                    ),
                                    Container(
                                      width: 2,
                                      height: 72,
                                      color: Colors.white24,
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              alert.title,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: color.withValues(alpha: 0.2),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              alert.severity,
                                              style: TextStyle(
                                                color: color,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        alert.message,
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 6,
                                        children: [
                                          _MetaChip(
                                              label: alert.city,
                                              icon: Icons.location_on),
                                          _MetaChip(
                                              label: alert.state,
                                              icon: Icons.map_outlined),
                                          _MetaChip(
                                              label: date,
                                              icon: Icons.schedule),
                                          if (alert.currentLevel != null)
                                            _MetaChip(
                                              label:
                                                  '${alert.currentLevel!.toStringAsFixed(2)} m',
                                              icon: Icons.straighten,
                                            ),
                                        ],
                                      )
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Color _severityColor(String severity) {
    if (severity == 'ALL') return const Color(0xFF24C9E8);
    return Color(AppConstants.riskColors[severity] ??
        AppConstants.riskColors['MODERATE']!);
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _MetaChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white60),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
