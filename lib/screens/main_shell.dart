// lib/screens/main_shell.dart
// OpsFlood — MainShell v1
//
// Persistent bottom navigation bar wrapping the 5 primary screens:
//   0  Dashboard   (home / live levels)
//   1  Map         (Bihar river map)
//   2  Alerts      (IMD + NDMA alerts)
//   3  Predict     (flood prediction)
//   4  Settings
//
// Design decisions:
//   • IndexedStack preserves scroll & provider state in every tab
//   • Custom _NavBar widget: pill indicator, RiverColors tokens,
//     haptic on every tap
//   • Shell exposes a static `jumpTo(context, index)` helper so any
//     nested screen can switch tabs programmatically (e.g. CityDetail
//     can jump to Map tab)
//   • Android back-button: if not on tab 0, go to tab 0 first;
//     only exit when already on tab 0
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/river_theme.dart';
import 'dashboard_screen.dart';
import 'bihar_river_map_screen.dart';
import 'alerts_screen.dart';
import 'predict_screen.dart';
import 'settings_screen.dart';

// ── Provider for the current tab index ───────────────────────────────────────
// Using a simple StateProvider so any widget in the tree can read / write it.
final shellTabProvider = StateProvider<int>((ref) => 0);

class MainShell extends ConsumerWidget {
  static const String route = '/shell';

  const MainShell({super.key});

  /// Call this from any screen to programmatically switch tabs.
  static void jumpTo(BuildContext context, int index) {
    final container = ProviderScope.containerOf(context);
    container.read(shellTabProvider.notifier).state = index;
  }

  static const _screens = [
    DashboardScreen(),
    BiharRiverMapScreen(),
    AlertsScreen(),
    PredictScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(shellTabProvider);

    return PopScope(
      // Back button returns to tab 0 before exiting the app
      canPop: currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ref.read(shellTabProvider.notifier).state = 0;
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: _NavBar(
          currentIndex: currentIndex,
          onTap: (i) {
            HapticFeedback.selectionClick();
            ref.read(shellTabProvider.notifier).state = i;
          },
        ),
      ),
    );
  }
}

// ── Custom bottom nav bar ─────────────────────────────────────────────────────

class _NavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _NavBar({required this.currentIndex, required this.onTap});

  static const _items = [
    _NavItem(icon: Icons.dashboard_rounded,     activeIcon: Icons.dashboard_rounded,        label: 'Dashboard'),
    _NavItem(icon: Icons.map_outlined,           activeIcon: Icons.map_rounded,               label: 'Map'),
    _NavItem(icon: Icons.notifications_outlined, activeIcon: Icons.notifications_rounded,    label: 'Alerts'),
    _NavItem(icon: Icons.psychology_outlined,    activeIcon: Icons.psychology_rounded,        label: 'Predict'),
    _NavItem(icon: Icons.settings_outlined,      activeIcon: Icons.settings_rounded,          label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: t.cardBg,
        border: Border(top: BorderSide(color: t.stroke, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (i) {
              final item      = _items[i];
              final isActive  = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Active pill indicator
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutBack,
                          width:  isActive ? 40 : 0,
                          height: isActive ? 3  : 0,
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: t.accent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        // Icon
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Icon(
                            isActive ? item.activeIcon : item.icon,
                            key: ValueKey('nav_icon_${i}_$isActive'),
                            size: 22,
                            color: isActive ? t.accent : t.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        // Label
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 180),
                          style: TextStyle(
                            color: isActive ? t.accent : t.textSecondary,
                            fontSize: 10,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                          child: Text(item.label),
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
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String   label;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
