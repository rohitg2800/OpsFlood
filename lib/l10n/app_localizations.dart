// GENERATED — hand-written stub.
// Run `flutter gen-l10n` to replace with the real generated file.
library app_localizations;

export 'package:flutter_localizations/flutter_localizations.dart'
    show
        GlobalCupertinoLocalizations,
        GlobalMaterialLocalizations,
        GlobalWidgetsLocalizations;

import 'dart:ui' show Locale;
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

const List<Locale> kSupportedLocales = [
  Locale('en'),
  Locale('hi'),
];

class AppLocalizations {
  AppLocalizations(this.localeName);
  final String localeName;

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      AppLocalizations('en');

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  String _t(String en, String hi) => localeName == 'hi' ? hi : en;

  // ── Original keys ────────────────────────────────────────────────────────────
  String get appTitle        => _t('EQUINOX-BH',          'इक्विनॉक्स-बीएच');
  String get tabHome         => _t('Home',                 'होम');
  String get tabMonitors     => _t('Monitors',             'निगरानी');
  String get tabAlerts       => _t('Alerts',               'अलर्ट');
  String get tabPredict      => _t('Predict',              'पूर्वानुमान');
  String get tabMap          => _t('Map',                  'नक्शा');
  String get loading         => _t('Loading…',             'लोड हो रहा है…');
  String get retry           => _t('Retry',                'पुनः प्रयास');
  String get noData          => _t('No data available',    'कोई डेटा उपलब्ध नहीं');
  String get riverLevel      => _t('River Level',          'नदी स्तर');
  String get rainfall        => _t('Rainfall',             'वर्षा');
  String get discharge       => _t('Discharge',            'प्रवाह');
  String get safe            => _t('Safe',                 'सुरक्षित');
  String get warning         => _t('Warning',              'चेतावनी');
  String get danger          => _t('Danger',               'खतरा');
  String get critical        => _t('Critical',             'अत्यंत खतरनाक');
  String get lastUpdated     => _t('Last updated',         'अंतिम अपडेट');
  String get stations        => _t('Stations',             'स्टेशन');
  String get forecast        => _t('Forecast',             'पूर्वानुमान');
  String get floodRisk       => _t('Flood Risk',           'बाढ़ का खतरा');
  String get high            => _t('High',                 'उच्च');
  String get medium          => _t('Medium',               'मध्यम');
  String get low             => _t('Low',                  'कम');
  String get settings        => _t('Settings',             'सेटिंग्स');
  String get language        => _t('Language',             'भाषा');
  String get theme           => _t('Theme',                'थीम');
  String get themeAuto       => _t('Auto',                 'स्वतः');
  String get themeDay        => _t('Day River',            'दिन नदी');
  String get themeDark       => _t('Night River',          'रात नदी');
  String get themeSunset     => _t('Sunset Warm',          'सूर्यास्त');
  String get themeOcean      => _t('Deep Ocean',           'गहरा सागर');
  String get premiumFilters  => _t('Premium Filters',      'प्रीमियम फ़िल्टर');
  String get selectTheme     => _t('Select Theme',         'थीम चुनें');
  String get bihar           => _t('Bihar',                'बिहार');
  String get currentLevel    => _t('Current Level',        'वर्तमान स्तर');
  String get dangerLevel     => _t('Danger Level',         'खतरे का स्तर');
  String get warningLevel    => _t('Warning Level',        'चेतावनी स्तर');
  String get city            => _t('City',                 'शहर');
  String get river           => _t('River',                'नदी');
  String get alerts          => _t('Alerts',               'अलर्ट');
  String get noAlerts        => _t('No active alerts',     'कोई सक्रिय अलर्ट नहीं');
  String get activeAlerts    => _t('Active Alerts',        'सक्रिय अलर्ट');
  String get viewAll         => _t('View All',             'सभी देखें');
  String get meters          => _t('m',                    'मी');
  String get mmRainfall      => _t('mm',                   'मिमी');
  String get cumecs          => _t('cumecs',               'क्यूमेक्स');
  String get searchCity      => _t('Search city…',         'शहर खोजें…');
  String get monitoredCities => _t('Monitored Cities',     'निगरानी शहर');
  String get liveData        => _t('Live Data',            'लाइव डेटा');
  String get predictionModel => _t('Prediction Model',     'पूर्वानुमान मॉडल');
  String get accuracy        => _t('Accuracy',             'सटीकता');
  String get confidence      => _t('Confidence',           'विश्वास स्तर');

  // ── New keys (from grep audit) ──────────────────────────────────────────────────
  String get live                => _t('LIVE',                          'लाइव');
  String get riskIndex           => _t('RISK INDEX',                    'जोखिम सूचकांक');
  String get allStationsSafe     => _t('All stations within safe levels', 'सभी स्टेशन सुरक्षित स्तर में');
  String get fetchingLiveData    => _t('Fetching live flood data…',      'लाइव बाढ़ डेटा लोड हो रहा है…');
  String get dataSources         => _t('CWC  •  GloFAS  •  IMD  •  Open-Meteo', 'CWC  •  GloFAS  •  IMD  •  Open-Meteo');
  String get noStationsFound     => _t('No stations found.',             'कोई स्टेशन नहीं मिला।');
  String get rivers              => _t('Rivers',                        'नदियाँ');
  String get floodAlerts         => _t('Flood Alerts',                  'बाढ़ अलर्ट');
  String get mlModelInfo         => _t('ML Model Info',                 'ML मॉडल जानकारी');
  String get floodPredictionEngine => _t('Flood Prediction Engine',     'बाढ़ पूर्वानुमान इंजन');
  String get stateMatrix         => _t('State Matrix',                  'राज्य मैट्रिक्स');
  String get primaryRivers       => _t('Primary Rivers',               'प्रमुख नदियाँ');
  String get vulnerableDistricts => _t('Vulnerable Districts',          'संवेदनशील जिले');
  String get sortBy              => _t('Sort by:',                      'क्रम दें:');
  String get fetchingWeather     => _t('Fetching live weather…',        'लाइव मौसम लोड हो रहा है…');
  String get riverLevelTrend     => _t('24-hr River Level Trend',       '24-घंटे नदी स्तर रुझान');
  String get capacity            => _t('capacity',                      'क्षमता');
  String get buildingTrend       => _t('Building trend…',               'रुझान बन रहा है…');
  String get comingSoon          => _t('Coming soon',                   'जल्द आएगा');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      kSupportedLocales.any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => true;
}
