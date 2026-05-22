import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/real_time_service.dart';
import '../screens/india_river_explorer_screen.dart';
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
    with TickerProviderStateMixin {
  final RealTimeService _svc = RealTimeService();
  int _currentIndex = 0;

  static const _destinations = [
    _NavEntry(label: 'Dashboard', icon: Icons.dashboard_outlined,      selectedIcon: Icons.dashboard),
    _NavEntry(label: 'Monitors',  icon: Icons.monitor_heart_outlined,  selectedIcon: Icons.monitor_heart),
    _NavEntry(label: 'Alerts',    icon: Icons.notifications_outlined,  selectedIcon: Icons.notifications),
    _NavEntry(label: 'Weather',   icon: Icons.cloud_outlined,          selectedIcon: Icons.cloud),
    _NavEntry(label: 'Predict',   icon: Icons.model_training_outlined, selectedIcon: Icons.model_training),
    _NavEntry(label: 'Rivers',    icon: Icons.water_outlined,          selectedIcon: Icons.water),
    _NavEntry(label: 'India',     icon: Icons.map_outlined,            selectedIcon: Icons.map),
  ];

  // One AnimationController per tab for the icon pop
  late final List<AnimationController> _iconCtrl;
  late final List<Animation<double>>   _iconScale;

  @override
  void initState() {
    super.initState();
    _svc.startPolling();

    _iconCtrl = List.generate(
      _destinations.length,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 220),
        lowerBound: 1.0,
        upperBound: 1.30,
      ),
    );
    _iconScale = _iconCtrl
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeOutBack))
        .toList();

    // pre-select first tab
    _iconCtrl[0].forward();
  }

  @override
  void dispose() {
    for (final c in _iconCtrl) c.dispose();
    _svc.stopPolling();
    super.dispose();
  }

  void _onTap(int index) {
    if (index == _currentIndex) return;
    _iconCtrl[_currentIndex].reverse();
    setState(() => _currentIndex = index);
    _iconCtrl[index].forward();
  }

  Widget _buildScreen(int index) {
    switch (index) {
      case 0: return const DashboardScreen();
      case 1: return const MonitorsScreen();
      case 2: return const AlertsScreen();
      case 3: return const WeatherScreen();
      case 4: return const PredictScreen();
      case 5: return const RiverMonitorScreen();
      case 6: return const IndiaRiverExplorerScreen();
      default: return const DashboardScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,          // body draws behind the translucent nav bar
      body: _buildScreen(_currentIndex),
      bottomNavigationBar: _AnimatedNavBar(
        destinations: _destinations,
        currentIndex: _currentIndex,
        iconScales: _iconScale,
        onTap: _onTap,
      ),
    );
  }
}

// ── Animated nav bar ─────────────────────────────────────────────────────────
class _AnimatedNavBar extends StatelessWidget {
  final List<_NavEntry>             destinations;
  final int                         currentIndex;
  final List<Animation<double>>     iconScales;
  final ValueChanged<int>           onTap;

  const _AnimatedNavBar({
    required this.destinations,
    required this.currentIndex,
    required this.iconScales,
    required this.onTap,
  });

  static const _activeColor  = Color(0xFF34C759);   // OpsFlood green
  static const _inactiveColor= Color(0xFF8E9BAE);
  static const _pillColor    = Color(0x2634C759);   // 15 % green
  static const _barBg        = Color(0xE6101820);   // 90 % dark

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          // pill nav bar height + safe area inset
          height: 64 + bottom,
          padding: EdgeInsets.only(bottom: bottom, left: 6, right: 6),
          decoration: BoxDecoration(
            color: _barBg,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(22)),
            border: const Border(
              top: BorderSide(color: Color(0x2234C759), width: 1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(destinations.length, (i) {
              final selected = i == currentIndex;
              final entry    = destinations[i];
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: _NavItem(
                    entry: entry,
                    selected: selected,
                    scaleAnim: iconScales[i],
                    activeColor:   _activeColor,
                    inactiveColor: _inactiveColor,
                    pillColor:     _pillColor,
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ── Single nav item ───────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final _NavEntry          entry;
  final bool               selected;
  final Animation<double>  scaleAnim;
  final Color              activeColor;
  final Color              inactiveColor;
  final Color              pillColor;

  const _NavItem({
    required this.entry,
    required this.selected,
    required this.scaleAnim,
    required this.activeColor,
    required this.inactiveColor,
    required this.pillColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scaleAnim,
      builder: (_, __) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon inside animated pill
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              padding: selected
                  ? const EdgeInsets.symmetric(horizontal: 14, vertical: 6)
                  : const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? pillColor : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Transform.scale(
                scale: scaleAnim.value,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(scale: anim, child: child),
                  ),
                  child: Icon(
                    selected ? entry.selectedIcon : entry.icon,
                    key: ValueKey(selected),
                    color: selected ? activeColor : inactiveColor,
                    size: 22,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            // Label — always single line, never wraps
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              style: TextStyle(
                color:      selected ? activeColor : inactiveColor,
                fontSize:   selected ? 10.5 : 9.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                height: 1.0,
              ),
              child: Text(
                entry.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NavEntry {
  const _NavEntry({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
  final String   label;
  final IconData icon;
  final IconData selectedIcon;
}
