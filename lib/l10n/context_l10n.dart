// lib/l10n/context_l10n.dart
//
// BuildContext extension — gives every widget access to the active
// AppLocalizations instance without any boilerplate.
//
// Usage in any build() method:
//   final s = context.l10n;
//   Text(s.riverLevel)
//   Text(s.floodRisk)

import 'package:flutter/widgets.dart';
import 'app_localizations.dart';

extension ContextL10n on BuildContext {
  /// Returns the AppLocalizations for the current locale.
  /// Falls back to English if the delegate hasn't loaded yet.
  AppLocalizations get l10n => AppLocalizations.of(this);
}
