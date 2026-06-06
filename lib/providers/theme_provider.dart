// lib/providers/theme_provider.dart
// Riverpod v3 — StateNotifier/StateNotifierProvider removed in v3.
// Migrated to Notifier<T> + NotifierProvider.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_theme.dart';

// ── AppThemeMode enum ─────────────────────────────────────────────────────
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

// ── Riverpod v3: Notifier<AppThemeMode> ─────────────────────────────────────────
// ThemeCycleButton calls: ref.watch(themeModeProvider)
//                         ref.read(themeModeProvider.notifier).cycle()
class ThemeModeNotifier extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() {
    // Load persisted value asynchronously after first build
    Future.microtask(() async {
      final saved = await AppThemeMode.load();
      state = saved;
    });
    return AppThemeMode.system;
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
    NotifierProvider<ThemeModeNotifier, AppThemeMode>(
  ThemeModeNotifier.new,
);

// ── Legacy ChangeNotifier (used by MaterialApp builder) ─────────────────────
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
    setThemeMode(
      _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }
}
