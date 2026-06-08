// lib/theme/robotic_theme.dart
// Robotic design language — sharp corners, glow effects, monospaced type
// Two faces: Tactical Dark (isDark=true) / System Light (isDark=false)
library;

import 'package:flutter/material.dart';

// ─── Robotic palette ─────────────────────────────────────────────────────────

class RoboticColors {
  RoboticColors._();

  // TACTICAL DARK
  static const rdBg          = Color(0xFF030508);
  static const rdSurface     = Color(0xFF0A0D12);
  static const rdSurface2    = Color(0xFF111620);
  static const rdBorder      = Color(0xFF1C2333);
  static const rdAccent      = Color(0xFF00FFB2);
  static const rdAccentGlow  = Color(0x3300FFB2);
  static const rdAccent2     = Color(0xFF00AAFF);
  static const rdAccent2Glow = Color(0x2200AAFF);
  static const rdDanger      = Color(0xFFFF2D55);
  static const rdDangerGlow  = Color(0x33FF2D55);
  static const rdWarning     = Color(0xFFFFBF00);
  static const rdText        = Color(0xFFE0F0FF);
  static const rdTextDim     = Color(0xFF4A6080);
  static const rdScanline    = Color(0x06E0F0FF);

  // SYSTEM LIGHT
  static const rlBg          = Color(0xFFF0F4F8);
  static const rlSurface     = Color(0xFFFFFFFF);
  static const rlSurface2    = Color(0xFFE8EEF5);
  static const rlBorder      = Color(0xFFCDD5E0);
  static const rlAccent      = Color(0xFF006EFF);
  static const rlAccentGlow  = Color(0x1A006EFF);
  static const rlAccent2     = Color(0xFF00B896);
  static const rlDanger      = Color(0xFFD0021B);
  static const rlWarning     = Color(0xFFFF8C00);
  static const rlText        = Color(0xFF0D1B2A);
  static const rlTextDim     = Color(0xFF6B7A90);
}

// ─── RoboticTheme token bundle ───────────────────────────────────────────────

class RoboticTheme {
  final bool isDark;
  const RoboticTheme({required this.isDark});

  // Surfaces
  Color get bg       => isDark ? RoboticColors.rdBg       : RoboticColors.rlBg;
  Color get surface  => isDark ? RoboticColors.rdSurface  : RoboticColors.rlSurface;
  Color get surface2 => isDark ? RoboticColors.rdSurface2 : RoboticColors.rlSurface2;
  Color get border   => isDark ? RoboticColors.rdBorder   : RoboticColors.rlBorder;

  // Text
  Color get text    => isDark ? RoboticColors.rdText    : RoboticColors.rlText;
  Color get textDim => isDark ? RoboticColors.rdTextDim : RoboticColors.rlTextDim;

  // Accents
  Color get accent     => isDark ? RoboticColors.rdAccent    : RoboticColors.rlAccent;
  Color get accentGlow => isDark ? RoboticColors.rdAccentGlow: RoboticColors.rlAccentGlow;
  Color get accent2    => isDark ? RoboticColors.rdAccent2   : RoboticColors.rlAccent2;
  Color get danger     => isDark ? RoboticColors.rdDanger    : RoboticColors.rlDanger;
  Color get dangerGlow => isDark ? RoboticColors.rdDangerGlow: Colors.transparent;
  Color get warning    => isDark ? RoboticColors.rdWarning   : RoboticColors.rlWarning;

  // ── Decoration helpers ──────────────────────────────────────────────────

  /// Sharp zero-radius card with optional accent glow
  BoxDecoration cardDeco({Color? glowColor, double borderWidth = 1}) => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.zero,
    border: Border.all(color: border, width: borderWidth),
    boxShadow: glowColor != null
        ? [BoxShadow(color: glowColor, blurRadius: 14, spreadRadius: 1)]
        : null,
  );

  /// Accent-bordered card — for highlighted/active cards
  BoxDecoration accentCardDeco() => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.zero,
    border: Border.all(color: accent, width: 1.5),
    boxShadow: [BoxShadow(color: accentGlow, blurRadius: 14, spreadRadius: 1)],
  );

  /// HUD corner brackets widget wrapper
  Widget hudCorners({required Widget child, double size = 12, double thickness = 2}) =>
      _HudCorners(color: accent, size: size, thickness: thickness, child: child);

  /// Glowing horizontal rule
  Widget glowDivider() => _GlowDivider(color: accent);

  /// Scanline overlay — wraps any dark surface widget
  Widget scanlines({required Widget child}) => _Scanlines(child: child);

  /// Pulsing glow border
  Widget glowPulse({required Widget child, Duration period = const Duration(seconds: 2)}) =>
      _GlowPulse(color: accent, period: period, child: child);

  // ── Flutter ThemeData ────────────────────────────────────────────────────

  ThemeData toFlutterTheme() {
    final brightness = isDark ? Brightness.dark : Brightness.light;
    return ThemeData(
      brightness:             brightness,
      scaffoldBackgroundColor: bg,
      fontFamily:             'monospace',
      colorScheme: ColorScheme(
        brightness:  brightness,
        primary:     accent,
        onPrimary:   isDark ? Colors.black : Colors.white,
        secondary:   accent2,
        onSecondary: isDark ? Colors.black : Colors.white,
        surface:     surface,
        onSurface:   text,
        error:       danger,
        onError:     Colors.white,
      ),
      cardTheme: CardTheme(
        color:  surface,
        shape:  const RoundedRectangleBorder(),
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      dividerColor: border,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: text,
        elevation:       0,
        centerTitle:     false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color:       accent,
          fontSize:    15,
          fontWeight:  FontWeight.w700,
          letterSpacing: 2.5,
          fontFamily:  'monospace',
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? RoboticColors.rdBg : RoboticColors.rlBg,
        indicatorColor:  accentGlow,
        height:          64,
        iconTheme: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) {
            return IconThemeData(color: accent, size: 24);
          }
          return IconThemeData(color: textDim, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((s) {
          final c = s.contains(WidgetState.selected) ? accent : textDim;
          return TextStyle(
            color: c, fontSize: 10, fontWeight: FontWeight.w700,
            letterSpacing: 0.8, fontFamily: 'monospace',
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled:    true,
        fillColor: surface2,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide:   BorderSide(color: RoboticColors.rdBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide:   BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide:   BorderSide(color: accent, width: 1.5),
        ),
        hintStyle: TextStyle(color: textDim, fontFamily: 'monospace'),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: isDark ? Colors.black : Colors.white,
          shape: const RoundedRectangleBorder(),
          elevation: 0,
          textStyle: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            fontFamily: 'monospace',
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: BorderSide(color: accent, width: 1.5),
          shape: const RoundedRectangleBorder(),
          textStyle: TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            fontFamily: 'monospace',
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color:            accent,
        linearTrackColor: surface2,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface2,
        labelStyle: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600,
          color: text, letterSpacing: 0.6, fontFamily: 'monospace',
        ),
        side: BorderSide(color: border),
        shape: const RoundedRectangleBorder(),
      ),
    );
  }
}

// ─── RoboticFonts — convenience text style factory ───────────────────────────

class RoboticFonts {
  RoboticFonts._();

  static TextStyle mono({
    double size = 13,
    Color color = RoboticColors.rdText,
    FontWeight weight = FontWeight.w400,
    double letterSpacing = 0.5,
  }) =>
      TextStyle(
        fontFamily:    'monospace',
        fontSize:      size,
        color:         color,
        fontWeight:    weight,
        letterSpacing: letterSpacing,
      );

  static TextStyle display({
    double size = 18,
    Color color = RoboticColors.rdAccent,
    FontWeight weight = FontWeight.w700,
  }) =>
      TextStyle(
        fontFamily:    'monospace',
        fontSize:      size,
        color:         color,
        fontWeight:    weight,
        letterSpacing: 2.0,
      );

  static TextStyle body({
    double size = 13,
    Color color = RoboticColors.rdText,
  }) =>
      TextStyle(
        fontFamily:    'monospace',
        fontSize:      size,
        color:         color,
        letterSpacing: 0.3,
      );
}

// ─── Private widget helpers ───────────────────────────────────────────────────

class _HudCorners extends StatelessWidget {
  final Widget child;
  final Color  color;
  final double size, thickness;
  const _HudCorners({
    required this.child,
    required this.color,
    required this.size,
    required this.thickness,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(top: 0, left: 0,
            child: _Corner(color, size, thickness, _CornerPos.tl)),
        Positioned(top: 0, right: 0,
            child: _Corner(color, size, thickness, _CornerPos.tr)),
        Positioned(bottom: 0, left: 0,
            child: _Corner(color, size, thickness, _CornerPos.bl)),
        Positioned(bottom: 0, right: 0,
            child: _Corner(color, size, thickness, _CornerPos.br)),
      ],
    );
  }
}

enum _CornerPos { tl, tr, bl, br }

class _Corner extends StatelessWidget {
  final Color      color;
  final double     size, thickness;
  final _CornerPos pos;
  const _Corner(this.color, this.size, this.thickness, this.pos);

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size, height: size,
    child: CustomPaint(
      painter: _CornerPainter(
        color,
        thickness,
        pos == _CornerPos.tl || pos == _CornerPos.bl,
        pos == _CornerPos.tl || pos == _CornerPos.tr,
      ),
    ),
  );
}

class _CornerPainter extends CustomPainter {
  final Color  color;
  final double t;
  final bool   isLeft, isTop;
  _CornerPainter(this.color, this.t, this.isLeft, this.isTop);

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color      = color
      ..strokeWidth = t
      ..style      = PaintingStyle.stroke;
    final x  = isLeft ? 0.0  : s.width;
    final y  = isTop  ? 0.0  : s.height;
    final ex = isLeft ? s.width  : 0.0;
    final ey = isTop  ? s.height : 0.0;
    canvas.drawLine(Offset(x, y), Offset(ex, y), p);
    canvas.drawLine(Offset(x, y), Offset(x, ey), p);
  }

  @override
  bool shouldRepaint(_CornerPainter o) => o.color != color;
}

class _GlowDivider extends StatelessWidget {
  final Color color;
  const _GlowDivider({required this.color});

  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [
        Colors.transparent, color, color, Colors.transparent,
      ]),
      boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6)],
    ),
  );
}

class _Scanlines extends StatelessWidget {
  final Widget child;
  const _Scanlines({required this.child});

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      child,
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(painter: _ScanlinePainter()),
        ),
      ),
    ],
  );
}

class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color       = RoboticColors.rdScanline
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override bool shouldRepaint(_) => false;
}

class _GlowPulse extends StatefulWidget {
  final Widget   child;
  final Color    color;
  final Duration period;
  const _GlowPulse({required this.child, required this.color, required this.period});

  @override State<_GlowPulse> createState() => _GlowPulseState();
}

class _GlowPulseState extends State<_GlowPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double>   _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.period)
      ..repeat(reverse: true);
    _a = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
  }

  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _a,
    builder: (_, child) => Container(
      decoration: BoxDecoration(boxShadow: [
        BoxShadow(
          color:       widget.color.withValues(alpha: 0.15 + 0.35 * _a.value),
          blurRadius:  8 + 16 * _a.value,
          spreadRadius: _a.value * 2,
        ),
      ]),
      child: child,
    ),
    child: widget.child,
  );
}
