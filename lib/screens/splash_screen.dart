// lib/screens/splash_screen.dart
// OpsFlood Universe Splash — 3-layer architecture:
//   Layer 1: Generative starfield (CustomPainter)
//   Layer 2: OpsFlood branding (FadeTransition)
//   Layer 3: Data-fetch progress (pulses with galactic core)
//
// NOTE: Class is named SplashScreen (not SplashPage) to match existing
//       routes in main.dart that reference SplashScreen.route.

import 'dart:ui' show Size;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/universe_splash_painter.dart';
import 'home_screen.dart';

// ─── Minimum splash display time ─────────────────────────────────────────────
const _kMinSplashMs = 2800;

// ─── SplashScreen ─────────────────────────────────────────────────────────────

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  // Route constant expected by main.dart
  static const String route = '/';

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {

  // Animation controllers
  late final AnimationController _universeCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _brandCtrl;
  late final AnimationController _exitCtrl;

  // Derived animations
  late final Animation<double> _coreGlow;
  late final Animation<double> _brandFade;
  late final Animation<double> _exitFade;

  // Star field — built once after first layout
  List<StarParticle> _stars      = [];
  bool               _starsReady = false;

  // Data fetch state
  double _fetchProg  = 0.0;
  String _fetchLabel = 'INITIALISING SYSTEMS...';

  late final DateTime _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();

    // Universe runs continuously until exit
    _universeCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(seconds: 60),
    )..repeat();

    // Core pulse — 2.4 s sine wave
    _pulseCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _coreGlow = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);

    // Brand logo fades in after 600 ms
    _brandCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 900),
    );
    _brandFade = CurvedAnimation(parent: _brandCtrl, curve: Curves.easeOut);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _brandCtrl.forward();
    });

    // Exit fade
    _exitCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 800),
    );
    _exitFade = CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn);
    _exitCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Navigator.of(context).pushReplacementNamed(HomeScreen.route);
      }
    });

    _initializeData();
  }

  @override
  void dispose() {
    _universeCtrl.dispose();
    _pulseCtrl.dispose();
    _brandCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  // ─── Data initialisation ───────────────────────────────────────────────────

  Future<void> _initializeData() async {
    try {
      _setStatus('CONNECTING WRD BIHAR...', 0.0);
      await _fetchWrd();
      _setStatus('WRD SYNC COMPLETE', 0.5);

      _setStatus('CONNECTING CWC DIRECT...', 0.5);
      await _fetchCwc();
      _setStatus('ALL SYSTEMS ONLINE', 1.0);
    } catch (_) {
      _setStatus('PARTIAL DATA — CONTINUING', 1.0);
    } finally {
      final elapsed   = DateTime.now().difference(_startTime).inMilliseconds;
      final remaining = _kMinSplashMs - elapsed;
      if (remaining > 0) await Future.delayed(Duration(milliseconds: remaining));
      if (mounted) _exitCtrl.forward();
    }
  }

  void _setStatus(String label, double progress) {
    if (!mounted) return;
    setState(() { _fetchLabel = label; _fetchProg = progress; });
  }

  // ── Replace these stubs with your actual service calls: ───────────────────
  Future<void> _fetchWrd() async {
    // await WrdBiharService.instance.fetch();
    await Future.delayed(const Duration(milliseconds: 900));
  }

  Future<void> _fetchCwc() async {
    // await CwcDirectService.instance.fetchAll();
    await Future.delayed(const Duration(milliseconds: 700));
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030508),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          if (!_starsReady) {
            _stars      = buildStarField(320, size);
            _starsReady = true;
          }

          return AnimatedBuilder(
            animation: Listenable.merge([_universeCtrl, _pulseCtrl, _exitCtrl]),
            builder: (context, _) {
              final fadeOut = _exitFade.value;
              return Stack(
                fit: StackFit.expand,
                children: [
                  // Layer 1 — Starfield universe
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: UniversePainter(
                        animation: _universeCtrl,
                        stars:     _stars,
                        coreGlow:  _coreGlow,
                        fadeOut:   fadeOut,
                      ),
                      size: size,
                    ),
                  ),

                  // Layer 2 — Branding
                  FadeTransition(
                    opacity: _brandFade,
                    child: Opacity(
                      opacity: (1.0 - fadeOut).clamp(0.0, 1.0),
                      child: _BrandingOverlay(coreGlow: _coreGlow),
                    ),
                  ),

                  // Layer 3 — Progress / service monitor
                  Positioned(
                    bottom: 60, left: 40, right: 40,
                    child: Opacity(
                      opacity: (1.0 - fadeOut).clamp(0.0, 1.0),
                      child: _ProgressLayer(
                        label:    _fetchLabel,
                        progress: _fetchProg,
                        pulse:    _coreGlow,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Branding overlay ─────────────────────────────────────────────────────────

class _BrandingOverlay extends StatelessWidget {
  const _BrandingOverlay({required this.coreGlow});
  final Animation<double> coreGlow;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: coreGlow,
            builder: (_, __) {
              const accent = Color(0xFF00FFB2);
              final p = coreGlow.value;
              return Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: accent.withValues(alpha: 0.6 + 0.4 * p),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:      accent.withValues(alpha: 0.25 + 0.15 * p),
                      blurRadius: 18 + 10 * p,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.water_drop_outlined,
                  color: Color(0xFF00FFB2),
                  size: 38,
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'OPSFLOOD',
            style: TextStyle(
              fontFamily: 'RobotoMono', fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Color(0xFFE0F0FF), letterSpacing: 5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'REAL-TIME FLOOD INTELLIGENCE',
            style: TextStyle(
              fontFamily: 'RobotoMono', fontSize: 10,
              color: Color(0xFF5A7080), letterSpacing: 2.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Progress layer ───────────────────────────────────────────────────────────

class _ProgressLayer extends StatelessWidget {
  const _ProgressLayer({
    required this.label,
    required this.progress,
    required this.pulse,
  });

  final String            label;
  final double            progress;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) {
        const accent = Color(0xFF00FFB2);
        final p = pulse.value;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.5 + 0.5 * p),
                    boxShadow: [
                      BoxShadow(color: accent.withValues(alpha: 0.4 * p), blurRadius: 6),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Text(
                      label,
                      key: ValueKey(label),
                      style: const TextStyle(
                        fontFamily: 'RobotoMono', fontSize: 10,
                        color: Color(0xFF5A7080), letterSpacing: 1.4,
                      ),
                    ),
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: TextStyle(
                    fontFamily: 'RobotoMono', fontSize: 10,
                    color: accent.withValues(alpha: 0.8), letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 2,
              color: const Color(0xFF111620),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    color: accent,
                    boxShadow: [
                      BoxShadow(color: accent.withValues(alpha: 0.6 * p), blurRadius: 6),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
