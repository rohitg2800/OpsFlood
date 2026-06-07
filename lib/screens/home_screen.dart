// lib/screens/home_screen.dart
// OpsFlood — HomeScreen v8  (Settings tab + locale-aware labels)
library;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/flood_providers.dart';
import '../theme/river_theme.dart';
import 'dashboard_screen.dart';
import 'live_stations_screen.dart';
import 'monitors_screen.dart';
import 'predict_screen.dart';
import 'river_monitor_screen.dart';
import 'settings_screen.dart';
import 'weather_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _idx = 0;

  late AnimationController _glowCtrl;
  late Animation<double> _glow;

  // Labels are hardcoded English here; for full i18n swap with AppLocalizations
  static const _tabs = [
    _Tab('Dashboard', Icons.dashboard_outlined,      Icons.dashboard_rounded),
    _Tab('Rivers',    Icons.water_outlined,           Icons.water_rounded),
    _Tab('Alerts',    Icons.notifications_outlined,   Icons.notifications_rounded),
    _Tab('Weather',   Icons.cloud_outlined,           Icons.cloud_rounded),
    _Tab('Predict',   Icons.model_training_outlined,  Icons.model_training_rounded),
    _Tab('Stations',  Icons.sensors_outlined,         Icons.sensors_rounded),
    _Tab('Monitor',   Icons.monitor_heart_outlined,   Icons.monitor_heart_rounded),
    _Tab('Settings',  Icons.settings_outlined,        Icons.settings_rounded),
  ];

  Widget _screen(int i) => switch (i) {
    0 => const DashboardScreen(),
    1 => const RiverMonitorScreen(),
    2 => const AlertsScreen(),
    3 => const WeatherScreen(),
    4 => const PredictScreen(),
    5 => const LiveStationsScreen(),
    6 => const MonitorsScreen(),
    7 => const SettingsScreen(),
    _ => const DashboardScreen(),
  };

  @override
  void initState() {
    super.initState();
    _screens = List.generate(6, _buildScreen);
    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(realTimeProvider);
    });
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  void _go(int i) {
    if (i == _idx) return;
    HapticFeedback.selectionClick();
    setState(() => _idx = i);
  }

  void _showMoreSheet() {
    final offline = ref.read(isOfflineProvider);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MoreSheet(
        current:  _idx,
        offline:  offline,
        onSelect: (i) {
          Navigator.pop(context);
          _go(i);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t       = RiverColors.of(context);
    final offline = ref.watch(isOfflineProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light
          .copyWith(systemNavigationBarColor: t.navBg),
      child: Scaffold(
        backgroundColor: t.scaffoldBg,
        body: IndexedStack(
          index: _idx,
          children: _screens,
        ),
        bottomNavigationBar: _NavBar(
          current: _idx,
          primary: _primary,
          glow:    _glow,
          offline: offline,
          onTap:   _go,
          onMore:  _showMoreSheet,
        ),
      ),
    );
  }
}

// ── nav bar ───────────────────────────────────────────────────────────────────

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.current,
    required this.primary,
    required this.glow,
    required this.offline,
    required this.onTap,
    required this.onMore,
  });

  final int                current;
  final List<_Tab>         primary;
  final Animation<double>  glow;
  final bool               offline;
  final ValueChanged<int>  onTap;
  final VoidCallback       onMore;

  @override
  Widget build(BuildContext context) {
    final t   = RiverColors.of(context);
    final pad = MediaQuery.of(context).padding.bottom;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          height: 62 + pad,
          decoration: BoxDecoration(
            color: t.navBg.withValues(alpha: 0.85),
            border: Border(
                top: BorderSide(color: t.stroke.withValues(alpha: 0.18), width: 1)),
            boxShadow: [
              BoxShadow(
                color: t.accent.withValues(alpha: 0.04),
                blurRadius: 20,
                offset: const Offset(0, -4)),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: pad),
            child: Row(
              children: [
                ...List.generate(primary.length, (i) {
                  final active = i == current;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap(i),
                      child: AnimatedBuilder(
                        animation: glow,
                        builder: (_, __) => _NavItem(
                          tab:     primary[i],
                          active:  active,
                          glowVal: active ? glow.value : 0,
                        ),
                      ),
                    ),
                  );
                }),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onMore,
                    child: _MoreButton(
                      active:  current >= primary.length,
                      offline: offline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── nav item ──────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  const _NavItem({required this.tab, required this.active, required this.glowVal});
  final _Tab   tab;
  final bool   active;
  final double glowVal;

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    final c = active ? t.navActive : t.navInactive;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 36, height: 26,
          decoration: active
              ? BoxDecoration(
                  color: t.navActive.withValues(alpha: 0.10 * glowVal),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: t.navActive.withValues(alpha: 0.22 * glowVal),
                      blurRadius: 16,
                    ),
                  ],
                )
              : null,
          child: Icon(active ? tab.activeIcon : tab.icon,
              size: active ? 18 : 16, color: c),
        ),
        const SizedBox(height: 3),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          style: TextStyle(
            fontSize:   active ? 8.5 : 8,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            color: c, letterSpacing: 0.2,
          ),
          child: Text(tab.label),
        ),
      ],
    );
  }
}

class _Tab {
  const _Tab(this.label, this.icon, this.activeIcon);
  final String   label;
  final IconData icon, activeIcon;
}
