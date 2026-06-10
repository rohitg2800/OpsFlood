// lib/widgets/opsflood_widgets.dart
// OpsFlood — Module 10: Reusable widget barrel
//
// Single import gives access to every shared widget in the app:
//
//   import 'package:opsflood/widgets/opsflood_widgets.dart';
//
// Add new widget files to the exports list as they are created.

library opsflood_widgets;

// ── Common UI primitives
export 'river_level_bar.dart';
export 'severity_badge.dart';
export 'station_card.dart';
export 'alert_banner.dart';
export 'loading_shimmer.dart';
export 'empty_state.dart';
export 'error_card.dart';

// ── Charts
export 'level_chart.dart';
export 'trend_sparkline.dart';

// ── Map overlays
export 'flood_marker.dart';
export 'district_chip.dart';

// ── Forms
export 'labelled_field.dart';
export 'date_range_picker.dart';

// ── Misc
export 'sos_fab.dart';
export 'offline_banner.dart';
