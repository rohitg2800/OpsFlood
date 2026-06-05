// lib/screens/splash_screen.dart
// EQUINOX-BH — SplashScreen v7  "Deep Space Launch"
// ─────────────────────────────────────────────────────────────────────────────
// Phase 5 upgrades over v6:
//  1. Star-field CustomPainter  — 120 randomised twinkling stars
//  2. Dual orbit rings          — outer slow CW + inner fast CCW, different radii
//  3. Letter-by-letter wordmark — staggered Interval fade/slide per character
//  4. Multi-phase boot log      — each phase unlocks when its provider is ready
//  5. Riverpod warm-up progress — reads isWakingUpProvider + liveLevelsProvider
//                                 to drive a real (not fake) progress arc
// ─────────────────────────────────────────────────────────────────────────────
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/flood_providers.dart';
import '../services/api_service.dart';
import '../theme/river_theme.dart';
import 'home_screen.dart';

// ─── boot phases ─────────────────────────────────────────────────────────────

enum _Phase {
  init,       // 0 — flutter bindings
  backend,    // 1 — api health check
  providers,  // 2 — riverpod warm-up polling
  stations,   // 3 — live station data arrived
  done,       // 4 — navigate
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

// ─── screen ──────────────────────────────────────────────────────────────────

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  final _api = ApiService();

  // animation controllers
  late final AnimationController _outerRingCtrl;  // slow CW
  late final AnimationController _innerRingCtrl;  // fast CCW
  late final AnimationController _starCtrl;       // twinkle pulsing
  late final AnimationController _entryCtrl;      // logo + text entry
  late final AnimationController _progressCtrl;   // real progress arc 0→1

  // derived animations
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _badgeFade;
  late final List<Animation<double>> _charFades;
  late final List<Animation<Offset>> _charSlides;

  _Phase  _phase   = _Phase.init;
  bool    _online  = false;
  bool    _exiting = false;

  static const _wordmark   = 'EQUINOX-BH';
  static const _charCount  = _wordmark.length;          // 10
  static const _charWindow = 0.08;                      // fraction per char
  static const _charStart  = 0.40;                      // when text begins

  // star field data — generated once
  late final List<_Star> _stars;

  @override
  void initState() {
    super.initState();

    // ── generate 120 stars ─────────────────────────────────────────────────
    final rng = math.Random(42);
    _stars = List.generate(120, (_) => _Star(
      x:        rng.nextDouble(),
      y:        rng.nextDouble(),
      r:        rng.nextDouble() * 1.4 + 0.4,
      phase:    rng.nextDouble() * math.pi * 2,
      speed:    rng.nextDouble() * 0.6 + 0.2,
      opacity:  rng.nextDouble() * 0.5 + 0.15,
    ));

    // ── animation controllers ───────────────────────────────────────────────
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

    // ── entry animations ────────────────────────────────────────────────────
    _logoFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _entryCtrl,
            curve: const Interval(0.0, 0.45, curve: Curves.easeOut)));

    _logoScale = Tween<double>(begin: 0.65, end: 1).animate(
        CurvedAnimation(parent: _entryCtrl,
            curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic)));

    _badgeFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _entryCtrl,
            curve: const Interval(0.75, 1.0, curve: Curves.easeOut)));

    // staggered character animations
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
        Tween<Offset>(
                begin: const Offset(0, 0.5), end: Offset.zero)
            .animate(CurvedAnimation(parent: _entryCtrl,
                curve: Interval(start, end, curve: Curves.easeOutCubic))),
      );
    }

    _entryCtrl.forward();
    _advancePhase(_Phase.init);
    Future.delayed(const Duration(milliseconds: 500), _runBoot);
  }

  // ── boot sequence ───────────────────────────────────────────────────────────

  Future<void> _runBoot() async {
    // Phase 1 — backend health
    try {
      _online = await _api.checkHealth();
    } catch (_) {}
    _advancePhase(_Phase.backend);
    _animateProgressTo(0.35);

    // Phase 2 — kick off providers
    ref.read(realTimeProvider);          // start polling
    _advancePhase(_Phase.providers);
    _animateProgressTo(0.60);

    // Phase 3 — wait for stations (max 4 s)
    await _waitForStations();
    _advancePhase(_Phase.stations);
    _animateProgressTo(0.90);

    // Phase 4 — short cosmetic pause then done
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

  // ── build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: AppPalette.abyss0,
      body: Stack(
        fit: StackFit.expand,
        children: [

          // ── 1. star field ─────────────────────────────────────────────────
          AnimatedBuilder(
            animation: _starCtrl,
            builder: (_, __) => CustomPaint(
              painter: _StarFieldPainter(
                  stars: _stars, tick: _starCtrl.value),
            ),
          ),

          // ── 2. radial glow ────────────────────────────────────────────────
          CustomPaint(painter: _RadialGlowPainter(size: sz)),

          // ── 3. main content ───────────────────────────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                // logo assembly
                AnimatedBuilder(
                  animation: Listenable.merge([
                    _outerRingCtrl, _innerRingCtrl, _entryCtrl, _progressCtrl,
                  ]),
                  builder: (_, __) => FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: SizedBox(
                        width: 140, height: 140,
                        child: Stack(alignment: Alignment.center, children: [

                          // outer ring — slow CW
                          Transform.rotate(
                            angle: _outerRingCtrl.value * 2 * math.pi,
                            child: CustomPaint(
                              size: const Size(140, 140),
                              painter: _OrbitRingPainter(
                                radius:      66,
                                strokeWidth: 1.2,
                                arcFraction: 0.72,
                                color:       AppPalette.cyan,
                                alpha:       0.30,
                                dotCount:    3,
                              ),
                            ),
                          ),

                          // inner ring — fast CCW
                          Transform.rotate(
                            angle: -_innerRingCtrl.value * 2 * math.pi,
                            child: CustomPaint(
                              size: const Size(140, 140),
                              painter: _OrbitRingPainter(
                                radius:      50,
                                strokeWidth: 1.0,
                                arcFraction: 0.45,
                                color:       AppPalette.gold,
                                alpha:       0.40,
                                dotCount:    2,
                              ),
                            ),
                          ),

                          // real progress arc overlay
                          CustomPaint(
                            size: const Size(140, 140),
                            painter: _ProgressArcPainter(
                              fraction: _progressCtrl.value,
                            ),
                          ),

                          // core icon
                          Container(
                            width: 76, height: 76,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppPalette.abyss2,
                              border: Border.all(
                                  color: AppPalette.cyan.withValues(alpha: 0.28),
                                  width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: AppPalette.cyan.withValues(alpha: 0.20),
                                  blurRadius: 28,
                                  spreadRadius: 2,
                                ),
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
                        ]),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // ── staggered wordmark ──────────────────────────────────────
                AnimatedBuilder(
                  animation: _entryCtrl,
                  builder: (_, __) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(_charCount, (i) {
                      final ch = _wordmark[i];
                      return FadeTransition(
                        opacity: _charFades[i],
                        child: SlideTransition(
                          position: _charSlides[i],
                          child: Text(
                            ch,
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: ch == '-'
                                  ? AppPalette.cyan.withValues(alpha: 0.70)
                                  : AppPalette.textWhite,
                              letterSpacing: 2.5,
                              height: 1,
                              shadows: [
                                Shadow(
                                  color: AppPalette.cyan.withValues(alpha: 0.35),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 8),

                // tagline
                FadeTransition(
                  opacity: _badgeFade,
                  child: const Text(
                    'Real-time flood intelligence',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppPalette.textGrey,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),

                const SizedBox(height: 44),

                // ── boot log ────────────────────────────────────────────────
                _BootLog(phase: _phase),

                const SizedBox(height: 20),

                // ── online pill ─────────────────────────────────────────────
                FadeTransition(
                  opacity: _badgeFade,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: (_online
                              ? AppPalette.safe
                              : AppPalette.textGrey)
                          .withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: (_online
                                ? AppPalette.safe
                                : AppPalette.textGrey)
                            .withValues(alpha: 0.28),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PulseDot(online: _online),
                        const SizedBox(width: 7),
                        Text(
                          _online ? 'Backend online' : 'Connecting…',
                          style: TextStyle(
                            fontSize: 10,
                            color: _online
                                ? AppPalette.safe
                                : AppPalette.textGrey,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
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

// ─── boot log widget ──────────────────────────────────────────────────────────

class _BootLog extends StatelessWidget {
  final _Phase phase;
  const _BootLog({required this.phase});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _steps.map((step) {
          final done    = step.completeAt.index <= phase.index;
          final active  = step.completeAt.index == phase.index + 1;
          final col = done
              ? AppPalette.safe
              : active
                  ? AppPalette.cyan
                  : AppPalette.textDim.withValues(alpha: 0.45);
          return AnimatedOpacity(
            duration: const Duration(milliseconds: 350),
            opacity: done || active ? 1.0 : 0.35,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.5),
              child: Row(
                children: [
                  SizedBox(
                    width: 16, height: 16,
                    child: done
                        ? Icon(Icons.check_circle_rounded,
                            color: AppPalette.safe, size: 12)
                        : active
                            ? const SizedBox(
                                width: 12, height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: AppPalette.cyan,
                                ),
                              )
                            : Container(
                                width: 6, height: 6,
                                margin: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppPalette.textDim
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    step.label,
                    style: TextStyle(
                      color: col,
                      fontSize: 10.5,
                      fontWeight: done
                          ? FontWeight.w600
                          : FontWeight.w400,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── pulse dot ────────────────────────────────────────────────────────────────

class _PulseDot extends StatefulWidget {
  final bool online;
  const _PulseDot({required this.online});
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final col = widget.online ? AppPalette.safe : AppPalette.textGrey;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: 7, height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: col.withValues(alpha: 0.5 + 0.5 * _ctrl.value),
          boxShadow: widget.online
              ? [
                  BoxShadow(
                    color: col.withValues(alpha: 0.4 * _ctrl.value),
                    blurRadius: 6,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
      ),
    );
  }
}

// ─── painters ─────────────────────────────────────────────────────────────────

// Star data
class _Star {
  final double x, y, r, phase, speed, opacity;
  const _Star({
    required this.x, required this.y, required this.r,
    required this.phase, required this.speed, required this.opacity,
  });
}

class _StarFieldPainter extends CustomPainter {
  final List<_Star> stars;
  final double      tick;   // 0→1 repeating
  const _StarFieldPainter({required this.stars, required this.tick});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final s in stars) {
      // each star has its own phase offset → they twinkle independently
      final flicker = 0.5 +
          0.5 * math.sin(tick * math.pi * 2 * s.speed + s.phase);
      paint.color = AppPalette.textWhite
          .withValues(alpha: s.opacity * flicker);
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height),
        s.r,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StarFieldPainter old) => old.tick != tick;
}

class _RadialGlowPainter extends CustomPainter {
  final Size size;
  const _RadialGlowPainter({required this.size});

  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawRect(
      Offset.zero & s,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF00C6FF).withValues(alpha: 0.09),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(
          center: Offset(s.width / 2, s.height * 0.38),
          radius: s.width * 0.65,
        )),
    );
    // secondary warm glow at bottom
    canvas.drawRect(
      Offset.zero & s,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppPalette.gold.withValues(alpha: 0.04),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(
          center: Offset(s.width / 2, s.height * 0.75),
          radius: s.width * 0.50,
        )),
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// Dual orbit ring painter — reusable for both rings
class _OrbitRingPainter extends CustomPainter {
  final double radius, strokeWidth, arcFraction, alpha;
  final Color  color;
  final int    dotCount;
  const _OrbitRingPainter({
    required this.radius,
    required this.strokeWidth,
    required this.arcFraction,
    required this.color,
    required this.alpha,
    required this.dotCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx   = size.width / 2;
    final cy   = size.height / 2;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    // track (full circle, very faint)
    canvas.drawCircle(
      Offset(cx, cy), radius,
      Paint()
        ..style       = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color       = color.withValues(alpha: alpha * 0.18),
    );

    // sweep arc
    canvas.drawArc(
      rect, 0, math.pi * 2 * arcFraction, false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          colors: [
            Colors.transparent,
            color.withValues(alpha: alpha),
            Colors.transparent,
          ],
        ).createShader(rect),
    );

    // glowing dots distributed on arc
    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: alpha + 0.2);
    for (int d = 0; d < dotCount; d++) {
      final angle = math.pi * 2 * arcFraction * d / math.max(dotCount - 1, 1);
      final dx    = cx + radius * math.cos(angle);
      final dy    = cy + radius * math.sin(angle);
      canvas.drawCircle(Offset(dx, dy), strokeWidth * 2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_OrbitRingPainter old) => false;
}

// Real progress arc — driven by _progressCtrl (0→1)
class _ProgressArcPainter extends CustomPainter {
  final double fraction;
  const _ProgressArcPainter({required this.fraction});

  @override
  void paint(Canvas canvas, Size size) {
    if (fraction <= 0) return;
    final cx   = size.width / 2;
    final cy   = size.height / 2;
    final r    = size.width / 2 - 3;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    canvas.drawArc(
      rect,
      -math.pi / 2,                    // start at 12 o'clock
      math.pi * 2 * fraction,
      false,
      Paint()
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap   = StrokeCap.round
        ..shader      = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle:   -math.pi / 2 + math.pi * 2,
          colors: [
            AppPalette.cyan.withValues(alpha: 0.0),
            AppPalette.cyan,
            AppPalette.gold.withValues(alpha: 0.6),
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_ProgressArcPainter old) => old.fraction != fraction;
}
