// lib/providers/theme_provider.dart
// Resolves issue #8: Theme persistence — ChangeNotifier + Riverpod StateNotifier

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_theme.dart';

// ───────────────────────────────────────────────────────────────────
enum AppThemeMode {
  system,
  light,
  dark,
  sunset,
  ocean;

  String get label {
    switch (this) {
      case AppThemeMode.system: return 'System Default';
      case AppThemeMode.light:  return 'Light';
      case AppThemeMode.dark:   return 'Dark';
      case AppThemeMode.sunset: return 'Sunset';
      case AppThemeMode.ocean:  return 'Ocean';
    }
  }

  ThemeMode get flutterMode {
    switch (this) {
      case AppThemeMode.system: return ThemeMode.system;
      case AppThemeMode.light:  return ThemeMode.light;
      case AppThemeMode.dark:   return ThemeMode.dark;
      case AppThemeMode.sunset: return ThemeMode.light;
      case AppThemeMode.ocean:  return ThemeMode.dark;
    }
  }

  static const String _prefsKey = 'app_theme_mode_v2';

  static Future<AppThemeMode> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(_prefsKey);
    return AppThemeMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => AppThemeMode.system,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, name);
  }
}

// ── Riverpod StateNotifier ────────────────────────────────────────────────────
class ThemeModeNotifier extends StateNotifier<AppThemeMode> {
  ThemeModeNotifier() : super(AppThemeMode.system);

  Future<void> init() async {
    state = await AppThemeMode.load();
  }

  Future<void> set(AppThemeMode mode) async {
    state = mode;
    await mode.save();
  }

  void cycle() {
    final next = AppThemeMode.values[
      (state.index + 1) % AppThemeMode.values.length
    ];
    set(next);
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, AppThemeMode>(
  (ref) => ThemeModeNotifier()..init(),
);

// ── Legacy ChangeNotifier ───────────────────────────────────────────────────
class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  Future<void> init() async {
    _themeMode = await AppTheme.loadThemeMode();
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await AppTheme.saveThemeMode(mode);
    notifyListeners();
  }

  void toggleTheme() {
    if (_themeMode == ThemeMode.dark) {
      setThemeMode(ThemeMode.light);
    } else {
      setThemeMode(ThemeMode.dark);
    }
  }
}
