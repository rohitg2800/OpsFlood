// lib/screens/monitors_screen.dart
// OpsFlood — Main tab shell (bottom navigation)
// Tabs: Home | AI Predict | Alerts/News | SOS
// The DangerProximityBanner is injected at the top of the Home tab.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/river_theme.dart';
import '../widgets/danger_proximity_banner.dart';
import 'live_stations_screen.dart';
import 'news_feed_screen.dart';
import 'prediction_screen.dart';
import 'sos_screen.dart';

class MonitorsScreen extends ConsumerStatefulWidget {
  const MonitorsScreen({super.key});

  @override
  ConsumerState<MonitorsScreen> createState() => _MonitorsScreenState();
}

class _MonitorsScreenState extends ConsumerState<MonitorsScreen> {
  int _tab = 0;

  static const _tabs = [
    _TabItem(icon: Icons.water_rounded,       label: 'Live'),
    _TabItem(icon: Icons.auto_graph_rounded,  label: 'AI Predict'),
    _TabItem(icon: Icons.feed_rounded,        label: 'Alerts'),
    _TabItem(icon: Icons.sos_rounded,         label: 'SOS'),
  ];

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppPalette.abyss0,
        body: IndexedStack(
          index: _tab,
          children: [
            // Tab 0 — Live Stations + DangerProximityBanner
            _LiveTabWithBanner(),
            // Tab 1 — AI Flood Prediction
            const PredictionScreen(),
            // Tab 2 — NDMA / IMD / WRD News Feed
            const NewsFeedScreen(),
            // Tab 3 — Emergency SOS
            const SosScreen(),
          ],
        ),
        bottomNavigationBar: _BottomBar(
          currentIndex: _tab,
          tabs:         _tabs,
          onTap: (i) {
            HapticFeedback.selectionClick();
            setState(() => _tab = i);
          },
        ),
      ),
    );
  }
}

// ── Live tab wrapper injects the proximity banner ───────────────────────────────
class _LiveTabWithBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
        children: const [
          DangerProximityBanner(),   // ⬆️ auto-hides when user is safe
          Expanded(child: LiveStationsScreen()),
        ],
      );
}

// ── Bottom nav bar ────────────────────────────────────────────────────────────
class _TabItem {
  final IconData icon;
  final String   label;
  const _TabItem({required this.icon, required this.label});
}

class _BottomBar extends StatelessWidget {
  final int              currentIndex;
  final List<_TabItem>   tabs;
  final ValueChanged<int> onTap;
  const _BottomBar({
    required this.currentIndex,
    required this.tabs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Container(
        height: 64 + MediaQuery.of(context).padding.bottom,
        decoration: BoxDecoration(
          color: AppPalette.abyss1,
          border: Border(
            top: BorderSide(
                color: AppPalette.abyssStroke, width: 1)),
        ),
        child: Row(
          children: tabs.asMap().entries.map((e) {
            final i      = e.key;
            final tab    = e.value;
            final active = i == currentIndex;
            final col    = i == 3
                ? AppPalette.critical   // SOS always red
                : AppPalette.cyan;
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: Padding(
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width:  active ? 42 : 36,
                        height: active ? 42 : 36,
                        decoration: BoxDecoration(
                          color: active
                              ? col.withValues(alpha: 0.14)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(tab.icon,
                            color: active ? col : AppPalette.textDim,
                            size: active ? 22 : 19),
                      ),
                      const SizedBox(height: 2),
                      Text(tab.label,
                          style: TextStyle(
                            color: active ? col : AppPalette.textDim,
                            fontSize: 9.5,
                            fontWeight: active
                                ? FontWeight.w800
                                : FontWeight.w500,
                          )),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
}
