// lib/screens/monitors_screen.dart
// OpsFlood — MonitorsScreen v5.2  "Full i18n pass"
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/context_l10n.dart';
import '../models/flood_data.dart';
import '../providers/flood_providers.dart';
import '../providers/weather_provider.dart';
import '../theme/river_theme.dart';

class MonitorsScreen extends ConsumerStatefulWidget {
  const MonitorsScreen({super.key});
  static const String route = '/monitors';
  @override
  ConsumerState<MonitorsScreen> createState() => _MonitorsScreenState();
}
