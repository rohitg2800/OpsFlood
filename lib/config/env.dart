class AppEnvironment {
  static const bool isProduction = true;
  static const bool useMockData = false;
  
  // Directly targeting public distribution telemetry portals
  static const String apiBaseUrl = const String.fromEnvironment(
    'API_BASE_URL', 
    defaultValue: 'https://gdacs.org/',
  );
}
