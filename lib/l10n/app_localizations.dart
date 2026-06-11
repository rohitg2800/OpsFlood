import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
  ];

  String get appTitle;
  String get tabHome;
  String get tabMonitors;
  String get tabAlerts;
  String get tabPredict;
  String get tabMap;
  String get tabDashboard;
  String get tabSettings;
  String get loading;
  String get retry;
  String get noData;
  String get riverLevel;
  String get rainfall;
  String get discharge;
  String get safe;
  String get warning;
  String get danger;
  String get critical;
  String get lastUpdated;
  String get stations;
  String get forecast;
  String get floodRisk;
  String get high;
  String get medium;
  String get low;
  String get settings;
  String get language;
  String get theme;
  String get themeAuto;
  String get themeDay;
  String get themeDark;
  String get themeSunset;
  String get themeOcean;
  String get premiumFilters;
  String get selectTheme;
  String get bihar;
  String get currentLevel;
  String get dangerLevel;
  String get warningLevel;
  String get city;
  String get river;
  String get alerts;
  String get noAlerts;
  String get activeAlerts;
  String get viewAll;
  String get meters;
  String get mmRainfall;
  String get cumecs;
  String get searchCity;
  String get monitoredCities;
  String get liveData;
  String get predictionModel;
  String get accuracy;
  String get confidence;
  String get live;
  String get riskIndex;
  String get allStationsSafe;
  String get fetchingLiveData;
  String get dataSources;
  String get noStationsFound;
  String get rivers;
  String get floodAlerts;
  String get mlModelInfo;
  String get floodPredictionEngine;
  String get stateMatrix;
  String get primaryRivers;
  String get vulnerableDistricts;
  String get sortBy;
  String get fetchingWeather;
  String get riverLevelTrend;
  String get capacity;
  String get buildingTrend;
  String get comingSoon;
  String get monitors;
  String get biharLiveData;
  String get gloFasDischarge;
  String get rainfall24h;
  String get trend;
  String get rising;
  String get falling;
  String get stable;
  String get floodForecast;
  String get hfl;
  String get district;
  String get openCityDetail;
  String get biharRiverGaugeMap;
  String get locateMe;
  String get locationPermissionDenied;
  String get couldNotGetLocation;
  String get allRivers;
  String get noCriticalStations;
  String get criticalStations;
  String get inputParameters;
  String get stateCity;
  String get riverLevelM;
  String get rainfall7d;
  String get dischargeOptional;
  String get runPrediction;
  String get floodPrediction;
  String get mlModelSubtitle;
  String get modelConfidence;
  String get tip;
  String get predictAutoFillTip;
  String get required_;
  String get selectLanguage;
  String get english;
  String get hindi;
  String get appLanguage;
  String get restartRequired;
  String get tabNews;
  String get newsFeedTitle;
  String get imdAlertsTitle;
  String get ndmaAdvisoriesTitle;
  String get officialSources;
  String get noActiveImdAlerts;
  String get noActiveNdmaAdvisories;
  String get imdFloodForecasting;
  String get ndmaAdvisoriesLink;
  String get cwcFloodBulletin;
  String get onboardingSkip;
  String get onboardingNext;
  String get onboardingGetStarted;
  String get onboardingTitle1;
  String get onboardingSubtitle1;
  String get onboardingTitle2;
  String get onboardingSubtitle2;
  String get onboardingTitle3;
  String get onboardingSubtitle3;
  String get onboardingTitle4;
  String get onboardingSubtitle4;
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

  // shouldReload must return true so that when MaterialApp.locale changes,
  // Flutter re-invokes load() and rebuilds all localised widgets.
  @override
  bool shouldReload(_AppLocalizationsDelegate old) => true;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }
  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale".');
}
