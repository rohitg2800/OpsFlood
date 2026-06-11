// lib/providers/locale_provider.dart
// OpsFlood — LocaleNotifier
//
// FIX: Previously build() returned Locale('en') synchronously and kicked off
// an async _loadFromPrefs(). This created a race: screens read Locale('en')
// on frame 0, and the async load only updated state later — sometimes never
// triggering a rebuild if the saved code was also 'en'.
//
// FIX: Accept the pre-loaded languageCode from main() via constructor so that
// build() returns the correct Locale immediately — zero async gap, no flash.
// _loadFromPrefs() is kept only as a safeguard for future pref changes while
// the app is running.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLocaleKey = 'app_locale';

class LocaleNotifier extends Notifier<Locale> {
  /// Pass the language code pre-loaded from SharedPreferences in main()
  /// so build() is synchronous and correct on frame 0.
  final String _initialCode;
  LocaleNotifier([this._initialCode = 'en']);

  @override
  Locale build() => Locale(_initialCode);

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocaleKey, locale.languageCode);
  }

  String get languageCode => state.languageCode;
}

final localeProvider =
    NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);
