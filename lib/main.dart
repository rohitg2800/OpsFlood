import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'providers/theme_provider.dart';
import 'screens/splash_screen.dart';
import 'theme/river_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RealTimeService.startPolling() is NOT called here.
// It is called in SplashScreen.initState() AFTER runApp(), so
// notifyListeners() always fires into a live widget tree.
// ─────────────────────────────────────────────────────────────────────────────
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:                    Colors.transparent,
    statusBarIconBrightness:           Brightness.light,
    systemNavigationBarColor:          AppPalette.carbon0,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

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

  await ThemeProvider().init();

  runApp(const EquinoxApp());
}

class EquinoxApp extends StatelessWidget {
  const EquinoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeProvider(),
      builder: (_, __) => MaterialApp(
        title:                      'Equinox',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeProvider().mode,
        theme:     RiverColors.lightTheme(),
        darkTheme:  RiverColors.darkTheme(),
        home:      const SplashScreen(),
        builder: (context, child) {
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
