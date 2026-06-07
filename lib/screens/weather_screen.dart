// lib/screens/weather_screen.dart
// OpsFlood — WeatherScreen v3  "Command Centre"
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/weather_provider.dart';
import '../theme/river_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen root
// ─────────────────────────────────────────────────────────────────────────────

class WeatherScreen extends ConsumerStatefulWidget {
  const WeatherScreen({super.key});
  @override
  ConsumerState<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends ConsumerState<WeatherScreen>
    with TickerProviderStateMixin {
  final _searchCtrl   = TextEditingController();
  final _searchFocus  = FocusNode();
  bool  _searchOpen   = false;
  late AnimationController _searchBarCtrl;
  late Animation<double>   _searchBarAnim;
  late AnimationController _contentCtrl;
  late Animation<double>   _contentAnim;
  late AnimationController _rotateCtrl;

  @override
  void initState() {
    super.initState();
    _searchBarCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _searchBarAnim = CurvedAnimation(
        parent: _searchBarCtrl, curve: Curves.easeOutCubic);

    _contentCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _contentAnim = CurvedAnimation(
        parent: _contentCtrl, curve: Curves.easeOutCubic);

    _rotateCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 12))
      ..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _contentCtrl.forward();
    });
  }

  @override
  void dispose() {
    _searchBarCtrl.dispose();
    _contentCtrl.dispose();
    _rotateCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() => _searchOpen = !_searchOpen);
    if (_searchOpen) {
      _searchBarCtrl.forward();
      Future.delayed(const Duration(milliseconds: 200), () {
        _searchFocus.requestFocus();
      });
    } else {
      _searchBarCtrl.reverse();
      _searchFocus.unfocus();
      _searchCtrl.clear();
      ref.read(weatherProvider.notifier).clearSearch();
    }
  }

  void _onSearchChanged(String v) {
    ref.read(weatherProvider.notifier).searchCity(v);
  }

  void _selectCity(CityResult city) {
    _searchCtrl.clear();
    _searchFocus.unfocus();
    setState(() => _searchOpen = false);
    _searchBarCtrl.reverse();
    ref.read(weatherProvider.notifier).selectCity(city);
    _contentCtrl
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final ws = ref.watch(weatherProvider);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppPalette.abyss0,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _WeatherHeader(
                cityName:   ws.cityName,
                searchOpen: _searchOpen,
                onSearchTap: _toggleSearch,
                onRefresh: () {
                  HapticFeedback.mediumImpact();
                  _contentCtrl.reset();
                  ref.read(weatherProvider.notifier)
                      .fetchWeather(forceRefresh: true);
                  _contentCtrl.forward();
                },
                rotateCtrl: _rotateCtrl,
                status: ws.status,
              ),
              SizeTransition(
                sizeFactor: _searchBarAnim,
                child: _SearchBar(
                  ctrl:       _searchCtrl,
                  focus:      _searchFocus,
                  loading:    ws.searchLoading,
                  results:    ws.searchResults,
                  onChanged:  _onSearchChanged,
                  onSelect:   _selectCity,
                ),
              ),
              Expanded(
                child: switch (ws.status) {
                  WeatherStatus.loading => const _LoadingView(),
                  WeatherStatus.error   => _ErrorView(
                      message:        ws.error,
                      isRateLimited:  ws.isRateLimited,
                      retryInSeconds: ws.retryInSeconds,
                      onRetry: () => ref
                          .read(weatherProvider.notifier)
                          .fetchWeather(forceRefresh: true),
                    ),
                  WeatherStatus.loaded  => _WeatherContent(
                      ws:          ws,
                      contentAnim: _contentAnim,
                    ),
                  _                     => const _LoadingView(),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _WeatherHeader extends StatelessWidget {
  final String             cityName;
  final bool               searchOpen;
  final VoidCallback       onSearchTap;
  final VoidCallback       onRefresh;
  final AnimationController rotateCtrl;
  final WeatherStatus      status;
  const _WeatherHeader({
    required this.cityName,    required this.searchOpen,
    required this.onSearchTap, required this.onRefresh,
    required this.rotateCtrl,  required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: AppPalette.abyss0,
        border: Border(
          bottom: BorderSide(
              color: AppPalette.cyan.withValues(alpha: 0.10), width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0072FF).withValues(alpha: 0.20),
                  const Color(0xFF00C6FF).withValues(alpha: 0.06),
                ],
              ),
              border: Border.all(
                  color: AppPalette.cyan.withValues(alpha: 0.28), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppPalette.cyan.withValues(alpha: 0.14),
                  blurRadius: 14,
                ),
              ],
            ),
            child: status == WeatherStatus.loading
                ? RotationTransition(
                    turns: rotateCtrl,
                    child: const Icon(Icons.radar_rounded,
                        color: AppPalette.cyan, size: 22))
                : const Icon(Icons.cloud_rounded,
                    color: AppPalette.cyan, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [Color(0xFF00E5FF), Color(0xFF0072FF)],
                  ).createShader(b),
                  child: const Text(
                    'Weather',
                    style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900,
                      color: Colors.white, letterSpacing: -0.8, height: 1.1,
                    ),
                  ),
                ),
                Text(
                  cityName,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: AppPalette.textGrey.withValues(alpha: 0.65),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSearchTap();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: searchOpen
                    ? AppPalette.cyan.withValues(alpha: 0.14)
                    : AppPalette.abyss2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: searchOpen
                      ? AppPalette.cyan.withValues(alpha: 0.35)
                      : AppPalette.abyssStroke,
                ),
              ),
              child: Icon(
                searchOpen ? Icons.search_off_rounded : Icons.search_rounded,
                color: searchOpen ? AppPalette.cyan : AppPalette.textGrey,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRefresh,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppPalette.abyss2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppPalette.abyssStroke),
              ),
              child: const Icon(Icons.refresh_rounded,
                  color: AppPalette.textGrey, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search bar + autocomplete dropdown
// ─────────────────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController  ctrl;
  final FocusNode              focus;
  final bool                   loading;
  final List<CityResult>       results;
  final ValueChanged<String>   onChanged;
  final ValueChanged<CityResult> onSelect;
  const _SearchBar({
    required this.ctrl,    required this.focus,
    required this.loading, required this.results,
    required this.onChanged, required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        children: [
          Container(
            height: 46,
            decoration: BoxDecoration(
              color: AppPalette.abyss2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppPalette.cyan.withValues(alpha: 0.28), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppPalette.cyan.withValues(alpha: 0.08),
                  blurRadius: 12,
                ),
              ],
            ),
            child: TextField(
              controller:  ctrl,
              focusNode:   focus,
              onChanged:   onChanged,
              style: const TextStyle(
                  color: AppPalette.textWhite, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search city, e.g. Patna or Muzaffarpur…',
                hintStyle: TextStyle(
                  color: AppPalette.textGrey.withValues(alpha: 0.40),
                  fontSize: 12,
                ),
                prefixIcon: loading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: AppPalette.cyan,
                          ),
                        ),
                      )
                    : const Icon(Icons.search_rounded,
                        color: AppPalette.cyan, size: 18),
                suffixIcon: ctrl.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          ctrl.clear();
                          onChanged('');
                        },
                        child: const Icon(Icons.close_rounded,
                            color: AppPalette.textGrey, size: 16),
                      )
                    : null,
                border:         InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 13),
              ),
            ),
          ),
          if (results.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: AppPalette.abyss2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppPalette.abyssStroke),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.30),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: results.map((city) => GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelect(city);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: results.last == city
                            ? BorderSide.none
                            : BorderSide(
                                color: AppPalette.abyssStroke, width: 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            color: AppPalette.cyan, size: 14),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            city.displayName,
                            style: const TextStyle(
                              color: AppPalette.textWhite,
                              fontSize: 12, fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          city.country,
                          style: const TextStyle(
                            color: AppPalette.textDim, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                )).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main content (loaded state)
// ─────────────────────────────────────────────────────────────────────────────

class _WeatherContent extends StatelessWidget {
  final WeatherState      ws;
  final Animation<double> contentAnim;
  const _WeatherContent({required this.ws, required this.contentAnim});

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: contentAnim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end:   Offset.zero,
        ).animate(contentAnim),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          physics: const BouncingScrollPhysics(),
          children: [
            _HeroCard(current: ws.current!, cityName: ws.cityName),
            const SizedBox(height: 12),
            _MonitorShareRow(ws: ws),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _MetricCard(
                  icon:  Icons.air_rounded,
                  label: 'Wind',
                  value: '${ws.windKph.toStringAsFixed(0)} km/h',
                  sub:   _windDir(ws.current!.windDir),
                  color: const Color(0xFF64B5F6),
                )),
                const SizedBox(width: 10),
                Expanded(child: _MetricCard(
                  icon:  Icons.wb_sunny_rounded,
                  label: 'UV Index',
                  value: ws.current!.uvIndex.toStringAsFixed(1),
                  sub:   _uvLabel(ws.current!.uvIndex),
                  color: AppPalette.amber,
                )),
                const SizedBox(width: 10),
                Expanded(child: _MetricCard(
                  icon:  Icons.visibility_rounded,
                  label: 'Visibility',
                  value: '${(ws.current!.visibilityKm / 1000).toStringAsFixed(1)} km',
                  sub:   '',
                  color: AppPalette.cyan,
                )),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _MetricCard(
                  icon:  Icons.speed_rounded,
                  label: 'Pressure',
                  value: '${ws.current!.surfacePressure.toStringAsFixed(0)} hPa',
                  sub:   '',
                  color: const Color(0xFFCE93D8),
                )),
                const SizedBox(width: 10),
                Expanded(child: _MetricCard(
                  icon:  Icons.cloud_queue_rounded,
                  label: 'Cloud Cover',
                  value: '${ws.current!.cloudCoverPct.toStringAsFixed(0)}%',
                  sub:   '',
                  color: AppPalette.textGrey,
                )),
                const SizedBox(width: 10),
                Expanded(child: _MetricCard(
                  icon:  Icons.water_drop_rounded,
                  label: 'Humidity',
                  value: '${ws.humidity}%',
                  sub:   '',
                  color: AppPalette.cyan,
                )),
              ],
            ),
            const SizedBox(height: 14),
            _RainfallChart(forecast: ws.forecast),
            const SizedBox(height: 14),
            _ForecastList(forecast: ws.forecast),
          ],
        ),
      ),
    );
  }

  String _windDir(double deg) {
    const dirs = ['N','NE','E','SE','S','SW','W','NW','N'];
    return dirs[((deg + 22.5) ~/ 45) % 8];
  }

  String _uvLabel(double uv) {
    if (uv < 3)  return 'Low';
    if (uv < 6)  return 'Moderate';
    if (uv < 8)  return 'High';
    if (uv < 11) return 'Very High';
    return 'Extreme';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero current card
// ─────────────────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final WeatherCurrent current;
  final String         cityName;
  const _HeroCard({required this.current, required this.cityName});

  @override
  Widget build(BuildContext context) {
    final wc  = current.weatherCode;
    final col = _wxColor(wc);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [
            col.withValues(alpha: 0.15),
            AppPalette.abyss2,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: col.withValues(alpha: 0.30), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: col.withValues(alpha: 0.12),
            blurRadius: 24, offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      current.tempC.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 58, fontWeight: FontWeight.w900,
                        color: AppPalette.textWhite, height: 1.0,
                        letterSpacing: -3,
                        shadows: [
                          Shadow(color: col.withValues(alpha: 0.5),
                              blurRadius: 20),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('°C',
                          style: TextStyle(
                            fontSize: 18, color: AppPalette.textGrey,
                            fontWeight: FontWeight.w600,
                          )),
                    ),
                  ],
                ),
                Text(
                  'Feels ${current.feelsLikeC.toStringAsFixed(1)}°C  ·  ${_wxLabel(wc)}',
                  style: const TextStyle(
                      color: AppPalette.textGrey, fontSize: 10.5),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _HeroPill(
                      icon: Icons.water_drop_rounded,
                      value: '${current.precipMm} mm',
                      label: 'Now',
                      color: AppPalette.cyan,
                    ),
                    const SizedBox(width: 8),
                    _HeroPill(
                      icon: Icons.opacity_rounded,
                      value: '${current.humidity}%',
                      label: 'Humidity',
                      color: const Color(0xFF64B5F6),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                _wxEmoji(wc),
                style: const TextStyle(fontSize: 56),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: col.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: col.withValues(alpha: 0.25)),
                ),
                child: Text(
                  _wxLabel(wc),
                  style: TextStyle(
                    color: col, fontSize: 9, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _wxColor(int c) {
    if (c == 0)  return AppPalette.amber;
    if (c <= 3)  return const Color(0xFF64B5F6);
    if (c <= 48) return AppPalette.textGrey;
    if (c <= 67) return AppPalette.cyan;
    if (c <= 77) return Colors.white;
    if (c <= 82) return AppPalette.cyan;
    if (c <= 99) return AppPalette.danger;
    return AppPalette.textGrey;
  }

  String _wxLabel(int c) {
    if (c == 0)  return 'Clear Sky';
    if (c <= 3)  return 'Partly Cloudy';
    if (c <= 48) return 'Fog';
    if (c <= 57) return 'Drizzle';
    if (c <= 67) return 'Rain';
    if (c <= 77) return 'Snow';
    if (c <= 82) return 'Rain Showers';
    if (c <= 99) return 'Thunderstorm';
    return 'Unknown';
  }

  String _wxEmoji(int c) {
    if (c == 0)  return '☀️';
    if (c <= 3)  return '⛅';
    if (c <= 48) return '🌫️';
    if (c <= 57) return '🌦️';
    if (c <= 67) return '🌧️';
    if (c <= 77) return '❄️';
    if (c <= 82) return '🌦️';
    if (c <= 99) return '⛈️';
    return '🌡️';
  }
}

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String   value, label;
  final Color    color;
  const _HeroPill({
    required this.icon, required this.value,
    required this.label, required this.color,
  });
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color:        color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w800)),
              Text(label, style: const TextStyle(
                color: AppPalette.textDim, fontSize: 8)),
            ],
          ),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Monitor-share row
// ─────────────────────────────────────────────────────────────────────────────

class _MonitorShareRow extends StatelessWidget {
  final WeatherState ws;
  const _MonitorShareRow({required this.ws});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.abyss2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: AppPalette.cyan.withValues(alpha: 0.18), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppPalette.cyan.withValues(alpha: 0.05),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6, height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppPalette.safe,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'MONITOR FEED',
                style: TextStyle(
                  color: AppPalette.cyan,
                  fontSize: 9, fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '· shared with station monitor',
                style: TextStyle(
                  color: AppPalette.textDim, fontSize: 9),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _FeedTile(
                label: '7d Rainfall',
                value: '${ws.rainfall7dMm.toStringAsFixed(1)} mm',
                icon:  Icons.grain_rounded,
                color: AppPalette.cyan,
              )),
              _divider(),
              Expanded(child: _FeedTile(
                label: 'Rain Index',
                value: '${ws.rainfallIndex.toStringAsFixed(0)}/100',
                icon:  Icons.analytics_rounded,
                color: _indexColor(ws.rainfallIndex),
              )),
              _divider(),
              Expanded(child: _FeedTile(
                label: 'Precip Prob',
                value: '${ws.maxPrecipProb.toStringAsFixed(0)}%',
                icon:  Icons.umbrella_rounded,
                color: AppPalette.amber,
              )),
              _divider(),
              Expanded(child: _FeedTile(
                label: 'Temperature',
                value: '${ws.tempC.toStringAsFixed(1)}°C',
                icon:  Icons.thermostat_rounded,
                color: AppPalette.amber,
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
      width: 1, height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: AppPalette.abyssStroke);

  Color _indexColor(double v) {
    if (v > 70) return AppPalette.critical;
    if (v > 45) return AppPalette.danger;
    if (v > 25) return AppPalette.amber;
    return AppPalette.safe;
  }
}

class _FeedTile extends StatelessWidget {
  final String   label, value;
  final IconData icon;
  final Color    color;
  const _FeedTile({
    required this.label, required this.value,
    required this.icon,  required this.color,
  });
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(
            color: AppPalette.textDim, fontSize: 7.5,
            fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Metric card
// ─────────────────────────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String   label, value, sub;
  final Color    color;
  const _MetricCard({
    required this.icon, required this.label,
    required this.value, required this.sub,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color:        AppPalette.abyss2,
          borderRadius: BorderRadius.circular(16),
          border:       Border.all(color: AppPalette.abyssStroke),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(
              color: AppPalette.textWhite, fontSize: 12,
              fontWeight: FontWeight.w900,
            )),
            if (sub.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(sub, style: TextStyle(
                color: color, fontSize: 8.5, fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(
              color: AppPalette.textDim, fontSize: 8)),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Rainfall bar chart (7-day)
// ─────────────────────────────────────────────────────────────────────────────

class _RainfallChart extends StatelessWidget {
  final List<WeatherDay> forecast;
  const _RainfallChart({required this.forecast});

  @override
  Widget build(BuildContext context) {
    final maxRain = forecast.map((d) => d.rainMm).fold(0.0, math.max);
    final scale   = maxRain > 0 ? maxRain : 1.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        AppPalette.abyss2,
        borderRadius: BorderRadius.circular(18),
        border:       Border.all(color: AppPalette.abyssStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded,
                  color: AppPalette.cyan, size: 15),
              const SizedBox(width: 6),
              const Text('7-Day Rainfall',
                  style: TextStyle(
                    color: AppPalette.textGrey,
                    fontSize: 11, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('Max ${maxRain.toStringAsFixed(1)} mm',
                  style: const TextStyle(
                      color: AppPalette.textDim, fontSize: 9.5)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: forecast.map((day) {
              final frac  = day.rainMm / scale;
              final col   = day.rainMm > 20
                  ? AppPalette.danger
                  : day.rainMm > 5
                      ? AppPalette.amber
                      : AppPalette.cyan;
              final label = DateFormat('EEE').format(
                  DateTime.tryParse(day.date) ?? DateTime.now());
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    children: [
                      Text(day.rainMm.toStringAsFixed(0),
                          style: TextStyle(
                            color: col, fontSize: 8,
                            fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Container(
                        height: math.max(4.0, 70.0 * frac),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end:   Alignment.bottomCenter,
                            colors: [col, col.withValues(alpha: 0.35)],
                          ),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                          boxShadow: [
                            BoxShadow(
                              color: col.withValues(alpha: 0.35),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(label, style: const TextStyle(
                        color: AppPalette.textDim, fontSize: 8)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 7-day forecast list
// ─────────────────────────────────────────────────────────────────────────────

class _ForecastList extends StatelessWidget {
  final List<WeatherDay> forecast;
  const _ForecastList({required this.forecast});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        AppPalette.abyss2,
        borderRadius: BorderRadius.circular(18),
        border:       Border.all(color: AppPalette.abyssStroke),
      ),
      child: Column(
        children: forecast.asMap().entries.map((e) {
          final i   = e.key;
          final day = e.value;
          final dt  = DateTime.tryParse(day.date);
          final label = i == 0 ? 'Today'
              : i == 1 ? 'Tomorrow'
              : (dt != null ? DateFormat('EEE, d MMM').format(dt) : day.date);
          final emoji = _wxEmoji(day.weatherCode);
          final col   = day.rainMm > 20
              ? AppPalette.danger
              : day.rainMm > 5
                  ? AppPalette.amber
                  : AppPalette.textGrey;
          return Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: i < forecast.length - 1
                    ? BorderSide(color: AppPalette.abyssStroke)
                    : BorderSide.none,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(label,
                      style: TextStyle(
                        color: i == 0
                            ? AppPalette.textWhite
                            : AppPalette.textGrey,
                        fontSize: 11,
                        fontWeight: i == 0
                            ? FontWeight.w800
                            : FontWeight.w500,
                      )),
                ),
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const Spacer(),
                Row(children: [
                  Icon(Icons.grain_rounded, color: col, size: 11),
                  const SizedBox(width: 3),
                  Text('${day.rainMm.toStringAsFixed(1)} mm',
                      style: TextStyle(
                          color: col, fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(width: 12),
                Text('${day.precipProb.toStringAsFixed(0)}%',
                    style: const TextStyle(
                        color: AppPalette.textDim, fontSize: 10)),
                const SizedBox(width: 12),
                Text(
                  '${day.maxC.round()}° / ${day.minC.round()}°',
                  style: const TextStyle(
                    color: AppPalette.textWhite,
                    fontSize: 11, fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _wxEmoji(int c) {
    if (c == 0)  return '☀️';
    if (c <= 3)  return '⛅';
    if (c <= 48) return '🌫️';
    if (c <= 67) return '🌧️';
    if (c <= 77) return '❄️';
    if (c <= 82) return '🌦️';
    if (c <= 99) return '⛈️';
    return '🌡️';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading / Error views
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 44, height: 44,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppPalette.cyan,
                backgroundColor:
                    AppPalette.cyan.withValues(alpha: 0.12),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Fetching live weather…',
                style: TextStyle(
                    color: AppPalette.textGrey, fontSize: 12)),
          ],
        ),
      );
}

class _ErrorView extends StatelessWidget {
  final String       message;
  final bool         isRateLimited;
  final int          retryInSeconds;
  final VoidCallback onRetry;
  const _ErrorView({
    required this.message,
    required this.isRateLimited,
    required this.retryInSeconds,
    required this.onRetry,
  });

  String _formatCountdown(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return m > 0 ? '${m}m ${s}s' : '${s}s';
  }

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isRateLimited
                    ? Icons.hourglass_top_rounded
                    : Icons.cloud_off_rounded,
                color: isRateLimited
                    ? AppPalette.amber
                    : AppPalette.danger,
                size: 44,
              ),
              const SizedBox(height: 14),
              Text(
                isRateLimited
                    ? 'Weather service is busy right now.'
                    : message,
                style: const TextStyle(
                    color: AppPalette.textGrey,
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (isRateLimited && retryInSeconds > 0) ...[
                Text(
                  'Auto-retrying in ${_formatCountdown(retryInSeconds)}',
                  style: TextStyle(
                      color: AppPalette.amber.withValues(alpha: 0.80),
                      fontSize: 11),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 140,
                  child: LinearProgressIndicator(
                    value: 1 - (retryInSeconds / 300),
                    backgroundColor:
                        AppPalette.amber.withValues(alpha: 0.15),
                    color: AppPalette.amber,
                    minHeight: 3,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 16),
              ] else
                const SizedBox(height: 16),
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: isRateLimited
                        ? AppPalette.amber.withValues(alpha: 0.10)
                        : AppPalette.cyan.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isRateLimited
                          ? AppPalette.amber.withValues(alpha: 0.30)
                          : AppPalette.cyan.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Text(
                    isRateLimited ? 'Try Now Anyway' : 'Retry',
                    style: TextStyle(
                      color: isRateLimited
                          ? AppPalette.amber
                          : AppPalette.cyan,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
