import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../providers/flood_providers.dart';
import '../services/imd_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

class _GeoResult {
  final String name;
  final String admin1;
  final String country;
  final double lat;
  final double lon;
  const _GeoResult(
      {required this.name,
      required this.admin1,
      required this.country,
      required this.lat,
      required this.lon});
  factory _GeoResult.fromJson(Map<String, dynamic> j) => _GeoResult(
        name: j['name'] ?? '',
        admin1: j['admin1'] ?? '',
        country: j['country'] ?? '',
        lat: (j['latitude'] as num).toDouble(),
        lon: (j['longitude'] as num).toDouble(),
      );
}

class _Weather {
  final double temp;
  final double feelsLike;
  final int humidity;
  final double windSpeed;
  final int weatherCode;
  final double rainfall1h;
  final int uvIndex;
  final double visibility;
  final List<double> hourlyTemp;
  final List<double> hourlyRain;
  final List<DateTime> hourlyTime;
  final List<double> dailyMaxTemp;
  final List<double> dailyMinTemp;
  final List<double> dailyRain;
  final List<DateTime> dailyDate;
  final List<int> dailyCode;

  const _Weather({
    required this.temp,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.weatherCode,
    required this.rainfall1h,
    required this.uvIndex,
    required this.visibility,
    required this.hourlyTemp,
    required this.hourlyRain,
    required this.hourlyTime,
    required this.dailyMaxTemp,
    required this.dailyMinTemp,
    required this.dailyRain,
    required this.dailyDate,
    required this.dailyCode,
  });

  factory _Weather.fromJson(Map<String, dynamic> j) {
    final cur    = j['current'] as Map<String, dynamic>;
    final hourly = j['hourly']  as Map<String, dynamic>;
    final daily  = j['daily']   as Map<String, dynamic>;

    List<double>   hTemp = (hourly['temperature_2m'] as List).map((e) => (e as num).toDouble()).toList();
    List<double>   hRain = (hourly['precipitation']  as List).map((e) => (e as num).toDouble()).toList();
    List<DateTime> hTime = (hourly['time'] as List).map((e) => DateTime.parse(e.toString())).toList();

    final now = DateTime.now();
    int startIdx = hTime.indexWhere((t) => t.isAfter(now.subtract(const Duration(hours: 1))));
    if (startIdx < 0) startIdx = 0;
    final endIdx = math.min(startIdx + 24, hTime.length);
    hTemp = hTemp.sublist(startIdx, endIdx);
    hRain = hRain.sublist(startIdx, endIdx);
    hTime = hTime.sublist(startIdx, endIdx);

    return _Weather(
      temp:        (cur['temperature_2m']       as num).toDouble(),
      feelsLike:   (cur['apparent_temperature'] as num).toDouble(),
      humidity:    (cur['relative_humidity_2m'] as num).toInt(),
      windSpeed:   (cur['wind_speed_10m']       as num).toDouble(),
      weatherCode: (cur['weather_code']         as num).toInt(),
      rainfall1h:  (cur['precipitation']        as num?)?.toDouble() ?? 0.0,
      uvIndex:     (cur['uv_index']             as num?)?.toInt()    ?? 0,
      visibility:  (cur['visibility']           as num?)?.toDouble() ?? 0.0,
      hourlyTemp:  hTemp,
      hourlyRain:  hRain,
      hourlyTime:  hTime,
      dailyMaxTemp: (daily['temperature_2m_max']  as List).map((e) => (e as num).toDouble()).toList(),
      dailyMinTemp: (daily['temperature_2m_min']  as List).map((e) => (e as num).toDouble()).toList(),
      dailyRain:    (daily['precipitation_sum']   as List).map((e) => (e as num).toDouble()).toList(),
      dailyDate:    (daily['time'] as List).map((e) => DateTime.parse(e.toString())).toList(),
      dailyCode:    (daily['weather_code'] as List).map((e) => (e as num).toInt()).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WMO WEATHER CODE → LABEL + ICON
// ─────────────────────────────────────────────────────────────────────────────
String _wmoLabel(int code) {
  if (code == 0)  return 'Clear Sky';
  if (code <= 2)  return 'Partly Cloudy';
  if (code == 3)  return 'Overcast';
  if (code <= 49) return 'Fog';
  if (code <= 59) return 'Drizzle';
  if (code <= 69) return 'Rain';
  if (code <= 79) return 'Snow';
  if (code <= 82) return 'Rain Showers';
  if (code <= 84) return 'Snow Showers';
  if (code == 95) return 'Thunderstorm';
  if (code >= 96) return 'Thunderstorm + Hail';
  return 'Unknown';
}

String _wmoEmoji(int code) {
  if (code == 0)  return '☀️';
  if (code <= 2)  return '⛅';
  if (code == 3)  return '☁️';
  if (code <= 49) return '🌫️';
  if (code <= 69) return '🌧️';
  if (code <= 79) return '❄️';
  if (code <= 82) return '🌦️';
  if (code == 95) return '⛈️';
  if (code >= 96) return '🌩️';
  return '🌡️';
}

// ─────────────────────────────────────────────────────────────────────────────
// IMD RAINFALL CLASSIFICATION
// ─────────────────────────────────────────────────────────────────────────────
_RainfallClass _imdClass(double mm) {
  if (mm < 2.4)   return _RainfallClass.nil;
  if (mm < 15.6)  return _RainfallClass.light;
  if (mm < 64.5)  return _RainfallClass.moderate;
  if (mm < 115.6) return _RainfallClass.heavy;
  if (mm < 204.5) return _RainfallClass.veryHeavy;
  return _RainfallClass.extremely;
}

enum _RainfallClass { nil, light, moderate, heavy, veryHeavy, extremely }

extension _RainfallClassX on _RainfallClass {
  String get label {
    switch (this) {
      case _RainfallClass.nil:       return 'No Rain';
      case _RainfallClass.light:     return 'Light Rain';
      case _RainfallClass.moderate:  return 'Moderate Rain';
      case _RainfallClass.heavy:     return 'Heavy Rain ⚠️';
      case _RainfallClass.veryHeavy: return 'Very Heavy Rain 🚨';
      case _RainfallClass.extremely: return 'Extremely Heavy Rain 🔴';
    }
  }

  Color get color {
    switch (this) {
      case _RainfallClass.nil:       return const Color(0xFF90CAF9);
      case _RainfallClass.light:     return const Color(0xFF42A5F5);
      case _RainfallClass.moderate:  return const Color(0xFF1E88E5);
      case _RainfallClass.heavy:     return const Color(0xFFFB8C00);
      case _RainfallClass.veryHeavy: return const Color(0xFFF4511E);
      case _RainfallClass.extremely: return const Color(0xFFB71C1C);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN  ── ConsumerStatefulWidget (Riverpod-aware)
// ─────────────────────────────────────────────────────────────────────────────
class WeatherScreen extends ConsumerStatefulWidget {
  const WeatherScreen({super.key});
  @override
  ConsumerState<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends ConsumerState<WeatherScreen>
    with TickerProviderStateMixin {
  final _searchCtrl  = TextEditingController();
  final _searchFocus = FocusNode();
  List<_GeoResult> _suggestions  = [];
  bool             _searching     = false;
  Timer?           _debounce;

  _GeoResult? _location;
  _Weather?   _weather;
  bool        _loadingWeather = false;
  String      _weatherError   = '';

  // CWC ticker data — derived from Riverpod liveLevelsProvider
  List<Map<String, dynamic>> _cwcAlerts = [];

  late TabController _chartTabs;

  @override
  void initState() {
    super.initState();
    _chartTabs = TabController(length: 2, vsync: this);
    _loadDefault();
  }

  Future<void> _loadDefault() async {
    const motihari = _GeoResult(
      name: 'Motihari', admin1: 'Bihar',
      country: 'India', lat: 26.6507, lon: 84.9172,
    );
    setState(() => _location = motihari);
    await _fetchWeather(motihari);
    _refreshCwcAlerts();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    _chartTabs.dispose();
    super.dispose();
  }

  // ── CWC alerts now read from the shared Riverpod singleton ────────────────
  void _refreshCwcAlerts() {
    final levels = ref.read(liveLevelsProvider);
    final alerts = levels
        .where((l) => l.riskLevel == 'HIGH' || l.riskLevel == 'CRITICAL')
        .map((l) => {
              'city':     l.city,
              'level':    l.riskLevel,
              'river':    l.riverName ?? 'River',
              'capacity': l.capacityPercent,
            })
        .toList();
    if (mounted) setState(() => _cwcAlerts = alerts);
  }

  Future<void> _onSearchChanged(String q) async {
    _debounce?.cancel();
    if (q.trim().length < 2) { setState(() => _suggestions = []); return; }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _searching = true);
      try {
        final uri = Uri.parse(
          'https://geocoding-api.open-meteo.com/v1/search'
          '?name=${Uri.encodeComponent(q.trim())}'
          '&count=10&language=en&format=json',
        );
        final res = await http.get(uri).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final data    = jsonDecode(res.body) as Map<String, dynamic>;
          final results = (data['results'] as List? ?? [])
              .map((e) => _GeoResult.fromJson(e as Map<String, dynamic>))
              .toList()
            ..sort((a, b) {
              final aIn = a.country.toLowerCase().contains('india') ? 0 : 1;
              final bIn = b.country.toLowerCase().contains('india') ? 0 : 1;
              return aIn.compareTo(bIn);
            });
          if (mounted) setState(() { _suggestions = results; _searching = false; });
        } else {
          if (mounted) setState(() => _searching = false);
        }
      } catch (_) {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  Future<void> _fetchWeather(_GeoResult loc) async {
    setState(() { _loadingWeather = true; _weatherError = ''; _weather = null; });
    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=${loc.lat}&longitude=${loc.lon}'
        '&current=temperature_2m,apparent_temperature,relative_humidity_2m,'
        'wind_speed_10m,weather_code,precipitation,uv_index,visibility'
        '&hourly=temperature_2m,precipitation'
        '&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum'
        '&timezone=Asia%2FKolkata'
        '&forecast_days=7',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final w = _Weather.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
        if (mounted) setState(() { _weather = w; _loadingWeather = false; });
      } else {
        if (mounted) setState(() { _weatherError = 'Weather fetch failed (${res.statusCode})'; _loadingWeather = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _weatherError = 'Network error: $e'; _loadingWeather = false; });
    }
  }

  void _selectSuggestion(_GeoResult r) {
    _searchCtrl.text = '${r.name}, ${r.admin1}';
    _searchFocus.unfocus();
    setState(() { _location = r; _suggestions = []; });
    _fetchWeather(r);
    _refreshCwcAlerts();
  }

  @override
  Widget build(BuildContext context) {
    // ── IMD alerts: reactive via stateImdAlertsProvider ───────────────────
    final imdAlerts = _location != null && _location!.admin1.isNotEmpty
        ? ref.watch(stateImdAlertsProvider(_location!.admin1))
        : <ImdAlert>[];

    return Scaffold(
      backgroundColor: const Color(0xFF05141E),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF07283D), Color(0xFF05141E), Color(0xFF02080E)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _CwcTickerBar(alerts: _cwcAlerts),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: Column(
                  children: [
                    _SearchBar(
                      controller: _searchCtrl,
                      focusNode:  _searchFocus,
                      searching:  _searching,
                      onChanged:  _onSearchChanged,
                    ),
                    if (_suggestions.isNotEmpty)
                      _SuggestionsList(
                        suggestions: _suggestions,
                        onSelect:    _selectSuggestion,
                      ),
                  ],
                ),
              ),
              Expanded(
                child: _loadingWeather
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Color(0xFF0DA7C2)),
                            SizedBox(height: 14),
                            Text('Fetching weather...',
                                style: TextStyle(color: Colors.white60, fontSize: 14)),
                          ],
                        ),
                      )
                    : _weatherError.isNotEmpty
                        ? _ErrorPanel(error: _weatherError)
                        : _weather == null
                            ? const Center(
                                child: Text('Search any city, village or state',
                                    style: TextStyle(color: Colors.white38, fontSize: 15)),
                              )
                            : _WeatherBody(
                                weather:   _weather!,
                                location:  _location!,
                                chartTabs: _chartTabs,
                                imdAlerts: imdAlerts,
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CWC TICKER BAR
// ─────────────────────────────────────────────────────────────────────────────
class _CwcTickerBar extends StatefulWidget {
  final List<Map<String, dynamic>> alerts;
  const _CwcTickerBar({required this.alerts});
  @override
  State<_CwcTickerBar> createState() => _CwcTickerBarState();
}

class _CwcTickerBarState extends State<_CwcTickerBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  static const double _segmentWidth    = 1800.0;
  static const double _pixelsPerSecond = 50.0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(
          milliseconds: (_segmentWidth / _pixelsPerSecond * 1000).round()),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasCritical = widget.alerts.any((a) => a['level'] == 'CRITICAL');
    final bgColor = hasCritical
        ? const Color(0xFFB71C1C).withValues(alpha: 0.85)
        : widget.alerts.isEmpty
            ? const Color(0xFF0D2B3E)
            : const Color(0xFFE65100).withValues(alpha: 0.8);

    final items = widget.alerts.isEmpty
        ? ['✅  CWC Feed: No active flood warnings  •  IMD: Normal conditions  •  Stay prepared during monsoon season']
        : widget.alerts
            .map((a) =>
                '${a['level'] == 'CRITICAL' ? '🔴' : '🟠'}  CWC Alert: ${a['city']} — ${a['river']} at ${(a['capacity'] as double).toStringAsFixed(0)}% capacity [${a['level']}]  •  ')
            .toList();

    final tickerText = '${items.join('   ')}          ${items.join('   ')}';

    return Container(
      height: 34,
      color: bgColor,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            color: Colors.black26,
            child: const Text(
              'CWC',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 1.2),
            ),
          ),
          Expanded(
            child: ClipRect(
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (context, child) => FractionalTranslation(
                  translation: Offset(-_ctrl.value, 0),
                  child: child,
                ),
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  maxWidth: _segmentWidth * 2,
                  maxHeight: 34,
                  child: SizedBox(
                    width: _segmentWidth * 2,
                    height: 34,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        tickerText,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500),
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.clip,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH BAR
// ─────────────────────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode             focusNode;
  final bool                  searching;
  final void Function(String) onChanged;
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.searching,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: TextField(
        controller: controller,
        focusNode:  focusNode,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        onChanged:  onChanged,
        decoration: InputDecoration(
          hintText:  'Search city, village, district, state...',
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
          suffixIcon: searching
              ? const SizedBox(
                  width: 18, height: 18,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                  ))
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUGGESTIONS LIST
// ─────────────────────────────────────────────────────────────────────────────
class _SuggestionsList extends StatelessWidget {
  final List<_GeoResult>          suggestions;
  final void Function(_GeoResult) onSelect;
  const _SuggestionsList({required this.suggestions, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color:        const Color(0xFF0D2232),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics:    const NeverScrollableScrollPhysics(),
        itemCount:  math.min(suggestions.length, 6),
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
        itemBuilder: (_, i) {
          final r       = suggestions[i];
          final isIndia = r.country.toLowerCase().contains('india');
          return ListTile(
            dense:    true,
            leading:  Text(isIndia ? '🇮🇳' : '🌍', style: const TextStyle(fontSize: 18)),
            title:    Text(r.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            subtitle: Text('${r.admin1}${r.admin1.isNotEmpty ? ', ' : ''}${r.country}',
                style: const TextStyle(color: Colors.white54, fontSize: 11)),
            trailing: const Icon(Icons.chevron_right, color: Colors.white38, size: 16),
            onTap: () => onSelect(r),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN WEATHER BODY  ── imdLoading removed (provider is synchronous)
// ─────────────────────────────────────────────────────────────────────────────
class _WeatherBody extends StatelessWidget {
  final _Weather       weather;
  final _GeoResult     location;
  final TabController  chartTabs;
  final List<ImdAlert> imdAlerts;
  const _WeatherBody({
    required this.weather,
    required this.location,
    required this.chartTabs,
    required this.imdAlerts,
  });

  @override
  Widget build(BuildContext context) {
    final rc           = _imdClass(weather.rainfall1h);
    final maxDailyRain = weather.dailyRain.reduce(math.max);
    final highRainDays = weather.dailyRain.where((r) => r >= 64.5).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 30),
      children: [
        if (rc == _RainfallClass.heavy ||
            rc == _RainfallClass.veryHeavy ||
            rc == _RainfallClass.extremely)
          _ImdAlertBanner(rc: rc, locationName: location.name),
        const SizedBox(height: 8),
        _HeroWeatherCard(weather: weather, location: location),
        const SizedBox(height: 14),
        if (highRainDays > 0)
          _RainWarningBanner(days: highRainDays, maxRain: maxDailyRain),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color:        Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border:       Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            children: [
              TabBar(
                controller:              chartTabs,
                labelColor:              const Color(0xFF0DA7C2),
                unselectedLabelColor:    Colors.white54,
                indicatorColor:          const Color(0xFF0DA7C2),
                indicatorSize:           TabBarIndicatorSize.label,
                tabs: const [
                  Tab(text: '24h Temperature'),
                  Tab(text: '7-Day Rainfall'),
                ],
              ),
              SizedBox(
                height: 220,
                child: TabBarView(
                  controller: chartTabs,
                  children: [
                    _HourlyTempChart(weather: weather),
                    _DailyRainfallChart(weather: weather),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _DetailGrid(weather: weather),
        const SizedBox(height: 14),
        _SevenDayForecast(weather: weather),
        const SizedBox(height: 14),
        _OfficialImdAlertsCard(alerts: imdAlerts),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OFFICIAL IMD ALERTS CARD  ── loading spinner removed (provider is sync)
// ─────────────────────────────────────────────────────────────────────────────
class _OfficialImdAlertsCard extends StatelessWidget {
  final List<ImdAlert> alerts;
  const _OfficialImdAlertsCard({required this.alerts});

  Color _severityColor(String s) {
    switch (s) {
      case 'RED':    return const Color(0xFFB71C1C);
      case 'ORANGE': return const Color(0xFFF4511E);
      case 'YELLOW': return const Color(0xFFFBC02D);
      default:       return const Color(0xFF43A047);
    }
  }

  String _severityEmoji(String s) {
    switch (s) {
      case 'RED':    return '🔴';
      case 'ORANGE': return '🟠';
      case 'YELLOW': return '🟡';
      default:       return '🟢';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                const Text('🌦', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Official IMD Alerts',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0DA7C2).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFF0DA7C2).withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    'IMD',
                    style: TextStyle(
                        color: Color(0xFF0DA7C2),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.07)),
          if (alerts.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
              child: Row(
                children: [
                  const Text('ℹ️', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No active official IMD alerts for this state.\n'
                      'Backend endpoint /api/imd/alerts not yet live.',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 12),
                    ),
                  ),
                ],
              ),
            )
          else
            ...alerts.map((alert) {
              final color = _severityColor(alert.severity);
              final emoji = _severityEmoji(alert.severity);
              return Container(
                margin: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:        color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border:       Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alert.title,
                            style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w700,
                                fontSize: 12),
                          ),
                          if (alert.district.isNotEmpty)
                            Text(
                              alert.district,
                              style: const TextStyle(
                                  color: Colors.white60, fontSize: 11),
                            ),
                          if (alert.message.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                alert.message,
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 11),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          if (alert.rainfallMm > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '💧 ${alert.rainfallMm.toStringAsFixed(0)} mm expected',
                                style: TextStyle(
                                    color: color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        alert.severity,
                        style: TextStyle(
                            color: color,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5),
                      ),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Text(
              'Source: India Meteorological Department (IMD) via OpsFlood proxy',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.25),
                  fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// IMD ALERT BANNER
// ─────────────────────────────────────────────────────────────────────────────
class _ImdAlertBanner extends StatelessWidget {
  final _RainfallClass rc;
  final String         locationName;
  const _ImdAlertBanner({required this.rc, required this.locationName});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color:        rc.color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: rc.color.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Text(rc == _RainfallClass.extremely ? '🔴' : '🟠',
              style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('IMD Warning — $locationName',
                    style: TextStyle(color: rc.color, fontWeight: FontWeight.bold, fontSize: 13)),
                Text(rc.label,
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO WEATHER CARD
// ─────────────────────────────────────────────────────────────────────────────
class _HeroWeatherCard extends StatelessWidget {
  final _Weather   weather;
  final _GeoResult location;
  const _HeroWeatherCard({required this.weather, required this.location});

  @override
  Widget build(BuildContext context) {
    final rc = _imdClass(weather.rainfall1h);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF0A3B52), Color(0xFF05141E)],
        ),
        border:    Border.all(color: const Color(0xFF0DA7C2).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color:      const Color(0xFF0DA7C2).withValues(alpha: 0.08),
            blurRadius: 24, spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: Color(0xFF0DA7C2), size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${location.name}, ${location.admin1}',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13,
                      fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                DateFormat('dd MMM, HH:mm').format(DateTime.now()),
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_wmoEmoji(weather.weatherCode),
                  style: const TextStyle(fontSize: 56)),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${weather.temp.toStringAsFixed(1)}°C',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 46,
                        fontWeight: FontWeight.w200, height: 1.0),
                  ),
                  Text(_wmoLabel(weather.weatherCode),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 16,
                          fontWeight: FontWeight.w400)),
                  const SizedBox(height: 4),
                  Text('Feels like ${weather.feelsLike.toStringAsFixed(1)}°C',
                      style: const TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (weather.rainfall1h > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color:        rc.color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
                border:       Border.all(color: rc.color.withValues(alpha: 0.5)),
              ),
              child: Text(
                '${weather.rainfall1h.toStringAsFixed(1)} mm/h  •  ${rc.label}',
                style: TextStyle(color: rc.color, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 24H TEMPERATURE LINE CHART
// ─────────────────────────────────────────────────────────────────────────────
class _HourlyTempChart extends StatelessWidget {
  final _Weather weather;
  const _HourlyTempChart({required this.weather});

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (var i = 0; i < weather.hourlyTemp.length; i++) {
      spots.add(FlSpot(i.toDouble(), weather.hourlyTemp[i]));
    }
    final minY = (weather.hourlyTemp.reduce(math.min) - 2).floorToDouble();
    final maxY = (weather.hourlyTemp.reduce(math.max) + 2).ceilToDouble();

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      child: LineChart(
        LineChartData(
          minY: minY, maxY: maxY,
          clipData: const FlClipData.all(),
          gridData: FlGridData(
            show: true, drawVerticalLine: false,
            horizontalInterval: 5,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: Colors.white.withValues(alpha: 0.07), strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true, reservedSize: 36,
                getTitlesWidget: (v, _) => Text('${v.toInt()}°',
                    style: const TextStyle(color: Colors.white54, fontSize: 10)),
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true, interval: 6,
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= weather.hourlyTime.length) return const SizedBox.shrink();
                  return Text(
                    DateFormat('HH:mm').format(weather.hourlyTime[idx]),
                    style: const TextStyle(color: Colors.white38, fontSize: 9),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots, isCurved: true,
              color: const Color(0xFFFFA726), barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFFFA726).withValues(alpha: 0.3),
                    const Color(0xFFFFA726).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 7-DAY RAINFALL BAR CHART
// ─────────────────────────────────────────────────────────────────────────────
class _DailyRainfallChart extends StatelessWidget {
  final _Weather weather;
  const _DailyRainfallChart({required this.weather});

  @override
  Widget build(BuildContext context) {
    final bars = weather.dailyRain.asMap().entries.map((e) {
      final rc = _imdClass(e.value);
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: e.value, color: rc.color, width: 18,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ],
      );
    }).toList();

    final maxY = math.max(weather.dailyRain.reduce(math.max) + 20, 80.0).ceilToDouble();

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      child: BarChart(
        BarChartData(
          maxY: maxY, barGroups: bars,
          gridData: FlGridData(
            show: true, drawVerticalLine: false, horizontalInterval: 20,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: Colors.white.withValues(alpha: 0.07), strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true, reservedSize: 34, interval: 20,
                getTitlesWidget: (v, _) => Text('${v.toInt()}',
                    style: const TextStyle(color: Colors.white38, fontSize: 9)),
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= weather.dailyDate.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(DateFormat('E').format(weather.dailyDate[idx]),
                        style: const TextStyle(color: Colors.white54, fontSize: 10)),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: 64.5, color: const Color(0xFFFB8C00),
                strokeWidth: 1.4, dashArray: [5, 5],
                label: HorizontalLineLabel(
                  show: true, alignment: Alignment.topRight,
                  labelResolver: (_) => ' Heavy ▶',
                  style: const TextStyle(
                      color: Color(0xFFFB8C00), fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
              HorizontalLine(
                y: 115.6, color: const Color(0xFFF4511E),
                strokeWidth: 1.4, dashArray: [5, 5],
                label: HorizontalLineLabel(
                  show: true, alignment: Alignment.topRight,
                  labelResolver: (_) => ' V.Heavy ▶',
                  style: const TextStyle(
                      color: Color(0xFFF4511E), fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                '${rod.toY.toStringAsFixed(1)} mm',
                const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DETAIL GRID
// ─────────────────────────────────────────────────────────────────────────────
class _DetailGrid extends StatelessWidget {
  final _Weather weather;
  const _DetailGrid({required this.weather});

  String _uvLabel(int uv) {
    if (uv <= 2)  return '$uv (Low)';
    if (uv <= 5)  return '$uv (Moderate)';
    if (uv <= 7)  return '$uv (High)';
    if (uv <= 10) return '$uv (Very High)';
    return '$uv (Extreme)';
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      _DetailItem(Icons.water_drop, 'Humidity',    '${weather.humidity}%'),
      _DetailItem(Icons.air,        'Wind Speed',  '${weather.windSpeed.toStringAsFixed(1)} km/h'),
      _DetailItem(Icons.wb_sunny,   'UV Index',    _uvLabel(weather.uvIndex)),
      _DetailItem(Icons.visibility, 'Visibility',  '${(weather.visibility / 1000).toStringAsFixed(1)} km'),
    ];
    return Column(
      children: [
        Row(children: [
          Expanded(child: _DetailCard(item: items[0])),
          const SizedBox(width: 10),
          Expanded(child: _DetailCard(item: items[1])),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _DetailCard(item: items[2])),
          const SizedBox(width: 10),
          Expanded(child: _DetailCard(item: items[3])),
        ]),
      ],
    );
  }
}

class _DetailItem {
  final IconData icon;
  final String   label;
  final String   value;
  const _DetailItem(this.icon, this.label, this.value);
}

class _DetailCard extends StatelessWidget {
  final _DetailItem item;
  const _DetailCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color:        Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(item.icon, color: const Color(0xFF0DA7C2), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
                const SizedBox(height: 2),
                Text(item.value, style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RAIN WARNING BANNER
// ─────────────────────────────────────────────────────────────────────────────
class _RainWarningBanner extends StatelessWidget {
  final int    days;
  final double maxRain;
  const _RainWarningBanner({required this.days, required this.maxRain});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color:        const Color(0xFFF4511E).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: const Color(0xFFF4511E).withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Text('🚨', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$days day${days > 1 ? 's' : ''} of heavy rain forecast  •  Peak: ${maxRain.toStringAsFixed(1)} mm',
              style: const TextStyle(
                  color: Color(0xFFF4511E), fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 7-DAY FORECAST LIST
// ─────────────────────────────────────────────────────────────────────────────
class _SevenDayForecast extends StatelessWidget {
  final _Weather weather;
  const _SevenDayForecast({required this.weather});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: List.generate(weather.dailyDate.length, (i) {
          final rc      = _imdClass(weather.dailyRain[i]);
          final isToday = i == 0;
          return Container(
            decoration: BoxDecoration(
              border: i < weather.dailyDate.length - 1
                  ? Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.07)))
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 42,
                  child: Text(
                    isToday ? 'Today' : DateFormat('E').format(weather.dailyDate[i]),
                    style: TextStyle(
                        color: isToday ? const Color(0xFF0DA7C2) : Colors.white70,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                        fontSize: 12),
                  ),
                ),
                Text(_wmoEmoji(weather.dailyCode[i]),
                    style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_wmoLabel(weather.dailyCode[i]),
                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                      overflow: TextOverflow.ellipsis),
                ),
                if (weather.dailyRain[i] >= 2.4)
                  Container(
                    margin:  const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color:        rc.color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${weather.dailyRain[i].toStringAsFixed(0)}mm',
                      style: TextStyle(color: rc.color, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ),
                Text(
                  '${weather.dailyMaxTemp[i].toStringAsFixed(0)}° / ${weather.dailyMinTemp[i].toStringAsFixed(0)}°',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ERROR PANEL
// ─────────────────────────────────────────────────────────────────────────────
class _ErrorPanel extends StatelessWidget {
  final String error;
  const _ErrorPanel({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, color: Colors.white38, size: 48),
            const SizedBox(height: 16),
            Text(error,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
