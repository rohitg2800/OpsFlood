// lib/screens/home_screen.dart
// Bihar Flood Command — Home (Tab Shell) v4
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/flood_providers.dart';
import '../providers/theme_provider.dart';
import '../theme/river_theme.dart';
import '../widgets/premium_theme_sheet.dart';
import 'alerts_screen.dart';
import 'dashboard_screen.dart';
import 'monitors_screen.dart';
import 'river_monitor_screen.dart';
import 'settings_screen.dart';
import 'weather_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  static const String route = '/home';
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _idx = 0;