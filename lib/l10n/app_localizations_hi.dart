// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
/// 100% complete — every key from AppLocalizations is overridden.
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  // ── App / Navigation ──────────────────────────────────────────────────
  @override String get appTitle               => 'EQUINOX-BR05';
  @override String get tabHome                => 'होम';
  @override String get tabMonitors            => 'निगरानी';
  @override String get tabAlerts              => 'अलर्ट';
  @override String get tabPredict             => 'पूर्वानुमान';
  @override String get tabMap                 => 'नक्शा';
  @override String get tabDashboard           => 'डैशबोर्ड';
  @override String get tabSettings            => 'सेटिंग्स';
  @override String get tabNews                => 'समाचार';

  // ── General UI ───────────────────────────────────────────────────────
  @override String get loading                => 'लोड हो रहा है…';
  @override String get retry                  => 'पुनः प्रयास';
  @override String get noData                 => 'कोई डेटा उपलब्ध नहीं';
  @override String get comingSoon             => 'जल्द आएगा';
  @override String get viewAll                => 'सभी देखें';
  @override String get sortBy                 => 'क्रम दें:';
  @override String get required_              => 'आवश्यक है';
  @override String get required               => 'आवश्यक';
  @override String get tip                    => 'सुझाव';
  @override String get live                   => 'लाइव';
  @override String get liveData               => 'लाइव डेटा';

  // ── Flood status ─────────────────────────────────────────────────────
  @override String get safe                   => 'सुरक्षित';
  @override String get warning               => 'चेतावनी';
  @override String get danger                => 'खतरा';
  @override String get critical              => 'अत्यंत खतरनाक';
  @override String get high                  => 'उच्च';
  @override String get medium                => 'मध्यम';
  @override String get low                   => 'कम';
  @override String get riskIndex             => 'जोखिम सूचकांक';
  @override String get floodRisk             => 'बाढ़ का खतरा';
  @override String get floodAlerts           => 'बाढ़ अलर्ट';
  @override String get floodForecast         => 'बाढ़ पूर्वानुमान';
  @override String get floodPrediction       => 'बाढ़ पूर्वानुमान';
  @override String get floodPredictionEngine => 'बाढ़ पूर्वानुमान इंजन';
  @override String get allStationsSafe       => 'सभी स्टेशन सुरक्षित स्तर में';
  @override String get noCriticalStations    => 'सब सुरक्षित';
  @override String get criticalStations      => 'अत्यंत खतरनाक';

  // ── River / Water data ───────────────────────────────────────────────
  @override String get riverLevel            => 'नदी स्तर';
  @override String get riverLevelM           => 'नदी स्तर (मी)';
  @override String get riverLevelTrend       => '24-घंटे नदी स्तर रुझान';
  @override String get rainfall              => 'वर्षा';
  @override String get rainfall24h           => '24 घंटे की वर्षा';
  @override String get rainfall7d            => '7 दिन की वर्षा (मिमी)';
  @override String get discharge             => 'प्रवाह';
  @override String get dischargeOptional     => 'प्रवाह मी³/से (वैकल्पिक)';
  @override String get currentLevel          => 'वर्तमान स्तर';
  @override String get dangerLevel           => 'खतरे का स्तर';
  @override String get warningLevel          => 'चेतावनी स्तर';
  @override String get hfl                   => 'अधिकतम बाढ़ स्तर';
  @override String get capacity              => 'क्षमता';
  @override String get trend                 => 'रुझान';
  @override String get rising               => 'बढ़ रही है';
  @override String get falling              => 'घट रही है';
  @override String get stable               => 'स्थिर';
  @override String get buildingTrend        => 'रुझान बन रहा है…';
  @override String get gloFasDischarge      => 'GloFAS प्रवाह';
  @override String get biharLiveData        => 'बिहार लाइव डेटा';
  @override String get dataSources          => 'CWC  •  GloFAS  •  IMD  •  Open-Meteo';

  // ── Stations / Monitors ──────────────────────────────────────────────
  @override String get stations             => 'स्टेशन';
  @override String get noStationsFound      => 'कोई स्टेशन नहीं मिला।';
  @override String get monitors             => 'निगरानी';
  @override String get monitoredCities      => 'निगरानी शहर';
  @override String get lastUpdated          => 'अंतिम अपडेट';
  @override String get fetchingLiveData     => 'लाइव बाढ़ डेटा लोड हो रहा है…';
  @override String get fetchingWeather      => 'लाइव मौसम लोड हो रहा है…';
  @override String get allStationsSafe      => 'सभी स्टेशन सुरक्षित स्तर में';

  // ── Geography ────────────────────────────────────────────────────────
  @override String get bihar                => 'बिहार';
  @override String get city                 => 'शहर';
  @override String get river                => 'नदी';
  @override String get rivers               => 'नदियाँ';
  @override String get district             => 'जिला';
  @override String get allRivers            => 'सभी';
  @override String get primaryRivers        => 'प्रमुख नदियाँ';
  @override String get vulnerableDistricts  => 'संवेदनशील जिले';
  @override String get stateMatrix          => 'राज्य मैट्रिक्स';
  @override String get stateCity            => 'राज्य / शहर';
  @override String get biharRiverGaugeMap   => 'बिहार नदी गेज नक्शा';

  // ── Forecast / Prediction ────────────────────────────────────────────
  @override String get forecast             => 'पूर्वानुमान';
  @override String get predictionModel      => 'पूर्वानुमान मॉडल';
  @override String get accuracy             => 'सटीकता';
  @override String get confidence           => 'विश्वास स्तर';
  @override String get mlModelInfo          => 'ML मॉडल जानकारी';
  @override String get mlModelSubtitle      => 'ML मॉडल · जोखिम स्तर + विश्वास';
  @override String get modelConfidence      => 'मॉडल विश्वास स्तर';
  @override String get inputParameters      => 'इनपुट पैरामीटर';
  @override String get runPrediction        => 'पूर्वानुमान चलाएं';
  @override String get predictAutoFillTip   => 'शहर विवरण स्क्रीन से नेविगेट करें और नदी स्तर व शहर का नाम स्वतः भर जाएगा।';

  // ── Alerts ───────────────────────────────────────────────────────────
  @override String get alerts               => 'अलर्ट';
  @override String get noAlerts             => 'कोई सक्रिय अलर्ट नहीं';
  @override String get activeAlerts         => 'सक्रिय अलर्ट';

  // ── Map ──────────────────────────────────────────────────────────────
  @override String get locateMe                  => 'मेरी स्थिति पर केंद्रित करें';
  @override String get locationPermissionDenied  => 'स्थान अनुमति अस्वीकृत';
  @override String get couldNotGetLocation       => 'स्थान प्राप्त नहीं हो सका';
  @override String get openCityDetail            => 'शहर विवरण खोलें';

  // ── Settings ─────────────────────────────────────────────────────────
  @override String get settings             => 'सेटिंग्स';
  @override String get language             => 'भाषा';
  @override String get theme                => 'थीम';
  @override String get themeAuto            => 'स्वतः';
  @override String get themeDay             => 'दिन नदी';
  @override String get themeDark            => 'रात नदी';
  @override String get themeSunset          => 'सूर्यास्त';
  @override String get themeOcean           => 'गहरा सागर';
  @override String get premiumFilters       => 'प्रीमियम फ़िल्टर';
  @override String get selectTheme          => 'थीम चुनें';
  @override String get selectLanguage       => 'भाषा चुनें';
  @override String get english              => 'अंग्रेज़ी';
  @override String get hindi                => 'हिन्दी';
  @override String get appLanguage          => 'ऐप भाषा';
  @override String get restartRequired      => 'भाषा अपडेट हो गई';

  // ── Units ────────────────────────────────────────────────────────────
  @override String get meters               => 'मी';
  @override String get mmRainfall           => 'मिमी';
  @override String get cumecs               => 'क्यूमेक्स';

  // ── Search ───────────────────────────────────────────────────────────
  @override String get searchCity           => 'शहर खोजें…';

  // ── News ─────────────────────────────────────────────────────────────
  @override String get newsFeedTitle             => 'बाढ़ समाचार और सलाह';
  @override String get imdAlertsTitle            => 'IMD अलर्ट';
  @override String get ndmaAdvisoriesTitle       => 'NDMA सलाहकार';
  @override String get officialSources           => 'आधिकारिक स्रोत';
  @override String get noActiveImdAlerts         => 'कोई सक्रिय IMD अलर्ट नहीं';
  @override String get noActiveNdmaAdvisories    => 'कोई सक्रिय NDMA सलाह नहीं';
  @override String get imdFloodForecasting       => 'IMD बाढ़ पूर्वानुमान';
  @override String get ndmaAdvisoriesLink        => 'NDMA सलाहकार';
  @override String get cwcFloodBulletin          => 'CWC बाढ़ बुलेटिन';

  // ── Onboarding ───────────────────────────────────────────────────────
  @override String get onboardingSkip            => 'छोड़ें';
  @override String get onboardingNext            => 'आगे';
  @override String get onboardingGetStarted      => 'शुरू करें';
  @override String get onboardingTitle1          => 'रियल-टाइम बाढ़\nजानकारी';
  @override String get onboardingSubtitle1       => 'बिहार WRD गेज स्टेशन, GloFAS डिस्चार्ज और IMD वर्षा से लाइव डेटा — हर कुछ मिनट में अपडेट।';
  @override String get onboardingTitle2          => 'इंटरैक्टिव\nनदी नक्शा';
  @override String get onboardingSubtitle2       => 'बिहार नदियों में रंग-कोडित जोखिम पिन। किसी भी स्टेशन पर टैप करें और वर्तमान स्तर बनाम खतरे की सीमा तुरंत देखें।';
  @override String get onboardingTitle3          => 'ML बाढ़\nपूर्वानुमान';
  @override String get onboardingSubtitle3       => 'नदी स्तर और वर्षा दर्ज करें और तुरंत AI जोखिम मूल्यांकन पाएं: सुरक्षित, चेतावनी, खतरा या अत्यंत खतरनाक।';
  @override String get onboardingTitle4          => 'SOS और\nआपातकालीन सहायता';
  @override String get onboardingSubtitle4       => 'एक-टैप SOS से हेल्पलाइन, निकासी मार्गदर्शन और आपातकालीन सहायता तक त्वरित पहुँच।';
}
