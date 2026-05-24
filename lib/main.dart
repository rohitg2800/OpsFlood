import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'providers/flood_providers.dart';
import 'providers/theme_provider.dart';
import 'screens/alerts_screen.dart';
import 'screens/splash_screen.dart';
import 'services/background_service.dart';
import 'services/fcm_service.dart';
import 'services/pipeline_service.dart';
import 'services/threshold_alert_service.dart';
import 'theme/river_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Defer first frame until all async init completes.
  WidgetsBinding.instance.deferFirstFrame();

  // Load .env — gracefully handles missing file in production.
  try {
    await dotenv.load(fileName: '.env', mergeWith: {});
  } catch (e) {
    if (kDebugMode) debugPrint('\u26a0\ufe0f  .env not found — running with defaults: $e');
  }

  // Firebase — skip on web (no web config); guard against duplicate-app init.
  if (!kIsWeb) {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  }

  if (!kIsWeb) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor:                    Colors.transparent,
      statusBarIconBrightness:           Brightness.light,
      systemNavigationBarColor:          AppPalette.navy0,  // was: AppPalette.carbon0
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // Global error handlers.
  FlutterError.onError = (FlutterErrorDetails details) {
    if (kDebugMode) {
      FlutterError.presentError(details);
      debugPrint('\u274c FlutterError: ${details.summary}');
    }
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    if (kDebugMode) debugPrint('\u274c PlatformDispatcher: $error\n$stack');
    return true;
  };

  await ThemeProvider().init();

  // ── Background services (native only — not supported on web) ─────────────────────────
  if (!kIsWeb) {
    // 1. State severity matrix — fetched once, cached 1 hour.
    unawaited(
      PipelineService.instance.init().catchError((e) {
        if (kDebugMode) debugPrint('\u26a0\ufe0f  PipelineService.init failed: $e');
      }),
    );

    // 2. FCM — request push-notification permissions and register device token.
    unawaited(
      FcmService.instance.init().catchError((e) {
        if (kDebugMode) debugPrint('\u26a0\ufe0f  FcmService.init failed: $e');
      }),
    );

    // 3. Workmanager background tasks — keep-alive ping + 15-min data refresh.
    unawaited(
      BackgroundService.init().catchError((e) {
        if (kDebugMode) debugPrint('\u26a0\ufe0f  BackgroundService.init failed: $e');
      }),
    );

    // 4. Threshold alert engine — polls GloFAS every 15 min for all 93 cities
    //    + 31 Bihar gauges; fires local FCM notifications on ≥ Warning breach.
    unawaited(
      ThresholdAlertService.instance.start().catchError((e) {
        if (kDebugMode) debugPrint('\u26a0\ufe0f  ThresholdAlertService.start failed: $e');
      }),
    );
  }

  WidgetsBinding.instance.allowFirstFrame();

  runApp(const ProviderScope(child: OpsFloodApp()));
}

class OpsFloodApp extends ConsumerWidget {
  const OpsFloodApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title:                      'OpsFlood',
      debugShowCheckedModeBanner: false,
      themeMode:                  themeMode,
      theme:                      RiverColors.lightTheme(),
      darkTheme:                  RiverColors.darkTheme(),
      home:                       const SplashScreen(),
      routes: {
        AlertsScreen.route: (_) => const AlertsScreen(),
      },
      // Clamp text scale — prevents overflow on accessibility large-text settings.
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
    );
  }
}
