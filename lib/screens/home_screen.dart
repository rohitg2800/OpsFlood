import 'package:flutter/material.dart';

import '../services/real_time_service.dart';
import 'alerts_screen.dart';
import 'dashboard_screen.dart';
import 'india_river_explorer_screen.dart';
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
  final RealTimeService _realTimeService = RealTimeService();
  int _currentIndex = 0;

  // 7 screens: Dashboard, Monitors, Alerts, Weather, Predict, Rivers (CWC), India Explorer
  static const List<Widget> _screens = [
    DashboardScreen(),
    MonitorsScreen(),
    AlertsScreen(),
    WeatherScreen(),
    PredictScreen(),
    RiverMonitorScreen(),
    IndiaRiverExplorerScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _realTimeService.startPolling();
  }

  @override
  void dispose() {
    _realTimeService.stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) =>
            setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            selectedIcon: Icon(Icons.monitor_heart),
            label: 'Monitors',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.cloud_outlined),
            selectedIcon: Icon(Icons.cloud),
            label: 'Weather',
          ),
          NavigationDestination(
            icon: Icon(Icons.model_training_outlined),
            selectedIcon: Icon(Icons.model_training),
            label: 'Predict',
          ),
          NavigationDestination(
            icon: Icon(Icons.water_outlined),
            selectedIcon: Icon(Icons.water),
            label: 'Rivers',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'India',
          ),
        ],
      ),
    );
  }
}
