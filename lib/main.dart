import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'providers/flood_providers.dart';
import 'providers/locale_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/alerts_screen.dart';
import 'screens/splash_screen.dart';
import 'services/fcm_service.dart';
import 'services/local_cache_service.dart';
import 'services/threshold_alert_service.dart';
import 'theme/river_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  WidgetsBinding.instance.deferFirstFrame();

  try {
    // 1. Load .env
    try {
      await dotenv.load(fileName: '.env', mergeWith: {});
    } catch (e) {
      if (kDebugMode) debugPrint('\u26a0\ufe0f  .env not found \u2014 running with defaults: $e');
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
              if (kDebugMode) debugPrint('\u26a0\ufe0f  Firebase.initializeApp timed out \u2014 continuing without Firebase');
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

    // 5. Theme + locale
    await ThemeProvider().init();

    // 6. Essential services
    if (!kIsWeb) {
      await LocalCacheService.instance.init().catchError((e) {
        if (kDebugMode) debugPrint('\u26a0\ufe0f  LocalCacheService.init failed: $e');
      });

      unawaited(
        FcmService.instance.init().catchError((e) {
          if (kDebugMode) debugPrint('\u26a0\ufe0f  FcmService.init failed: $e');
        }),
      );

      unawaited(
        ThresholdAlertService.instance.start().catchError((e) {
          if (kDebugMode) debugPrint('\u26a0\ufe0f  ThresholdAlertService.start failed: $e');
        }),
      );
    }
  } finally {
    WidgetsBinding.instance.allowFirstFrame();
  }

  runApp(const ProviderScope(child: EquinoxBHApp()));
}

class EquinoxBHApp extends ConsumerWidget {
  const EquinoxBHApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use AppThemeMode from theme_provider (owns the full enum incl. sunset/ocean).
    // themeModeProvider in flood_providers.dart has been removed to avoid the
    // duplicate-export conflict.
    final appMode = ref.watch(themeNotifierProvider);
    final locale  = ref.watch(localeProvider);

    // Switch expression — Dart sees exhaustiveness, so flutterMode is always assigned.
    final ThemeMode flutterMode = switch (appMode) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light  => ThemeMode.light,
      AppThemeMode.dark   => ThemeMode.dark,
      AppThemeMode.sunset => ThemeMode.light,
      AppThemeMode.ocean  => ThemeMode.dark,
    };

    return MaterialApp(
      title:                      'EQUINOX-BH',
      debugShowCheckedModeBanner: false,
      themeMode:                  flutterMode,
      theme:                      RiverColors.lightTheme(),
      darkTheme:                  RiverColors.darkTheme(),
      locale:                     locale,
      supportedLocales:           kSupportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home:   const SplashScreen(),
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
