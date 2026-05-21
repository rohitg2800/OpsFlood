import 'package:flutter/material.dart';

import 'providers/theme_provider.dart';
import 'screens/splash_screen.dart';
import 'services/real_time_service.dart';
import 'theme/river_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        theme:      RiverColors.lightTheme(),
        darkTheme:  RiverColors.darkTheme(),
        home: const SplashScreen(),
      ),
    );
  }
}
