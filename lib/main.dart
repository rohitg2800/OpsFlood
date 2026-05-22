import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'providers/theme_provider.dart';
import 'screens/splash_screen.dart';
import 'theme/river_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FIX #1: RealTimeService.startPolling() is NO LONGER called here.
//         It is called in SplashScreen.initState() AFTER runApp(), so
//         notifyListeners() always fires into a live widget tree.
// ─────────────────────────────────────────────────────────────────────────────
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force dark mode and Ferrari status bar style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:                    Colors.transparent,
    statusBarIconBrightness:           Brightness.light,
    systemNavigationBarColor:          AppPalette.carbon0,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Lock to portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (kDebugMode) debugPrint('\u274c FlutterError: ${details.summary}');
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    if (kDebugMode) debugPrint('\u274c PlatformDispatcher: $error');
    return true;
  };

  // FIX #1: Load ThemeProvider ONLY — no polling yet.
  // RealTimeService is started inside SplashScreen.initState().
  await ThemeProvider().init();

  runApp(const OpsFloodApp());
}

class OpsFloodApp extends StatelessWidget {
  const OpsFloodApp({super.key});

  @override
  Widget build(BuildContext context) {
    // FIX #2 + #3: Use ListenableBuilder scoped only to ThemeProvider.
    //   - ListenableBuilder replaces AnimatedBuilder to avoid rebuilding
    //     the entire MaterialApp on every unrelated ChangeNotifier call.
    //   - themeMode now reads ThemeProvider().mode instead of being
    //     hardcoded to ThemeMode.dark.
    return ListenableBuilder(
      listenable: ThemeProvider(),
      builder: (_, __) => MaterialApp(
        title:                    'OpsFlood',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeProvider().mode,          // FIX #3: live from provider
        theme:     RiverColors.lightTheme(),
        darkTheme:  RiverColors.darkTheme(),
        home:      const SplashScreen(),
        builder: (context, child) {
          // Prevent font scaling beyond 1.2x so labels never overflow
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(
              textScaler: TextScaler.linear(
                mq.textScaler.scale(1.0).clamp(0.8, 1.2),
              ),
            ),
            child: child!,
          );
        },
      ),
    );
  }
}
