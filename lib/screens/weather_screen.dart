import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../services/real_time_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
class _GeoResult {
  final String name, admin1, country;
  final double lat, lon;
  const _GeoResult({
    required this.name, required this.admin1, required this.country,
    required this.lat,  required this.lon,
  });
  factory _GeoResult.fromJson(Map<String, dynamic> j) => _GeoResult(
    name:    j['name']    ?? '',
    admin1:  j['admin1']  ?? '',
    country: j['country'] ?? '',
    lat:     (j['latitude']  as num).toDouble(),
    lon:     (j['longitude'] as num).toDouble(),
  );
}

class _Weather {
  final double temp, feelsLike, windSpeed, rainfall1h, visibility;
  final int    humidity, weatherCode, uvIndex;
  final List<double>   hourlyTemp, hourlyRain;
  final List<DateTime> hourlyTime;
  final List<double>   dailyMaxTemp, dailyMinTemp, dailyRain;
  final List<DateTime> dailyDate;
  final List<int>      dailyCode;

  const _Weather({
    required this.temp, required this.feelsLike, required this.humidity,
    required this.windSpeed, required this.weatherCode, required this.rainfall1h,
    required this.uvIndex, required this.visibility,
    required this.hourlyTemp, required this.hourlyRain, required this.hourlyTime,
    required this.dailyMaxTemp, required this.dailyMinTemp, required this.dailyRain,
    required this.dailyDate, required this.dailyCode,
  });

  factory _Weather.fromJson(Map<String, dynamic> j) {
    final cur    = j['current']  as Map<String, dynamic>;
    final hourly = j['hourly']   as Map<String, dynamic>;
    final daily  = j['daily']    as Map<String, dynamic>;

    // ---- parse hourly arrays ------------------------------------------------
    final allTime = (hourly['time'] as List)
        .map((e) => DateTime.parse(e.toString())).toList();
    final allTemp = _dbl(hourly['temperature_2m']);
    final allRain = _dbl(hourly['precipitation']);
    final allUv   = _dbl(hourly['uv_index']);
    final allVis  = _dbl(hourly['visibility']);

    // Slice to next 24 h from now
    final now      = DateTime.now();
    int startIdx   = allTime.indexWhere((t) => !t.isBefore(now.subtract(const Duration(hours: 1))));
    if (startIdx < 0) startIdx = 0;
    final endIdx   = math.min(startIdx + 24, allTime.length);

    // UV & visibility at the current hour (or closest)
    final curHourIdx = allTime.indexWhere((t) =>
        t.year  == now.year  && t.month == now.month &&
        t.day   == now.day   && t.hour  == now.hour);
    final uvNow  = curHourIdx >= 0 && allUv.length > curHourIdx ? allUv[curHourIdx]  : 0.0;
    final visNow = curHourIdx >= 0 && allVis.length > curHourIdx ? allVis[curHourIdx] : 0.0;

    return _Weather(
      temp:        (cur['temperature_2m']       as num).toDouble(),
      feelsLike:   (cur['apparent_temperature'] as num).toDouble(),
      humidity:    (cur['relative_humidity_2m'] as num).toInt(),
      windSpeed:   (cur['wind_speed_10m']       as num).toDouble(),
      weatherCode: (cur['weather_code']         as num).toInt(),
      rainfall1h:  (cur['precipitation']        as num?)?.toDouble() ?? 0.0,
      uvIndex:     uvNow.round(),
      visibility:  visNow,
      hourlyTemp:  allTemp.sublist(startIdx, endIdx),
      hourlyRain:  allRain.sublist(startIdx, endIdx),
      hourlyTime:  allTime.sublist(startIdx, endIdx),
      dailyMaxTemp: _dbl(daily['temperature_2m_max']),
      dailyMinTemp: _dbl(daily['temperature_2m_min']),
      dailyRain:    _dbl(daily['precipitation_sum']),
      dailyDate:    (daily['time'] as List)
          .map((e) => DateTime.parse(e.toString())).toList(),
      dailyCode:    (daily['weather_code'] as List)
          .map((e) => (e as num).toInt()).toList(),
    );
  }

  static List<double> _dbl(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((e) => e == null ? 0.0 : (e as num).toDouble()).toList();
  }
}

// ── WMO code helpers ───────────────────────────────────────────────────────────────────────────
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
  if (code == 0)  return '\u2600\uFE0F';
  if (code <= 2)  return '\u26C5';
  if (code == 3)  return '\u2601\uFE0F';
  if (code <= 49) return '\uD83C\uDF2B\uFE0F';
  if (code <= 69) return '\uD83C\uDF27\uFE0F';
  if (code <= 79) return '\u2744\uFE0F';
  if (code <= 82) return '\uD83C\uDF26\uFE0F';
  if (code == 95) return '\u26C8\uFE0F';
  if (code >= 96) return '\uD83C\uDF29\uFE0F';
  return '\uD83C\uDF21\uFE0F';
}

// ── IMD rainfall classification ────────────────────────────────────────────────────────────
enum _RainfallClass { nil, light, moderate, heavy, veryHeavy, extremely }

_RainfallClass _imdClass(double mm) {
  if (mm <   2.4) return _RainfallClass.nil;
  if (mm <  15.6) return _RainfallClass.light;
  if (mm <  64.5) return _RainfallClass.moderate;
  if (mm < 115.6) return _RainfallClass.heavy;
  if (mm < 204.5) return _RainfallClass.veryHeavy;
  return _RainfallClass.extremely;
}

extension _RainfallClassX on _RainfallClass {
  String get label => switch (this) {
    _RainfallClass.nil       => 'No Rain',
    _RainfallClass.light     => 'Light Rain',
    _RainfallClass.moderate  => 'Moderate Rain',
    _RainfallClass.heavy     => 'Heavy Rain \u26A0\uFE0F',
    _RainfallClass.veryHeavy => 'Very Heavy Rain \uD83D\uDEA8',
    _RainfallClass.extremely => 'Extremely Heavy Rain \uD83D\uDD34',
  };
  Color get color => switch (this) {
    _RainfallClass.nil       => const Color(0xFF90CAF9),
    _RainfallClass.light     => const Color(0xFF42A5F5),
    _RainfallClass.moderate  => const Color(0xFF1E88E5),
    _RainfallClass.heavy     => const Color(0xFFFB8C00),
    _RainfallClass.veryHeavy => const Color(0xFFF4511E),
    _RainfallClass.extremely => const Color(0xFFB71C1C),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});
  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen>
    with TickerProviderStateMixin {
  final _searchCtrl  = TextEditingController();
  final _searchFocus = FocusNode();
  List<_GeoResult> _suggestions    = [];
  bool             _searching       = false;
  Timer?           _debounce;

  _GeoResult? _location;
  _Weather?   _weather;
  bool        _loadingWeather = false;
  String      _weatherError   = '';

  List<Map<String, dynamic>> _cwcAlerts = [];
  late TabController _chartTabs;

  @override
  void initState() {
    super.initState();
    _chartTabs = TabController(length: 2, vsync: this);
    _loadCwcAlerts();
    _loadDefault();
  }

  Future<void> _loadDefault() async {
    final mumbai = _GeoResult(
      name: 'Mumbai', admin1: 'Maharashtra',
      country: 'India', lat: 19.0760, lon: 72.8777,
    );
    _location = mumbai;
    await _fetchWeather(mumbai);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    _chartTabs.dispose();
    super.dispose();
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

  // ── KEY FIX: correct Open-Meteo URL ──────────────────────────────────────────────
  // uv_index and visibility are NOT valid `current` variables in Open-Meteo.
  // They must be requested under `hourly` and looked up by the current hour.
  Future<void> _fetchWeather(_GeoResult loc) async {
    setState(() { _loadingWeather = true; _weatherError = ''; _weather = null; });
    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=${loc.lat}&longitude=${loc.lon}'
        '&current=temperature_2m,apparent_temperature,relative_humidity_2m,'
        'wind_speed_10m,weather_code,precipitation'
        '&hourly=temperature_2m,precipitation,uv_index,visibility'
        '&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum'
        '&timezone=Asia%2FKolkata'
        '&forecast_days=7',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 14));
      if (res.statusCode == 200) {
        final w = _Weather.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
        if (mounted) setState(() { _weather = w; _loadingWeather = false; });
      } else {
        if (mounted) setState(() {
          _weatherError = 'Weather fetch failed (${res.statusCode})';
          _loadingWeather = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _weatherError = 'Network error: $e';
        _loadingWeather = false;
      });
    }
  }

  Future<void> _loadCwcAlerts() async {
    try {
      final levels = RealTimeService().liveLevels;
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
    } catch (_) {}
  }

  void _selectSuggestion(_GeoResult r) {
    _searchCtrl.text = '${r.name}, ${r.admin1}';
    _searchFocus.unfocus();
    setState(() { _location = r; _suggestions = []; });
    _fetchWeather(r);
    _loadCwcAlerts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05141E),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end:   Alignment.bottomCenter,
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
                                child: Text(
                                  'Search any city, village or state',
                                  style: TextStyle(color: Colors.white38, fontSize: 15),
                                ),
                              )
                            : _WeatherBody(
                                weather:   _weather!,
                                location:  _location!,
                                chartTabs: _chartTabs,
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── CWC Ticker Bar ─────────────────────────────────────────────────────────────────────────
class _CwcTickerBar extends StatefulWidget {
  final List<Map<String, dynamic>> alerts;
  const _CwcTickerBar({required this.alerts});
  @override
  State<_CwcTickerBar> createState() => _CwcTickerBarState();
}

class _CwcTickerBarState extends State<_CwcTickerBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  static const double _pixelsPerSecond = 50.0;
  static const double _totalWidth      = 1800.0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (_totalWidth / _pixelsPerSecond * 1000).round()),
    )..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final hasCritical = widget.alerts.any((a) => a['level'] == 'CRITICAL');
    final bgColor = hasCritical
        ? const Color(0xFFB71C1C).withValues(alpha: 0.85)
        : widget.alerts.isEmpty
            ? const Color(0xFF0D2B3E)
            : const Color(0xFFE65100).withValues(alpha: 0.8);

    final items = widget.alerts.isEmpty
        ? ['\u2705  CWC Feed: No active flood warnings  \u2022  IMD: Normal conditions  \u2022  Stay prepared during monsoon season']
        : widget.alerts
            .map((a) =>
                '${a['level'] == 'CRITICAL' ? '\uD83D\uDD34' : '\uD83D\uDFE0'}  '
                'CWC Alert: ${a['city']} \u2014 ${a['river']} at '
                '${(a['capacity'] as double).toStringAsFixed(0)}% capacity [${a['level']}]  \u2022  ')
            .toList();

    final tickerText = items.join('   ');

    return Container(
      height: 34,
      color:  bgColor,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            color: Colors.black26,
            child: const Text('CWC',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800,
                    fontSize: 11, letterSpacing: 1.2)),
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
                  maxWidth:  _totalWidth * 2,
                  child: Row(
                    children: [
                      _TickerText(text: tickerText),
                      const SizedBox(width: 60),
                      _TickerText(text: tickerText),
                    ],
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

class _TickerText extends StatelessWidget {
  final String text;
  const _TickerText({required this.text});
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w500),
    maxLines: 1,
  );
}

// ── Search Bar ────────────────────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode             focusNode;
  final bool                  searching;
  final void Function(String) onChanged;
  const _SearchBar({
    required this.controller, required this.focusNode,
    required this.searching,  required this.onChanged,
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
          hintText:   'Search city, village, district, state...',
          hintStyle:  const TextStyle(color: Colors.white38, fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
          suffixIcon: searching
              ? const SizedBox(
                  width: 18, height: 18,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                  ))
              : null,
          border:         InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        ),
      ),
    );
  }
}

// ── Suggestions List ───────────────────────────────────────────────────────────────────────
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
        shrinkWrap:  true,
        physics:     const NeverScrollableScrollPhysics(),
        itemCount:   math.min(suggestions.length, 6),
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
        itemBuilder: (_, i) {
          final r       = suggestions[i];
          final isIndia = r.country.toLowerCase().contains('india');
          return ListTile(
            dense:    true,
            leading:  Text(isIndia ? '\uD83C\uDDEE\uD83C\uDDF3' : '\uD83C\uDF0D',
                style: const TextStyle(fontSize: 18)),
            title:    Text(r.name,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            subtitle: Text(
              '${r.admin1}${r.admin1.isNotEmpty ? ', ' : ''}${r.country}',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.white38, size: 16),
            onTap:    () => onSelect(r),
          );
        },
      ),
    );
  }
}

// ── Error Panel ────────────────────────────────────────────────────────────────────────────
class _ErrorPanel extends StatelessWidget {
  final String error;
  const _ErrorPanel({required this.error});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.white38, size: 48),
            const SizedBox(height: 16),
            Text(error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

// ── Main Weather Body ──────────────────────────────────────────────────────────────────────
class _WeatherBody extends StatelessWidget {
  final _Weather      weather;
  final _GeoResult    location;
  final TabController chartTabs;
  const _WeatherBody({
    required this.weather, required this.location, required this.chartTabs,
  });

  @override
  Widget build(BuildContext context) {
    final rc           = _imdClass(weather.rainfall1h);
    final maxDailyRain = weather.dailyRain.isEmpty ? 0.0 : weather.dailyRain.reduce(math.max);
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
                controller:           chartTabs,
                labelColor:           const Color(0xFF0DA7C2),
                unselectedLabelColor: Colors.white54,
                indicatorColor:       const Color(0xFF0DA7C2),
                indicatorSize:        TabBarIndicatorSize.label,
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
      ],
    );
  }
}

// ── IMD Alert Banner ──────────────────────────────────────────────────────────────────────
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
          Text(rc == _RainfallClass.extremely ? '\uD83D\uDD34' : '\uD83D\uDFE0',
              style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('IMD Warning \u2014 $locationName',
                    style: TextStyle(
                        color: rc.color, fontWeight: FontWeight.bold, fontSize: 13)),
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

// ── Rain Warning Banner ────────────────────────────────────────────────────────────────────
class _RainWarningBanner extends StatelessWidget {
  final int    days;
  final double maxRain;
  const _RainWarningBanner({required this.days, required this.maxRain});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color:        const Color(0xFFFB8C00).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: const Color(0xFFFB8C00).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Text('\uD83C\uDF27\uFE0F', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$days day${days > 1 ? 's' : ''} with heavy rain forecast  \u2022  Peak: ${maxRain.toStringAsFixed(1)} mm',
              style: const TextStyle(
                  color: Color(0xFFFFA726), fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero Weather Card ──────────────────────────────────────────────────────────────────────
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
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
          colors: [Color(0xFF0A3B52), Color(0xFF05141E)],
        ),
        border: Border.all(color: const Color(0xFF0DA7C2).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color:       const Color(0xFF0DA7C2).withValues(alpha: 0.08),
            blurRadius:  24,
            spreadRadius: 2,
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
                      color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
                  Text('${weather.temp.toStringAsFixed(1)}\u00B0C',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 46,
                          fontWeight: FontWeight.w200, height: 1.0)),
                  Text(_wmoLabel(weather.weatherCode),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w400)),
                  const SizedBox(height: 4),
                  Text('Feels like ${weather.feelsLike.toStringAsFixed(1)}\u00B0C',
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
                '${weather.rainfall1h.toStringAsFixed(1)} mm/h  \u2022  ${rc.label}',
                style: TextStyle(
                    color: rc.color, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

// ── 24h Temperature Line Chart ───────────────────────────────────────────────────────────
class _HourlyTempChart extends StatelessWidget {
  final _Weather weather;
  const _HourlyTempChart({required this.weather});

  @override
  Widget build(BuildContext context) {
    if (weather.hourlyTemp.isEmpty) {
      return const Center(child: Text('No hourly data', style: TextStyle(color: Colors.white38)));
    }
    final spots = <FlSpot>[
      for (var i = 0; i < weather.hourlyTemp.length; i++)
        FlSpot(i.toDouble(), weather.hourlyTemp[i]),
    ];
    final minY = (weather.hourlyTemp.reduce(math.min) - 2).floorToDouble();
    final maxY = (weather.hourlyTemp.reduce(math.max) + 2).ceilToDouble();

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      child: LineChart(
        LineChartData(
          minY: minY, maxY: maxY,
          clipData: const FlClipData.all(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 5,
            getDrawingHorizontalLine: (_) => FlLine(
                color: Colors.white.withValues(alpha: 0.07), strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles:   true,
                reservedSize: 36,
                getTitlesWidget: (v, _) => Text('${v.toInt()}\u00B0',
                    style: const TextStyle(color: Colors.white54, fontSize: 10)),
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval:   6,
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
              spots:    spots,
              isCurved: true,
              color:    const Color(0xFFFFA726),
              barWidth: 2.5,
              dotData:  const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end:   Alignment.bottomCenter,
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

// ── 7-Day Rainfall Bar Chart ────────────────────────────────────────────────────────────────
class _DailyRainfallChart extends StatelessWidget {
  final _Weather weather;
  const _DailyRainfallChart({required this.weather});

  @override
  Widget build(BuildContext context) {
    if (weather.dailyRain.isEmpty) {
      return const Center(child: Text('No rainfall data', style: TextStyle(color: Colors.white38)));
    }
    final bars = weather.dailyRain.asMap().entries.map((e) {
      final rc = _imdClass(e.value);
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY:          e.value,
            color:        rc.color,
            width:        18,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ],
      );
    }).toList();

    final maxY = math.max(
        weather.dailyRain.reduce(math.max) + 20, 80.0).ceilToDouble();

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      child: BarChart(
        BarChartData(
          maxY:      maxY,
          barGroups: bars,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 20,
            getDrawingHorizontalLine: (_) => FlLine(
                color: Colors.white.withValues(alpha: 0.07), strokeWidth: 1),
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
                  if (idx < 0 || idx >= weather.dailyDate.length)
                    return const SizedBox.shrink();
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
                  labelResolver: (_) => ' Heavy \u25B6',
                  style: const TextStyle(
                      color: Color(0xFFFB8C00), fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
              HorizontalLine(
                y: 115.6, color: const Color(0xFFF4511E),
                strokeWidth: 1.4, dashArray: [5, 5],
                label: HorizontalLineLabel(
                  show: true, alignment: Alignment.topRight,
                  labelResolver: (_) => ' V.Heavy \u25B6',
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
                const TextStyle(
                    color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Detail Grid ────────────────────────────────────────────────────────────────────────────
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
    final tiles = [
      _DetailTile(icon: Icons.water_drop_outlined, label: 'Humidity',
          value: '${weather.humidity}%'),
      _DetailTile(icon: Icons.air_rounded,         label: 'Wind',
          value: '${weather.windSpeed.toStringAsFixed(1)} km/h'),
      _DetailTile(icon: Icons.wb_sunny_outlined,   label: 'UV Index',
          value: _uvLabel(weather.uvIndex)),
      _DetailTile(icon: Icons.visibility_outlined, label: 'Visibility',
          value: '${(weather.visibility / 1000).toStringAsFixed(1)} km'),
    ];
    return Column(
      children: [
        Row(children: [Expanded(child: tiles[0]), const SizedBox(width: 10), Expanded(child: tiles[1])]),
        const SizedBox(height: 10),
        Row(children: [Expanded(child: tiles[2]), const SizedBox(width: 10), Expanded(child: tiles[3])]),
      ],
    );
  }
}

class _DetailTile extends StatelessWidget {
  final IconData icon;
  final String   label, value;
  const _DetailTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0DA7C2), size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
              Text(value, style: const TextStyle(color: Colors.white,   fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 7-Day Forecast ───────────────────────────────────────────────────────────────────────────
class _SevenDayForecast extends StatelessWidget {
  final _Weather weather;
  const _SevenDayForecast({required this.weather});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_rounded,
                    color: Color(0xFF0DA7C2), size: 16),
                const SizedBox(width: 6),
                const Text('7-Day Forecast',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0x14FFFFFF)),
          for (var i = 0; i < weather.dailyDate.length; i++) ...[
            _ForecastRow(
              date:    weather.dailyDate[i],
              code:    weather.dailyCode[i],
              maxTemp: weather.dailyMaxTemp[i],
              minTemp: weather.dailyMinTemp[i],
              rain:    weather.dailyRain[i],
            ),
            if (i < weather.dailyDate.length - 1)
              const Divider(height: 1, color: Color(0x0AFFFFFF)),
          ],
        ],
      ),
    );
  }
}

class _ForecastRow extends StatelessWidget {
  final DateTime date;
  final int      code;
  final double   maxTemp, minTemp, rain;
  const _ForecastRow({
    required this.date, required this.code,
    required this.maxTemp, required this.minTemp, required this.rain,
  });

  @override
  Widget build(BuildContext context) {
    final rc      = _imdClass(rain);
    final isToday = DateFormat('yyyyMMdd').format(date) ==
                    DateFormat('yyyyMMdd').format(DateTime.now());
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              isToday ? 'Today' : DateFormat('E').format(date),
              style: TextStyle(
                color:      isToday ? const Color(0xFF0DA7C2) : Colors.white70,
                fontSize:   12,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          Text(_wmoEmoji(code), style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_wmoLabel(code),
                style: const TextStyle(color: Colors.white60, fontSize: 12),
                overflow: TextOverflow.ellipsis),
          ),
          if (rain > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                '${rain.toStringAsFixed(0)} mm',
                style: TextStyle(
                    color: rc.color, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          Text(
            '${maxTemp.toStringAsFixed(0)}\u00B0 / ${minTemp.toStringAsFixed(0)}\u00B0',
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
