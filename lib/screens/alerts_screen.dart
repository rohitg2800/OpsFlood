import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants.dart';
import '../models/flood_data.dart';
import '../services/cwc_live_provider.dart';
import '../services/real_time_service.dart';
import '../widgets/animated_alert_badge.dart';
import '../widgets/river_level_visualizer.dart';

// ─── palette ───────────────────────────────────────────────────────────────────
const _kBg     = Color(0xFF060D14);
const _kCard   = Color(0xFF0D1B26);
const _kCyan   = Color(0xFF00C2DE);
const _kGreen  = Color(0xFF22C55E);
const _kYellow = Color(0xFFF59E0B);
const _kOrange = Color(0xFFEA580C);
const _kRed    = Color(0xFFEF4444);
const _kText   = Color(0xFFE2EAF0);
const _kSub    = Color(0xFF6B8699);

Color _sevColor(String sev) {
  switch (sev) {
    case 'ALL':      return _kCyan;
    case 'CRITICAL': return _kRed;
    case 'HIGH':     return _kOrange;
    case 'MODERATE': return _kYellow;
    default:         return _kGreen;
  }
}

String _sevIcon(String sev) {
  switch (sev) {
    case 'CRITICAL': return '🔴';
    case 'HIGH':     return '🟠';
    case 'MODERATE': return '🟡';
    case 'LOW':      return '🟢';
    default:         return '⚪';
  }
}

// ─── screen ─────────────────────────────────────────────────────────────────────
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});
  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen>
    with SingleTickerProviderStateMixin {
  final RealTimeService _svc      = RealTimeService();
  final Set<String>     _dismissed = {};
  String  _filter   = 'ALL';
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _svc.addListener(_onUpdate);
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _svc.removeListener(_onUpdate);
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onUpdate() { if (mounted) setState(() {}); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A1E2C), _kBg, Color(0xFF030608)],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _svc,
            builder: (context, _) {
              final levels = List<FloodData>.from(_svc.liveLevels)
                ..sort((a, b) =>
                    b.capacityPercent.compareTo(a.capacityPercent));

              final baseAlerts = _svc.criticalAlerts.isNotEmpty
                  ? _svc.criticalAlerts
                  : _svc.activeCriticalAlerts;

              final timelineAlerts = baseAlerts
                  .where((a) => !_dismissed.contains(a.id))
                  .where((a) => _filter == 'ALL' || a.severity == _filter)
                  .toList()
                ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

              // severity counts
              final counts = <String, int>{
                'CRITICAL': baseAlerts.where((a) => a.severity == 'CRITICAL').length,
                'HIGH':     baseAlerts.where((a) => a.severity == 'HIGH').length,
                'MODERATE': baseAlerts.where((a) => a.severity == 'MODERATE').length,
                'LOW':      baseAlerts.where((a) => a.severity == 'LOW').length,
              };

              return RefreshIndicator(
                onRefresh: _svc.refreshData,
                color: _kCyan,
                backgroundColor: _kCard,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── title row ─────────────────────────────────
                            Row(
                              children: [
                                const Text('Live Alerts',
                                    style: TextStyle(
                                        color: _kText,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.5)),
                                const Spacer(),
                                IconButton(
                                  onPressed: _svc.refreshData,
                                  icon: const Icon(Icons.refresh_rounded,
                                      color: _kSub, size: 20),
                                  style: IconButton.styleFrom(
                                      backgroundColor:
                                          Colors.white.withOpacity(0.06),
                                      padding:
                                          const EdgeInsets.all(8)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // ── animated alert badge ────────────────────
                            AnimatedAlertBadge(
                              count: timelineAlerts.length,
                              isCritical: timelineAlerts
                                  .any((e) => e.severity == 'CRITICAL'),
                              label: 'Active Timeline Alerts',
                            ),
                            const SizedBox(height: 14),

                            // ── severity count row ─────────────────────
                            Row(
                              children: [
                                'CRITICAL', 'HIGH', 'MODERATE', 'LOW'
                              ].map((s) {
                                final c = _sevColor(s);
                                return Expanded(
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8),
                                    decoration: BoxDecoration(
                                      color: c.withOpacity(0.08),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      border: Border.all(
                                          color: c.withOpacity(0.22)),
                                    ),
                                    child: Column(
                                      children: [
                                        Text('${counts[s] ?? 0}',
                                            style: TextStyle(
                                                color: c,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 18)),
                                        Text(s[0] + s.substring(1).toLowerCase(),
                                            style: const TextStyle(
                                                color: _kSub,
                                                fontSize: 9)),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),

                            // ── offline notice ──────────────────────────
                            if (!_svc.isOnline || _svc.isUsingCache)
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color:
                                      _kOrange.withOpacity(0.12),
                                  borderRadius:
                                      BorderRadius.circular(12),
                                  border: Border.all(
                                      color: _kOrange.withOpacity(0.4)),
                                ),
                                child: Row(
                                  children: const [
                                    Icon(Icons.wifi_off_rounded,
                                        color: _kOrange, size: 14),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Offline — showing cached alerts.',
                                        style: TextStyle(
                                            color: _kOrange,
                                            fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // ── gauge mini-cards ────────────────────────
                            Row(
                              children: const [
                                Icon(Icons.water_drop,
                                    color: _kCyan, size: 13),
                                SizedBox(width: 5),
                                Text('Live River Gauges',
                                    style: TextStyle(
                                        color: _kText,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14)),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),

                    // gauge cards
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) {
                            final item = levels[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _GaugeCard(item: item),
                            );
                          },
                          childCount: levels.take(4).length,
                        ),
                      ),
                    ),

                    // ── filter chips ─────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(18, 8, 18, 12),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              'ALL', 'CRITICAL', 'HIGH', 'MODERATE', 'LOW'
                            ].map((s) {
                              final selected = s == _filter;
                              final c = _sevColor(s);
                              return GestureDetector(
                                onTap: () =>
                                    setState(() => _filter = s),
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 250),
                                  margin:
                                      const EdgeInsets.only(right: 8),
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? c.withOpacity(0.2)
                                        : Colors.white.withOpacity(0.05),
                                    borderRadius:
                                        BorderRadius.circular(22),
                                    border: Border.all(
                                      color: selected
                                          ? c
                                          : Colors.white.withOpacity(0.15),
                                      width: selected ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (s != 'ALL') ...
                                        [
                                          Text(_sevIcon(s),
                                              style: const TextStyle(
                                                  fontSize: 12)),
                                          const SizedBox(width: 5),
                                        ],
                                      Text(s,
                                          style: TextStyle(
                                            color: selected
                                                ? c
                                                : Colors.white70,
                                            fontWeight: selected
                                                ? FontWeight.w700
                                                : FontWeight.w400,
                                            fontSize: 12,
                                          )),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),

                    // ── timeline alerts ──────────────────────────────────
                    if (timelineAlerts.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding:
                              const EdgeInsets.fromLTRB(18, 0, 18, 30),
                          child: Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.1)),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.check_circle_outline,
                                    color: _kGreen, size: 36),
                                SizedBox(height: 10),
                                Text('No alerts for this severity',
                                    style: TextStyle(
                                        color: _kSub, fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding:
                            const EdgeInsets.fromLTRB(18, 0, 18, 30),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (_, i) {
                              final alert = timelineAlerts[i];
                              return _AlertCard(
                                key: ValueKey(alert.id),
                                alert: alert,
                                pulseCtrl: _pulseCtrl,
                                onDismiss: () => setState(
                                    () => _dismissed.add(alert.id)),
                                onUndo: () => setState(
                                    () => _dismissed.remove(alert.id)),
                              );
                            },
                            childCount: timelineAlerts.length,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─── gauge mini card ──────────────────────────────────────────────────────────
class _GaugeCard extends StatelessWidget {
  final FloodData item;
  const _GaugeCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final riskC = _getRiskColor(item.riskLevel);
    final pct   = item.capacityPercent.clamp(0.0, 100.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: riskC.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // level indicator bar
          Container(
            width: 4,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end:   Alignment.topCenter,
                colors: [riskC.withOpacity(0.3), riskC],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(item.city,
                        style: const TextStyle(
                            color: _kText,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(item.riverName ?? '',
                        style: const TextStyle(
                            color: _kSub, fontSize: 11)),
                    const Spacer(),
                    Text(
                        'D ${item.dangerLevel.toStringAsFixed(1)}',
                        style: const TextStyle(
                            color: _kSub, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${item.currentLevel.toStringAsFixed(2)} m',
                      style: TextStyle(
                          color: riskC,
                          fontWeight: FontWeight.w700,
                          fontSize: 16),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: riskC.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('ESTIMATED',
                          style: TextStyle(
                              color: riskC.withOpacity(0.8),
                              fontSize: 9,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // capacity bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    children: [
                      Container(
                          height: 4,
                          color: Colors.white.withOpacity(0.06)),
                      FractionallySizedBox(
                        widthFactor: pct / 100,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                riskC.withOpacity(0.6),
                                riskC
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getRiskColor(String risk) {
    switch (risk) {
      case 'CRITICAL': return _kRed;
      case 'HIGH':     return _kOrange;
      case 'MODERATE': return _kYellow;
      default:         return _kGreen;
    }
  }
}

// ─── alert card ───────────────────────────────────────────────────────────────
class _AlertCard extends StatelessWidget {
  final dynamic              alert;
  final AnimationController  pulseCtrl;
  final VoidCallback         onDismiss;
  final VoidCallback         onUndo;
  const _AlertCard({
    super.key,
    required this.alert,
    required this.pulseCtrl,
    required this.onDismiss,
    required this.onUndo,
  });

  @override
  Widget build(BuildContext context) {
    final color  = _sevColor(alert.severity as String);
    final isCrit = alert.severity == 'CRITICAL';
    final date   = DateFormat('dd MMM | HH:mm')
        .format((alert.timestamp as DateTime).toLocal());

    return Dismissible(
      key: ValueKey(alert.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding:   const EdgeInsets.only(right: 20),
        margin:    const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color:        _kRed.withOpacity(0.2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.white60),
      ),
      onDismissed: (_) {
        onDismiss();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _kCard,
            content: Text('${alert.city} alert dismissed',
                style: const TextStyle(color: _kText)),
            action: SnackBarAction(
              label: 'UNDO',
              textColor: _kCyan,
              onPressed: onUndo,
            ),
          ),
        );
      },
      child: AnimatedBuilder(
        animation: pulseCtrl,
        builder: (_, child) {
          final glow = isCrit
              ? color.withOpacity(0.04 + pulseCtrl.value * 0.06)
              : Colors.transparent;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isCrit
                    ? color.withOpacity(0.5 + pulseCtrl.value * 0.3)
                    : color.withOpacity(0.35),
                width: isCrit ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(color: glow, blurRadius: 16, spreadRadius: 1)
              ],
            ),
            child: child,
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // severity colour header bar
            Container(
              height: 3,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                    topLeft:  Radius.circular(18),
                    topRight: Radius.circular(18)),
                gradient: LinearGradient(
                    colors: [color.withOpacity(0.6), color]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // timeline dot + line
                  Column(
                    children: [
                      Container(
                        width: 12, height: 12,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: color.withOpacity(0.5),
                                blurRadius: 6)
                          ],
                        ),
                      ),
                      Container(
                          width: 1.5,
                          height: 70,
                          color: color.withOpacity(0.2)),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                alert.title as String,
                                style: const TextStyle(
                                    color: _kText,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: color.withOpacity(0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_sevIcon(alert.severity as String),
                                      style:
                                          const TextStyle(fontSize: 10)),
                                  const SizedBox(width: 4),
                                  Text(alert.severity as String,
                                      style: TextStyle(
                                          color: color,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          alert.message as String,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _Chip(
                                Icons.location_on_outlined,
                                alert.city as String),
                            _Chip(
                                Icons.map_outlined,
                                alert.state as String),
                            _Chip(Icons.schedule_rounded, date),
                            if (alert.currentLevel != null)
                              _Chip(
                                  Icons.straighten,
                                  '${(alert.currentLevel as double).toStringAsFixed(2)} m'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String   text;
  const _Chip(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color:        Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(18),
        border:       Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: _kSub),
          const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(color: Colors.white60, fontSize: 10.5)),
        ],
      ),
    );
  }
}
