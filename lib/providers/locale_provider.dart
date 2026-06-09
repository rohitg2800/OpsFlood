// lib/providers/locale_provider.dart
// OpsFlood — LocaleProvider
//
// Persists the user's chosen language to SharedPreferences.
// Riverpod notifier so MaterialApp.locale rebuilds immediately on change.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLocaleKey = 'app_locale';

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    // Load synchronously from cache if available; async init below.
    _loadFromPrefs();
    return const Locale('en'); // default until prefs load
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final code  = prefs.getString(_kLocaleKey) ?? 'en';
    state = Locale(code);
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocaleKey, locale.languageCode);
  }

  String get languageCode => state.languageCode;
}

final localeProvider =
    NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);
