// lib/screens/home_screen.dart
// Bihar Flood Command — Home (Tab Shell) v5
// CHANGE: Added Map tab (index 3); Settings pushed to index 6.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_provider.dart';
import '../theme/rx.dart';
import '../widgets/premium_theme_sheet.dart';
import 'alerts_screen.dart';
import 'dashboard_screen.dart';
import 'map_screen.dart';
import 'monitors_screen.dart';
import 'river_monitor_screen.dart';
import 'settings_screen.dart';
import 'weather_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  static const String route = '/home';
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _idx = 0;

  // ── Tab bodies ────────────────────────────────────────────────────────────
  static const _tabs = [
    DashboardScreen(),
    MonitorsScreen(),
    AlertsScreen(),
    MapScreen(),          // ← MAP tab restored
    WeatherScreen(),
    RiverMonitorScreen(),
    SettingsScreen(),
  ];

  // ── Bottom nav destinations ───────────────────────────────────────────────
  static const _navItems = [
    NavigationDestination(
      icon:         Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard_rounded),
      label: 'Dashboard',
    ),
    NavigationDestination(
      icon:         Icon(Icons.sensors_outlined),
      selectedIcon: Icon(Icons.sensors_rounded),
      label: 'Monitors',
    ),
    NavigationDestination(
      icon:         Icon(Icons.notifications_outlined),
      selectedIcon: Icon(Icons.notifications_rounded),
      label: 'Alerts',
    ),
    NavigationDestination(
      icon:         Icon(Icons.map_outlined),
      selectedIcon: Icon(Icons.map_rounded),
      label: 'Map',
    ),
    NavigationDestination(
      icon:         Icon(Icons.wb_sunny_outlined),
      selectedIcon: Icon(Icons.wb_sunny_rounded),
      label: 'Weather',
    ),
    NavigationDestination(
      icon:         Icon(Icons.water_outlined),
      selectedIcon: Icon(Icons.water_rounded),
      label: 'Rivers',
    ),
    NavigationDestination(
      icon:         Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings_rounded),
      label: 'Settings',
    ),
  ];

  void _onThemeTap() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Consumer(
        builder: (ctx, ref, _) => PremiumThemeSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch theme so the nav bar colour rebuilds on theme switch.
    ref.watch(themeModeProvider);
    final rc = context.rc;

    return Scaffold(
      backgroundColor: rc.scaffoldBg,
      body: IndexedStack(
        index: _idx,
        children: _tabs,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) {
          HapticFeedback.selectionClick();
          setState(() => _idx = i);
        },
        destinations: _navItems,
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: _onThemeTap,
        tooltip: 'Change theme',
        backgroundColor: rc.accent,
        child: const Icon(Icons.palette_rounded, size: 18),
      ),
    );
  }
}
