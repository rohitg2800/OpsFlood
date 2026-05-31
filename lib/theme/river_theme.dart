import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  EQUINOX-BR05  –  Golden Ops Design Language  (v6 — Warm Gold Rebuild)
//
//  Philosophy:
//    • Deep warm-gold base        →  rich dark-amber scaffold, zero blue
//    • Bronze-to-gold layers      →  each card step warms upward visibly
//    • Bright amber gold accent   →  primary CTA / live data highlights
//    • Electric cyan retained     →  only for live status / alerts
//    • Red reserved               →  critical alerts ONLY
//    • Glass morphism             →  warm frosted overlays
//
//  Background progression (dark → light, all warm gold):
//    abyss0  #0F0A00  ← deepest floor  (near-black with warm gold tint)
//    abyss1  #1A1000  ← scaffold bg    (dark amber-brown)
//    abyss2  #251800  ← card surface   (deep bronze)
//    abyss3  #312200  ← elevated card  (richer bronze-gold)
//    abyss4  #3D2C00  ← chip / input   (warm mid-gold)
//    abyssStroke #5A4000 ← borders     (visible golden edge)
// ─────────────────────────────────────────────────────────────────────────────

class AppPalette {
  // ── Golden Abyss backgrounds ────────────────────────────────────────────────
  //  Warm amber-to-bronze depth ladder. Zero blue anywhere.
  static const abyss0      = Color(0xFF0F0A00);  // near-black warm gold floor
  static const abyss1      = Color(0xFF1A1000);  // dark amber-brown scaffold
  static const abyss2      = Color(0xFF251800);  // deep bronze card
  static const abyss3      = Color(0xFF312200);  // elevated bronze-gold card
  static const abyss4      = Color(0xFF3D2C00);  // chip / input warm gold
  static const abyssStroke = Color(0xFF5A4000);  // golden border edge
  static const abyssGlass  = Color(0xCC251800);  // frosted warm bronze overlay

  // ── Keep old names as aliases so existing code compiles ──────────────────
  static const navy0      = abyss0;
  static const navy1      = abyss1;
  static const navy2      = abyss2;
  static const navy3      = abyss3;
  static const navy4      = abyss4;
  static const navyStroke = abyssStroke;
  static const navyGlass  = abyssGlass;

  // ── Primary accent — bright amber gold ───────────────────────────────────
  //  Replaces cyan as the main accent throughout the UI
  static const gold        = Color(0xFFFFB800);  // vivid amber gold (primary)
  static const goldLight   = Color(0xFFFFD966);  // bright highlight gold
  static const goldDark    = Color(0xFFB07800);  // pressed / muted gold
  static const goldGlow    = Color(0x55FFB800);  // glow halo
  static const goldGlow2   = Color(0x22FFB800);  // subtle ambient glow
  static const goldDim     = Color(0xFF7A5200);  // inactive gold

  // ── Keep cyan alias for live-status only ─────────────────────────────────
  static const cyan      = Color(0xFF00C6FF);  // reserved for LIVE badge only
  static const cyanDark  = Color(0xFF007FA8);
  static const cyanGlow  = Color(0x4400C6FF);
  static const cyanDim   = Color(0xFF005F80);
  static const cyanGlow2 = Color(0x1A00C6FF);

  // ── Warm amber gold metrics ──────────────────────────────────────────────
  static const amber      = Color(0xFFFFB800);  // same as gold — unified
  static const amberLight = Color(0xFFFFD966);
  static const amberDim   = Color(0xFF7A5200);

  // ── Status palette ────────────────────────────────────────────────────────
  static const safe        = Color(0xFF10E88A);
  static const warning     = Color(0xFFFFA520);
  static const danger      = Color(0xFFFF5500);
  static const critical    = Color(0xFFFF1A44);
  static const safeGlow    = Color(0x2810E88A);
  static const warnGlow    = Color(0x28FFA520);
  static const dangerGlow  = Color(0x28FF5500);
  static const critGlow    = Color(0x28FF1A44);

  // ── Text ──────────────────────────────────────────────────────────────────
  static const textWhite = Color(0xFFFFF8E7);  // warm white — cream not cold
  static const textGrey  = Color(0xFF9A8060);  // warm tan-grey
  static const textDim   = Color(0xFF4A3410);  // dark warm-brown

  // ── Gradient helpers ──────────────────────────────────────────────────────
  static const LinearGradient abyssGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [abyss1, abyss3],
  );

  static const LinearGradient navyGradient = abyssGradient;

  // Golden radial glow from top-center — warm amber bloom
  static BoxDecoration scaffoldDecoration() => const BoxDecoration(
    gradient: RadialGradient(
      center: Alignment(0.0, -0.6),
      radius: 1.1,
      colors: [
        Color(0x33FFB800),  // warm gold bloom at top
        Color(0xFF0F0A00),  // deep warm-black floor
      ],
    ),
  );

  static LinearGradient glowGradient(Color c) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      c.withValues(alpha: 0.20),
      c.withValues(alpha: 0.04),
    ],
  );

  static List<BoxShadow> glowShadow(Color c, {double blur = 20}) => [
    BoxShadow(
      color: c.withValues(alpha: 0.28),
      blurRadius: blur,
      offset: const Offset(0, 6),
    ),
    BoxShadow(
      color: c.withValues(alpha: 0.10),
      blurRadius: blur * 2,
      spreadRadius: 2,
    ),
  ];

  static BoxDecoration glassMorph({
    Color borderColor = AppPalette.abyssStroke,
    double radius = 20,
    Color? bg,
  }) =>
      BoxDecoration(
        color: bg ?? AppPalette.abyssGlass,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.50),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      );

  static Color statusColor(String level) {
    switch (level.toUpperCase()) {
      case 'SAFE':     return safe;
      case 'WARNING':  return warning;
      case 'DANGER':   return danger;
      case 'CRITICAL': return critical;
      default:         return textGrey;
    }
  }
}

class RiverColors extends ThemeExtension<RiverColors> {
  const RiverColors({
    required this.riverNormal,
    required this.riverWarning,
    required this.riverDanger,
    required this.riverCritical,
    required this.riverSurface,
    required this.riverGlow,
    required this.cardBg,
    required this.cardBgElevated,
    required this.chipBg,
    required this.stroke,
    required this.textPrimary,
    required this.textSecondary,
    required this.sparklineColor,
    required this.accent,
    required this.accentGlow,
    required this.metricColor,
    required this.navBg,
    required this.navActive,
    required this.navInactive,
  });

  final Color riverNormal;
  final Color riverWarning;
  final Color riverDanger;
  final Color riverCritical;
  final Color riverSurface;
  final Color riverGlow;
  final Color cardBg;
  final Color cardBgElevated;
  final Color chipBg;
  final Color stroke;
  final Color textPrimary;
  final Color textSecondary;
  final Color sparklineColor;
  final Color accent;
  final Color accentGlow;
  final Color metricColor;
  final Color navBg;
  final Color navActive;
  final Color navInactive;

  static RiverColors of(BuildContext context) =>
      Theme.of(context).extension<RiverColors>() ?? _golden;

  static const RiverColors _golden = RiverColors(
    riverNormal:    AppPalette.safe,
    riverWarning:   AppPalette.warning,
    riverDanger:    AppPalette.danger,
    riverCritical:  AppPalette.critical,
    riverSurface:   AppPalette.abyss2,
    riverGlow:      AppPalette.goldGlow,
    cardBg:         AppPalette.abyss2,
    cardBgElevated: AppPalette.abyss3,
    chipBg:         AppPalette.abyss4,
    stroke:         AppPalette.abyssStroke,
    textPrimary:    AppPalette.textWhite,
    textSecondary:  AppPalette.textGrey,
    sparklineColor: AppPalette.gold,
    accent:         AppPalette.gold,
    accentGlow:     AppPalette.goldGlow,
    metricColor:    AppPalette.goldLight,
    navBg:          AppPalette.abyss0,
    navActive:      AppPalette.gold,
    navInactive:    AppPalette.textDim,
  );

  static const RiverColors _light = RiverColors(
    riverNormal:    Color(0xFF00897B),
    riverWarning:   AppPalette.warning,
    riverDanger:    AppPalette.danger,
    riverCritical:  AppPalette.critical,
    riverSurface:   Color(0xFFFFF8E7),
    riverGlow:      Color(0x33FFB800),
    cardBg:         Colors.white,
    cardBgElevated: Color(0xFFFFF3CC),
    chipBg:         Color(0xFFFFE999),
    stroke:         Color(0xFFE8C84A),
    textPrimary:    Color(0xFF1A0F00),
    textSecondary:  Color(0xFF6B4F20),
    sparklineColor: AppPalette.goldDark,
    accent:         AppPalette.goldDark,
    accentGlow:     Color(0x33FFB800),
    metricColor:    AppPalette.amberDim,
    navBg:          Color(0xFF1A1000),
    navActive:      AppPalette.gold,
    navInactive:    Color(0xFF9A8060),
  );

  @override
  RiverColors copyWith({
    Color? riverNormal, Color? riverWarning, Color? riverDanger,
    Color? riverCritical, Color? riverSurface, Color? riverGlow,
    Color? cardBg, Color? cardBgElevated, Color? chipBg, Color? stroke,
    Color? textPrimary, Color? textSecondary, Color? sparklineColor,
    Color? accent, Color? accentGlow, Color? metricColor,
    Color? navBg, Color? navActive, Color? navInactive,
  }) =>
      RiverColors(
        riverNormal:    riverNormal    ?? this.riverNormal,
        riverWarning:   riverWarning   ?? this.riverWarning,
        riverDanger:    riverDanger    ?? this.riverDanger,
        riverCritical:  riverCritical  ?? this.riverCritical,
        riverSurface:   riverSurface   ?? this.riverSurface,
        riverGlow:      riverGlow      ?? this.riverGlow,
        cardBg:         cardBg         ?? this.cardBg,
        cardBgElevated: cardBgElevated ?? this.cardBgElevated,
        chipBg:         chipBg         ?? this.chipBg,
        stroke:         stroke         ?? this.stroke,
        textPrimary:    textPrimary    ?? this.textPrimary,
        textSecondary:  textSecondary  ?? this.textSecondary,
        sparklineColor: sparklineColor ?? this.sparklineColor,
        accent:         accent         ?? this.accent,
        accentGlow:     accentGlow     ?? this.accentGlow,
        metricColor:    metricColor    ?? this.metricColor,
        navBg:          navBg          ?? this.navBg,
        navActive:      navActive      ?? this.navActive,
        navInactive:    navInactive    ?? this.navInactive,
      );

  @override
  RiverColors lerp(RiverColors? other, double t) {
    if (other == null) return this;
    return RiverColors(
      riverNormal:    Color.lerp(riverNormal,    other.riverNormal,    t)!,
      riverWarning:   Color.lerp(riverWarning,   other.riverWarning,   t)!,
      riverDanger:    Color.lerp(riverDanger,    other.riverDanger,    t)!,
      riverCritical:  Color.lerp(riverCritical,  other.riverCritical,  t)!,
      riverSurface:   Color.lerp(riverSurface,   other.riverSurface,   t)!,
      riverGlow:      Color.lerp(riverGlow,      other.riverGlow,      t)!,
      cardBg:         Color.lerp(cardBg,         other.cardBg,         t)!,
      cardBgElevated: Color.lerp(cardBgElevated, other.cardBgElevated, t)!,
      chipBg:         Color.lerp(chipBg,         other.chipBg,         t)!,
      stroke:         Color.lerp(stroke,         other.stroke,         t)!,
      textPrimary:    Color.lerp(textPrimary,    other.textPrimary,    t)!,
      textSecondary:  Color.lerp(textSecondary,  other.textSecondary,  t)!,
      sparklineColor: Color.lerp(sparklineColor, other.sparklineColor, t)!,
      accent:         Color.lerp(accent,         other.accent,         t)!,
      accentGlow:     Color.lerp(accentGlow,     other.accentGlow,     t)!,
      metricColor:    Color.lerp(metricColor,    other.metricColor,    t)!,
      navBg:          Color.lerp(navBg,          other.navBg,          t)!,
      navActive:      Color.lerp(navActive,      other.navActive,      t)!,
      navInactive:    Color.lerp(navInactive,    other.navInactive,    t)!,
    );
  }

  static ThemeData lightTheme() => _buildTheme(
      brightness: Brightness.light, ext: _light,
      scaffoldBg: const Color(0xFF1A1000));

  static ThemeData darkTheme() => _buildTheme(
      brightness: Brightness.dark, ext: _golden,
      scaffoldBg: AppPalette.abyss1);

  static ThemeData _buildTheme({
    required Brightness brightness,
    required RiverColors ext,
    required Color scaffoldBg,
  }) {
    final isDark = brightness == Brightness.dark;
    final cs = ColorScheme.fromSeed(
      seedColor: AppPalette.gold,
      brightness: brightness,
    ).copyWith(
      primary:     AppPalette.gold,
      secondary:   AppPalette.goldLight,
      surface:     isDark ? AppPalette.abyss2 : Colors.white,
      onPrimary:   AppPalette.abyss0,
      onSecondary: AppPalette.abyss0,
      error:       AppPalette.critical,
    );

    return ThemeData(
      useMaterial3:            true,
      colorScheme:             cs,
      scaffoldBackgroundColor: scaffoldBg,
      extensions:              <ThemeExtension<dynamic>>[ext],
      fontFamily:              'Roboto',
      textTheme: TextTheme(
        displayLarge: const TextStyle(
          fontWeight: FontWeight.w900, letterSpacing: -1.5,
          color: AppPalette.textWhite,
        ),
        displaySmall: const TextStyle(
          fontWeight: FontWeight.w800, letterSpacing: -1.0,
          color: AppPalette.textWhite,
        ),
        titleLarge: const TextStyle(
          fontWeight: FontWeight.w700, letterSpacing: -0.5,
          color: AppPalette.textWhite,
        ),
        titleMedium: const TextStyle(
          fontWeight: FontWeight.w600, letterSpacing: -0.2,
          color: AppPalette.textWhite,
        ),
        bodyMedium: TextStyle(
          fontWeight: FontWeight.w400,
          color: isDark ? AppPalette.textGrey : AppPalette.textWhite,
        ),
        labelSmall: const TextStyle(
          fontWeight: FontWeight.w600, letterSpacing: 1.0,
          color: AppPalette.textGrey,
        ),
      ),
      cardTheme: CardThemeData(
        color:     isDark ? AppPalette.abyss2 : Colors.white,
        elevation: 0,
        shape:     RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: isDark ? AppPalette.abyssStroke : const Color(0xFFE8C84A),
            width: 1,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor:  isDark ? AppPalette.abyss0 : const Color(0xFF1A1000),
        foregroundColor:  AppPalette.textWhite,
        elevation:        0,
        centerTitle:      false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          color: AppPalette.textWhite, fontSize: 20,
          fontWeight: FontWeight.w800, letterSpacing: -0.5,
        ),
        iconTheme: const IconThemeData(color: AppPalette.gold),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor:  isDark ? AppPalette.abyss0 : const Color(0xFF1A1000),
        indicatorColor:   AppPalette.goldGlow,
        height:           64,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppPalette.gold, size: 24);
          }
          return const IconThemeData(color: AppPalette.textDim, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: AppPalette.gold, fontSize: 10,
              fontWeight: FontWeight.w700, letterSpacing: 0.3);
          }
          return const TextStyle(
            color: AppPalette.textDim, fontSize: 10, letterSpacing: 0.2);
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppPalette.gold,
          foregroundColor: AppPalette.abyss0,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppPalette.gold,
          side: const BorderSide(color: AppPalette.gold, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? AppPalette.abyss4 : const Color(0xFFFFE999),
        labelStyle: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: isDark ? AppPalette.textWhite : AppPalette.abyss2,
        ),
        side: BorderSide(
          color: isDark ? AppPalette.abyssStroke : const Color(0xFFE8C84A),
          width: 1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppPalette.gold,
        linearTrackColor: AppPalette.abyss3,
      ),
      dividerTheme: const DividerThemeData(
        color: AppPalette.abyssStroke, space: 1, thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled:    true,
        fillColor: isDark ? AppPalette.abyss2 : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppPalette.abyssStroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppPalette.abyssStroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppPalette.gold, width: 2),
        ),
        hintStyle: const TextStyle(color: AppPalette.textDim),
      ),
    );
  }
}
