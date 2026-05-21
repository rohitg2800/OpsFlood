import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';
import 'services/real_time_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RealTimeService().initialize();
  runApp(const OpsFloodApp());
}

class OpsFloodApp extends StatelessWidget {
  const OpsFloodApp({super.key});

  @override
  Widget build(BuildContext context) {
    final lightColorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF006C77),
      brightness: Brightness.light,
    );

    final darkColorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF00151A),
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: 'OpsFlood',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: lightColorScheme,
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: darkColorScheme,
        scaffoldBackgroundColor: const Color(0xFF06101A),
      ),
      home: const SplashScreen(),
    );
  }
}
