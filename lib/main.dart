import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/flood_providers.dart';
import 'screens/splash_screen.dart';
import 'theme/river_theme.dart';
import 'providers/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Preload image cache and enable shader warm-up.
  // Reduces first-frame jank on lower-end devices.
  WidgetsBinding.instance.deferFirstFrame();

  // Load .env — gracefully handles missing file in production.
  try {
    await dotenv.load(fileName: '.env', mergeWith: {});
  } catch (e) {
    if (kDebugMode) debugPrint('⚠️  .env not found — running with defaults: $e');
  }

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

  // Only surface errors in debug; swallow in release to avoid user-visible crashes.
  FlutterError.onError = (FlutterErrorDetails details) {
    if (kDebugMode) {
      FlutterError.presentError(details);
      debugPrint('❌ FlutterError: ${details.summary}');
    }
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    if (kDebugMode) debugPrint('❌ PlatformDispatcher: $error\n$stack');
    return true; // prevents OS from killing the app
  };

  await ThemeProvider().init();

  WidgetsBinding.instance.allowFirstFrame();

  runApp(const ProviderScope(child: EquinoxApp()));
}

class EquinoxApp extends ConsumerWidget {
  const EquinoxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title:                      'Equinox',
      debugShowCheckedModeBanner: false,
      themeMode:                  themeMode,
      theme:                      RiverColors.lightTheme(),
      darkTheme:                  RiverColors.darkTheme(),
      home:                       const SplashScreen(),
      // Clamp text scaling — prevents overflow on accessibility large-text.
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
