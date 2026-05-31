// GENERATED — hand-written stub.
// Run `flutter gen-l10n` to replace this with the real generated file.
// This stub keeps the build green without requiring the codegen step.
//
// FIX: All getters now return the correct locale string via _t().
// Previously every getter was hardcoded English, so changing language
// in Settings had zero visible effect on any screen.
library app_localizations;

export 'package:flutter_localizations/flutter_localizations.dart'
    show
        GlobalCupertinoLocalizations,
        GlobalMaterialLocalizations,
        GlobalWidgetsLocalizations;

import 'dart:ui' show Locale;
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Supported locales exposed as a constant for MaterialApp.supportedLocales.
const List<Locale> kSupportedLocales = [
  Locale('en'),
  Locale('hi'),
];

/// AppLocalizations — returns the correct string for the active locale.
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

  // ── Internal helper: pick string by locale ────────────────────────────────
  String _t(String en, String hi) => localeName == 'hi' ? hi : en;

  // ── Strings ───────────────────────────────────────────────────────────────
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

  // FIX: shouldReload must return true so the delegate re-loads strings
  // when the locale changes at runtime. false meant old English strings
  // were cached and never replaced with Hindi.
  @override
  bool shouldReload(_AppLocalizationsDelegate old) => true;
}
