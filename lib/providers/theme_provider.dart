// lib/providers/theme_provider.dart
// Riverpod v3 — single clean Notifier, legacy ChangeNotifier kept for init().
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Extended theme modes ────────────────────────────────────────────
enum AppThemeMode {
  system,
  light,   // Day River
  dark,    // Night River
  sunset,  // 🌅 Sunset Warm  (premium)
  ocean,   // 🌊 Deep Ocean   (premium)
}

// ─── Legacy ChangeNotifier singleton (kept for non-Riverpod init() in main.dart) ──
class ThemeProvider extends ChangeNotifier {
  static final ThemeProvider _instance = ThemeProvider._internal();
  factory ThemeProvider() => _instance;
  ThemeProvider._internal();

  static const _key = 'equinox_theme_mode';
  AppThemeMode _appMode = AppThemeMode.system;

  AppThemeMode get appMode => _appMode;

  ThemeMode get mode {
    switch (_appMode) {
      case AppThemeMode.system:  return ThemeMode.system;
      case AppThemeMode.light:   return ThemeMode.light;
      case AppThemeMode.dark:    return ThemeMode.dark;
      case AppThemeMode.sunset:  return ThemeMode.light;
      case AppThemeMode.ocean:   return ThemeMode.dark;
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

// ─── Riverpod 3 Notifier ────────────────────────────────────────────────────
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
      case AppThemeMode.system:  setMode(AppThemeMode.light);  break;
      case AppThemeMode.light:   setMode(AppThemeMode.dark);   break;
      default:                   setMode(AppThemeMode.system); break;
    }
  }

  String get label {
    switch (state) {
      case AppThemeMode.system:  return 'Auto';
      case AppThemeMode.light:   return 'Day River';
      case AppThemeMode.dark:    return 'Night River';
      case AppThemeMode.sunset:  return 'Sunset Warm';
      case AppThemeMode.ocean:   return 'Deep Ocean';
    }
  }

  IconData get icon {
    switch (state) {
      case AppThemeMode.system:  return Icons.brightness_auto;
      case AppThemeMode.light:   return Icons.wb_sunny;
      case AppThemeMode.dark:    return Icons.nights_stay;
      case AppThemeMode.sunset:  return Icons.wb_twilight;
      case AppThemeMode.ocean:   return Icons.water;
    }
  }

  ThemeMode get flutterMode => switch (state) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light  => ThemeMode.light,
    AppThemeMode.dark   => ThemeMode.dark,
    AppThemeMode.sunset => ThemeMode.light,
    AppThemeMode.ocean  => ThemeMode.dark,
  };
}

final themeModeProvider = NotifierProvider<_ThemeModeNotifier, AppThemeMode>(
  _ThemeModeNotifier.new,
);
