import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'providers/theme_provider.dart';
import 'screens/splash_screen.dart';
import 'services/real_time_service.dart';
import 'theme/river_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force dark mode and Ferrari status bar style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:           Colors.transparent,
    statusBarIconBrightness:  Brightness.light,
    systemNavigationBarColor: AppPalette.carbon0,
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

  await ThemeProvider().init();
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
        title:                    'OpsFlood',
        debugShowCheckedModeBanner: false,
        // Default to dark (Ferrari) theme
        themeMode: ThemeMode.dark,
        theme:     RiverColors.lightTheme(),
        darkTheme:  RiverColors.darkTheme(),
        home:      const SplashScreen(),
        // Smooth page transitions throughout
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
