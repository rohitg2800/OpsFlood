import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  OpsFlood  –  Midnight Ops Design Language  (v2)
//
//  Philosophy:
//    • Deep navy base  →  professional emergency ops feel
//    • Neon cyan accent →  live data / active state (not danger)
//    • Amber gold       →  metrics / numbers
//    • Red reserved     →  critical alerts ONLY (no false alarm fatigue)
//    • Green/orange     →  standard safe / warning status
//
//  Primary bg:   #050C1A  (Midnight Navy)
//  Accent:       #00D4FF  (Neon Cyan)
//  Metric gold:  #FFB800  (Amber Gold)
//  Card:         #0D1B2E  (Deep Navy Card)
// ─────────────────────────────────────────────────────────────────────────────

class AppPalette {
  // ── Navy backgrounds ──────────────────────────────────────────────────────
  static const navy0     = Color(0xFF020810); // deepest — scaffold
  static const navy1     = Color(0xFF050C1A); // base background
  static const navy2     = Color(0xFF0D1B2E); // card surface
  static const navy3     = Color(0xFF142438); // elevated card
  static const navy4     = Color(0xFF1C3050); // chip / badge
  static const navyStroke= Color(0xFF1E3A5F); // border / divider

  // ── Neon cyan (accent — live / active, NOT danger) ────────────────────────
  static const cyan      = Color(0xFF00D4FF); // primary accent
  static const cyanDark  = Color(0xFF0099BB); // pressed state
  static const cyanGlow  = Color(0x3300D4FF); // glow overlay 20%
  static const cyanDim   = Color(0xFF007A99); // inactive

  // ── Amber gold (metrics / numbers) ───────────────────────────────────────
  static const amber     = Color(0xFFFFB800); // metric gold
  static const amberLight= Color(0xFFFFD54F); // shimmer
  static const amberDim  = Color(0xFF996D00); // muted

  // ── Status palette ────────────────────────────────────────────────────────
  static const safe      = Color(0xFF00E676); // bright green
  static const warning   = Color(0xFFFFB300); // amber warning
  static const danger    = Color(0xFFFF6D00); // deep orange
  static const critical  = Color(0xFFFF1744); // hot red  ← ONLY red in system
  static const safeGlow  = Color(0x2200E676);
  static const warnGlow  = Color(0x22FFB300);
  static const dangerGlow= Color(0x22FF6D00);
  static const critGlow  = Color(0x22FF1744);

  // ── Text ─────────────────────────────────────────────────────────────────
  static const textWhite = Color(0xFFF0F4FF); // cool white
  static const textGrey  = Color(0xFF7A8CA8); // muted blue-grey
  static const textDim   = Color(0xFF3A4A60); // very muted
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
      Theme.of(context).extension<RiverColors>() ?? _midnight;

  // ── Midnight Ops dark theme (primary) ────────────────────────────────────
  static const RiverColors _midnight = RiverColors(
    riverNormal:      AppPalette.safe,
    riverWarning:     AppPalette.warning,
    riverDanger:      AppPalette.danger,
    riverCritical:    AppPalette.critical,
    riverSurface:     AppPalette.navy2,
    riverGlow:        AppPalette.cyanGlow,
    cardBg:           AppPalette.navy2,
    cardBgElevated:   AppPalette.navy3,
    chipBg:           AppPalette.navy4,
    stroke:           AppPalette.navyStroke,
    textPrimary:      AppPalette.textWhite,
    textSecondary:    AppPalette.textGrey,
    sparklineColor:   AppPalette.cyan,
    accent:           AppPalette.cyan,
    accentGlow:       AppPalette.cyanGlow,
    metricColor:      AppPalette.amber,
    navBg:            AppPalette.navy0,
    navActive:        AppPalette.cyan,
    navInactive:      AppPalette.textDim,
  );

  // ── Light variant (for system light mode) ────────────────────────────────
  static const RiverColors _light = RiverColors(
    riverNormal:      Color(0xFF00897B),
    riverWarning:     AppPalette.warning,
    riverDanger:      AppPalette.danger,
    riverCritical:    AppPalette.critical,
    riverSurface:     Color(0xFFF0F4FF),
    riverGlow:        Color(0x220099BB),
    cardBg:           Colors.white,
    cardBgElevated:   Color(0xFFF0F4FF),
    chipBg:           Color(0xFFE0EAF8),
    stroke:           Color(0xFFCCDDEE),
    textPrimary:      Color(0xFF0A1628),
    textSecondary:    Color(0xFF4A6080),
    sparklineColor:   AppPalette.cyanDark,
    accent:           AppPalette.cyanDark,
    accentGlow:       Color(0x220099BB),
    metricColor:      AppPalette.amberDim,
    navBg:            Color(0xFF0A1628),
    navActive:        AppPalette.cyan,
    navInactive:      Color(0xFF8A9AAA),
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

  // ── ThemeData builders ───────────────────────────────────────────────────
  static ThemeData lightTheme() => _buildTheme(
      brightness: Brightness.light, ext: _light,
      scaffoldBg: const Color(0xFF0A1628));

  static ThemeData darkTheme() => _buildTheme(
      brightness: Brightness.dark, ext: _midnight,
      scaffoldBg: AppPalette.navy0);

  static ThemeData _buildTheme({
    required Brightness brightness,
    required RiverColors ext,
    required Color scaffoldBg,
  }) {
    final isDark = brightness == Brightness.dark;
    final cs = ColorScheme.fromSeed(
      seedColor: AppPalette.cyan,
      brightness: brightness,
    ).copyWith(
      primary:     AppPalette.cyan,
      secondary:   AppPalette.amber,
      surface:     isDark ? AppPalette.navy1 : Colors.white,
      onPrimary:   AppPalette.navy0,
      onSecondary: AppPalette.navy0,
      error:       AppPalette.critical,
    );

    return ThemeData(
      useMaterial3:            true,
      colorScheme:             cs,
      scaffoldBackgroundColor: scaffoldBg,
      extensions:              <ThemeExtension<dynamic>>[ext],

      // ── Typography ───────────────────────────────────────────────────────
      textTheme: TextTheme(
        displayLarge: const TextStyle(
          fontFamily: 'Roboto', fontWeight: FontWeight.w900,
          letterSpacing: -1.5, color: AppPalette.textWhite,
        ),
        displaySmall: const TextStyle(
          fontFamily: 'Roboto', fontWeight: FontWeight.w800,
          letterSpacing: -1.0, color: AppPalette.textWhite,
        ),
        titleLarge: const TextStyle(
          fontFamily: 'Roboto', fontWeight: FontWeight.w700,
          letterSpacing: -0.5, color: AppPalette.textWhite,
        ),
        titleMedium: const TextStyle(
          fontFamily: 'Roboto', fontWeight: FontWeight.w600,
          letterSpacing: -0.2, color: AppPalette.textWhite,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Roboto', fontWeight: FontWeight.w400,
          color: isDark ? AppPalette.textGrey : AppPalette.textWhite,
        ),
        labelSmall: const TextStyle(
          fontFamily: 'Roboto', fontWeight: FontWeight.w600,
          letterSpacing: 1.0, color: AppPalette.textGrey,
        ),
      ),

      // ── Cards ────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color:     isDark ? AppPalette.navy2 : Colors.white,
        elevation: 0,
        shape:     RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? AppPalette.navyStroke : const Color(0xFFCCDDEE),
            width: 1,
          ),
        ),
      ),

      // ── AppBar ───────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppPalette.navy0 : const Color(0xFF0A1628),
        foregroundColor: AppPalette.textWhite,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          color:       AppPalette.textWhite,
          fontSize:    20,
          fontWeight:  FontWeight.w800,
          letterSpacing: -0.5,
          fontFamily:  'Roboto',
        ),
        iconTheme: const IconThemeData(color: AppPalette.cyan),
      ),

      // ── Bottom nav ───────────────────────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor:      isDark ? AppPalette.navy0 : const Color(0xFF0A1628),
        selectedItemColor:    AppPalette.cyan,
        unselectedItemColor:  AppPalette.textDim,
        selectedLabelStyle:   const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        type:                 BottomNavigationBarType.fixed,
        elevation:            0,
      ),

      // ── NavigationBar (Material 3) ────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor:      isDark ? AppPalette.navy0 : const Color(0xFF0A1628),
        indicatorColor:       AppPalette.cyanGlow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppPalette.cyan, size: 24);
          }
          return const IconThemeData(color: AppPalette.textDim, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: AppPalette.cyan, fontSize: 11,
              fontWeight: FontWeight.w700,
            );
          }
          return const TextStyle(
            color: AppPalette.textDim, fontSize: 11,
          );
        }),
      ),

      // ── Buttons ──────────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppPalette.cyan,
          foregroundColor: AppPalette.navy0,
          elevation:       0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700, letterSpacing: 0.5,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppPalette.cyan,
          side: const BorderSide(color: AppPalette.cyan, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      // ── Chips ────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? AppPalette.navy4 : const Color(0xFFE0EAF8),
        labelStyle: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: isDark ? AppPalette.textWhite : AppPalette.navy2,
        ),
        side: BorderSide(
          color: isDark ? AppPalette.navyStroke : const Color(0xFFCCDDEE),
          width: 1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      // ── Progress ────────────────────────────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color:            AppPalette.cyan,
        linearTrackColor: AppPalette.navy3,
      ),

      // ── Divider ─────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color:     AppPalette.navyStroke,
        space:     1,
        thickness: 1,
      ),

      // ── Input fields ────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled:      true,
        fillColor:   isDark ? AppPalette.navy2 : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppPalette.navyStroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppPalette.navyStroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppPalette.cyan, width: 2),
        ),
        hintStyle: const TextStyle(color: AppPalette.textDim),
      ),
    );
  }
}
