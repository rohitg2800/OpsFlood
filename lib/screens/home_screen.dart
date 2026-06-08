// lib/screens/home_screen.dart
// Bihar Flood Command — Home (Tab Shell) v6
// CHANGE v6: Added SOS tab (index 3) between Alerts and Map.
//            SOS tab uses a red-badged emergency icon to signal priority.
//            Total tabs: 8 (Dashboard, Monitors, Alerts, SOS, Map, Weather, Rivers, Settings).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_provider.dart';
import '../theme/river_theme.dart'; // AppPalette.critical used by SOS badge
import '../theme/rx.dart';
import '../widgets/premium_theme_sheet.dart';
import 'alerts_screen.dart';
import 'dashboard_screen.dart';
import 'map_screen.dart';
import 'monitors_screen.dart';
import 'river_monitor_screen.dart';
import 'settings_screen.dart';
import 'sos_screen.dart';
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
    DashboardScreen(),    // 0
    MonitorsScreen(),     // 1
    AlertsScreen(),       // 2
    SosScreen(),          // 3  ← SOS (new, preferred emergency tab)
    MapScreen(),          // 4
    WeatherScreen(),      // 5
    RiverMonitorScreen(), // 6
    SettingsScreen(),     // 7
  ];

  // ── Bottom nav destinations ───────────────────────────────────────────────
  static List<Widget> _buildNavItems(Color sosColor) => [
    const NavigationDestination(
      icon:         Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard_rounded),
      label: 'Dashboard',
    ),
    const NavigationDestination(
      icon:         Icon(Icons.sensors_outlined),
      selectedIcon: Icon(Icons.sensors_rounded),
      label: 'Monitors',
    ),
    const NavigationDestination(
      icon:         Icon(Icons.notifications_outlined),
      selectedIcon: Icon(Icons.notifications_rounded),
      label: 'Alerts',
    ),
    // SOS tab — red badge dot marks emergency priority
    NavigationDestination(
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.local_hospital_outlined),
          Positioned(
            top: -2, right: -2,
            child: Container(
              width: 7, height: 7,
              decoration: BoxDecoration(
                color: sosColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
      selectedIcon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.local_hospital_rounded),
          Positioned(
            top: -2, right: -2,
            child: Container(
              width: 7, height: 7,
              decoration: BoxDecoration(
                color: sosColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
      label: 'SOS',
    ),
    const NavigationDestination(
      icon:         Icon(Icons.map_outlined),
      selectedIcon: Icon(Icons.map_rounded),
      label: 'Map',
    ),
    const NavigationDestination(
      icon:         Icon(Icons.wb_sunny_outlined),
      selectedIcon: Icon(Icons.wb_sunny_rounded),
      label: 'Weather',
    ),
    const NavigationDestination(
      icon:         Icon(Icons.water_outlined),
      selectedIcon: Icon(Icons.water_rounded),
      label: 'Rivers',
    ),
    const NavigationDestination(
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
        destinations: _buildNavItems(AppPalette.critical),
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
