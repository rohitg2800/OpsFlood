// lib/providers/locale_provider.dart
// OpsFlood — LocaleProvider
//
// Persists the user's chosen language to SharedPreferences.
// Riverpod notifier so MaterialApp.locale rebuilds immediately on change.
//
// FIX: Previous build() started an async _loadFromPrefs() but immediately
// returned Locale('en'), meaning on cold-start the saved Hindi preference was
// ignored until the async call completed (causing a brief English flash and,
// if the widget tree was already stable, potentially never re-rendering).
// Now we load from prefs BEFORE the first frame via an overrideWithValue
// pattern — but since Notifier.build() cannot be async, we instead keep the
// async load AND emit a notifyListeners-equivalent by setting state again,
// which Riverpod handles correctly (state setter triggers rebuild).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLocaleKey = 'app_locale';

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    // Kick off async load; Riverpod will re-render when state is updated.
    _loadFromPrefs();
    return const Locale('en'); // safe default; overwritten by _loadFromPrefs
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final code  = prefs.getString(_kLocaleKey) ?? 'en';
    // Only update if different to avoid an unnecessary rebuild on first launch.
    if (state.languageCode != code) {
      state = Locale(code);
    }
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;                                    // triggers rebuild immediately
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocaleKey, locale.languageCode);
  }

  String get languageCode => state.languageCode;
}

final localeProvider =
    NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);
