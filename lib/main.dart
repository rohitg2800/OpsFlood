import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/flood_providers.dart';
import 'screens/splash_screen.dart';
import 'theme/river_theme.dart';
import 'providers/theme_provider.dart';

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

  // ThemeProvider singleton must be pre-initialised before the first frame
  // so the stored theme preference is applied synchronously.
  await ThemeProvider().init();

  // ProviderScope is the Riverpod container — must wrap the entire app.
  runApp(const ProviderScope(child: EquinoxApp()));
}

// EquinoxApp is now a ConsumerWidget so it can watch Riverpod providers
// directly without a separate ListenableBuilder.
class EquinoxApp extends ConsumerWidget {
  const EquinoxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ref.watch(themeModeProvider) rebuilds MaterialApp ONLY when themeMode
    // changes — not on every notifyListeners() from RealTimeService.
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title:                      'Equinox',
      debugShowCheckedModeBanner: false,
      themeMode:                  themeMode,
      theme:                      RiverColors.lightTheme(),
      darkTheme:                  RiverColors.darkTheme(),
      home:                       const SplashScreen(),
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
