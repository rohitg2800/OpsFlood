// GENERATED — hand-written stub.
// Run `flutter gen-l10n` to replace this with the real generated file.
// This stub keeps the build green without requiring the codegen step.
library app_localizations;

export 'package:flutter_localizations/flutter_localizations.dart'
    show
        GlobalCupertinoLocalizations,
        GlobalMaterialLocalizations,
        GlobalWidgetsLocalizations;

import 'dart:ui' show Locale;
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' show Intl;

/// Supported locales exposed as a constant for MaterialApp.supportedLocales.
const List<Locale> kSupportedLocales = [
  Locale('en'),
  Locale('hi'),
];

/// Minimal AppLocalizations stub.
/// Screens access strings via AppLocalizations.of(context)!.<key>.
class AppLocalizations {
  AppLocalizations(this.localeName);

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations('en');
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  // ── strings ────────────────────────────────────────────────────────────────
  String get appTitle => 'EQUINOX-BH';
  String get tabHome => 'Home';
  String get tabMonitors => 'Monitors';
  String get tabAlerts => 'Alerts';
  String get tabPredict => 'Predict';
  String get tabMap => 'Map';
  String get loading => 'Loading\u2026';
  String get retry => 'Retry';
  String get noData => 'No data available';
  String get riverLevel => 'River Level';
  String get rainfall => 'Rainfall';
  String get discharge => 'Discharge';
  String get safe => 'Safe';
  String get warning => 'Warning';
  String get danger => 'Danger';
  String get critical => 'Critical';
  String get lastUpdated => 'Last updated';
  String get stations => 'Stations';
  String get forecast => 'Forecast';
  String get floodRisk => 'Flood Risk';
  String get high => 'High';
  String get medium => 'Medium';
  String get low => 'Low';
  String get settings => 'Settings';
  String get language => 'Language';
  String get theme => 'Theme';
  String get themeAuto => 'Auto';
  String get themeDay => 'Day River';
  String get themeDark => 'Night River';
  String get themeSunset => 'Sunset Warm';
  String get themeOcean => 'Deep Ocean';
  String get premiumFilters => 'Premium Filters';
  String get selectTheme => 'Select Theme';
  String get bihar => 'Bihar';
  String get currentLevel => 'Current Level';
  String get dangerLevel => 'Danger Level';
  String get warningLevel => 'Warning Level';
  String get city => 'City';
  String get river => 'River';
  String get alerts => 'Alerts';
  String get noAlerts => 'No active alerts';
  String get activeAlerts => 'Active Alerts';
  String get viewAll => 'View All';
  String get meters => 'm';
  String get mmRainfall => 'mm';
  String get cumecs => 'cumecs';
  String get searchCity => 'Search city\u2026';
  String get monitoredCities => 'Monitored Cities';
  String get liveData => 'Live Data';
  String get predictionModel => 'Prediction Model';
  String get accuracy => 'Accuracy';
  String get confidence => 'Confidence';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      kSupportedLocales.any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale.languageCode);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
