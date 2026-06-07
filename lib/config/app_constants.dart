class AppConstants {
  // ── Flood level defaults ──────────────────────────────────────────────────
  static const double defaultWarningLevel = 8.0;
  static const double defaultDangerLevel  = 10.0;

  // ── Monitored cities ─────────────────────────────────────────────────────
  static const List<String> monitoredCities = [
    'Patna', 'Varanasi', 'Allahabad', 'Lucknow',
    'Gorakhpur', 'Gaya', 'Bhagalpur', 'Munger',
  ];

  // ── Base URL
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://opsflood-api.onrender.com',
  );

  // ── HTTP client defaults ──────────────────────────────────────────────────
  static const Duration defaultTimeout = Duration(seconds: 30);
  static const Duration shortTimeout   = Duration(seconds: 10);
  static const Duration retryDelay     = Duration(seconds: 2);
  static const int      maxRetries     = 3;
}
