// lib/screens/monitors_screen.dart
// OpsFlood — Monitor screen (inner tab shell) v2 — RiverColors migration
// Tabs: AI Predict | Alerts/News | SOS
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/river_theme.dart';
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
    _TabItem(icon: Icons.auto_graph_rounded, label: 'AI Predict'),
    _TabItem(icon: Icons.feed_rounded,       label: 'Alerts'),
    _TabItem(icon: Icons.sos_rounded,        label: 'SOS'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: t.scaffoldBg,
        body: IndexedStack(
          index: _tab,
          children: const [
            PredictionScreen(),
            NewsFeedScreen(),
            SosScreen(),
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

class _TabItem {
  final IconData icon;
  final String   label;
  const _TabItem({required this.icon, required this.label});
}

class _BottomBar extends StatelessWidget {
  final int               currentIndex;
  final List<_TabItem>    tabs;
  final ValueChanged<int> onTap;
  const _BottomBar({
    required this.currentIndex,
    required this.tabs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Container(
      height: 64 + MediaQuery.of(context).padding.bottom,
      decoration: BoxDecoration(
        color: t.navBg,
        border: Border(
          top: BorderSide(color: t.stroke, width: 1)),
      ),
      child: Row(
        children: tabs.asMap().entries.map((e) {
          final i      = e.key;
          final tab    = e.value;
          final active = i == currentIndex;
          // SOS last tab stays red; others use theme accent
          final col = i == tabs.length - 1
              ? AppPalette.critical
              : t.accent;
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
                          color: active ? col : t.stroke,
                          size: active ? 22 : 19),
                    ),
                    const SizedBox(height: 2),
                    Text(tab.label,
                        style: TextStyle(
                          color: active ? col : t.stroke,
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
}
