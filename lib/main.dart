// lib/main.dart
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';
import 'models/flood_data.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/monitors_screen.dart';
import 'screens/predict_screen.dart';
import 'screens/prediction_screen.dart';
import 'screens/city_detail_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/sos_screen.dart';
import 'screens/weather_screen.dart';
import 'screens/river_monitor_screen.dart';
import 'screens/river_detail_screen.dart';
import 'screens/state_matrix_screen.dart';
import 'screens/model_info_screen.dart';
import 'screens/manual_predict_screen.dart';
import 'screens/bihar_river_map_screen.dart';
import 'screens/india_river_explorer_screen.dart';
import 'screens/cwc_station_detail_screen.dart';
import 'services/befiqr_cwc_service.dart';
import 'screens/live_stations_screen.dart';
import 'screens/news_feed_screen.dart';
import 'screens/map_screen.dart';
import 'theme/app_theme.dart';
import 'theme/river_theme.dart';
import 'theme/robotic_theme.dart';
import 'providers/theme_provider.dart';

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FCM BG] ${message.notification?.title}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env').catchError((_) {});

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings();
  await _localNotifications.initialize(
    const InitializationSettings(android: androidSettings, iOS: iosSettings),
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ProviderScope(child: FloodWatchApp()));
}

// ─── Root app ─────────────────────────────────────────────────────────────────
// Each AppThemeMode gets its own fully-wired ThemeData that carries the correct
// RiverColors ThemeExtension.  MaterialApp.themeMode selects light vs dark;
// we ensure both slots are filled with the right palette so there is never a
// fallback to the wrong palette regardless of system brightness.
class FloodWatchApp extends ConsumerWidget {
  const FloodWatchApp({super.key});

  // Build a ThemeData for the chosen mode, putting it in BOTH the light and
  // dark slot so Flutter always picks it regardless of ThemeMode.light/dark.
  static ThemeData _themeFor(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return RiverColors.lightTheme();
      case AppThemeMode.dark:
        return RiverColors.darkTheme();
      case AppThemeMode.sunset:
        return RiverColors.sunsetTheme();
      case AppThemeMode.ocean:
        return RiverColors.oceanTheme();
      case AppThemeMode.roboticDark:
        return const RoboticTheme(isDark: true).toThemeData();
      case AppThemeMode.roboticLight:
        return const RoboticTheme(isDark: false).toThemeData();
      case AppThemeMode.system:
        // For system mode provide both light and dark river themes;
        // MaterialApp.themeMode = ThemeMode.system picks the right one.
        return RiverColors.darkTheme(); // placeholder; overridden below
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode          = ref.watch(themeModeProvider);
    final themeNotifier = ref.read(themeModeProvider.notifier);

    // For system mode: provide separate light/dark; for every other mode
    // stuff the same theme in both slots so ThemeMode.light/dark are both
    // correctly served.
    final ThemeData lightSlot;
    final ThemeData darkSlot;

    if (mode == AppThemeMode.system) {
      lightSlot = RiverColors.lightTheme();
      darkSlot  = RiverColors.darkTheme();
    } else {
      final t = _themeFor(mode);
      lightSlot = t;
      darkSlot  = t;
    }

    return MaterialApp(
      title:                  'FloodWatch',
      debugShowCheckedModeBanner: false,
      theme:                  lightSlot,
      darkTheme:              darkSlot,
      themeMode:              themeNotifier.flutterMode,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('hi'),
      ],
      initialRoute: SplashScreen.route,
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case SplashScreen.route:
            return _fade(const SplashScreen());
          case HomeScreen.route:
            return _fade(const HomeScreen());
          case DashboardScreen.route:
            return _fade(const DashboardScreen());
          case AlertsScreen.route:
            return _fade(const AlertsScreen());
          case MonitorsScreen.route:
            return _fade(const MonitorsScreen());
          case PredictScreen.route:
            return _fade(const PredictScreen());
          case PredictionScreen.route:
            return _fade(const PredictionScreen());
          case SettingsScreen.route:
            return _fade(const SettingsScreen());
          case SosScreen.route:
            return _fade(const SosScreen());
          case WeatherScreen.route:
            return _fade(const WeatherScreen());
          case RiverMonitorScreen.route:
            return _fade(const RiverMonitorScreen());
          case StateMatrixScreen.route:
            return _fade(const StateMatrixScreen());
          case ModelInfoScreen.route:
            return _fade(const ModelInfoScreen());
          case ManualPredictScreen.route:
            return _fade(const ManualPredictScreen());
          case BiharRiverMapScreen.route:
            return _fade(const BiharRiverMapScreen());
          case IndiaRiverExplorerScreen.route:
            return _fade(const IndiaRiverExplorerScreen());
          case LiveStationsScreen.route:
            return _fade(const LiveStationsScreen());
          case NewsFeedScreen.route:
            return _fade(const NewsFeedScreen());
          case MapScreen.route:
            return _fade(const MapScreen());
          case '/city_detail':
            final cityName = settings.arguments as String? ?? '';
            return _fade(CityDetailScreen(cityName: cityName));
          case '/river_detail':
            final rdArgs = settings.arguments;
            if (rdArgs is! FloodData) return _fade(const SplashScreen());
            return _fade(RiverDetailScreen(data: rdArgs));
          case '/cwc_station':
            final cwcArgs = settings.arguments;
            if (cwcArgs is! CwcStation) return _fade(const SplashScreen());
            return _fade(CwcStationDetailScreen(station: cwcArgs));
          default:
            return _fade(const SplashScreen());
        }
      },
    );
  }

  PageRoute<T> _fade<T>(Widget page) => PageRouteBuilder<T>(
        pageBuilder:        (_, __, ___) => page,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 220),
      );
}
