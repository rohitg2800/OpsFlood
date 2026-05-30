// lib/screens/home_screen.dart
// OpsFlood — HomeScreen v6  (Minimal frosted nav — premium rebuild)
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final RealTimeService _svc = RealTimeService();
  int _idx = 0;

  late AnimationController _glowCtrl;
  late Animation<double> _glow;

  static const _tabs = [
    _Tab('Dashboard', Icons.dashboard_outlined,     Icons.dashboard_rounded),
    _Tab('Rivers',    Icons.water_outlined,          Icons.water_rounded),
    _Tab('Alerts',    Icons.notifications_outlined,  Icons.notifications_rounded),
    _Tab('Weather',   Icons.cloud_outlined,          Icons.cloud_rounded),
    _Tab('Predict',   Icons.model_training_outlined, Icons.model_training_rounded),
    _Tab('Monitor',   Icons.monitor_heart_outlined,  Icons.monitor_heart_rounded),
  ];

  Widget _screen(int i) => switch (i) {
    0 => const DashboardScreen(),
    1 => const RiverMonitorScreen(),
    2 => const AlertsScreen(),
    3 => const WeatherScreen(),
    4 => const PredictScreen(),
    5 => const MonitorsScreen(),
    _ => const DashboardScreen(),
  };

  @override
  void initState() {
    super.initState();
    Future.microtask(_svc.startPolling);
    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _svc.stopPolling();
    _glowCtrl.dispose();
    super.dispose();
  }

  void _go(int i) {
    if (i == _idx) return;
    HapticFeedback.selectionClick();
    setState(() => _idx = i);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light
          .copyWith(systemNavigationBarColor: AppPalette.abyss0),
      child: Scaffold(
        backgroundColor: AppPalette.abyss0,
        body: _screen(_idx),
        bottomNavigationBar: _NavBar(
          current: _idx, tabs: _tabs, glow: _glow, onTap: _go,
        ),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.current, required this.tabs,
    required this.glow,   required this.onTap,
  });
  final int current;
  final List<_Tab> tabs;
  final Animation<double> glow;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding.bottom;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: 58 + pad,
          decoration: const BoxDecoration(
            color: Color(0xCC010810),
            border: Border(top: BorderSide(color: Color(0x1800C6FF), width: 1)),
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: pad),
            child: Row(
              children: List.generate(tabs.length, (i) {
                final active = i == current;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: AnimatedBuilder(
                      animation: glow,
                      builder: (_, __) => _NavItem(
                        tab: tabs[i], active: active,
                        glowVal: active ? glow.value : 0,
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
  const _NavItem({required this.tab, required this.active, required this.glowVal});
  final _Tab tab;
  final bool active;
  final double glowVal;

  @override
  Widget build(BuildContext context) {
    final c = active ? AppPalette.cyan : const Color(0xFF2E3E55);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 40, height: 28,
          decoration: active
              ? BoxDecoration(
                  color: AppPalette.cyan.withValues(alpha: 0.08 * glowVal),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppPalette.cyan.withValues(alpha: 0.20 * glowVal),
                      blurRadius: 14,
                    ),
                  ],
                )
              : null,
          child: Icon(active ? tab.activeIcon : tab.icon,
              size: active ? 20 : 18, color: c),
        ),
        const SizedBox(height: 2),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          style: TextStyle(
            fontSize: active ? 9.5 : 9,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            color: c, letterSpacing: 0.3,
          ),
          child: Text(tab.label),
        ),
      ],
    );
  }
}

class _Tab {
  const _Tab(this.label, this.icon, this.activeIcon);
  final String label;
  final IconData icon, activeIcon;
}
