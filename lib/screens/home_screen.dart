// lib/screens/home_screen.dart
// EQUINOX-BH — HomeScreen v9
// Phase 6 upgrades over v8:
//  - Alerts tab shows live red badge from criticalCountProvider
//  - Offline dot on nav bar (isOfflineProvider)
//  - Nav items grouped: primary 5 (visible) + secondary tray (overflow sheet)
//  - PageView with keepAlive so tabs don't rebuild on switch
//  - Entry FadeTransition per tab swap
//  - Bottom safe-area handles gesture nav bar properly
library;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/flood_providers.dart';
import '../theme/river_theme.dart';
import 'alerts_screen.dart';
import 'dashboard_screen.dart';
import 'live_stations_screen.dart';
import 'monitors_screen.dart';
import 'predict_screen.dart';
import 'river_monitor_screen.dart';
import 'settings_screen.dart';
import 'weather_screen.dart';

// ── tab descriptors ───────────────────────────────────────────────────────────

class _Tab {
  const _Tab(this.label, this.icon, this.activeIcon, {this.badgeProvider});
  final String   label;
  final IconData icon, activeIcon;
  // Optional: provider index into [_badgeValues] resolved at build time
  final int?     badgeProvider;
}

// Primary nav (always visible) — 5 items
const _primary = [
  _Tab('Home',     Icons.dashboard_outlined,     Icons.dashboard_rounded),
  _Tab('Rivers',   Icons.water_outlined,          Icons.water_rounded),
  _Tab('Alerts',   Icons.notifications_outlined,  Icons.notifications_rounded,
       badgeProvider: 0),
  _Tab('Weather',  Icons.cloud_outlined,           Icons.cloud_rounded),
  _Tab('Predict',  Icons.model_training_outlined,  Icons.model_training_rounded),
];

// Secondary nav (tray / «More» sheet) — overflow items
const _secondary = [
  _Tab('Stations', Icons.sensors_outlined,         Icons.sensors_rounded),
  _Tab('Monitor',  Icons.monitor_heart_outlined,   Icons.monitor_heart_rounded),
  _Tab('Settings', Icons.settings_outlined,        Icons.settings_rounded),
];

// All screens in index order (primary 0-4, secondary 5-7)
Widget _buildScreen(int i) => switch (i) {
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

// ── screen ────────────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _idx = 0;

  // glow pulse for active tab icon
  late final AnimationController _glowCtrl;
  late final Animation<double>    _glow;

  // keep screens alive
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = List.generate(8, _buildScreen);
    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    // kick providers warm
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
    final offline  = ref.read(isOfflineProvider);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MoreSheet(
        current:   _idx,
        offline:   offline,
        onSelect:  (i) {
          Navigator.pop(context);
          _go(i);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final criticalCount = ref.watch(criticalCountProvider);
    final offline       = ref.watch(isOfflineProvider);

    // badge values indexed by _Tab.badgeProvider
    final badgeValues = [criticalCount];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light
          .copyWith(systemNavigationBarColor: AppPalette.abyss0),
      child: Scaffold(
        backgroundColor: AppPalette.abyss0,
        // IndexedStack keeps all screens mounted & alive
        body: IndexedStack(
          index: _idx,
          children: _screens,
        ),
        bottomNavigationBar: _NavBar(
          current:     _idx,
          primary:     _primary,
          glow:        _glow,
          badgeValues: badgeValues,
          offline:     offline,
          onTap:       _go,
          onMore:      _showMoreSheet,
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
    required this.badgeValues,
    required this.offline,
    required this.onTap,
    required this.onMore,
  });

  final int                  current;
  final List<_Tab>           primary;
  final Animation<double>    glow;
  final List<int>            badgeValues;
  final bool                 offline;
  final ValueChanged<int>    onTap;
  final VoidCallback         onMore;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding.bottom;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          height: 62 + pad,
          decoration: BoxDecoration(
            color: const Color(0xD0010810),
            border: const Border(
                top: BorderSide(color: Color(0x1800C6FF), width: 1)),
            boxShadow: [
              BoxShadow(
                  color: AppPalette.cyan.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, -4)),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: pad),
            child: Row(
              children: [
                // Primary tabs
                ...List.generate(primary.length, (i) {
                  final active = i == current;
                  final badge  = primary[i].badgeProvider != null
                      ? badgeValues[primary[i].badgeProvider!]
                      : 0;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap(i),
                      child: AnimatedBuilder(
                        animation: glow,
                        builder: (_, __) => _NavItem(
                          tab:      primary[i],
                          active:   active,
                          glowVal:  active ? glow.value : 0,
                          badge:    badge,
                        ),
                      ),
                    ),
                  );
                }),

                // «More» button
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
  const _NavItem({
    required this.tab,
    required this.active,
    required this.glowVal,
    this.badge = 0,
  });

  final _Tab   tab;
  final bool   active;
  final double glowVal;
  final int    badge;

  @override
  Widget build(BuildContext context) {
    final c = active ? AppPalette.cyan : const Color(0xFF2E3E55);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 36, height: 26,
              decoration: active
                  ? BoxDecoration(
                      color: AppPalette.cyan
                          .withValues(alpha: 0.10 * glowVal),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppPalette.cyan
                              .withValues(alpha: 0.22 * glowVal),
                          blurRadius: 16,
                        ),
                      ],
                    )
                  : null,
              child: Icon(
                active ? tab.activeIcon : tab.icon,
                size:  active ? 18 : 16,
                color: c,
              ),
            ),
            // badge
            if (badge > 0)
              Positioned(
                top: -4, right: -4,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 14),
                  height: 14,
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: AppPalette.critical,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                        color: AppPalette.abyss0, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      badge > 9 ? '9+' : '$badge',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 7.5,
                          fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 3),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          style: TextStyle(
            fontSize:   active ? 8.5 : 8,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            color: c,
            letterSpacing: 0.2,
          ),
          child: Text(tab.label),
        ),
      ],
    );
  }
}

// ── More button ───────────────────────────────────────────────────────────────

class _MoreButton extends StatelessWidget {
  final bool active, offline;
  const _MoreButton({required this.active, required this.offline});

  @override
  Widget build(BuildContext context) {
    final c = active ? AppPalette.cyan : const Color(0xFF2E3E55);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 36, height: 26,
              decoration: active
                  ? BoxDecoration(
                      color: AppPalette.cyan.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    )
                  : null,
              child: Icon(
                active
                    ? Icons.grid_view_rounded
                    : Icons.grid_view_outlined,
                size: 16, color: c,
              ),
            ),
            // offline dot
            if (offline)
              Positioned(
                top: -3, right: -3,
                child: Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppPalette.amber,
                    border: Border.all(
                        color: AppPalette.abyss0, width: 1.2),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 3),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          style: TextStyle(
            fontSize:   active ? 8.5 : 8,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            color: c,
            letterSpacing: 0.2,
          ),
          child: Text(offline ? 'Offline' : 'More'),
        ),
      ],
    );
  }
}

// ── More bottom sheet ─────────────────────────────────────────────────────────

class _MoreSheet extends StatelessWidget {
  final int                       current;
  final bool                      offline;
  final ValueChanged<int>         onSelect;
  const _MoreSheet({
    required this.current,
    required this.offline,
    required this.onSelect,
  });

  // secondary items map to global screen index starting at 5
  static const _items = [
    (idx: 5, label: 'Stations', icon: Icons.sensors_rounded,       sub: 'Live gauge stations'),
    (idx: 6, label: 'Monitor',  icon: Icons.monitor_heart_rounded,  sub: 'Multi-location watch'),
    (idx: 7, label: 'Settings', icon: Icons.settings_rounded,       sub: 'App preferences'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF060F1C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
            top: BorderSide(
                color: Color(0x2200C6FF), width: 1.5)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // handle
              Container(
                width: 36, height: 3,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: AppPalette.abyssStroke,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              if (offline)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppPalette.amber.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppPalette.amber.withValues(alpha: 0.28)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.wifi_off_rounded,
                          color: AppPalette.amber, size: 14),
                      SizedBox(width: 8),
                      Text(
                        'Offline — showing cached data',
                        style: TextStyle(
                            color: AppPalette.amber, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              for (final item in _items)
                _SheetRow(
                  label:    item.label,
                  icon:     item.icon,
                  sub:      item.sub,
                  active:   current == item.idx,
                  onTap:    () => onSelect(item.idx),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  final String   label, sub;
  final IconData icon;
  final bool     active;
  final VoidCallback onTap;
  const _SheetRow({
    required this.label, required this.icon,
    required this.sub,   required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = active ? AppPalette.cyan : AppPalette.textWhite;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: active
              ? AppPalette.cyan.withValues(alpha: 0.08)
              : AppPalette.abyss2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active
                ? AppPalette.cyan.withValues(alpha: 0.35)
                : AppPalette.abyssStroke,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: c, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: c,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                  Text(sub,
                      style: const TextStyle(
                          color: AppPalette.textDim,
                          fontSize: 10)),
                ],
              ),
            ),
            if (active)
              Container(
                width: 6, height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppPalette.cyan,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
