// lib/l10n/context_l10n.dart
//
// CRITICAL FIX: The previous implementation had:
//   AppLocalizations get l10n => _fallback;   ← always returned English!
//
// Every screen called `context.l10n.someKey` expecting a locale-aware string,
// but got the hardcoded English _FallbackLocalizations singleton every time.
// Switching to Hindi in Settings updated the Riverpod state and MaterialApp
// locale correctly, but the UI never reflected it because every text read
// came from this static English fallback.
//
// Fix: call AppLocalizations.of(context) — which Flutter resolves from the
// nearest Localizations ancestor (i.e. MaterialApp with the active locale).
// A try/catch catches the case where a widget is outside MaterialApp (e.g.
// during tests or early boot) and falls back gracefully to English.

import 'package:flutter/widgets.dart';
import 'app_localizations.dart';
import 'app_localizations_en.dart';

extension ContextL10n on BuildContext {
  AppLocalizations get l10n {
    try {
      return AppLocalizations.of(this);
    } catch (_) {
      // Widget is outside a Localizations scope (tests / early boot).
      return AppLocalizationsEn();
    }
  }
}
