import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'providers/theme_provider.dart';
import 'screens/splash_screen.dart';
import 'services/real_time_service.dart';
import 'theme/river_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Global Flutter framework error handler ──────────────────────────────
  // Catches widget-build errors, overflow, missing assets etc.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details); // prints in debug, logs in release
    // In release builds you could forward to a crash reporter here.
    if (kReleaseMode) {
      // e.g. FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    }
  };

  // ── Catches async errors that escape the Flutter framework ─────────────
  // e.g. Future.error(), Zone errors, isolate errors in release mode.
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    if (kDebugMode) {
      debugPrint('❌ PlatformDispatcher.onError: $error\n$stack');
    }
    // In release builds forward to a crash reporter here.
    return true; // mark as handled so Flutter doesn't also print
  };

  await ThemeProvider().init();
  await RealTimeService().initialize();
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
