// lib/screens/dashboard_screen.dart
// OpsFlood — DashboardScreen  v14  (Premium Midnight Ops rebuild)
// ─────────────────────────────────────────────────────────────────────────────
// Layout:
//   1. Alert Hero Strip        — full-bleed gradient banner
//   2. OpsFlood Header         — identity + status pill + refresh
//   3. KPI Metric Row          — 4 frosted chips
//   4. India Map Preview Card  — tappable gradient card
//   5. Hero Data Card          — replaces gauge; bar + top city metrics
//   6. River Trend Chart       — upgraded dual-line with ref bands
//   7. CWC Station Strip       — compact shimmer cards
//   8. City Cards Grid         — 2-col premium cards with glow
//   9. State Risk Matrix       — heatmap
library;

import 'dart:convert';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
import '../screens/india_rivers_screen.dart';
import '../services/real_time_service.dart';
import '../theme/river_theme.dart';
import '../widgets/animated_alert_badge.dart';
import '../widgets/premium_stat_card.dart';
import '../widgets/risk_heatmap.dart';
import '../widgets/river_level_visualizer.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final RealTimeService _service = RealTimeService();
  String? _selectedCity;

  bool _showDebug     = false;
  int  _lastLevelHash = 0;
  List<FloodData> _cachedSortedLevels = [];
  int  _cachedHash = -1;

  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  @override
  voi