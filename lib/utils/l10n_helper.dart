// lib/utils/l10n_helper.dart
//
// Module-level shorthand for terse use inside build methods:
//   final s = l(context);
//   Text(s.loading)

import 'package:flutter/widgets.dart';
import '../l10n/app_localizations.dart';

AppLocalizations l(BuildContext context) => AppLocalizations.of(context);
