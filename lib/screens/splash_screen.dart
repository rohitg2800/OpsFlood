// lib/screens/splash_screen.dart
// EQUINOX-BR05 — SplashScreen v6  (Deep Space — ultra-minimal premium)
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/flood_providers.dart';
import '../services/api_service.dart';
import '../theme/river_theme.dart';
import 'home_screen.dart';

// ─── boot phases ───────────────────────────────────────────────────────────────────────

enum _Phase {
  init,
  backend,
  providers,
  stations,
  done,
}

class _BootStep {
  final String label;
  final _Phase completeAt;
  const _BootStep(this.label, this.completeAt);
}

const _steps = [
  _BootStep('Initializing runtime',          _Phase.init),
  _BootStep('Connecting to backend',         _Phase.backend),
  _BootStep('Warming up data providers',     _Phase.providers),
  _BootStep('Loading live station feed',     _Phase.stations),
  _BootStep('System ready',                  _Phase.done),
];

// ─── screen ──────────────────────────────────────────────────────────────────────────────

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  final _api = ApiService();

  late final AnimationController _outerRingCtrl;
  late final AnimationController _innerRingCtrl;
  late final AnimationController _starCtrl;
  late final AnimationController _entryCtrl;
  late final AnimationController _progressCtrl;

  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _badgeFade;
  late final Animation<double> _textFade;
  late final Animation<Offset>  _textSlide;
  late final List<Animation<double>> _charFades;
  late final List<Animation<Offset>> _charSlides;

  _Phase  _phase   = _Phase.init;
  bool    _online  = false;
  bool    _exiting = false;

  static const _wordmark   = 'EQUINOX-BH';
  static const _charCount  = _wordmark.length;
  static const _charWindow = 0.08;
  static const _charStart  = 0.40;

  late final List<_Star> _stars;

  @override
  void initState() {
    super.initState();

    final rng = math.Random(42);
    _stars = List.generate(120, (_) => _Star(
      x:        rng.nextDouble(),
      y:        rng.nextDouble(),
      r:        rng.nextDouble() * 1.4 + 0.4,
      phase:    rng.nextDouble() * math.pi * 2,
      speed:    rng.nextDouble() * 0.6 + 0.2,
      opacity:  rng.nextDouble() * 0.5 + 0.15,
    ));

    _outerRingCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 4800))
      ..repeat();
    _innerRingCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600))
      ..repeat();
    _starCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3000))
      ..repeat();
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000));
    _progressCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));

    _logoFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _entryCtrl,
            curve: const Interval(0.0, 0.45, curve: Curves.easeOut)));
    _logoScale = Tween<double>(begin: 0.65, end: 1).animate(
        CurvedAnimation(parent: _entryCtrl,
            curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic)));
    _badgeFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _entryCtrl,
            curve: const Interval(0.75, 1.0, curve: Curves.easeOut)));

    // Combined text fade + slide for the subtitle block
    _textFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _entryCtrl,
            curve: const Interval(0.55, 0.90, curve: Curves.easeOut)));
    _textSlide = Tween<Offset>(
            begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl,
            curve: const Interval(0.55, 0.90, curve: Curves.easeOutCubic)));

    _charFades  = [];
    _charSlides = [];
    for (int i = 0; i < _charCount; i++) {
      final start = _charStart + i * (_charWindow * 0.7);
      final end   = (start + _charWindow).clamp(0.0, 1.0);
      _charFades.add(
        Tween<double>(begin: 0, end: 1).animate(
            CurvedAnimation(parent: _entryCtrl,
                curve: Interval(start, end, curve: Curves.easeOut))),
      );
      _charSlides.add(
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
            .animate(CurvedAnimation(parent: _entryCtrl,
                curve: Interval(start, end, curve: Curves.easeOutCubic))),
      );
    }

    _entryCtrl.forward();
    _advancePhase(_Phase.init);
    Future.delayed(const Duration(milliseconds: 500), _runBoot);
  }

  Future<void> _runBoot() async {
    try { _online = await _api.checkHealth(); } catch (_) {}
    _advancePhase(_Phase.backend);
    _animateProgressTo(0.35);

    ref.read(realTimeProvider);
    _advancePhase(_Phase.providers);
    _animateProgressTo(0.60);

    await _waitForStations();
    _advancePhase(_Phase.stations);
    _animateProgressTo(0.90);

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted || _exiting) return;
    _advancePhase(_Phase.done);
    _animateProgressTo(1.0);
    await Future.delayed(const Duration(milliseconds: 400));
    _navigate();
  }

  Future<void> _waitForStations() async {
    final deadline = DateTime.now().add(const Duration(seconds: 4));
    while (DateTime.now().isBefore(deadline)) {
      final levels = ref.read(liveLevelsProvider);
      if (levels.isNotEmpty) return;
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  void _advancePhase(_Phase p) {
    if (!mounted) return;
    setState(() => _phase = p);
  }

  void _animateProgressTo(double target) {
    _progressCtrl.animateTo(target,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic);
  }

  void _navigate() {
    if (_exiting || !mounted) return;
    _exiting = true;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 750),
      pageBuilder: (_, a, __) => const HomeScreen(),
      transitionsBuilder: (_, a, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: Curves.easeInOut),
        child: child,
      ),
    ));
  }

  @override
  void dispose() {
    _outerRingCtrl.dispose();
    _innerRingCtrl.dispose();
    _starCtrl.dispose();
    _entryCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  // ─── build ───────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.abyss0,
      body: Stack(
        children: [
          // Star field
          AnimatedBuilder(
            animation: _starCtrl,
            builder: (_, __) => CustomPaint(
              painter: _StarPainter(
                stars: _stars,
                t: _starCtrl.value,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          // Rings
          AnimatedBuilder(
            animation: Listenable.merge([_outerRingCtrl, _innerRingCtrl]),
            builder: (_, __) => CustomPaint(
              painter: _RingPainter(
                outerT: _outerRingCtrl.value,
                innerT: _innerRingCtrl.value,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          // Main content
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                FadeTransition(
                  opacity: _logoFade,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: Container(
                      width: 90, height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppPalette.abyss2,
                        border: Border.all(
                          color: AppPalette.gold.withValues(alpha: 0.50),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppPalette.gold.withValues(alpha: 0.10),
                            blurRadius: 40,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.water_drop_rounded,
                          color: AppPalette.cyan, size: 34),
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                // Text block (subtitle)
                FadeTransition(
                  opacity: _textFade,
                  child: SlideTransition(
                    position: _textSlide,
                    child: const Column(
                      children: [
                        Text('EQUINOX-BR05',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: AppPalette.textWhite,
                              letterSpacing: 1.5,
                            )),
                        SizedBox(height: 6),
                        Text('Real-time flood intelligence',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppPalette.textGrey,
                              letterSpacing: 0.5,
                            )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 56),
                // Boot steps
                ..._steps.map((step) {
                  final done = step.completeAt.index <= _phase.index;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: done
                              ? const Icon(Icons.check_circle_rounded,
                                  size: 14, color: AppPalette.gold,
                                  key: ValueKey('done'))
                              : const SizedBox(width: 14, height: 14,
                                  key: ValueKey('empty')),
                        ),
                        const SizedBox(width: 8),
                        Text(step.label,
                            style: TextStyle(
                              fontSize: 12,
                              color: done
                                  ? AppPalette.textWhite
                                  : AppPalette.textGrey,
                            )),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 32),
                // Progress arc
                AnimatedBuilder(
                  animation: _progressCtrl,
                  builder: (_, __) => SizedBox(
                    width: 200, height: 3,
                    child: LinearProgressIndicator(
                      value: _progressCtrl.value,
                      backgroundColor: AppPalette.abyss3,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppPalette.gold),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FadeTransition(
                  opacity: _badgeFade,
                  child: Text(
                    _online ? '• LIVE' : '• OFFLINE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _online ? AppPalette.cyan : AppPalette.warning,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Star data ────────────────────────────────────────────────────────────────────────────
class _Star {
  final double x, y, r, phase, speed, opacity;
  const _Star({
    required this.x, required this.y, required this.r,
    required this.phase, required this.speed, required this.opacity,
  });
}

class _StarPainter extends CustomPainter {
  final List<_Star> stars;
  final double t;
  const _StarPainter({required this.stars, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final s in stars) {
      final twinkle = (math.sin((t * s.speed + s.phase) * math.pi * 2) * 0.5 + 0.5);
      paint.color = AppPalette.textWhite.withValues(alpha: s.opacity * twinkle);
      canvas.drawCircle(Offset(s.x * size.width, s.y * size.height), s.r, paint);
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.t != t;
}

class _RingPainter extends CustomPainter {
  final double outerT, innerT;
  const _RingPainter({required this.outerT, required this.innerT});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Outer ring
    paint.color = AppPalette.gold.withValues(alpha: 0.08);
    canvas.drawCircle(Offset(cx, cy), size.width * 0.42, paint);

    // Outer dashes
    paint.color = AppPalette.gold.withValues(alpha: 0.15);
    paint.strokeWidth = 1.5;
    final outerAngle = outerT * 2 * math.pi;
    for (int i = 0; i < 12; i++) {
      final a = outerAngle + i * (2 * math.pi / 12);
      final r = size.width * 0.42;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        a, 0.15, false, paint,
      );
    }

    // Inner ring
    paint.color = AppPalette.cyan.withValues(alpha: 0.06);
    paint.strokeWidth = 1.0;
    canvas.drawCircle(Offset(cx, cy), size.width * 0.28, paint);

    final innerAngle = -innerT * 2 * math.pi;
    paint.color = AppPalette.cyan.withValues(alpha: 0.12);
    paint.strokeWidth = 1.2;
    for (int i = 0; i < 8; i++) {
      final a = innerAngle + i * (2 * math.pi / 8);
      final r = size.width * 0.28;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        a, 0.18, false, paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.outerT != outerT || old.innerT != innerT;
}
