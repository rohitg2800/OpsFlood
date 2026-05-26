// lib/screens/home_screen.dart
// OpsFlood — HomeScreen v6  (Command Dashboard)
// New UI: critical banner, avg risk meter, monitored count, alert count,
// quick-nav cards, WRD Bihar live summary.
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_state_service.dart';
import '../services/real_time_service.dart';
import '../theme/river_theme.dart';
import 'alerts_screen.dart';
import 'dashboard_screen.dart';
import 'monitors_screen.dart';
import 'predict_screen.dart';
import 'river_monitor_screen.dart';
import 'weather_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final RealTimeService _svc  = RealTimeService();
  final AppStateService _app  = AppStateService.instance;
  int _currentIndex = 0;

  late AnimationController _glowCtrl;
  late Animation<double>   _glowAnim;

  static const _destinations = [
    _NavEntry(label: 'Home',    icon: Icons.dashboard_rounded,      activeIcon: Icons.dashboard_rounded),
    _NavEntry(label: 'Rivers',  icon: Icons.water_outlined,          activeIcon: Icons.water_rounded),
    _NavEntry(label: 'Alerts',  icon: Icons.notifications_outlined,  activeIcon: Icons.notifications_rounded),
    _NavEntry(label: 'Weather', icon: Icons.cloud_outlined,          activeIcon: Icons.cloud_rounded),
    _NavEntry(label: 'Predict', icon: Icons.model_training_outlined, activeIcon: Icons.model_training_rounded),
    _NavEntry(label: 'Monitor', icon: Icons.monitor_heart_outlined,  activeIcon: Icons.monitor_heart_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _svc.startPolling();
    _app.startPolling();
    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _svc.stopPolling();
    _app.stopPolling();
    _glowCtrl.dispose();
    super.dispose();
  }

  Widget _buildScreen(int index) {
    switch (index) {
      case 0: return const _HomeBody();
      case 1: return const RiverMonitorScreen();
      case 2: return const AlertsScreen();
      case 3: return const WeatherScreen();
      case 4: return const PredictScreen();
      case 5: return const MonitorsScreen();
      default: return const _HomeBody();
    }
  }

  void _onTap(int i) {
    if (i == _currentIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = i);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
          systemNavigationBarColor: AppPalette.abyss0),
      child: Scaffold(
        backgroundColor: AppPalette.abyss0,
        body: _buildScreen(_currentIndex),
        bottomNavigationBar: _PremiumNavBar(
          currentIndex: _currentIndex,
          destinations: _destinations,
          glowAnim:     _glowAnim,
          onTap:        _onTap,
          alertCount:   _app.alertCount,
        ),
      ),
    );
  }
}

// ── Home Body (Command Dashboard) ─────────────────────────────────────────────
class _HomeBody extends StatelessWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppStateService.instance,
      builder: (context, _) {
        final app = AppStateService.instance;
        return CustomScrollView(
          slivers: [
            _buildAppBar(context, app),
            if (app.criticalCount > 0)
              SliverToBoxAdapter(child: _CriticalBanner(app: app)),
            SliverToBoxAdapter(child: _RiskMeterRow(app: app)),
            SliverToBoxAdapter(child: _StatsRow(app: app)),
            SliverToBoxAdapter(child: _WrdLiveSummary(app: app)),
            SliverToBoxAdapter(child: _QuickNavGrid()),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        );
      },
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, AppStateService app) {
    return SliverAppBar(
      backgroundColor: const Color(0xFF060C1A),
      expandedHeight: 120,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end:   Alignment.bottomRight,
              colors: [Color(0xFF060C1A), Color(0xFF0A1628)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.water_rounded,
                        color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('OpsFlood',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            )),
                        Text(
                          'Bihar Flood Command · WRD Live',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (app.loading)
                    const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.tealAccent),
                    )
                  else
                    GestureDetector(
                      onTap: () => AppStateService.instance.refresh(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.refresh_rounded,
                            color: Colors.tealAccent, size: 20),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Critical Banner ────────────────────────────────────────────────────────────
class _CriticalBanner extends StatelessWidget {
  final AppStateService app;
  const _CriticalBanner({required this.app});

  @override
  Widget build(BuildContext context) {
    final top = app.activeAlerts.first;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade900, Colors.red.shade800],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
              color: Colors.red.withOpacity(0.3),
              blurRadius: 20, spreadRadius: 2),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🚨 ${app.criticalCount} CRITICAL ALERT${app.criticalCount > 1 ? 'S' : ''} ACTIVE',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5),
                ),
                const SizedBox(height: 2),
                Text(
                  '${top.station} — ${top.pct.toStringAsFixed(0)}% of danger level · ${top.river}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              // Navigate to Alerts tab (index 2)
              final home = context.findAncestorStateOfType<_HomeScreenState>();
              home?._onTap(2);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('VIEW',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Risk Meter Row ─────────────────────────────────────────────────────────────
class _RiskMeterRow extends StatelessWidget {
  final AppStateService app;
  const _RiskMeterRow({required this.app});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1B2A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _riskColor(app.avgRisk).withOpacity(0.35)),
        ),
        child: Row(
          children: [
            // Risk dial
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 72, height: 72,
                  child: CircularProgressIndicator(
                    value: _riskValue(app.avgRisk),
                    backgroundColor: Colors.white10,
                    color: _riskColor(app.avgRisk),
                    strokeWidth: 6,
                  ),
                ),
                Column(
                  children: [
                    Text(
                      app.avgRiskLabel,
                      style: TextStyle(
                          color: _riskColor(app.avgRisk),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8),
                    ),
                    Text(
                      '${app.liveCount}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                    const Text('LIVE',
                        style: TextStyle(
                            color: Colors.white38, fontSize: 8)),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Average Basin Risk',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    'WRD Bihar: ${app.totalMonitored} stations monitored',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  // Risk band
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _riskValue(app.avgRisk),
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation(
                          _riskColor(app.avgRisk)),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _band('SAFE',     Colors.tealAccent),
                      _band('WATCH',    Colors.amber),
                      _band('HIGH',     Colors.orange),
                      _band('CRITICAL', Colors.red),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _band(String label, Color color) {
    return Row(
      children: [
        Container(
            width: 6, height: 6,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                color: color.withOpacity(0.8),
                fontSize: 8,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Color _riskColor(AppRisk r) {
    switch (r) {
      case AppRisk.critical: return Colors.red;
      case AppRisk.high:     return Colors.orange;
      case AppRisk.watch:    return Colors.amber;
      case AppRisk.safe:     return Colors.tealAccent;
      default:               return Colors.white38;
    }
  }

  double _riskValue(AppRisk r) {
    switch (r) {
      case AppRisk.critical: return 1.0;
      case AppRisk.high:     return 0.75;
      case AppRisk.watch:    return 0.5;
      case AppRisk.safe:     return 0.25;
      default:               return 0.1;
    }
  }
}

// ── Stats Row ──────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final AppStateService app;
  const _StatsRow({required this.app});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(child: _StatCard(
            value: '${app.totalMonitored}',
            label: 'Monitored',
            icon: Icons.sensors,
            color: Colors.tealAccent,
          )),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(
            value: '${app.alertCount}',
            label: 'Alerts',
            icon: Icons.warning_amber_rounded,
            color: app.alertCount > 0 ? Colors.orangeAccent : Colors.white38,
          )),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(
            value: '${app.criticalCount}',
            label: 'Critical',
            icon: Icons.crisis_alert,
            color: app.criticalCount > 0 ? Colors.redAccent : Colors.white38,
          )),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(
            value: '${app.liveCount}',
            label: 'Live Data',
            icon: Icons.circle,
            color: Colors.greenAccent,
          )),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String   value;
  final String   label;
  final IconData icon;
  final Color    color;
  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 9,
                  letterSpacing: 0.5),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── WRD Live Summary ───────────────────────────────────────────────────────────
class _WrdLiveSummary extends StatelessWidget {
  final AppStateService app;
  const _WrdLiveSummary({required this.app});

  @override
  Widget build(BuildContext context) {
    final critical = app.wrdStations
        .where((s) => s.riskLabel == 'CRITICAL').toList();
    final high = app.wrdStations
        .where((s) => s.riskLabel == 'HIGH').toList();
    final rising = app.wrdStations
        .where((s) =>
            s.hasLiveData &&
            (s.trend?.toLowerCase().contains('ris') ?? false)).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1B2A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                      color: Colors.tealAccent, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                const Text('WRD Bihar Live Database',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                if (app.lastRefresh != null)
                  Text(
                    _ago(app.lastRefresh!),
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 10),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (app.loading && app.wrdStations.isEmpty)
              const Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.tealAccent),
              )
            else if (app.wrdStations.isEmpty)
              const Text('No WRD data — check connection',
                  style: TextStyle(color: Colors.white38))
            else
              Column(
                children: [
                  _wrdRow('Total Stations', '${app.totalMonitored}',
                      Colors.white70),
                  _wrdRow('Live Gauges', '${app.liveCount}',
                      Colors.tealAccent),
                  _wrdRow('Critical', '${critical.length}',
                      critical.isNotEmpty
                          ? Colors.redAccent
                          : Colors.white38),
                  _wrdRow('High Risk', '${high.length}',
                      high.isNotEmpty
                          ? Colors.orange
                          : Colors.white38),
                  _wrdRow('Rising Trend', '${rising.length}',
                      rising.isNotEmpty
                          ? Colors.amberAccent
                          : Colors.white38),
                  if (critical.isNotEmpty) ...[
                    const Divider(color: Colors.white12, height: 20),
                    ...critical.take(3).map((s) => _alertRow(s)),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _wrdRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _alertRow(WrdStation s) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Icon(Icons.circle, color: Colors.redAccent, size: 7),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${s.site} — ${s.currentLevel?.toStringAsFixed(2) ?? "-"}m/${s.dangerLevel?.toStringAsFixed(2) ?? "-"}m DL',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
          Text('${s.river}',
              style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }

  String _ago(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inSeconds < 60) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    return '${d.inHours}h ago';
  }
}

// ── Quick Nav Grid ─────────────────────────────────────────────────────────────
class _QuickNavGrid extends StatelessWidget {
  const _QuickNavGrid();

  static const _cards = [
    _QuickCard('River Monitor',  Icons.water_rounded,          'Live gauge levels', Color(0xFF0097A7), 1),
    _QuickCard('Flood Alerts',   Icons.notifications_active,   'Active warnings',   Color(0xFFE53935), 2),
    _QuickCard('Prediction',     Icons.model_training_rounded, 'ML flood forecast', Color(0xFF8E24AA), 4),
    _QuickCard('System Monitor', Icons.monitor_heart_rounded,  'API & DB health',   Color(0xFF43A047), 5),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quick Access',
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.2,
            children: _cards
                .map((c) => _QuickNavTile(card: c))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _QuickNavTile extends StatelessWidget {
  final _QuickCard card;
  const _QuickNavTile({required this.card});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final home =
            context.findAncestorStateOfType<_HomeScreenState>();
        home?._onTap(card.navIndex);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: card.color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: card.color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(card.icon, color: card.color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(card.title,
                      style: TextStyle(
                          color: card.color,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                  Text(card.subtitle,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 9)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickCard {
  final String   title;
  final IconData icon;
  final String   subtitle;
  final Color    color;
  final int      navIndex;
  const _QuickCard(
      this.title, this.icon, this.subtitle, this.color, this.navIndex);
}

// ── Premium Nav Bar ────────────────────────────────────────────────────────────
class _PremiumNavBar extends StatelessWidget {
  final int               currentIndex;
  final List<_NavEntry>   destinations;
  final Animation<double> glowAnim;
  final ValueChanged<int> onTap;
  final int               alertCount;

  const _PremiumNavBar({
    required this.currentIndex,
    required this.destinations,
    required this.glowAnim,
    required this.onTap,
    required this.alertCount,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 62 + bottomPad,
          decoration: BoxDecoration(
            color: AppPalette.abyss0.withValues(alpha: 0.85),
            border: const Border(
                top: BorderSide(color: Color(0x2200C6FF), width: 1)),
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomPad),
            child: Row(
              children: List.generate(destinations.length, (i) {
                final isActive = i == currentIndex;
                final showBadge = i == 2 && alertCount > 0;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: AnimatedBuilder(
                      animation: glowAnim,
                      builder: (_, __) => Stack(
                        alignment: Alignment.topCenter,
                        children: [
                          _NavItem(
                            entry:     destinations[i],
                            isActive:  isActive,
                            glowValue: isActive ? glowAnim.value : 0.0,
                          ),
                          if (showBadge)
                            Positioned(
                              top: 6, right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$alertCount',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final _NavEntry entry;
  final bool      isActive;
  final double    glowValue;
  const _NavItem({
    required this.entry,
    required this.isActive,
    required this.glowValue,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppPalette.cyan : AppPalette.textDim;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: isActive ? 44 : 36, height: isActive ? 30 : 26,
          decoration: isActive
              ? BoxDecoration(
                  color: AppPalette.cyan.withValues(alpha: 0.10 * glowValue),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppPalette.cyan.withValues(alpha: 0.25 * glowValue),
                      blurRadius: 12,
                    ),
                  ],
                )
              : null,
          child: Icon(
            isActive ? entry.activeIcon : entry.icon,
            size: isActive ? 22 : 20, color: color,
          ),
        ),
        const SizedBox(height: 3),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontSize:   isActive ? 10.0 : 9.5,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
            color:      color,
            letterSpacing: 0.2,
          ),
          child: Text(entry.label),
        ),
      ],
    );
  }
}

class _NavEntry {
  const _NavEntry({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
  final String   label;
  final IconData icon;
  final IconData activeIcon;
}
