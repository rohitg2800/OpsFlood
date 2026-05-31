import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Supported locales ─────────────────────────────────────────────────────
const List<Locale> kSupportedLocales = [
  Locale('en'),
  Locale('hi'),
];

const Map<String, String> kLocaleLabels = {
  'en': 'English',
  'hi': 'हिन्दी',
};

// ─── Notifier (Riverpod 3) ──────────────────────────────────────────────────
class LocaleNotifier extends Notifier<Locale> {
  static const _key = 'equinox_locale';

  @override
  Locale build() {
    // Start with English; _loadSaved() corrects it once SharedPreferences loads.
    _loadSaved();
    return const Locale('en');
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final code  = prefs.getString(_key);
    if (code != null &&
        kSupportedLocales.any((l) => l.languageCode == code)) {
      state = Locale(code);
    }
  }

  /// Update Riverpod state immediately, then persist.
  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, locale.languageCode);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);
