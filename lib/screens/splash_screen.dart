// lib/screens/splash_screen.dart
// OpsFlood — SplashScreen v5 (Abyss Ops premium rebuild)
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_screen.dart';
import '../services/api_service.dart';
import '../theme/river_theme.dart';
import '../providers/flood_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {

  late AnimationController _entranceCtrl;
  late Animation<double>   _logoScale;
  late Animation<double>   _logoOpacity;
  late Animation<double>   _textOpacity;
  late Animation<Offset>   _textSlide;

  late AnimationController _ringCtrl;
  late Animation<double>   _ringScale;
  late Animation<double>   _ringOpacity;

  late AnimationController _orbitCtrl;

  late AnimationController _barCtrl;
  late Animation<double>   _barWidth;

  String _statusText    = 'Initializing systems';
  bool   _backendOnline = false;
  int    _msgIndex      = 0;
  Timer? _msgTimer;

  static const _msgs = [
    'Connecting to backend',
    'Loading flood data',
    'Calibrating sensors',
    'Syncing river gauges',
    'Almost ready',
  ];

  static const _bg     = AppPalette.abyss0;
  static const _cyan   = AppPalette.cyan;
  static const _amber  = AppPalette.amber;

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));
    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _entranceCtrl, curve: Curves.elasticOut));
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.0, 0.35)));
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.45, 0.80)));
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _entranceCtrl,
            curve: const Interval(0.45, 0.90, curve: Curves.easeOutCubic)));

    _ringCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _ringScale   = Tween<double>(begin: 1.0, end: 1.7)
        .animate(CurvedAnimation(parent: _ringCtrl, curve: Curves.easeInOut));
    _ringOpacity = Tween<double>(begin: 0.40, end: 0.0)
        .animate(CurvedAnimation(parent: _ringCtrl, curve: Curves.easeIn));

    _orbitCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3000))
      ..repeat();

    _barCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200));
    _barWidth = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _barCtrl, curve: Curves.easeInOut));

    _entranceCtrl.forward().then((_) => _barCtrl.forward());

    _msgTimer = Timer.periodic(const Duration(milliseconds: 1100), (_) {
      if (!mounted || _backendOnline) return;
      setState(() {
        _msgIndex   = (_msgIndex + 1) % _msgs.length;
        _statusText = _msgs[_msgIndex];
      });
    });

    _bootServices();
  }

  Future<void> _bootServices() async {
    ref.read(realTimeProvider).startPolling();
    try {
      final health = await ApiService()
          .checkHealth()
          .timeout(const Duration(seconds: 3));
      _backendOnline = health['status'] != 'offline' && health['status'] != 'error';
    } catch (_) {
      _backendOnline = false;
    }
    if (!mounted) return;
    setState(() {
      _statusText = _backendOnline ? 'Systems online ✓' : 'Loading cached data';
    });
    await Future.delayed(const Duration(milliseconds: 900));
    _navigate();
  }

  void _navigate() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeInOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 700),
      ),
    );
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _ringCtrl.dispose();
    _orbitCtrl.dispose();
    _barCtrl.dispose();
    _msgTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Radial bg glow
          Positioned.fill(
            child: CustomPaint(
              painter: _AbyssGridPainter(),
            ),
          ),
          // Cyan radial
          Positioned(
            top: size.height * 0.15,
            left: size.width * 0.5 - 200,
            child: Container(
              width: 400, height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _cyan.withValues(alpha: 0.07),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Logo ──────────────────────────────────────────────
                AnimatedBuilder(
                  animation: Listenable.merge([_entranceCtrl, _ringCtrl, _orbitCtrl]),
                  builder: (_, __) => Opacity(
                    opacity: _logoOpacity.value,
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: SizedBox(
                        width: 140, height: 140,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer pulse ring
                            Transform.scale(
                              scale: _ringScale.value,
                              child: Container(
                                width: 120, height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _cyan.withValues(alpha: _ringOpacity.value),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            // Orbit dot
                            Transform.rotate(
                              angle: _orbitCtrl.value * 2 * math.pi,
                              child: Transform.translate(
                                offset: const Offset(56, 0),
                                child: Container(
                                  width: 7, height: 7,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _amber,
                                    boxShadow: [
                                      BoxShadow(
                                        color: _amber.withValues(alpha: 0.8),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Inner glow ring
                            Container(
                              width: 104, height: 104,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _cyan.withValues(alpha: 0.18),
                                  width: 1,
                                ),
                              ),
                            ),
                            // Logo core
                            Container(
                              width: 86, height: 86,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    _cyan.withValues(alpha: 0.22),
                                    AppPalette.abyss2,
                                  ],
                                ),
                                border: Border.all(
                                  color: _cyan.withValues(alpha: 0.50),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _cyan.withValues(alpha: 0.30),
                                    blurRadius: 30,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.water_drop_rounded,
                                size: 40,
                                color: AppPalette.cyan,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // ── Title ─────────────────────────────────────────────
                SlideTransition(
                  position: _textSlide,
                  child: FadeTransition(
                    opacity: _textOpacity,
                    child: Column(
                      children: [
                        ShaderMask(
                          shaderCallback: (b) => const LinearGradient(
                            colors: [AppPalette.cyanBright, AppPalette.cyan, AppPalette.amber],
                            stops: [0.0, 0.55, 1.0],
                          ).createShader(b),
                          child: const Text(
                            'OpsFlood',
                            style: TextStyle(
                              fontSize: 46, fontWeight: FontWeight.w900,
                              color: Colors.white, letterSpacing: -1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'AI  •  FLOOD  •  INTELLIGENCE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _cyan.withValues(alpha: 0.65),
                            letterSpacing: 4.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 72),
                // ── Progress bar ──────────────────────────────────────
                FadeTransition(
                  opacity: _textOpacity,
                  child: Column(
                    children: [
                      SizedBox(
                        width: 180,
                        child: AnimatedBuilder(
                          animation: _barCtrl,
                          builder: (_, __) => Stack(
                            children: [
                              Container(
                                height: 2,
                                decoration: BoxDecoration(
                                  color: _cyan.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: _barWidth.value,
                                child: Container(
                                  height: 2,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [_cyan.withValues(alpha: 0.4), _cyan],
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _cyan.withValues(alpha: 0.6),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _statusText,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppPalette.textGrey.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Version
          Positioned(
            bottom: 28, left: 0, right: 0,
            child: Center(
              child: Text(
                'v2.2  ABYSS OPS  2026',
                style: TextStyle(
                  color: _cyan.withValues(alpha: 0.30),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AbyssGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x06FFFFFF)
      ..strokeWidth = 0.5;
    const step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  @override
  bool shouldRepaint(_AbyssGridPainter old) => false;
}
