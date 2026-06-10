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
import 'comparison_screen.dart';
import 'admin_dashboard_screen.dart';
import 'incident_report_screen.dart';
import 'export_screen.dart';

// ---------------------------------------------------------------------------
// Tab state
// ---------------------------------------------------------------------------

class ShellTabNotifier extends Notifier<int> {
  @override
  int build() => 0;
}

final shellTabProvider =
    NotifierProvider<ShellTabNotifier, int>(ShellTabNotifier.new);

// ---------------------------------------------------------------------------
// Admin role helper
// (replace body with real Firebase Auth check)
// ---------------------------------------------------------------------------

bool _isAdmin(BuildContext context) {
  // TODO: swap for FirebaseAuth.instance.currentUser?.email check
  // return FirebaseAuth.instance.currentUser?.email
  //     ?.endsWith('@opsflood.gov.in') ?? false;
  return false; // safe default for all users in prod
}

// ---------------------------------------------------------------------------
// MainShell
// ---------------------------------------------------------------------------

class MainShell extends ConsumerWidget {
  static const String route = '/shell';
  const MainShell({super.key});

  static void jumpTo(BuildContext context, int index) {
    final container = ProviderScope.containerOf(context);
    container.read(shellTabProvider.notifier).state = index;
  }

  // 7 tabs: Dashboard · Map · Alerts · News · Predict · Compare · Settings
  static const _screens = [
    DashboardScreen(),        // 0
    BiharRiverMapScreen(),    // 1
    AlertsScreen(),           // 2
    NewsFeedScreen(),         // 3
    PredictScreen(),          // 4
    ComparisonScreen(),       // 5  ← NEW
    SettingsScreen(),         // 6  (was 5)
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex  = ref.watch(shellTabProvider);
    final criticalCount = ref.watch(criticalAlertCountProvider);
    final t             = RiverColors.of(context);
    final admin         = _isAdmin(context);

    return PopScope(
      canPop: currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(shellTabProvider.notifier).state = 0;
      },
      child: Scaffold(
        // ── Drawer (Admin Dashboard + quick-links) ──────────────────────────
        drawer: _AppDrawer(isAdmin: admin),
        body: IndexedStack(index: currentIndex, children: _screens),
        floatingActionButton: _SosFab(t: t),
        floatingActionButtonLocation:
            FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: _NavBar(
          currentIndex:  currentIndex,
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

// ---------------------------------------------------------------------------
// Drawer
// ---------------------------------------------------------------------------

class _AppDrawer extends StatelessWidget {
  final bool isAdmin;
  const _AppDrawer({required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Header
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.water_drop,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(height: 8),
                const Text('OpsFlood',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                Text('Bihar Flood Monitor',
                    style: TextStyle(
                        color: Colors.white.withOpacity(.7),
                        fontSize: 12)),
              ],
            ),
          ),

          // ── Quick links ────────────────────────────────────────────────
          const _DrawerSection(title: 'Quick Actions'),

          ListTile(
            leading: const Icon(Icons.compare_arrows,
                color: Color(0xFF1565C0)),
            title: const Text('Compare Stations'),
            onTap: () {
              Navigator.pop(context);
              MainShell.jumpTo(context, 5);
            },
          ),

          ListTile(
            leading: const Icon(Icons.report_problem_outlined,
                color: Color(0xFFFF6D00)),
            title: const Text('Report Incident'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        const IncidentReportScreen()),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.file_download_outlined,
                color: Color(0xFF00695C)),
            title: const Text('Export Data'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ExportScreen()),
              );
            },
          ),

          const Divider(),

          // ── Admin section (role-gated) ──────────────────────────────────
          if (isAdmin) ...[
            const _DrawerSection(title: 'Admin'),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings,
                  color: Color(0xFF6A1B9A)),
              title: const Text('Admin Dashboard'),
              subtitle: const Text('Incidents · Stations · Broadcast',
                  style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const AdminDashboardScreen()),
                );
              },
            ),
            const Divider(),
          ],

          // ── App info ────────────────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About OpsFlood'),
            onTap: () {
              Navigator.pop(context);
              showAboutDialog(
                context:     context,
                applicationName: 'OpsFlood',
                applicationVersion: '1.0.0',
                applicationLegalese:
                    '© 2026 OpsFlood. Bihar Flood Monitor.',
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DrawerSection extends StatelessWidget {
  final String title;
  const _DrawerSection({required this.title});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.outline,
            letterSpacing: 1.2,
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// SOS FAB (unchanged)
// ---------------------------------------------------------------------------

class _SosFab extends StatefulWidget {
  final RiverColors t;
  const _SosFab({required this.t});

  @override
  State<_SosFab> createState() => _SosFabState();
}

class _SosFabState extends State<_SosFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync:    this,
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
      builder: (_, child) =>
          Transform.scale(scale: _scale.value, child: child),
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
                color:      const Color(0xFFEF4444).withValues(alpha: 0.55),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'SOS',
              style: TextStyle(
                color:       Colors.white,
                fontWeight:  FontWeight.w900,
                fontSize:    13,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom nav bar — now 7 items
// ---------------------------------------------------------------------------

class _NavBar extends StatelessWidget {
  final int currentIndex;
  final int criticalCount;
  final ValueChanged<int> onTap;

  const _NavBar({
    required this.currentIndex,
    required this.criticalCount,
    required this.onTap,
  });

  static const _kAlertsIndex = 2; // unchanged

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    final s = context.l10n;
    final items = [
      _NavItem(icon: Icons.dashboard_outlined,      activeIcon: Icons.dashboard_rounded,      label: s.tabHome),
      _NavItem(icon: Icons.map_outlined,             activeIcon: Icons.map_rounded,             label: s.tabMap),
      _NavItem(icon: Icons.notifications_outlined,   activeIcon: Icons.notifications_rounded,   label: s.tabAlerts),
      _NavItem(icon: Icons.feed_outlined,            activeIcon: Icons.feed_rounded,            label: s.tabNews),
      _NavItem(icon: Icons.psychology_outlined,      activeIcon: Icons.psychology_rounded,      label: s.tabPredict),
      _NavItem(icon: Icons.compare_arrows_outlined,  activeIcon: Icons.compare_arrows,          label: 'Compare'),  // NEW
      _NavItem(icon: Icons.settings_outlined,        activeIcon: Icons.settings_rounded,        label: s.tabSettings),
    ];

    return Container(
      decoration: BoxDecoration(
        color:  t.cardBg,
        border: Border(top: BorderSide(color: t.stroke, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset:     const Offset(0, -4),
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
              final item     = items[i];
              final isActive = i == currentIndex;
              final showBadge =
                  i == _kAlertsIndex && criticalCount > 0;

              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: isActive
                            ? Curves.easeOutBack
                            : Curves.easeOut,
                        width:  isActive ? 36.0 : 0.0,
                        height: isActive ? 3.0  : 0.0,
                        margin: const EdgeInsets.only(bottom: 3),
                        decoration: BoxDecoration(
                          color:        t.accent,
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
                              key:   ValueKey(isActive),
                              color: isActive
                                  ? t.accent
                                  : t.textSecondary,
                              size: 22,
                            ),
                          ),
                          if (showBadge)
                            Positioned(
                              right: -4,
                              top:   -3,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEF4444),
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                    minWidth: 14, minHeight: 14),
                                child: Text(
                                  criticalCount > 9
                                      ? '9+'
                                      : '$criticalCount',
                                  style: const TextStyle(
                                    color:      Colors.white,
                                    fontSize:   8,
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
                          fontSize:   10,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isActive
                              ? t.accent
                              : t.textSecondary,
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
  final String   label;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
