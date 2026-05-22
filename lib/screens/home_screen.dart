import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/flood_providers.dart';
import 'alerts_screen.dart';
import 'dashboard_screen.dart';
import 'monitors_screen.dart';
import 'predict_screen.dart';
import 'river_monitor_screen.dart';
import 'weather_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  static const _destinations = [
    _NavEntry(label: 'Home',     icon: Icons.dashboard_outlined,      selectedIcon: Icons.dashboard),
    _NavEntry(label: 'Monitors', icon: Icons.monitor_heart_outlined,  selectedIcon: Icons.monitor_heart),
    _NavEntry(label: 'Alerts',   icon: Icons.notifications_outlined,  selectedIcon: Icons.notifications),
    _NavEntry(label: 'Weather',  icon: Icons.cloud_outlined,          selectedIcon: Icons.cloud),
    _NavEntry(label: 'Predict',  icon: Icons.model_training_outlined, selectedIcon: Icons.model_training),
    _NavEntry(label: 'Rivers',   icon: Icons.water_outlined,          selectedIcon: Icons.water),
  ];

  Widget _buildScreen(int index) {
    switch (index) {
      case 0:  return const DashboardScreen();
      case 1:  return const MonitorsScreen();
      case 2:  return const AlertsScreen();
      case 3:  return const WeatherScreen();
      case 4:  return const PredictScreen();
      case 5:  return const RiverMonitorScreen();
      default: return const DashboardScreen();
    }
  }

  @override
  void initState() {
    super.initState();
    ref.read(realTimeProvider).startPolling();
  }

  @override
  void dispose() {
    ref.read(realTimeProvider).stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildScreen(_currentIndex),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: _destinations
            .map((d) => NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: d.label,
                ))
            .toList(),
      ),
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
