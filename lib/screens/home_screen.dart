// lib/screens/home_screen.dart
// OpsFlood — HomeScreen v5  (Abyss Ops Premium Nav)
// Custom frosted-glass bottom nav with animated glow indicator.
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
  int _currentIndex = 0;

  // Glow animation for selected tab
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

  Widget _buildScreen(int index) {
    switch (index) {
      case 0: return const DashboardScreen();
      case 1: return const RiverMonitorScreen();
      case 2: return const AlertsScreen();
      case 3: return const WeatherScreen();
      case 4: return const PredictScreen();
      case 5: return const MonitorsScreen();
      default: return const DashboardScreen();
    }
  }

  @override
  void initState() {
    super.initState();

    // IMPORTANT: Do NOT call _svc.startPolling() synchronously here.
    // startPolling() → refreshData() → notifyListeners() fires immediately,
    // which mutates a Riverpod ChangeNotifierProvider while the widget tree
    // is still being built — Riverpod throws:
    //   "Modifying a provider inside didChangeDependencies / initState is not allowed"
    //
    // Fix: defer to a microtask so the current build frame completes first.
    // The polling starts on the very next microtask — effectively instant,
    // but safely outside the build phase.
    Future.microtask(_svc.startPolling);

    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _svc.stopPolling();
    _glowCtrl.dispose();
    super.dispose();
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
        systemNavigationBarColor: AppPalette.abyss0,
      ),
      child: Scaffold(
        backgroundColor: AppPalette.abyss0,
        body: _buildScreen(_currentIndex),
        bottomNavigationBar: _PremiumNavBar(
          currentIndex: _currentIndex,
          destinations: _destinations,
          glowAnim:     _glowAnim,
          onTap:        _onTap,
        ),
      ),
    );
  }
}

// ── Premium frosted glass nav bar ─────────────────────────────────────────────────
class _PremiumNavBar extends StatelessWidget {
  final int                  currentIndex;
  final List<_NavEntry>      destinations;
  final Animation<double>    glowAnim;
  final ValueChanged<int>    onTap;

  const _PremiumNavBar({
    required this.currentIndex,
    required this.destinations,
    required this.glowAnim,
    required this.onTap,
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
              top: BorderSide(
                color: Color(0x2200C6FF),
                width: 1,
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomPad),
            child: Row(
              children: List.generate(destinations.length, (i) {
                final isActive = i == currentIndex;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: AnimatedBuilder(
                      animation: glowAnim,
                      builder: (_, __) => _NavItem(
                        entry:     destinations[i],
                        isActive:  isActive,
                        glowValue: isActive ? glowAnim.value : 0.0,
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
          width:  isActive ? 44 : 36,
          height: isActive ? 30 : 26,
          decoration: isActive
              ? BoxDecoration(
                  color:        AppPalette.cyan.withValues(alpha: 0.10 * glowValue),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color:      AppPalette.cyan.withValues(alpha: 0.25 * glowValue),
                      blurRadius: 12,
                    ),
                  ],
                )
              : null,
          child: Icon(
            isActive ? entry.activeIcon : entry.icon,
            size:  isActive ? 22 : 20,
            color: color,
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
