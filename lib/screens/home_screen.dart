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

class _HomeScreenState extends State<HomeScreen> {
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
  void initState() {
    super.initState();
    _svc.startPolling();
  }

  @override
  void dispose() {
    _svc.stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildScreen(_currentIndex),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        // Ensure labels and icons are comfortably sized and not clipped
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        elevation: 8,
        height: 68,
        destinations: _destinations
            .map((d) => NavigationDestination(
                  icon: Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Icon(d.icon, size: 24),
                  ),
                  selectedIcon: Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Icon(d.selectedIcon, size: 24),
                  ),
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
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
