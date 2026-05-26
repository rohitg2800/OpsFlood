import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static final ThemeProvider _instance = ThemeProvider._internal();
  factory ThemeProvider() => _instance;
  ThemeProvider._internal();

  // Renamed key from 'opsflood_theme_mode' -> 'equinox_theme_mode'
  static const _key = 'equinox_theme_mode';
  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored == 'light') {
      _mode = ThemeMode.light;
    } else if (stored == 'dark') {
      _mode = ThemeMode.dark;
    } else {
      _mode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  void cycle() {
    switch (_mode) {
      case ThemeMode.system:
        setMode(ThemeMode.light);
        break;
      case ThemeMode.light:
        setMode(ThemeMode.dark);
        break;
      case ThemeMode.dark:
        setMode(ThemeMode.system);
        break;
    }
  }

  String get label {
    switch (_mode) {
      case ThemeMode.system:
        return 'Auto';
      case ThemeMode.light:
        return 'Day River';
      case ThemeMode.dark:
        return 'Night River';
    }
  }

  IconData get icon {
    switch (_mode) {
      case ThemeMode.system:
        return Icons.brightness_auto;
      case ThemeMode.light:
        return Icons.wb_sunny;
      case ThemeMode.dark:
        return Icons.nights_stay;
    }
  }
}
