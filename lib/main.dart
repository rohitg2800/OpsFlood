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

  // Defer first frame. IMPORTANT: allowFirstFrame() is called in a finally
  // block below so it is ALWAYS reached — even if any init step throws/hangs.
  WidgetsBinding.instance.deferFirstFrame();

  try {
    // 1. Load .env — gracefully handles missing file in production.
    try {
      await dotenv.load(fileName: '.env', mergeWith: {});
    } catch (e) {
      if (kDebugMode) debugPrint('\u26a0\ufe0f  .env not found — running with defaults: $e');
    }

    // 2. Firebase — skip on web; guard with 5-second timeout so a slow
    //    Google-Play-Services response never freezes the splash screen.
    if (!kIsWeb) {
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          ).timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              if (kDebugMode) debugPrint('\u26a0\ufe0f  Firebase.initializeApp timed out — continuing without Firebase');
              // Return a dummy app instance or just swallow; the app works
              // without Firebase on first cold start.
              throw TimeoutException('Firebase init timeout');
            },
          );
        }
      } catch (e) {
        // Firebase failure is non-fatal — FCM / Firestore features degrade
        // gracefully; GloFAS flood data still loads.
        if (kDebugMode) debugPrint('\u26a0\ufe0f  Firebase init failed (non-fatal): $e');
      }
    }

    // 3. System chrome — nav bar matches Midnight Ops background.
    if (!kIsWeb) {
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor:                    Colors.transparent,
        statusBarIconBrightness:           Brightness.light,
        systemNavigationBarColor:          AppPalette.navy0,
        systemNavigationBarIconBrightness: Brightness.light,
      ));

      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }

    // 4. Global error handlers.
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

    // 5. Theme — load persisted light/dark preference from SharedPreferences.
    await ThemeProvider().init();

    // 6. Background services — all fire-and-forget; never block the UI.
    if (!kIsWeb) {
      unawaited(
        PipelineService.instance.init().catchError((e) {
          if (kDebugMode) debugPrint('\u26a0\ufe0f  PipelineService.init failed: $e');
        }),
      );
      unawaited(
        FcmService.instance.init().catchError((e) {
          if (kDebugMode) debugPrint('\u26a0\ufe0f  FcmService.init failed: $e');
        }),
      );
      unawaited(
        BackgroundService.init().catchError((e) {
          if (kDebugMode) debugPrint('\u26a0\ufe0f  BackgroundService.init failed: $e');
        }),
      );
      unawaited(
        ThresholdAlertService.instance.start().catchError((e) {
          if (kDebugMode) debugPrint('\u26a0\ufe0f  ThresholdAlertService.start failed: $e');
        }),
      );
    }
  } finally {
    // ALWAYS unblock the Flutter engine — even if something above threw.
    WidgetsBinding.instance.allowFirstFrame();
  }

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
