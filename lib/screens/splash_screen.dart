import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_screen.dart';
import '../services/api_service.dart';
import '../theme/river_theme.dart';
import '../providers/flood_providers.dart';

// ── Color aliases for the splash theme ─────────────────────────────────────
// Maps old "Equinox" palette names → existing AppPalette values.
extension _SplashColors on AppPalette {
  static const carbon0   = AppPalette.navy0;        // #020810 deepest bg
  static const ferrari   = AppPalette.critical;     // #FF1744 hot red  (was Ferrari red)
  static const gold      = AppPalette.amber;         // #FFB800 amber gold
  static const goldLight = AppPalette.amberLight;   // #FFD54F lighter amber
}

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
  late Animation<double>   _titleOpacity;
  late Animation<Offset>   _titleSlide;

  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseScale;
  late Animation<double>   _pulseOpacity;

  late AnimationController _sweepCtrl;
  late Animation<double>   _sweepPos;

  late AnimationController _statusCtrl;
  late Animation<double>   _statusOpacity;

  // Status cycling
  late AnimationController _dotCtrl;
  int _dotFrame = 0;

  String _statusText    = 'Initializing...';
  bool   _backendOnline = false;

  static const _statusMessages = [
    'Connecting to backend',
    'Loading flood data',
    'Calibrating sensors',
    'Almost there',
  ];
  int _msgIndex = 0;
  Timer? _msgTimer;

  @override
  void initState() {
    super.initState();

    // ── Entrance animation ────────────────────────────────────────────
    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _logoScale = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _entranceCtrl, curve: Curves.elasticOut));
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _entranceCtrl, curve: const Interval(0.0, 0.4)));
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _entranceCtrl, curve: const Interval(0.4, 0.8)));
    _titleSlide = Tween<Offset>(
            begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _entranceCtrl,
            curve: const Interval(0.4, 0.9, curve: Curves.easeOutCubic)));

    // ── Pulse ring ────────────────────────────────────────────────────
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _pulseScale   = Tween<double>(begin: 1.0, end: 1.6).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _pulseOpacity = Tween<double>(begin: 0.35, end: 0.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeIn));

    // ── Sweep line ────────────────────────────────────────────────────
    _sweepCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _sweepPos = Tween<double>(begin: -1.0, end: 1.0).animate(
        CurvedAnimation(parent: _sweepCtrl, curve: Curves.easeInOut));

    // ── Status fade-in ────────────────────────────────────────────────
    _statusCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _statusOpacity = CurvedAnimation(
        parent: _statusCtrl, curve: Curves.easeIn);

    // ── Animated dots ────────────────────────────────────────────────
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

    // Cycle status messages every 1.2 s so the screen feels active
    _msgTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      if (!mounted) return;
      setState(() {
        _msgIndex = (_msgIndex + 1) % _statusMessages.length;
        if (!_backendOnline) {
          _statusText = _statusMessages[_msgIndex];
        }
      });
    });

    _bootServices();
  }

  Future<void> _bootServices() async {
    // Fire-and-forget: start polling without awaiting it
    ref.read(realTimeProvider).startPolling();

    // Check backend with a hard 3-second timeout — never block splash longer
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
      _backendOnline = false; // timeout or network error — proceed anyway
    }

    if (!mounted) return;
    setState(() {
      _statusText = _backendOnline
          ? 'Systems online  \u2705'
          : 'Loading data  \u23f3';
    });

    // Show the final status for 800 ms then navigate — always
    await Future.delayed(const Duration(milliseconds: 800));
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
    _pulseCtrl.dispose();
    _sweepCtrl.dispose();
    _statusCtrl.dispose();
    _dotCtrl.dispose();
    _msgTimer?.cancel();
    super.dispose();
  }

  String get _dots => '.' * (_dotFrame % 4);

  // ── Local palette shorthands ──────────────────────────────────────────────
  static const _bg      = AppPalette.navy0;       // carbon0
  static const _accent  = AppPalette.critical;    // ferrari (red glow)
  static const _gold    = AppPalette.amber;        // gold
  static const _goldLt  = AppPalette.amberLight;  // goldLight

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Background radial gradient
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.2),
                radius: 0.9,
                colors: [const Color(0xFF1A0A0A), _bg],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
          // Carbon grid
          CustomPaint(size: size, painter: _CarbonGridPainter()),
          // Sweep line
          AnimatedBuilder(
            animation: _sweepCtrl,
            builder: (_, __) {
              final x = _sweepPos.value * size.width;
              return Positioned(
                left: x, top: 0, bottom: 0, width: 2,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _accent.withValues(alpha: 0.0),
                        _accent.withValues(alpha: 0.7),
                        _accent.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with pulse ring
                AnimatedBuilder(
                  animation: Listenable.merge([_entranceCtrl, _pulseCtrl]),
                  builder: (_, __) {
                    return Opacity(
                      opacity: _logoOpacity.value,
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: SizedBox(
                          width: 120, height: 120,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Pulse ring
                              Transform.scale(
                                scale: _pulseScale.value,
                                child: Container(
                                  width: 110, height: 110,
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
                              // Logo circle
                              Container(
                                width: 100, height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [const Color(0xFF3A0010), _accent],
                                    stops: const [0.0, 1.0],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _accent.withValues(alpha: 0.6),
                                      blurRadius: 32, spreadRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.water_drop,
                                  size: 52, color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 28),
                // Title
                SlideTransition(
                  position: _titleSlide,
                  child: FadeTransition(
                    opacity: _titleOpacity,
                    child: Column(
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [
                              _accent,
                              _goldLt,
                              Colors.white,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ).createShader(bounds),
                          child: const Text(
                            'OpsFlood',
                            style: TextStyle(
                              fontSize: 44, fontWeight: FontWeight.w900,
                              color: Colors.white, letterSpacing: -1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'AI-POWERED FLOOD INTELLIGENCE',
                          style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: _gold, letterSpacing: 3.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 64),
                // Status area
                FadeTransition(
                  opacity: _statusOpacity,
                  child: Column(
                    children: [
                      if (!_backendOnline)
                        SizedBox(
                          width: 200, height: 2,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              backgroundColor:
                                  _accent.withValues(alpha: 0.15),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _accent.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        )
                      else
                        const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppPalette.safe,
                            ),
                          ),
                        ),
                      const SizedBox(height: 14),
                      Text(
                        _backendOnline
                            ? _statusText
                            : '$_statusText$_dots',
                        style: const TextStyle(
                          color: AppPalette.textGrey, fontSize: 13,
                          fontWeight: FontWeight.w500, letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Version badge
          Positioned(
            bottom: 32, left: 0, right: 0,
            child: Center(
              child: Text(
                'v2.1  \u2022  MIDNIGHT OPS BUILD',
                style: TextStyle(
                  color: _accent.withValues(alpha: 0.5),
                  fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CarbonGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x08FFFFFF)
      ..strokeWidth = 0.5;
    const step = 28.0;
    for (double i = -size.height; i < size.width + size.height; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), paint);
      canvas.drawLine(Offset(i, 0), Offset(i - size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_CarbonGridPainter old) => false;
}
