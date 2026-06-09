// lib/screens/main_shell.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/context_l10n.dart';
import '../providers/alerts_badge_provider.dart';
import '../theme/river_theme.dart';
import 'dashboard_screen.dart';
import 'bihar_river_map_screen.dart';
import 'alerts_screen.dart';
import 'news_feed_screen.dart';
import 'predict_screen.dart';
import 'settings_screen.dart';
import 'sos_screen.dart';

// Riverpod v3: StateProvider removed — use Notifier instead
class ShellTabNotifier extends Notifier<int> {
  @override
  int build() => 0;
}

final shellTabProvider = NotifierProvider<ShellTabNotifier, int>(ShellTabNotifier.new);

class MainShell extends ConsumerWidget {
  static const String route = '/shell';
  const MainShell({super.key});

  static void jumpTo(BuildContext context, int index) {
    final container = ProviderScope.containerOf(context);
    container.read(shellTabProvider.notifier).state = index;
  }

  static const _screens = [
    DashboardScreen(),
    BiharRiverMapScreen(),
    AlertsScreen(),
    NewsFeedScreen(),
    PredictScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(shellTabProvider);
    final criticalCount = ref.watch(criticalAlertCountProvider);
    final t = RiverColors.of(context);

    return PopScope(
      canPop: currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(shellTabProvider.notifier).state = 0;
      },
      child: Scaffold(
        body: IndexedStack(index: currentIndex, children: _screens),
        floatingActionButton: _SosFab(t: t),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: _NavBar(
          currentIndex: currentIndex,
          criticalCount: criticalCount,
          onTap: (i) {
            HapticFeedback.selectionClick();
            ref.read(shellTabProvider.notifier).state = i;
          },
        ),
      ),
    );
  }
}

class _SosFab extends StatefulWidget {
  final RiverColors t;
  const _SosFab({required this.t});

  @override
  State<_SosFab> createState() => _SosFabState();
}

class _SosFabState extends State<_SosFab> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.heavyImpact();
          Navigator.pushNamed(context, SosScreen.route);
        },
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFEF4444),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEF4444).withValues(alpha: 0.55),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'SOS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  final int currentIndex;
  final int criticalCount;
  final ValueChanged<int> onTap;

  const _NavBar({
    required this.currentIndex,
    required this.criticalCount,
    required this.onTap,
  });

  static const _kAlertsIndex = 2;

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    final s = context.l10n;
    final items = [
      _NavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, label: s.tabHome),
      _NavItem(icon: Icons.map_outlined, activeIcon: Icons.map_rounded, label: s.tabMap),
      _NavItem(icon: Icons.notifications_outlined, activeIcon: Icons.notifications_rounded, label: s.tabAlerts),
      _NavItem(icon: Icons.feed_outlined, activeIcon: Icons.feed_rounded, label: s.tabNews),
      _NavItem(icon: Icons.psychology_outlined, activeIcon: Icons.psychology_rounded, label: s.tabPredict),
      _NavItem(icon: Icons.settings_outlined, activeIcon: Icons.settings_rounded, label: s.tabSettings),
    ];

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
            children: List.generate(items.length, (i) {
              final item = items[i];
              final isActive = i == currentIndex;
              final showBadge = i == _kAlertsIndex && criticalCount > 0;

              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // FIX: easeOutBack overshoots past zero → negative
                      // BoxConstraints crash. Use easeOutBack only when
                      // activating (expanding); use easeOut when deactivating
                      // (collapsing to zero) so the tween never goes negative.
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: isActive ? Curves.easeOutBack : Curves.easeOut,
                        width: isActive ? 36.0 : 0.0,
                        height: isActive ? 3.0 : 0.0,
                        margin: const EdgeInsets.only(bottom: 3),
                        decoration: BoxDecoration(
                          color: t.accent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: Icon(
                              isActive ? item.activeIcon : item.icon,
                              key: ValueKey(isActive),
                              color: isActive ? t.accent : t.textSecondary,
                              size: 22,
                            ),
                          ),
                          if (showBadge)
                            Positioned(
                              right: -4,
                              top: -3,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEF4444),
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                                child: Text(
                                  criticalCount > 9 ? '9+' : '$criticalCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                          color: isActive ? t.accent : t.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
  final String label;
  const _NavItem({required this.icon, required this.activeIcon, required this.label});
}
