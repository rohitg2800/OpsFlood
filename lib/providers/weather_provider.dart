// lib/providers/weather_provider.dart
// OpsFlood — WeatherProvider v7
// Primary:  api.open-meteo.com  (free, no key)
// Fallback: wttr.in             (completely separate service)
// Location: geolocator — device GPS on startup + manual 📍 button
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

class WeatherCurrent {
  final double tempC;
  final int    humidity;
  final double precipMm;
  final double windKph;
  final double windDir;
  final int    weatherCode;
  final double feelsLikeC;
  final double uvIndex;
  final double visibilityKm;
  final double cloudCoverPct;
  final double surfacePressure;
  const WeatherCurrent({
    required this.tempC,
    required this.humidity,
    required this.precipMm,
    required this.windKph,
    required this.windDir,
    required this.weatherCode,
    required this.feelsLikeC,
    required this.uvIndex,
    required this.visibilityKm,
    required this.cloudCoverPct,
    required this.surfacePressure,
  });

  factory WeatherCurrent.fromJson(Map<String, dynamic> j) => WeatherCurrent(
    tempC:           (j['temperature_2m']         as num?)?.toDouble() ?? 0,
    humidity:        (j['relative_humidity_2m']   as num?)?.toInt()    ?? 0,
    precipMm:        (j['precipitation']          as num?)?.toDouble() ?? 0,
    windKph:         (j['wind_speed_10m']         as num?)?.toDouble() ?? 0,
    windDir:         (j['wind_direction_10m']     as num?)?.toDouble() ?? 0,
    weatherCode:     (j['weathercode']            as num?)?.toInt()    ?? 0,
    feelsLikeC:      (j['apparent_temperature']   as num?)?.toDouble() ?? 0,
    uvIndex:         (j['uv_index']               as num?)?.toDouble() ?? 0,
    visibilityKm:    (j['visibility']             as num?)?.toDouble() ?? 0,
    cloudCoverPct:   (j['cloud_cover']            as num?)?.toDouble() ?? 0,
    surfacePressure: (j['surface_pressure']       as num?)?.toDouble() ?? 0,
  );

  factory WeatherCurrent.fromWttrJson(Map<String, dynamic> j) {
    final cur = (j['current_condition'] as List?)?.first as Map<String, dynamic>? ?? {};
    return WeatherCurrent(
      tempC:           double.tryParse(cur['temp_C']?.toString()        ?? '0') ?? 0,
      humidity:        int.tryParse(cur['humidity']?.toString()         ?? '0') ?? 0,
      precipMm:        double.tryParse(cur['precipMM']?.toString()      ?? '0') ?? 0,
      windKph:         double.tryParse(cur['windspeedKmph']?.toString() ?? '0') ?? 0,
      windDir:         double.tryParse(cur['winddirDegree']?.toString() ?? '0') ?? 0,
      weatherCode:     _wttrCode(int.tryParse(cur['weatherCode']?.toString() ?? '0') ?? 0),
      feelsLikeC:      double.tryParse(cur['FeelsLikeC']?.toString()   ?? '0') ?? 0,
      uvIndex:         double.tryParse(cur['uvIndex']?.toString()       ?? '0') ?? 0,
      visibilityKm:    double.tryParse(cur['visibility']?.toString()    ?? '0') ?? 0,
      cloudCoverPct:   double.tryParse(cur['cloudcover']?.toString()   ?? '0') ?? 0,
      surfacePressure: double.tryParse(cur['pressure']?.toString()     ?? '0') ?? 0,
    );
  }

  static int _wttrCode(int w) {
    if (w == 113) return 0;
    if (w == 116) return 1;
    if (w == 119 || w == 122) return 3;
    if (w >= 176 && w <= 266) return 61;
    if (w >= 293 && w <= 321) return 61;
    if (w >= 353 && w <= 395) return 80;
    if (w >= 200 && w <= 232) return 95;
    return 1;
  }
}

class WeatherDay {
  final String date;
  final double maxC;
  final double minC;
  final double rainMm;
  final double precipProb;
  final double windMaxKph;
  final double uvIndex;
  final int    weatherCode;
  const WeatherDay({
    required this.date, required this.maxC, required this.minC,
    required this.rainMm, required this.precipProb,
    required this.windMaxKph, required this.uvIndex,
    required this.weatherCode,
  });

  factory WeatherDay.fromWttrJson(Map<String, dynamic> d) {
    final hourly = (d['hourly'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    double totalRain = 0; double maxWind = 0; int wCode = 0;
    for (final h in hourly) {
      totalRain += double.tryParse(h['precipMM']?.toString()      ?? '0') ?? 0;
      final w    = double.tryParse(h['windspeedKmph']?.toString() ?? '0') ?? 0;
      if (w > maxWind) maxWind = w;
      wCode = int.tryParse(h['weatherCode']?.toString() ?? '0') ?? 0;
    }
    return WeatherDay(
      date:        d['date']?.toString() ?? '',
      maxC:        double.tryParse(d['maxtempC']?.toString() ?? '0') ?? 0,
      minC:        double.tryParse(d['mintempC']?.toString() ?? '0') ?? 0,
      rainMm:      totalRain,
      precipProb:  0,
      windMaxKph:  maxWind,
      uvIndex:     double.tryParse(d['uvIndex']?.toString()  ?? '0') ?? 0,
      weatherCode: WeatherCurrent._wttrCode(wCode),
    );
  }
}

class CityResult {
  final String name;
  final String admin1;
  final String country;
  final double lat;
  final double lon;
  const CityResult({
    required this.name, required this.admin1, required this.country,
    required this.lat, required this.lon,
  });
  String get displayName =>
      admin1.isNotEmpty ? '$name, $admin1' : '$name, $country';

  factory CityResult.fromJson(Map<String, dynamic> j) => CityResult(
    name:    j['name']      as String? ?? '',
    admin1:  j['admin1']    as String? ?? '',
    country: j['country']   as String? ?? '',
    lat:     (j['latitude'] as num).toDouble(),
    lon:     (j['longitude'] as num).toDouble(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

enum WeatherStatus { idle, loading, loaded, error }

class WeatherState {
  final WeatherStatus    status;
  final String           cityName;
  final double           lat;
  final double           lon;
  final WeatherCurrent?  current;
  final List<WeatherDay> forecast;
  final List<CityResult> searchResults;
  final bool             searchLoading;
  final String           error;
  final bool             isRateLimited;
  final int              retryInSeconds;
  /// true while GPS is being acquired
  final bool             locating;

  double get tempC        => current?.tempC    ?? 0;
  double get precipMm     => current?.precipMm ?? 0;
  double get rainfall7dMm =>
      forecast.fold(0.0, (s, d) => s + d.rainMm);
  double get rainfallIndex  => (rainfall7dMm / 3.5).clamp(0, 100);
  double get maxPrecipProb  =>
      forecast.isEmpty ? 0 : forecast
          .map((d) => d.precipProb)
          .reduce((a, b) => a > b ? a : b);
  int    get humidity     => current?.humidity ?? 0;
  double get windKph      => current?.windKph  ?? 0;

  const WeatherState({
    this.status         = WeatherStatus.idle,
    this.cityName       = 'Patna, Bihar',
    this.lat            = 25.5941,
    this.lon            = 85.1376,
    this.current,
    this.forecast       = const [],
    this.searchResults  = const [],
    this.searchLoading  = false,
    this.error          = '',
    this.isRateLimited  = false,
    this.retryInSeconds = 0,
    this.locating       = false,
  });

  WeatherState copyWith({
    WeatherStatus?    status,
    String?           cityName,
    double?           lat,
    double?           lon,
    WeatherCurrent?   current,
    List<WeatherDay>? forecast,
    List<CityResult>? searchResults,
    bool?             searchLoading,
    String?           error,
    bool?             isRateLimited,
    int?              retryInSeconds,
    bool?             locating,
  }) => WeatherState(
    status:         status         ?? this.status,
    cityName:       cityName       ?? this.cityName,
    lat:            lat            ?? this.lat,
    lon:            lon            ?? this.lon,
    current:        current        ?? this.current,
    forecast:       forecast       ?? this.forecast,
    searchResults:  searchResults  ?? this.searchResults,
    searchLoading:  searchLoading  ?? this.searchLoading,
    error:          error          ?? this.error,
    isRateLimited:  isRateLimited  ?? this.isRateLimited,
    retryInSeconds: retryInSeconds ?? this.retryInSeconds,
    locating:       locating       ?? this.locating,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

class WeatherNotifier extends Notifier<WeatherState> {
  DateTime? _lastFetchTime;
  double?   _lastFetchLat;
  double?   _lastFetchLon;
  Timer?    _countdownTimer;
  int       _retrySeconds = 0;

  static const _cacheDuration    = Duration(minutes: 15);
  static const _rateLimitBackoff = Duration(minutes: 5);

  @override
  WeatherState build() {
    // Try GPS first; fall back to default Patna coords
    Future.microtask(useDeviceLocation);
    return const WeatherState();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GPS / device location
  // ─────────────────────────────────────────────────────────────────────────

  /// Acquire GPS → reverse-geocode city name → fetch weather.
  /// Called automatically on open and when user taps 📍.
  Future<void> useDeviceLocation() async {
    state = state.copyWith(locating: true);
    try {
      // 1. Check service enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (kDebugMode) debugPrint('WeatherNotifier: GPS service disabled');
        state = state.copyWith(locating: false);
        await fetchWeather(); // fall back to default coords
        return;
      }

      // 2. Check / request permission
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (kDebugMode) debugPrint('WeatherNotifier: location permission denied');
        state = state.copyWith(locating: false);
        await fetchWeather();
        return;
      }

      // 3. Get position (try last-known first for speed)
      Position? pos = await Geolocator.getLastKnownPosition();
      pos ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final lat = pos.latitude;
      final lon = pos.longitude;

      // 4. Reverse-geocode → human-readable city name
      final city = await _reverseGeocode(lat, lon);

      state = state.copyWith(
        lat:      lat,
        lon:      lon,
        cityName: city,
        locating: false,
      );
      _lastFetchTime = null; // force fresh fetch
      await fetchWeather();
    } catch (e) {
      if (kDebugMode) debugPrint('WeatherNotifier: GPS error: $e');
      state = state.copyWith(locating: false);
      await fetchWeather();
    }
  }

  /// Open-Meteo reverse-geocoding via their free API
  Future<String> _reverseGeocode(double lat, double lon) async {
    try {
      // Open-Meteo doesn't do reverse geocoding directly;
      // use Nominatim (OpenStreetMap) — free, no key, rate limit 1 req/s
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=$lat&lon=$lon&format=json&accept-language=en',
      );
      final res = await http.get(
        uri,
        headers: {'User-Agent': 'OpsFlood/1.0 (flood monitoring app)'},
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final j       = jsonDecode(res.body) as Map<String, dynamic>;
        final addr    = j['address'] as Map<String, dynamic>? ?? {};
        final city    = addr['city']      as String?
                     ?? addr['town']      as String?
                     ?? addr['village']   as String?
                     ?? addr['county']    as String?
                     ?? 'My Location';
        final state_  = addr['state']     as String? ?? '';
        final parts   = [city, if (state_.isNotEmpty) state_];
        return parts.join(', ');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('WeatherNotifier: reverseGeocode error: $e');
    }
    return 'My Location (${lat.toStringAsFixed(2)}°, ${lon.toStringAsFixed(2)}°)';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Cache helpers
  // ─────────────────────────────────────────────────────────────────────────

  bool _isCacheValid() {
    if (_lastFetchTime == null) return false;
    if (_lastFetchLat != state.lat || _lastFetchLon != state.lon) return false;
    return DateTime.now().difference(_lastFetchTime!) < _cacheDuration;
  }

  void _startCountdown(int seconds) {
    _retrySeconds = seconds;
    _countdownTimer?.cancel();
    state = state.copyWith(retryInSeconds: _retrySeconds);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      _retrySeconds--;
      if (_retrySeconds <= 0) {
        t.cancel();
        state = state.copyWith(retryInSeconds: 0, isRateLimited: false);
        fetchWeather();
      } else {
        state = state.copyWith(retryInSeconds: _retrySeconds);
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Open-Meteo fetch
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> _tryOpenMeteo(double lat, double lon) async {
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$lat&longitude=$lon'
      '&current=temperature_2m,relative_humidity_2m,precipitation,weathercode,'
      'wind_speed_10m,wind_direction_10m,apparent_temperature,'
      'uv_index,visibility,cloud_cover,surface_pressure'
      '&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,'
      'precipitation_probability_max,wind_speed_10m_max,uv_index_max,weathercode'
      '&forecast_days=7&timezone=Asia%2FKolkata',
    );
    if (kDebugMode) debugPrint('WeatherNotifier: trying Open-Meteo');
    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return false;
    final body  = jsonDecode(res.body) as Map<String, dynamic>;
    final cur   = WeatherCurrent.fromJson(
        body['current'] as Map<String, dynamic>? ?? {});
    final daily = body['daily'] as Map<String, dynamic>? ?? {};
    final dates = (daily['time']                          as List?)?.cast<String>()  ?? [];
    final maxT  = (daily['temperature_2m_max']            as List?)?.cast<num>()    ?? [];
    final minT  = (daily['temperature_2m_min']            as List?)?.cast<num>()    ?? [];
    final rains = (daily['precipitation_sum']             as List?)?.cast<num?>()   ?? [];
    final probs = (daily['precipitation_probability_max'] as List?)?.cast<num?>()   ?? [];
    final winds = (daily['wind_speed_10m_max']            as List?)?.cast<num?>()   ?? [];
    final uvs   = (daily['uv_index_max']                  as List?)?.cast<num?>()   ?? [];
    final codes = (daily['weathercode']                   as List?)?.cast<num?>()   ?? [];

    final forecast = List.generate(dates.length, (i) => WeatherDay(
      date:        dates[i],
      maxC:        (maxT.elementAtOrNull(i)  ?? 0).toDouble(),
      minC:        (minT.elementAtOrNull(i)  ?? 0).toDouble(),
      rainMm:      (rains.elementAtOrNull(i) ?? 0)?.toDouble() ?? 0,
      precipProb:  (probs.elementAtOrNull(i) ?? 0)?.toDouble() ?? 0,
      windMaxKph:  (winds.elementAtOrNull(i) ?? 0)?.toDouble() ?? 0,
      uvIndex:     (uvs.elementAtOrNull(i)   ?? 0)?.toDouble() ?? 0,
      weatherCode: (codes.elementAtOrNull(i) ?? 0)?.toInt()   ?? 0,
    ));

    _applySuccess(lat, lon, cur, forecast);
    return true;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // wttr.in fallback
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> _tryWttr(double lat, double lon) async {
    final uri = Uri.parse('https://wttr.in/$lat,$lon?format=j2');
    if (kDebugMode) debugPrint('WeatherNotifier: trying wttr.in fallback');
    final res = await http
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) return false;
    final body     = jsonDecode(res.body) as Map<String, dynamic>;
    final cur      = WeatherCurrent.fromWttrJson(body);
    final weather  = (body['weather'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final forecast = weather.map(WeatherDay.fromWttrJson).toList();
    _applySuccess(lat, lon, cur, forecast);
    if (kDebugMode) debugPrint('WeatherNotifier: wttr.in success');
    return true;
  }

  void _applySuccess(double lat, double lon,
      WeatherCurrent cur, List<WeatherDay> forecast) {
    _lastFetchTime = DateTime.now();
    _lastFetchLat  = lat;
    _lastFetchLon  = lon;
    state = state.copyWith(
      status:         WeatherStatus.loaded,
      current:        cur,
      forecast:       forecast,
      error:          '',
      isRateLimited:  false,
      retryInSeconds: 0,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // City search
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> searchCity(String query) async {
    if (query.trim().isEmpty) {
      state = state.copyWith(searchResults: [], searchLoading: false);
      return;
    }
    state = state.copyWith(searchLoading: true);
    try {
      final uri = Uri.parse(
        'https://geocoding-api.open-meteo.com/v1/search'
        '?name=${Uri.encodeComponent(query)}&count=6&language=en&format=json',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final body    = jsonDecode(res.body) as Map<String, dynamic>;
        final results = (body['results'] as List? ?? [])
            .cast<Map<String, dynamic>>()
            .map(CityResult.fromJson)
            .toList();
        state = state.copyWith(searchResults: results, searchLoading: false);
      } else {
        state = state.copyWith(searchResults: [], searchLoading: false);
      }
    } catch (e) {
      state = state.copyWith(searchResults: [], searchLoading: false);
      if (kDebugMode) debugPrint('WeatherNotifier.searchCity error: $e');
    }
  }

  Future<void> selectCity(CityResult city) async {
    _countdownTimer?.cancel();
    state = state.copyWith(
      cityName:      city.displayName,
      lat:           city.lat,
      lon:           city.lon,
      searchResults: [],
      isRateLimited: false,
      retryInSeconds: 0,
    );
    _lastFetchTime = null;
    await fetchWeather();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Main fetch
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> fetchWeather({bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheValid() && state.status == WeatherStatus.loaded) {
      if (kDebugMode) debugPrint('WeatherNotifier: cache hit');
      return;
    }
    if (state.isRateLimited && !forceRefresh) return;

    state = state.copyWith(
      status:        WeatherStatus.loading,
      error:         '',
      isRateLimited: false,
    );

    final lat = state.lat;
    final lon = state.lon;

    try {
      if (await _tryOpenMeteo(lat, lon)) return;
      if (await _tryWttr(lat, lon)) return;
    } catch (e) {
      if (kDebugMode) debugPrint('WeatherNotifier: unexpected error: $e');
    }

    state = state.copyWith(
      status:        WeatherStatus.error,
      error:         'Weather unavailable. Auto-retrying in 5 min…',
      isRateLimited: true,
    );
    _startCountdown(_rateLimitBackoff.inSeconds);
  }

  void clearSearch() =>
      state = state.copyWith(searchResults: []);
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final weatherProvider = NotifierProvider<WeatherNotifier, WeatherState>(
  WeatherNotifier.new,
);
