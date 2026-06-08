// lib/screens/splash_screen.dart
// OpsFlood Universe Splash — 3-layer architecture:
//   Layer 1: Generative starfield (CustomPainter)
//   Layer 2: OpsFlood branding (FadeTransition)
//   Layer 3: Data-fetch progress indicator (pulsing with galactic core)
//
// Lifecycle:
//   1. Universe starts animating immediately.
//   2. WrdBiharService + CwcDirectService cold-start in parallel.
//   3. On both complete → 800ms fade-out → HomeScreen.

import 'dart:ui' show Size;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/universe_splash_painter.dart';
import 'home_screen.dart';

// ─── Minimum display time so the universe is always seen ────────────────────
const _kMinSplashMs = 2800;

// ─── SplashPage ─────────────────────────────────────────────────────────────

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with TickerProviderStateMixin {

  // Controllers
  late final AnimationController _universeCtrl;  // drives starfield + rotation
  late final AnimationController _pulseCtrl;     // drives galactic core pulse
  late final AnimationController _brandCtrl;     // drives branding fade-in
  late final AnimationController _exitCtrl;      // drives fade-out on completion

  // Animations
  late final Animation<double> _coreGlow;
  late final Animation<double> _brandFade;
  late final Animation<double> _exitFade;  // 0→1 when data done

  // Stars — built once after first layout
  List<_Star> _stars = [];
  bool        _starsReady = false;

  // Data state
  bool   _dataReady  = false;
  double _fetchProg  = 0.0;    // 0.0 .. 1.0
  String _fetchLabel = 'INITIALISING SYSTEMS...';

  // Timing
  late final DateTime _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();

    // Universe — runs forever until we stop it
    _universeCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(seconds: 60),
    )..repeat();

    // Core pulse — 2.4s sine wave
    _pulseCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _coreGlow = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);

    // Brand logo fades in after 600ms
    _brandCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 900),
    );
    _brandFade = CurvedAnimation(parent: _brandCtrl, curve: Curves.easeOut);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _brandCtrl.forward();
    });

    // Exit fade-out
    _exitCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 800),
    );
    _exitFade = CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn);
    _exitCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const HomeScreen(),
            transitionDuration: Duration.zero,
          ),
        );
      }
    });

    // Kick off data fetch
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

  // ── Data initialisation ──────────────────────────────────────────────────

  Future<void> _initializeData() async {
    try {
      // Step 1 — WRD Bihar
      _setStatus('CONNECTING WRD BIHAR...', 0.0);
      await _fetchWrd();
      _setStatus('WRD SYNC COMPLETE', 0.5);

      // Step 2 — CWC Direct
      _setStatus('CONNECTING CWC DIRECT...', 0.5);
      await _fetchCwc();
      _setStatus('ALL SYSTEMS ONLINE', 1.0);
    } catch (e) {
      _setStatus('PARTIAL DATA — CONTINUING', 1.0);
    } finally {
      // Honour minimum display time
      final elapsed = DateTime.now().difference(_startTime).inMilliseconds;
      final remaining = _kMinSplashMs - elapsed;
      if (remaining > 0) {
        await Future.delayed(Duration(milliseconds: remaining));
      }
      if (mounted) {
        setState(() => _dataReady = true);
        _exitCtrl.forward();
      }
    }
  }

  void _setStatus(String label, double progress) {
    if (!mounted) return;
    setState(() {
      _fetchLabel = label;
      _fetchProg  = progress;
    });
  }

  // Replace these with your actual service calls:
  Future<void> _fetchWrd() async {
    // await WrdBiharService.instance.fetch();
    await Future.delayed(const Duration(milliseconds: 900));
  }

  Future<void> _fetchCwc() async {
    // await CwcDirectService.instance.fetchAll();
    await Future.delayed(const Duration(milliseconds: 700));
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030508),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);

          // Build stars once
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
                  // ── Layer 1: Universe ──────────────────────────────
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

                  // ── Layer 2: Branding ──────────────────────────────
                  FadeTransition(
                    opacity: _brandFade,
                    child: Opacity(
                      opacity: (1.0 - fadeOut).clamp(0.0, 1.0),
                      child: _BrandingOverlay(
                        coreGlow: _coreGlow,
                        size: size,
                      ),
                    ),
                  ),

                  // ── Layer 3: Progress indicator ────────────────────
                  Positioned(
                    bottom: 60,
                    left:   40,
                    right:  40,
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

// ─── Branding overlay (Layer 2) ────────────────────────────────────────────

class _BrandingOverlay extends StatelessWidget {
  const _BrandingOverlay({
    required this.coreGlow,
    required this.size,
  });

  final Animation<double> coreGlow;
  final Size              size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Logo mark — hexagonal glow frame
          AnimatedBuilder(
            animation: coreGlow,
            builder: (_, __) {
              const accent = Color(0xFF00FFB2);
              final pulse  = coreGlow.value;
              return Container(
                width:  72,
                height: 72,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: accent.withValues(alpha: 0.6 + 0.4 * pulse),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:      accent.withValues(alpha: 0.25 + 0.15 * pulse),
                      blurRadius: 18 + 10 * pulse,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.water_drop_outlined,
                  color: accent,
                  size:  38,
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          // App name
          const Text(
            'OPSFLOOD',
            style: TextStyle(
              fontFamily:    'RobotoMono',
              fontSize:      26,
              fontWeight:    FontWeight.w700,
              color:         Color(0xFFE0F0FF),
              letterSpacing: 5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'REAL-TIME FLOOD INTELLIGENCE',
            style: TextStyle(
              fontFamily:    'RobotoMono',
              fontSize:      10,
              color:         Color(0xFF5A7080),
              letterSpacing: 2.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Progress layer (Layer 3) ──────────────────────────────────────────────

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
            // Status label
            Row(
              children: [
                // Pulsing dot synced with core
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.5 + 0.5 * p),
                    boxShadow: [
                      BoxShadow(
                        color:      accent.withValues(alpha: 0.4 * p),
                        blurRadius: 6,
                      ),
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
                        fontFamily:    'RobotoMono',
                        fontSize:      10,
                        color:         Color(0xFF5A7080),
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: TextStyle(
                    fontFamily:    'RobotoMono',
                    fontSize:      10,
                    color:         accent.withValues(alpha: 0.8),
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Progress bar — glows with the core
            Container(
              height: 2,
              decoration: const BoxDecoration(
                color: Color(0xFF111620),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    color: accent,
                    boxShadow: [
                      BoxShadow(
                        color:      accent.withValues(alpha: 0.6 * p),
                        blurRadius: 6,
                      ),
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
