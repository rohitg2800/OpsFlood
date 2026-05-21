import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'providers/theme_provider.dart';
import 'screens/splash_screen.dart';
import 'services/real_time_service.dart';
import 'theme/river_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (kReleaseMode) {
      // e.g. FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    }
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    if (kDebugMode) {
      debugPrint('\u274c PlatformDispatcher.onError: $error\n$stack');
    }
    return true;
  };

  await ThemeProvider().init();

  // startPolling() calls initialize() internally, then begins the 5-min
  // periodic refresh loop.  The dashboard listens via addListener() and
  // rebuilds automatically on every new telemetry snapshot.
  await RealTimeService().startPolling();

  runApp(const OpsFloodApp());
}

class OpsFloodApp extends StatelessWidget {
  const OpsFloodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeProvider(),
      builder: (_, __) => MaterialApp(
        title: 'OpsFlood',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeProvider().mode,
        theme:     RiverColors.lightTheme(),
        darkTheme:  RiverColors.darkTheme(),
        home: const SplashScreen(),
      ),
    );
  }
}
