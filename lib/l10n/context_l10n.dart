// lib/l10n/context_l10n.dart
// Null-safe BuildContext extension for AppLocalizations.
//
// BEFORE (crashes when AppLocalizations.delegate is missing or context is
// above the Localizations widget — e.g. inside a Sliver):
//   context.l10n.monitors   →  null! → _TypeError
//
// AFTER (safe everywhere):
//   context.l10n.monitors   →  returns value or '' — never throws

import 'package:flutter/widgets.dart';
import 'app_localizations.dart';

extension ContextL10n on BuildContext {
  // Null-safe: falls back to AppLocalizationsEn when not found in tree.
  AppLocalizations get l10n =>
      AppLocalizations.of(this) ?? _fallback;

  static final _fallback = _FallbackLocalizations();
}

// ── Fallback English instance used when AppLocalizations is not in the tree ──
// This prevents the null-check crash without hiding the real configuration bug.
// The real fix is adding AppLocalizations.delegate to MaterialApp (see main.dart).
class _FallbackLocalizations extends AppLocalizations {
  _FallbackLocalizations() : super('en');

  @override String get appTitle              => 'EQUINOX-BR05';
  @override String get tabHome               => 'Home';
  @override String get tabMonitors           => 'Monitors';
  @override String get tabAlerts             => 'Alerts';
  @override String get tabPredict            => 'Predict';
  @override String get tabMap                => 'Map';
  @override String get loading               => 'Loading\u2026';
  @override String get retry                 => 'Retry';
  @override String get noData                => 'No data available';
  @override String get riverLevel            => 'River Level';
  @override String get rainfall              => 'Rainfall';
  @override String get discharge             => 'Discharge';
  @override String get safe                  => 'Safe';
  @override String get warning               => 'Warning';
  @override String get danger                => 'Danger';
  @override String get critical              => 'Critical';
  @override String get lastUpdated           => 'Last updated';
  @override String get stations              => 'Stations';
  @override String get forecast              => 'Forecast';
  @override String get floodRisk             => 'Flood Risk';
  @override String get high                  => 'High';
  @override String get medium                => 'Medium';
  @override String get low                   => 'Low';
  @override String get settings              => 'Settings';
  @override String get language              => 'Language';
  @override String get theme                 => 'Theme';
  @override String get themeAuto             => 'Auto';
  @override String get themeDay              => 'Day River';
  @override String get themeDark             => 'Night River';
  @override String get themeSunset           => 'Sunset Warm';
  @override String get themeOcean            => 'Deep Ocean';
  @override String get premiumFilters        => 'Premium Filters';
  @override String get selectTheme           => 'Select Theme';
  @override String get bihar                 => 'Bihar';
  @override String get currentLevel          => 'Current Level';
  @override String get dangerLevel           => 'Danger Level';
  @override String get warningLevel          => 'Warning Level';
  @override String get city                  => 'City';
  @override String get river                 => 'River';
  @override String get alerts                => 'Alerts';
  @override String get noAlerts              => 'No active alerts';
  @override String get activeAlerts          => 'Active Alerts';
  @override String get viewAll               => 'View All';
  @override String get meters                => 'm';
  @override String get mmRainfall            => 'mm';
  @override String get cumecs               => 'cumecs';
  @override String get searchCity            => 'Search city\u2026';
  @override String get monitoredCities       => 'Monitored Cities';
  @override String get liveData              => 'Live Data';
  @override String get predictionModel       => 'Prediction Model';
  @override String get accuracy              => 'Accuracy';
  @override String get confidence            => 'Confidence';
  @override String get live                  => 'LIVE';
  @override String get riskIndex             => 'RISK INDEX';
  @override String get allStationsSafe       => 'All stations within safe levels';
  @override String get fetchingLiveData      => 'Fetching live flood data\u2026';
  @override String get dataSources           => 'CWC  \u2022  GloFAS  \u2022  IMD  \u2022  Open-Meteo';
  @override String get noStationsFound       => 'No stations found.';
  @override String get rivers                => 'Rivers';
  @override String get floodAlerts           => 'Flood Alerts';
  @override String get mlModelInfo           => 'ML Model Info';
  @override String get floodPredictionEngine => 'Flood Prediction Engine';
  @override String get stateMatrix           => 'State Matrix';
  @override String get primaryRivers         => 'Primary Rivers';
  @override String get vulnerableDistricts   => 'Vulnerable Districts';
  @override String get sortBy                => 'Sort by:';
  @override String get fetchingWeather       => 'Fetching live weather\u2026';
  @override String get riverLevelTrend       => '24-hr River Level Trend';
  @override String get capacity              => 'capacity';
  @override String get buildingTrend         => 'Building trend\u2026';
  @override String get comingSoon            => 'Coming soon';
  @override String get monitors              => 'Monitors';
}
