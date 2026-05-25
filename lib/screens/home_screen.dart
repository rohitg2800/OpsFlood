// lib/screens/home_screen.dart
// OpsFlood — HomeScreen v5 (Premium Abyss Ops nav bar)
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
  int _currentIndex = 0;

  static const _destinations = [
    _NavEntry(label: 'Dashboard', icon: Icons.dashboard_outlined,      selectedIcon: Icons.dashboard_rounded),
    _NavEntry(label: 'Monitors',  icon: Icons.monitor_heart_outlined,  selectedIcon: Icons.monitor_heart_rounded),
    _NavEntry(label: 'Alerts',    icon: Icons.notifications_outlined,  selectedIcon: Icons.notifications_rounded),
    _NavEntry(label: 'Weather',   icon: Icons.cloud_outlined,          selectedIcon: Icons.cloud_rounded),
    _NavEntry(label: 'Predict',   icon: Icons.model_training_outlined, selectedIcon: Icons.model_training),
    _NavEntry(label: 'Rivers',    icon: Icons.water_outlined,          selectedIcon: Icons.water_rounded),
  ];

  Widget _buildScreen(int index) {
    switch (index) {
      case 0: return const DashboardScreen();
      case 1: return const MonitorsScreen();
      case 2: return const AlertsScreen();
      case 3: return const WeatherScreen();
      case 4: return const PredictScreen();
      case 5: return const RiverMonitorScreen();
      default: return const DashboardScreen();
    }
  }

  @override
  void initState() {
    super.initState();
    _svc.startPolling();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppPalette.abyss0,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  }

  @override
  void dispose() {
    _svc.stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.abyss0,
      body: _buildScreen(_currentIndex),
      bottomNavigationBar: _PremiumNavBar(
        currentIndex: _currentIndex,
        destinations: _destinations,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

// ── Premium frosted-glass nav bar ─────────────────────────────────────────────
class _PremiumNavBar extends StatelessWidget {
  final int currentIndex;
  final List<_NavEntry> destinations;
  final ValueChanged<int> onDestinationSelected;

  const _PremiumNavBar({
    required this.currentIndex,
    required this.destinations,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: AppPalette.abyss0.withValues(alpha: 0.88),
            border: Border(
              top: BorderSide(
                color: AppPalette.cyan.withValues(alpha: 0.10),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 66,
              child: Row(
                children: List.generate(destinations.length, (i) {
                  final d       = destinations[i];
                  final active  = i == currentIndex;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onDestinationSelected(i);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              width: active ? 42 : 32,
                              height: active ? 30 : 26,
                              decoration: active
                                  ? BoxDecoration(
                                      color: AppPalette.cyanGlow,
                                      borderRadius: BorderRadius.circular(12),
                                    )
                                  : null,
                              child: Icon(
                                active ? d.selectedIcon : d.icon,
                                size: active ? 21 : 19,
                                color: active
                                    ? AppPalette.cyan
                                    : AppPalette.textGrey.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 3),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 220),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: active
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: active
                                    ? AppPalette.cyan
                                    : AppPalette.textGrey.withValues(alpha: 0.55),
                                letterSpacing: active ? 0.3 : 0.0,
                              ),
                              child: Text(d.label),
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
