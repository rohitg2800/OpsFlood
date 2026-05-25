// lib/screens/splash_screen.dart
// OpsFlood — SplashScreen v5  (Abyss Ops — cyan accent, minimal grid)
library;

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/flood_providers.dart';
import '../services/api_service.dart';
import '../theme/river_theme.dart';
import 'home_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  // ── Controllers ──────────────────────────────────────────────────────
  late AnimationController _entranceCtrl;
  late Animation<double>   _logoScale;
  late Animation<double>   _logoOpacity;
  late Animation<double>   _titleOpacity;
  late Animation<Offset>   _titleSlide;

  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseScale;
  late Animation<double>   _pulseOpacity;

  late AnimationController _sweepCtrl;
  late Animation<double>   _sweepPos;

  late AnimationController _statusCtrl;
  late Animation<double>   _statusOpacity;

  late AnimationController _dotCtrl;
  int _dotFrame = 0;

  String _statusText    = 'Initializing...';
  bool   _backendOnline = false;

  static const _statusMessages = [
    'Connecting to backend',
    'Loading flood data',
    'Syncing river sensors',
    'Almost ready',
  ];
  int    _msgIndex = 0;
  Timer? _msgTimer;

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _logoScale = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _entranceCtrl, curve: Curves.elasticOut));
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _entranceCtrl,
            curve: const Interval(0.0, 0.4)));
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _entranceCtrl,
            curve: const Interval(0.4, 0.8)));
    _titleSlide = Tween<Offset>(
            begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entranceCtrl,
            curve: const Interval(0.4, 0.9, curve: Curves.easeOutCubic)));

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _pulseScale   = Tween<double>(begin: 1.0, end: 1.55).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _pulseOpacity = Tween<double>(begin: 0.4, end: 0.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeIn));

    _sweepCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100));
    _sweepPos = Tween<double>(begin: -1.0, end: 1.0).animate(
        CurvedAnimation(parent: _sweepCtrl, curve: Curves.easeInOut));

    _statusCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _statusOpacity =
        CurvedAnimation(parent: _statusCtrl, curve: Curves.easeIn);

    _dotCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..addListener(() {
        if (!mounted) return;
        setState(() => _dotFrame = (_dotFrame + 1) % 4);
      })
      ..repeat();

    _entranceCtrl.forward().then((_) {
      _sweepCtrl.forward();
      _statusCtrl.forward();
    });

    _msgTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      if (!mounted) return;
      setState(() {
        _msgIndex = (_msgIndex + 1) % _statusMessages.length;
        if (!_backendOnline) _statusText = _statusMessages[_msgIndex];
      });
    });

    // FIX: defer _bootServices() until after the first frame so the
    // ProviderScope is fully mounted before RealTimeService calls
    // notifyListeners().  Calling startPolling() synchronously from
    // initState violates Riverpod's _debugCanModifyProviders invariant.
    // addPostFrameCallback does NOT create a FakeAsync-tracked Timer,
    // so the widget test teardown stays clean.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bootServices();
    });
  }

  Future<void> _bootServices() async {
    ref.read(realTimeProvider).startPolling();
    _checkBackend();
  }

  Future<void> _checkBackend() async {
    try {
      final health = await ApiService()
          .checkHealth()
          .timeout(const Duration(seconds: 3));
      _backendOnline =
          health['status'] != 'offline' && health['status'] != 'error';
    } catch (_) {
      _backendOnline = false;
    }
    if (!mounted) return;
    setState(() {
      _statusText = _backendOnline ? 'Systems online  ✅' : 'Loading cached data  ⏳';
    });
    await Future.delayed(const Duration(milliseconds: 800));
    _navigate();
  }

  void _navigate() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder:        (_, __, ___) => const HomeScreen(),
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
    _pulseCtrl.dispose();
    _sweepCtrl.dispose();
    _statusCtrl.dispose();
    _dotCtrl.dispose();
    _msgTimer?.cancel();
    super.dispose();
  }

  String get _dots => '.' * (_dotFrame % 4);

  // ── Palette ───────────────────────────────────────────────────────────
  static const _bg     = AppPalette.abyss0;
  static const _accent = AppPalette.cyan;
  static const _gold   = AppPalette.amber;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Deep radial glow — cyan instead of red
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.25),
                radius: 0.85,
                colors: [
                  _accent.withValues(alpha: 0.07),
                  _bg,
                ],
              ),
            ),
          ),
          // Minimal dot-grid background
          CustomPaint(size: size, painter: _DotGridPainter()),
          // Diagonal sweep line
          AnimatedBuilder(
            animation: _sweepCtrl,
            builder: (_, __) {
              final x = _sweepPos.value * size.width;
              return Positioned(
                left: x, top: 0, bottom: 0, width: 1.5,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end:   Alignment.bottomCenter,
                      colors: [
                        _accent.withValues(alpha: 0.0),
                        _accent.withValues(alpha: 0.5),
                        _accent.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          // ── Main content ──────────────────────────────────────────
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                AnimatedBuilder(
                  animation: Listenable.merge([_entranceCtrl, _pulseCtrl]),
                  builder: (_, __) => Opacity(
                    opacity: _logoOpacity.value,
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: SizedBox(
                        width: 128, height: 128,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // outer pulse ring
                            Transform.scale(
                              scale: _pulseScale.value,
                              child: Container(
                                width: 112, height: 112,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _accent.withValues(
                                        alpha: _pulseOpacity.value),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                            // logo circle
                            Container(
                              width: 96, height: 96,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF0A2A3A),
                                    Color(0xFF003D55),
                                  ],
                                  begin: Alignment.topLeft,
                                  end:   Alignment.bottomRight,
                                ),
                                border: Border.all(
                                    color: _accent.withValues(alpha: 0.55),
                                    width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color:      _accent.withValues(alpha: 0.40),
                                    blurRadius: 36,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.water_drop_rounded,
                                size: 48, color: AppPalette.cyan,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Title
                SlideTransition(
                  position: _titleSlide,
                  child: FadeTransition(
                    opacity: _titleOpacity,
                    child: Column(
                      children: [
                        ShaderMask(
                          shaderCallback: (b) => const LinearGradient(
                            colors: [AppPalette.cyan, AppPalette.textWhite],
                            stops: [0.0, 0.6],
                          ).createShader(b),
                          child: const Text(
                            'OpsFlood',
                            style: TextStyle(
                              fontSize:   46,
                              fontWeight: FontWeight.w900,
                              color:      Colors.white,
                              letterSpacing: -1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'AI-POWERED FLOOD INTELLIGENCE',
                          style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: _gold, letterSpacing: 3.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 72),
                // Status
                FadeTransition(
                  opacity: _statusOpacity,
                  child: Column(
                    children: [
                      if (!_backendOnline)
                        SizedBox(
                          width: 180, height: 2,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              backgroundColor:
                                  _accent.withValues(alpha: 0.12),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  _accent.withValues(alpha: 0.75)),
                            ),
                          ),
                        )
                      else
                        const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                AppPalette.safe),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Text(
                        _backendOnline
                            ? _statusText
                            : '$_statusText$_dots',
                        style: const TextStyle(
                          color: AppPalette.textGrey,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Version stamp
          Positioned(
            bottom: 32, left: 0, right: 0,
            child: Center(
              child: Text(
                'v2.2  •  ABYSS OPS BUILD',
                style: TextStyle(
                  color: _accent.withValues(alpha: 0.38),
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

// ── Minimal dot grid painter ──────────────────────────────────────────────────
class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0C00C6FF)
      ..style = PaintingStyle.fill;
    const step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }
  @override
  bool shouldRepaint(_DotGridPainter old) => false;
}
