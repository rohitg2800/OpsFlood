// lib/app_router.dart
// OpsFlood — Module 15: Central App Router
//
// Single source of truth for all named routes.
// Usage in MaterialApp:
//
//   MaterialApp(
//     navigatorKey: AppRouter.navigatorKey,
//     onGenerateRoute: AppRouter.onGenerateRoute,
//     initialRoute: AppRouter.initial,
//   )
//
// All routes check onboarding state; first-launch redirects
// to /onboarding automatically.

import 'package:flutter/material.dart';

import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/main_shell.dart';
import 'screens/dashboard_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/bihar_river_map_screen.dart';
import 'screens/news_feed_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/notification_settings_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/sos_screen.dart';
import 'screens/evacuation_routes_screen.dart';
import 'screens/evacuation_routes_screen.dart' show EvacuationRoutesScreen;
import 'screens/crowd_report_feed_screen.dart';
import 'screens/analytics_dashboard_screen.dart';
import 'screens/rainfall_forecast_screen.dart';
import 'screens/export_screen.dart';
import 'screens/incident_report_screen.dart';
import 'screens/cwc_station_detail_screen.dart';
import 'screens/river_detail_screen.dart';
import 'screens/historical_analytics_screen.dart';
import 'screens/predict_screen.dart';

// ---------------------------------------------------------------------------
// Route names (const strings — use these everywhere)
// ---------------------------------------------------------------------------

class Routes {
  Routes._();

  static const splash              = '/';
  static const onboarding          = '/onboarding';
  static const shell               = '/shell';
  static const dashboard           = '/dashboard';
  static const alerts              = '/alerts';
  static const map                 = '/map';
  static const news                = '/news';
  static const settings            = '/settings';
  static const notificationSettings = '/notification-settings';
  static const profile             = '/profile';
  static const sos                 = '/sos';
  static const evacuation          = '/evacuation';
  static const crowdReports        = '/crowd-reports';
  static const analytics           = '/analytics';
  static const rainfallForecast    = '/rainfall-forecast';
  static const export_             = '/export';
  static const incidentReport      = '/incident-report';
  static const stationDetail       = '/station';
  static const riverDetail         = '/river';
  static const historicalAnalytics = '/historical-analytics';
  static const predict             = '/predict';
}

// ---------------------------------------------------------------------------
// AppRouter
// ---------------------------------------------------------------------------

class AppRouter {
  AppRouter._();

  static final navigatorKey =
      GlobalKey<NavigatorState>();

  /// Initial route: SplashScreen decides onboarding vs shell.
  static const String initial = Routes.splash;

  static Route<dynamic> onGenerateRoute(
      RouteSettings settings) {
    final uri  = Uri.parse(settings.name ?? '/');
    final path = uri.path;

    // Parse query params (e.g. /shell?tab=2)
    final tab = int.tryParse(
        uri.queryParameters['tab'] ?? '') ?? 0;

    final Widget page = switch (path) {
      Routes.splash    => const SplashScreen(),
      Routes.onboarding => const OnboardingScreen(),
      Routes.shell     => MainShell(initialTab: tab),
      Routes.dashboard => const DashboardScreen(),
      Routes.alerts    => const AlertsScreen(),
      Routes.map       => const BiharRiverMapScreen(),
      Routes.news      => const NewsFeedScreen(),
      Routes.settings  => const SettingsScreen(),
      Routes.notificationSettings =>
          const NotificationSettingsScreen(),
      Routes.profile   => const ProfileScreen(),
      Routes.sos       => const SosScreen(),
      Routes.evacuation => const EvacuationRoutesScreen(),
      Routes.crowdReports => const CrowdReportFeedScreen(),
      Routes.analytics => const AnalyticsDashboardScreen(),
      Routes.rainfallForecast =>
          const RainfallForecastScreen(),
      Routes.export_   => const ExportScreen(),
      Routes.incidentReport =>
          const IncidentReportScreen(),
      Routes.historicalAnalytics =>
          const HistoricalAnalyticsScreen(),
      Routes.predict   => const PredictScreen(),

      // /station/STATION_ID
      _ when path.startsWith('/station/') => () {
          final id = path.replaceFirst('/station/', '');
          return CwcStationDetailScreen(stationId: id);
        }(),

      // /river/RIVER_NAME
      _ when path.startsWith('/river/') => () {
          final name = path.replaceFirst('/river/', '');
          return RiverDetailScreen(riverName: name);
        }(),

      _ => const SplashScreen(),
    };

    return MaterialPageRoute(
      settings: settings,
      builder: (_) => page,
    );
  }

  // --------------------------------------------------
  // Convenience push helpers
  // --------------------------------------------------

  static Future<T?> push<T>(String route,
      {Object? arguments}) =>
      navigatorKey.currentState!.pushNamed<T>(
          route, arguments: arguments);

  static Future<T?> pushReplacement<T>(String route,
      {Object? arguments}) =>
      navigatorKey.currentState!.pushReplacementNamed<T, dynamic>(
          route, arguments: arguments);

  static void pop<T>([T? result]) =>
      navigatorKey.currentState?.pop(result);

  static void popUntilRoot() =>
      navigatorKey.currentState
          ?.popUntil((r) => r.isFirst);
}
