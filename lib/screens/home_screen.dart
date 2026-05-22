import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/real_time_service.dart';
import '../screens/india_river_explorer_screen.dart';
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

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final RealTimeService _svc = RealTimeService();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _svc.startPolling();
  }

  @override
  void dispose() {
    _svc.stopPolling();
    super.dispose();
  }

  void _onTap(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
  }

  Widget _buildScreen(int index) {
    switch (index) {
      case 0:  return const DashboardScreen();
      case 1:  return const MonitorsScreen();
      case 2:  return const AlertsScreen();
      case 3:  return const WeatherScreen();
      case 4:  return const PredictScreen();
      case 5:  return const RiverMonitorScreen();
      case 6:  return const IndiaRiverExplorerScreen();
      default: return const DashboardScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeInOut),
          child: child,
        ),
        child: KeyedSubtree(
          key: ValueKey(_currentIndex),
          child: _buildScreen(_currentIndex),
        ),
      ),
      bottomNavigationBar: _FerrariNavBar(
        currentIndex: _currentIndex,
        onTap: _onTap,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Ferrari Nav Bar  — uses NavigationBar (M3) so layout is always safe
// ─────────────────────────────────────────────────────────────────────────────
class _FerrariNavBar extends StatelessWidget {
  final int             currentIndex;
  final ValueChanged<int> onTap;

  const _FerrariNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = [
    NavigationDestination(
      icon:         Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: 'Monitor',
    ),
    NavigationDestination(
      icon:         Icon(Icons.monitor_heart_outlined),
      selectedIcon: Icon(Icons.monitor_heart),
      label: 'Monitors',
    ),
    NavigationDestination(
      icon:         Icon(Icons.notifications_outlined),
      selectedIcon: Icon(Icons.notifications),
      label: 'Alerts',
    ),
    NavigationDestination(
      icon:         Icon(Icons.cloud_outlined),
      selectedIcon: Icon(Icons.cloud),
      label: 'Weather',
    ),
    NavigationDestination(
      icon:         Icon(Icons.model_training_outlined),
      selectedIcon: Icon(Icons.model_training),
      label: 'Predict',
    ),
    NavigationDestination(
      icon:         Icon(Icons.water_outlined),
      selectedIcon: Icon(Icons.water),
      label: 'Rivers',
    ),
    NavigationDestination(
      icon:         Icon(Icons.map_outlined),
      selectedIcon: Icon(Icons.map),
      label: 'India',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: NavigationBar(
          selectedIndex:    currentIndex,
          onDestinationSelected: onTap,
          animationDuration: const Duration(milliseconds: 300),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          height: 64,
          // Ferrari palette
          backgroundColor:        const Color(0xF0100808),
          shadowColor:            AppPalette.ferrari,
          surfaceTintColor:       Colors.transparent,
          indicatorColor:         AppPalette.ferrari.withOpacity(0.22),
          indicatorShape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          overlayColor: WidgetStateProperty.all(
            AppPalette.ferrari.withOpacity(0.08),
          ),
          destinations: _items,
        ),
      ),
    );
  }
}
