import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Extended theme modes (includes premium filters) ─────────────────────
enum AppThemeMode {
  system,
  light,   // Day River
  dark,    // Night River
  sunset,  // 🌅 Sunset Warm  (premium)
  ocean,   // 🌊 Deep Ocean   (premium)
}

// ─── ThemeProvider (ChangeNotifier — kept for legacy init()) ─────────────
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

  void cycle() {
    switch (_appMode) {
      case AppThemeMode.system:  setAppMode(AppThemeMode.light);  break;
      case AppThemeMode.light:   setAppMode(AppThemeMode.dark);   break;
      default:                   setAppMode(AppThemeMode.system); break;
    }
  }

  String get label {
    switch (_appMode) {
      case AppThemeMode.system:  return 'Auto';
      case AppThemeMode.light:   return 'Day River';
      case AppThemeMode.dark:    return 'Night River';
      case AppThemeMode.sunset:  return 'Sunset Warm';
      case AppThemeMode.ocean:   return 'Deep Ocean';
    }
  }

  IconData get icon {
    switch (_appMode) {
      case AppThemeMode.system:  return Icons.brightness_auto;
      case AppThemeMode.light:   return Icons.wb_sunny;
      case AppThemeMode.dark:    return Icons.nights_stay;
      case AppThemeMode.sunset:  return Icons.wb_twilight;
      case AppThemeMode.ocean:   return Icons.water;
    }
  }
}

// ─── Riverpod StateNotifier ─────────────────────────────────────────────────────
class _ThemeModeNotifier extends StateNotifier<AppThemeMode> {
  static const _key = 'equinox_theme_mode';

  // Start with system default; _loadSaved() will update state once prefs load.
  _ThemeModeNotifier() : super(AppThemeMode.system) {
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs  = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored == null) return;
    final saved = AppThemeMode.values.firstWhere(
      (e) => e.name == stored,
      orElse: () => AppThemeMode.system,
    );
    // Only update if different to avoid unnecessary rebuilds.
    if (saved != state) state = saved;
  }

  /// Update Riverpod state immediately (triggers MaterialApp rebuild),
  /// then persist to SharedPreferences.
  Future<void> setMode(AppThemeMode mode) async {
    state = mode; // ← Riverpod listeners rebuild right here
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
    // Keep legacy singleton in sync so ThemeProvider().appMode is consistent.
    ThemeProvider()._appMode = mode;
  }

  void cycle() {
    switch (state) {
      case AppThemeMode.system:  setMode(AppThemeMode.light);  break;
      case AppThemeMode.light:   setMode(AppThemeMode.dark);   break;
      default:                   setMode(AppThemeMode.system); break;
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

final themeModeProvider =
    StateNotifierProvider<_ThemeModeNotifier, AppThemeMode>(
  (ref) => _ThemeModeNotifier(),
);
