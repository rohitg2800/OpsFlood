// lib/providers/theme_provider.dart
// Riverpod v3 — single clean Notifier, legacy ChangeNotifier kept for init().
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/robotic_theme.dart';

// ─── Extended theme modes ─────────────────────────────────────────────────────
enum AppThemeMode {
  system,        // Auto
  light,         // Day River
  dark,          // Night River
  sunset,        // Sunset Warm  (premium)
  ocean,         // Deep Ocean   (premium)
  roboticDark,   // Tactical Dark (robotic)
  roboticLight,  // System Light  (robotic)
}

// ─── Legacy ChangeNotifier singleton (kept for non-Riverpod init()) ──────────
class ThemeProvider extends ChangeNotifier {
  static final ThemeProvider _instance = ThemeProvider._internal();
  factory ThemeProvider() => _instance;
  ThemeProvider._internal();

  static const _key = 'equinox_theme_mode';
  AppThemeMode _appMode = AppThemeMode.system;

  AppThemeMode get appMode => _appMode;

  ThemeMode get mode {
    switch (_appMode) {
      case AppThemeMode.system:       return ThemeMode.system;
      case AppThemeMode.light:        return ThemeMode.light;
      case AppThemeMode.dark:         return ThemeMode.dark;
      case AppThemeMode.sunset:       return ThemeMode.light;
      case AppThemeMode.ocean:        return ThemeMode.dark;
      case AppThemeMode.roboticDark:  return ThemeMode.dark;
      case AppThemeMode.roboticLight: return ThemeMode.light;
    }
  }

  Future<void> init() async {
    final prefs  = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    _appMode = AppThemeMode.values.firstWhere(
      (e) => e.name == stored,
      orElse: () => AppThemeMode.system,
    );
    notifyListeners();
  }

  Future<void> setAppMode(AppThemeMode mode) async {
    _appMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}

// ─── Riverpod 3 Notifier ──────────────────────────────────────────────────────
class _ThemeModeNotifier extends Notifier<AppThemeMode> {
  static const _key = 'equinox_theme_mode';

  @override
  AppThemeMode build() {
    _loadSaved();
    return AppThemeMode.system;
  }

  Future<void> _loadSaved() async {
    final prefs  = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored == null) return;
    final saved = AppThemeMode.values.firstWhere(
      (e) => e.name == stored,
      orElse: () => AppThemeMode.system,
    );
    if (saved != state) state = saved;
  }

  Future<void> setMode(AppThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
    ThemeProvider()._appMode = mode;
  }

  void cycle() {
    switch (state) {
      case AppThemeMode.system:  setMode(AppThemeMode.light); break;
      case AppThemeMode.light:   setMode(AppThemeMode.dark);  break;
      default:                   setMode(AppThemeMode.system); break;
    }
  }

  String get label => switch (state) {
    AppThemeMode.system       => 'Auto',
    AppThemeMode.light        => 'Day River',
    AppThemeMode.dark         => 'Night River',
    AppThemeMode.sunset       => 'Sunset Warm',
    AppThemeMode.ocean        => 'Deep Ocean',
    AppThemeMode.roboticDark  => 'Tactical Dark',
    AppThemeMode.roboticLight => 'System Light',
  };

  IconData get icon => switch (state) {
    AppThemeMode.system       => Icons.brightness_auto,
    AppThemeMode.light        => Icons.wb_sunny,
    AppThemeMode.dark         => Icons.nights_stay,
    AppThemeMode.sunset       => Icons.wb_twilight,
    AppThemeMode.ocean        => Icons.water,
    AppThemeMode.roboticDark  => Icons.memory_rounded,
    AppThemeMode.roboticLight => Icons.developer_board_rounded,
  };

  ThemeMode get flutterMode => switch (state) {
    AppThemeMode.system       => ThemeMode.system,
    AppThemeMode.light        => ThemeMode.light,
    AppThemeMode.dark         => ThemeMode.dark,
    AppThemeMode.sunset       => ThemeMode.light,
    AppThemeMode.ocean        => ThemeMode.dark,
    AppThemeMode.roboticDark  => ThemeMode.dark,
    AppThemeMode.roboticLight => ThemeMode.light,
  };
}

final themeModeProvider = NotifierProvider<_ThemeModeNotifier, AppThemeMode>(
  _ThemeModeNotifier.new,
);

// ─── Robotic theme providers ──────────────────────────────────────────────────

/// Returns RoboticTheme when mode is robotic, null otherwise.
/// Widgets NOT in robotic mode are never rebuilt by this provider.
final roboticThemeProvider = Provider<RoboticTheme?>((ref) {
  final mode = ref.watch(themeModeProvider);
  return switch (mode) {
    AppThemeMode.roboticDark  => const RoboticTheme(isDark: true),
    AppThemeMode.roboticLight => const RoboticTheme(isDark: false),
    _                         => null,
  };
});

/// Non-null convenience provider — always returns a RoboticTheme.
/// Use only inside widgets that exclusively render in robotic mode.
final robTheme = Provider<RoboticTheme>(
  (ref) => ref.watch(roboticThemeProvider) ?? const RoboticTheme(isDark: true),
);
