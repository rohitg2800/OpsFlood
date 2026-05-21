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
    return MaterialApp(
      title: 'OpsFlood',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF006C77),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF06101A),
      ),
      home: const SplashScreen(),
    );
  }
}
