import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../constants.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});
  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────
  int _selectedIdx = 0;
  bool _loading = false;
  Map<String, dynamic>? _wx;
  String _error = '';

  late final AnimationController _fadeCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _pulseCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat(reverse: true);
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _pulseAnim = Tween<double>(begin: 0.9, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _fetchCity(0);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchCity(int idx) async {
    final city = AppConstants.monitoredCities[idx];
    setState(() {
      _loading = true;
      _error = '';
      _wx = null;
      _selectedIdx = idx;
    });
    _fadeCtrl.reset();

    final res = await ApiService().getWeather(city['city'] as String);

    setState(() {
      _loading = false;
      if (res.containsKey('error') || res['status'] == 'error') {
        _error = res['error']?.toString() ??
            res['message']?.toString() ??
            'Unknown error';
      } else {
        _wx = res;
        _fadeCtrl.forward();
      }
    });
  }

  // ── Data helpers ────────────────────────────────────────
  Map<String, dynamic> get _main =>
      (_wx?["main"] as Map<String, dynamic>?) ?? {};
  Map<String, dynamic> get _wind =>
      (_wx?["wind"] as Map<String, dynamic>?) ?? {};
  List get _wlist => (_wx?["weather"] as List?) ?? [];

  String get _temp => (_main["temp"] as num?)?.round().toString() ?? '--';
  String get _feelsLike =>
      (_main["feels_like"] as num?)?.round().toString() ?? '--';
  String get _humid => (_main["humidity"]?.toString()) ?? '--';
  String get _pressure => (_main["pressure"]?.toString()) ?? '--';
  String get _windSpd {
    final s = _wind["speed"] as num?;
    return s == null ? '--' : (s * 3.6).toStringAsFixed(1); // m/s → km/h
  }

  String get _visibility {
    final v = _wx?["visibility"] as num?;
    return v == null ? '--' : (v / 1000).toStringAsFixed(1);
  }

  String get _desc =>
      _wlist.isEmpty ? '--' : (_wlist.first["description"]?.toString() ?? '--');
  String get _icon {
    if (_wlist.isEmpty) return '☁️';
    final id = _wlist.first["id"] as int? ?? 800;
    if (id == 800) return '☀️';
    if (id > 800) return '⛅';
    if (id >= 700) return '🌫️';
    if (id >= 600) return '❄️';
    if (id >= 500) return '🌧️';
    if (id >= 300) return '🌦️';
    if (id >= 200) return '⛈️';
    return '🌡️';
  }

  String get _cityName =>
      _wx?["name"]?.toString() ??
      AppConstants.monitoredCities[_selectedIdx]['city'] as String;

  // Risk color for selected city
  Color get _riskColor {
    final risk = AppConstants.monitoredCities[_selectedIdx]['risk'] as String;
    return Color(
        AppConstants.riskColors[risk] ?? AppConstants.riskColors['MODERATE']!);
  }

  // Background gradient based on temp
  List<Color> get _bgGradient {
    final t = double.tryParse(_temp) ?? 25;
    if (t >= 38) return [const Color(0xFF7F0000), const Color(0xFF1A0000)];
    if (t >= 32) return [const Color(0xFFBF4E0A), const Color(0xFF1A0800)];
    if (t >= 26) return [const Color(0xFF1A3A5C), const Color(0xFF0A0D14)];
    if (t >= 18) return [const Color(0xFF1C3550), const Color(0xFF060A12)];
    return [const Color(0xFF1A2A4A), const Color(0xFF050810)];
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ── Animated background ─────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: _bgGradient,
                ),
              ),
            ),

            // Subtle noise overlay
            Positioned.fill(
              child: CustomPaint(painter: _NoisePainter()),
            ),

            // ── Main scrollable ─────────────────────────
            SafeArea(
              child: Column(
                children: [
                  // City selector strip
                  _CitySelector(
                    cities: AppConstants.monitoredCities,
                    selectedIdx: _selectedIdx,
                    onSelect: _fetchCity,
                  ),

                  // Content
                  Expanded(
                    child: _loading
                        ? _buildLoading()
                        : _error.isNotEmpty
                            ? _buildError()
                            : _buildWeather(size),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Loading ─────────────────────────────────────────────
  Widget _buildLoading() {
    return Center(
        child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ScaleTransition(
          scale: _pulseAnim,
          child: const Text('⛅', style: TextStyle(fontSize: 72)),
        ),
        const SizedBox(height: 20),
        const Text('Fetching weather…',
            style: TextStyle(
                color: Colors.white54, fontSize: 14, letterSpacing: 1.5)),
      ],
    ));
  }

  // ── Error ───────────────────────────────────────────────
  Widget _buildError() {
    return Center(
        child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🌐', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 16),
          Text('Cannot reach weather service',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(_error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 13)),
          const SizedBox(height: 24),
          _GlassButton(
            label: 'Retry',
            icon: Icons.refresh,
            onTap: () => _fetchCity(_selectedIdx),
          ),
        ],
      ),
    ));
  }

  // ── Main weather UI ─────────────────────────────────────
  Widget _buildWeather(Size size) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          // ── Hero block ──────────────────────────────
          SizedBox(height: size.height * 0.02),
          Center(
              child: Column(children: [
            // Animated icon
            ScaleTransition(
              scale: _pulseAnim,
              child: Text(_icon, style: const TextStyle(fontSize: 90)),
            ),
            const SizedBox(height: 8),

            // City name
            Text(_cityName.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 4,
                )),
            const SizedBox(height: 4),
            Text(
              AppConstants.monitoredCities[_selectedIdx]['state'] as String,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 11, letterSpacing: 2),
            ),
            const SizedBox(height: 20),

            // Big temperature
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('$_temp',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 96,
                    fontWeight: FontWeight.w200,
                    letterSpacing: -4,
                    height: 1,
                  )),
              const Padding(
                padding: EdgeInsets.only(top: 18),
                child: Text('°C',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 36,
                        fontWeight: FontWeight.w200)),
              ),
            ]),
            const SizedBox(height: 4),

            // Description
            Text(_desc.toUpperCase(),
                style: const TextStyle(
                    color: Colors.white60, fontSize: 12, letterSpacing: 3)),
            const SizedBox(height: 6),

            // Feels like
            Text('Feels like $_feelsLike°C',
                style: const TextStyle(color: Colors.white38, fontSize: 13)),
          ])),

          SizedBox(height: size.height * 0.03),

          // ── Flood risk badge ─────────────────────────
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: _riskColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: _riskColor.withOpacity(0.5)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _riskColor,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                          color: _riskColor.withOpacity(0.8),
                          blurRadius: 6,
                          spreadRadius: 1)
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${AppConstants.monitoredCities[_selectedIdx]["risk"]} FLOOD RISK',
                  style: TextStyle(
                      color: _riskColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2),
                ),
              ]),
            ),
          ),

          const SizedBox(height: 28),
          _Divider(),

          // ── Stats grid ───────────────────────────────
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.55,
            children: [
              _StatCard('HUMIDITY', '$_humid%', Icons.water_drop_outlined),
              _StatCard('WIND', '$_windSpd km/h', Icons.air),
              _StatCard('PRESSURE', '$_pressure hPa', Icons.compress),
              _StatCard(
                  'VISIBILITY', '$_visibility km', Icons.visibility_outlined),
            ],
          ),

          const SizedBox(height: 20),
          _Divider(),
          const SizedBox(height: 20),

          // ── All monitored cities mini cards ──────────
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: Text('ALL MONITORED LOCATIONS',
                style: TextStyle(
                    color: Colors.white38, fontSize: 10, letterSpacing: 3)),
          ),
          ..._buildCityList(),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  List<Widget> _buildCityList() {
    return AppConstants.monitoredCities.asMap().entries.map((entry) {
      final i = entry.key;
      final c = entry.value;
      final isSelected = i == _selectedIdx;
      final risk = c['risk'] as String;
      final rColor = Color(AppConstants.riskColors[risk]!);
      return GestureDetector(
        onTap: () => _fetchCity(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withOpacity(0.1)
                : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? Colors.white.withOpacity(0.25)
                  : Colors.white.withOpacity(0.07),
            ),
          ),
          child: Row(children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                  color: rColor,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                        color: rColor.withOpacity(0.6),
                        blurRadius: 5,
                        spreadRadius: 1)
                  ]),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c['city'] as String,
                    style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w400)),
                Text(c['state'] as String,
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            )),
            Text(risk,
                style: TextStyle(
                    color: rColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5)),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, color: Colors.white24, size: 16),
          ]),
        ),
      );
    }).toList();
  }
}

// ── City selector tab strip ──────────────────────────────
class _CitySelector extends StatelessWidget {
  final List<Map<String, dynamic>> cities;
  final int selectedIdx;
  final void Function(int) onSelect;

  const _CitySelector({
    required this.cities,
    required this.selectedIdx,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: cities.length,
        itemBuilder: (ctx, i) {
          final selected = i == selectedIdx;
          return GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withOpacity(0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? Colors.white.withOpacity(0.4)
                      : Colors.white.withOpacity(0.12),
                ),
              ),
              child: Center(
                child: Text(
                  cities[i]['city'] as String,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white54,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w400,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Stat Card (glass) ─────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _StatCard(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Icon(icon, color: Colors.white38, size: 16),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white38, fontSize: 10, letterSpacing: 1.5)),
          ]),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w300)),
        ],
      ),
    );
  }
}

// ── Glass Button ──────────────────────────────────────────
class _GlassButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _GlassButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1)),
        ]),
      ),
    );
  }
}

// ── Divider ───────────────────────────────────────────────
class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.5,
      color: Colors.white.withOpacity(0.1),
    );
  }
}

// ── Noise texture painter ─────────────────────────────────
class _NoisePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(42);
    final paint = Paint()..strokeWidth = 1;
    for (int i = 0; i < 800; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      paint.color = Colors.white.withOpacity(rng.nextDouble() * 0.018);
      canvas.drawCircle(Offset(x, y), 0.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
