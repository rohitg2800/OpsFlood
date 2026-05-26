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
import 'services/all_india_alert_engine.dart';
import 'services/background_service.dart';
import 'services/fcm_service.dart';
import 'services/local_cache_service.dart';
import 'services/offline_rule_engine.dart';
import 'services/pipeline_service.dart';
import 'services/threshold_alert_service.dart';
import 'theme/river_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Defer first frame so splash renders before heavy init.
  WidgetsBinding.instance.deferFirstFrame();

  try {
    // 1. Load .env
    try {
      await dotenv.load(fileName: '.env', mergeWith: {});
    } catch (e) {
      if (kDebugMode) debugPrint('\u26a0\ufe0f  .env not found — running with defaults: $e');
    }

    // 2. Firebase
    if (!kIsWeb) {
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          ).timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              if (kDebugMode) debugPrint('\u26a0\ufe0f  Firebase.initializeApp timed out — continuing without Firebase');
              throw TimeoutException('Firebase init timeout');
            },
          );
        }
      } catch (e) {
        if (kDebugMode) debugPrint('\u26a0\ufe0f  Firebase init failed (non-fatal): $e');
      }
    }

    // 3. System chrome
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

    // 4. Global error handlers
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

    // 5. Theme
    await ThemeProvider().init();

    // 6. Background services — all fire-and-forget
    if (!kIsWeb) {
      // 6a. LocalCacheService must be ready before OfflineRuleEngine starts.
      await LocalCacheService.instance.init().catchError((e) {
        if (kDebugMode) debugPrint('\u26a0\ufe0f  LocalCacheService.init failed: $e');
      });

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

      // 6b. All-India alert engine (5-min polling for all states/cities)
      unawaited(
        AllIndiaAlertEngine().start().catchError((e) {
          if (kDebugMode) debugPrint('\u26a0\ufe0f  AllIndiaAlertEngine.start failed: $e');
        }),
      );

      // 6c. Offline rule engine — evaluates cached data even with no network.
      //     init() sets up local notifications, then start() runs immediately
      //     and every 5 minutes thereafter.
      unawaited(
        OfflineRuleEngine.instance.init().then((_) {
          OfflineRuleEngine.instance.start();
        }).catchError((e) {
          if (kDebugMode) debugPrint('\u26a0\ufe0f  OfflineRuleEngine init/start failed: $e');
        }),
      );
    }
  } finally {
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
