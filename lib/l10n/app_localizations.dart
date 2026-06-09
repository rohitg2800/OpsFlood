import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'EQUINOX-BR05'**
  String get appTitle;

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @tabMonitors.
  ///
  /// In en, this message translates to:
  /// **'Monitors'**
  String get tabMonitors;

  /// No description provided for @tabAlerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get tabAlerts;

  /// No description provided for @tabPredict.
  ///
  /// In en, this message translates to:
  /// **'Predict'**
  String get tabPredict;

  /// No description provided for @tabMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get tabMap;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get noData;

  /// No description provided for @riverLevel.
  ///
  /// In en, this message translates to:
  /// **'River Level'**
  String get riverLevel;

  /// No description provided for @rainfall.
  ///
  /// In en, this message translates to:
  /// **'Rainfall'**
  String get rainfall;

  /// No description provided for @discharge.
  ///
  /// In en, this message translates to:
  /// **'Discharge'**
  String get discharge;

  /// No description provided for @safe.
  ///
  /// In en, this message translates to:
  /// **'Safe'**
  String get safe;

  /// No description provided for @warning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get warning;

  /// No description provided for @danger.
  ///
  /// In en, this message translates to:
  /// **'Danger'**
  String get danger;

  /// No description provided for @critical.
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get critical;

  /// No description provided for @lastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated'**
  String get lastUpdated;

  /// No description provided for @stations.
  ///
  /// In en, this message translates to:
  /// **'Stations'**
  String get stations;

  /// No description provided for @forecast.
  ///
  /// In en, this message translates to:
  /// **'Forecast'**
  String get forecast;

  /// No description provided for @floodRisk.
  ///
  /// In en, this message translates to:
  /// **'Flood Risk'**
  String get floodRisk;

  /// No description provided for @high.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get high;

  /// No description provided for @medium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get medium;

  /// No description provided for @low.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get low;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get themeAuto;

  /// No description provided for @themeDay.
  ///
  /// In en, this message translates to:
  /// **'Day River'**
  String get themeDay;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Night River'**
  String get themeDark;

  /// No description provided for @themeSunset.
  ///
  /// In en, this message translates to:
  /// **'Sunset Warm'**
  String get themeSunset;

  /// No description provided for @themeOcean.
  ///
  /// In en, this message translates to:
  /// **'Deep Ocean'**
  String get themeOcean;

  /// No description provided for @premiumFilters.
  ///
  /// In en, this message translates to:
  /// **'Premium Filters'**
  String get premiumFilters;

  /// No description provided for @selectTheme.
  ///
  /// In en, this message translates to:
  /// **'Select Theme'**
  String get selectTheme;

  /// No description provided for @bihar.
  ///
  /// In en, this message translates to:
  /// **'Bihar'**
  String get bihar;

  /// No description provided for @currentLevel.
  ///
  /// In en, this message translates to:
  /// **'Current Level'**
  String get currentLevel;

  /// No description provided for @dangerLevel.
  ///
  /// In en, this message translates to:
  /// **'Danger Level'**
  String get dangerLevel;

  /// No description provided for @warningLevel.
  ///
  /// In en, this message translates to:
  /// **'Warning Level'**
  String get warningLevel;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @river.
  ///
  /// In en, this message translates to:
  /// **'River'**
  String get river;

  /// No description provided for @alerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get alerts;

  /// No description provided for @noAlerts.
  ///
  /// In en, this message translates to:
  /// **'No active alerts'**
  String get noAlerts;

  /// No description provided for @activeAlerts.
  ///
  /// In en, this message translates to:
  /// **'Active Alerts'**
  String get activeAlerts;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @meters.
  ///
  /// In en, this message translates to:
  /// **'m'**
  String get meters;

  /// No description provided for @mmRainfall.
  ///
  /// In en, this message translates to:
  /// **'mm'**
  String get mmRainfall;

  /// No description provided for @cumecs.
  ///
  /// In en, this message translates to:
  /// **'cumecs'**
  String get cumecs;

  /// No description provided for @searchCity.
  ///
  /// In en, this message translates to:
  /// **'Search city…'**
  String get searchCity;

  /// No description provided for @monitoredCities.
  ///
  /// In en, this message translates to:
  /// **'Monitored Cities'**
  String get monitoredCities;

  /// No description provided for @liveData.
  ///
  /// In en, this message translates to:
  /// **'Live Data'**
  String get liveData;

  /// No description provided for @predictionModel.
  ///
  /// In en, this message translates to:
  /// **'Prediction Model'**
  String get predictionModel;

  /// No description provided for @accuracy.
  ///
  /// In en, this message translates to:
  /// **'Accuracy'**
  String get accuracy;

  /// No description provided for @confidence.
  ///
  /// In en, this message translates to:
  /// **'Confidence'**
  String get confidence;

  /// No description provided for @live.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get live;

  /// No description provided for @riskIndex.
  ///
  /// In en, this message translates to:
  /// **'RISK INDEX'**
  String get riskIndex;

  /// No description provided for @allStationsSafe.
  ///
  /// In en, this message translates to:
  /// **'All stations within safe levels'**
  String get allStationsSafe;

  /// No description provided for @fetchingLiveData.
  ///
  /// In en, this message translates to:
  /// **'Fetching live flood data…'**
  String get fetchingLiveData;

  /// No description provided for @dataSources.
  ///
  /// In en, this message translates to:
  /// **'CWC  •  GloFAS  •  IMD  •  Open-Meteo'**
  String get dataSources;

  /// No description provided for @noStationsFound.
  ///
  /// In en, this message translates to:
  /// **'No stations found.'**
  String get noStationsFound;

  /// No description provided for @rivers.
  ///
  /// In en, this message translates to:
  /// **'Rivers'**
  String get rivers;

  /// No description provided for @floodAlerts.
  ///
  /// In en, this message translates to:
  /// **'Flood Alerts'**
  String get floodAlerts;

  /// No description provided for @mlModelInfo.
  ///
  /// In en, this message translates to:
  /// **'ML Model Info'**
  String get mlModelInfo;

  /// No description provided for @floodPredictionEngine.
  ///
  /// In en, this message translates to:
  /// **'Flood Prediction Engine'**
  String get floodPredictionEngine;

  /// No description provided for @stateMatrix.
  ///
  /// In en, this message translates to:
  /// **'State Matrix'**
  String get stateMatrix;

  /// No description provided for @primaryRivers.
  ///
  /// In en, this message translates to:
  /// **'Primary Rivers'**
  String get primaryRivers;

  /// No description provided for @vulnerableDistricts.
  ///
  /// In en, this message translates to:
  /// **'Vulnerable Districts'**
  String get vulnerableDistricts;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by:'**
  String get sortBy;

  /// No description provided for @fetchingWeather.
  ///
  /// In en, this message translates to:
  /// **'Fetching live weather…'**
  String get fetchingWeather;

  /// No description provided for @riverLevelTrend.
  ///
  /// In en, this message translates to:
  /// **'24-hr River Level Trend'**
  String get riverLevelTrend;

  /// No description provided for @capacity.
  ///
  /// In en, this message translates to:
  /// **'capacity'**
  String get capacity;

  /// No description provided for @buildingTrend.
  ///
  /// In en, this message translates to:
  /// **'Building trend…'**
  String get buildingTrend;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @monitors.
  ///
  /// In en, this message translates to:
  /// **'Monitors'**
  String get monitors;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
