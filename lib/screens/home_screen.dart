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

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  final RealTimeService _svc = RealTimeService();
  int _currentIndex = 0;

  static const _destinations = [
    _NavEntry(label: 'Monitor',  icon: Icons.dashboard_outlined,      selectedIcon: Icons.dashboard),
    _NavEntry(label: 'Alerts',   icon: Icons.notifications_outlined,  selectedIcon: Icons.notifications),
    _NavEntry(label: 'Weather',  icon: Icons.cloud_outlined,          selectedIcon: Icons.cloud),
    _NavEntry(label: 'Predict',  icon: Icons.model_training_outlined, selectedIcon: Icons.model_training),
    _NavEntry(label: 'Rivers',   icon: Icons.water_outlined,          selectedIcon: Icons.water),
    _NavEntry(label: 'India',    icon: Icons.map_outlined,            selectedIcon: Icons.map),
  ];

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
        duration: const Duration(milliseconds: 280),
        lowerBound: 1.0,
        upperBound: 1.25,
      ),
    );
    _iconScale = _iconCtrl
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeOutBack))
        .toList();
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
      case 1: return const AlertsScreen();
      case 2: return const WeatherScreen();
      case 3: return const PredictScreen();
      case 4: return const RiverMonitorScreen();
      case 5: return const IndiaRiverExplorerScreen();
      default: return const DashboardScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
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
        destinations: _destinations,
        currentIndex: _currentIndex,
        iconScales:   _iconScale,
        onTap:        _onTap,
      ),
    );
  }
}

// ── Ferrari Nav Bar ───────────────────────────────────────────────────────────
class _FerrariNavBar extends StatelessWidget {
  final List<_NavEntry>         destinations;
  final int                     currentIndex;
  final List<Animation<double>> iconScales;
  final ValueChanged<int>       onTap;

  const _FerrariNavBar({
    required this.destinations,
    required this.currentIndex,
    required this.iconScales,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rc     = RiverColors.of(context);
    final bottom = MediaQuery.of(context).padding.bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 62 + bottom,
          padding: EdgeInsets.only(bottom: bottom),
          decoration: BoxDecoration(
            color: rc.navBg,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            border: const Border(
              top: BorderSide(color: Color(0x44DC0000), width: 1),
            ),
            // Red glow strip along top edge
            boxShadow: const [
              BoxShadow(
                color:       Color(0x33DC0000),
                blurRadius:  16,
                spreadRadius: 0,
                offset:      Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: List.generate(destinations.length, (i) {
              final selected = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  onTap:     () => onTap(i),
                  behavior:  HitTestBehavior.opaque,
                  child: _NavItem(
                    entry:      destinations[i],
                    selected:   selected,
                    scaleAnim:  iconScales[i],
                    rc:         rc,
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
  final RiverColors        rc;

  const _NavItem({
    required this.entry,
    required this.selected,
    required this.scaleAnim,
    required this.rc,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scaleAnim,
      builder: (_, __) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize:      MainAxisSize.min,
          children: [
            // Icon
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve:    Curves.easeInOut,
              width:  40,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? AppPalette.ferrari.withOpacity(0.18)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                // selected indicator glow
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color:      AppPalette.ferrari.withOpacity(0.25),
                          blurRadius: 10,
                          spreadRadius: 0,
                        )
                      ]
                    : null,
              ),
              child: Transform.scale(
                scale: scaleAnim.value,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    selected ? entry.selectedIcon : entry.icon,
                    key:   ValueKey(selected),
                    color: selected ? rc.navActive : rc.navInactive,
                    size:  22,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            // Label — FittedBox prevents overflow
            SizedBox(
              width: 52,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    color:      selected ? rc.navActive : rc.navInactive,
                    fontSize:   10,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    letterSpacing: selected ? 0.2 : 0,
                    height:     1.0,
                  ),
                  child: Text(
                    entry.label,
                    maxLines:  1,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            // Active red dot
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              margin: const EdgeInsets.only(top: 3),
              width:  selected ? 16 : 0,
              height: 2,
              decoration: BoxDecoration(
                color: selected ? AppPalette.ferrari : Colors.transparent,
                borderRadius: BorderRadius.circular(1),
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
