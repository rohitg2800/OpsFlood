// lib/screens/india_river_explorer_screen.dart
//
// ── REDIRECT SHIM ─────────────────────────────────────────────────────────────
// The original IndiaRiverExplorerScreen (17k) was a superseded version of the
// India river explorer UI. The canonical, full-featured version is:
//   lib/screens/india_rivers_screen.dart  (IndiaRiversScreen, 68k)
//
// river_monitor_screen.dart uses `const IndiaRiverExplorerScreen()` as the
// 'Map' tab widget, so this class must remain a valid const-constructable
// widget. It simply delegates to IndiaRiversScreen.
//
// DO NOT add screen logic here. Develop in india_rivers_screen.dart.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/widgets.dart';
import 'india_rivers_screen.dart';

/// Thin redirect — delegates to the canonical [IndiaRiversScreen].
/// Kept to satisfy `const IndiaRiverExplorerScreen()` in river_monitor_screen.dart.
class IndiaRiverExplorerScreen extends StatelessWidget {
  const IndiaRiverExplorerScreen({super.key});

  @override
  Widget build(BuildContext context) => const IndiaRiversScreen();
}
