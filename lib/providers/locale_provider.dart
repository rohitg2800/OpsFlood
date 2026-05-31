import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Supported locales ───────────────────────────────────────────────────────
const List<Locale> kSupportedLocales = [
  Locale('en'),
  Locale('hi'),
];

const Map<String, String> kLocaleLabels = {
  'en': 'English',
  'hi': 'हिन्दी',
};

// ─── StateNotifier ───────────────────────────────────────────────────────────
class LocaleNotifier extends StateNotifier<Locale> {
  static const _key = 'equinox_locale';

  LocaleNotifier() : super(const Locale('en')) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code  = prefs.getString(_key);
    if (code != null && kSupportedLocales.any((l) => l.languageCode == code)) {
      state = Locale(code);
    }
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, locale.languageCode);
  }
}

final localeProvider =
    StateNotifierProvider<LocaleNotifier, Locale>(
      (ref) => LocaleNotifier(),
    );
