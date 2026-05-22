import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  OpsFlood  –  Ferrari Design Language
//  Primary:   Rosso Corsa  #DC0000  (Ferrari Racing Red)
//  Accent:    Oro Scuderia #C8972A  (Scuderia Gold)
//  Chrome:    #E8E0D0      (Silver Chrome)
//  Carbon:    #0A0A0A / #121212  (Carbon Fibre Black)
// ─────────────────────────────────────────────────────────────────────────────

class AppPalette {
  // Ferrari reds
  static const ferrari     = Color(0xFFDC0000); // Rosso Corsa
  static const ferrariDark = Color(0xFF9B0000); // deep shadow red
  static const ferrariGlow = Color(0xFFFF2828); // hot glow
  static const blood       = Color(0xFF6B0000); // critical depth

  // Gold / chrome
  static const gold        = Color(0xFFC8972A); // Scuderia gold
  static const goldLight   = Color(0xFFE8C060); // shimmer
  static const chrome      = Color(0xFFE8E0D0); // chrome silver
  static const titanium    = Color(0xFF9E9E9E);

  // Carbon backgrounds
  static const carbon0     = Color(0xFF080808); // deepest black
  static const carbon1     = Color(0xFF111111); // carbon fibre base
  static const carbon2     = Color(0xFF1A1A1A); // card surface
  static const carbon3     = Color(0xFF242424); // elevated card
  static const carbon4     = Color(0xFF2E2E2E); // chip/badge

  // Status
  static const safe        = Color(0xFF00C853); // safe green
  static const warning     = Color(0xFFFF9800); // amber
  static const danger      = Color(0xFFFF3D00); // deep orange
  static const critical    = Color(0xFFDC0000); // same as ferrari

  // Text
  static const textWhite   = Color(0xFFF5F0E8); // warm white
  static const textGrey    = Color(0xFF9E9E9E);
  static const textDim     = Color(0xFF5A5A5A);
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
    required this.chipBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.sparklineColor,
    required this.accent,
    required this.accentGlow,
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
  final Color chipBg;
  final Color textPrimary;
  final Color textSecondary;
  final Color sparklineColor;
  final Color accent;
  final Color accentGlow;
  final Color navBg;
  final Color navActive;
  final Color navInactive;

  static RiverColors of(BuildContext context) =>
      Theme.of(context).extension<RiverColors>() ?? _ferrari;

  // Ferrari dark theme (primary / only theme)
  static const RiverColors _ferrari = RiverColors(
    riverNormal:    AppPalette.safe,
    riverWarning:   AppPalette.warning,
    riverDanger:    AppPalette.danger,
    riverCritical:  AppPalette.critical,
    riverSurface:   AppPalette.carbon2,
    riverGlow:      AppPalette.ferrariGlow,
    cardBg:         AppPalette.carbon2,
    chipBg:         AppPalette.carbon3,
    textPrimary:    AppPalette.textWhite,
    textSecondary:  AppPalette.textGrey,
    sparklineColor: AppPalette.ferrari,
    accent:         AppPalette.gold,
    accentGlow:     AppPalette.goldLight,
    navBg:          Color(0xF0100808),  // near-black with red tint
    navActive:      AppPalette.ferrari,
    navInactive:    AppPalette.textDim,
  );

  // Light variant (for completeness; app defaults to dark)
  static const RiverColors _light = RiverColors(
    riverNormal:    Color(0xFF00897B),
    riverWarning:   AppPalette.warning,
    riverDanger:    AppPalette.danger,
    riverCritical:  AppPalette.critical,
    riverSurface:   Color(0xFFF5F0E8),
    riverGlow:      AppPalette.ferrari,
    cardBg:         Colors.white,
    chipBg:         Color(0xFFF5F0E8),
    textPrimary:    Color(0xFF1A0000),
    textSecondary:  Color(0xFF5A3A3A),
    sparklineColor: AppPalette.ferrari,
    accent:         AppPalette.gold,
    accentGlow:     AppPalette.goldLight,
    navBg:          Color(0xFF1A0000),
    navActive:      AppPalette.ferrari,
    navInactive:    Color(0xFF8A7070),
  );

  @override
  RiverColors copyWith({
    Color? riverNormal, Color? riverWarning, Color? riverDanger,
    Color? riverCritical, Color? riverSurface, Color? riverGlow,
    Color? cardBg, Color? chipBg, Color? textPrimary,
    Color? textSecondary, Color? sparklineColor,
    Color? accent, Color? accentGlow,
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
        chipBg:         chipBg         ?? this.chipBg,
        textPrimary:    textPrimary    ?? this.textPrimary,
        textSecondary:  textSecondary  ?? this.textSecondary,
        sparklineColor: sparklineColor ?? this.sparklineColor,
        accent:         accent         ?? this.accent,
        accentGlow:     accentGlow     ?? this.accentGlow,
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
      chipBg:         Color.lerp(chipBg,         other.chipBg,         t)!,
      textPrimary:    Color.lerp(textPrimary,    other.textPrimary,    t)!,
      textSecondary:  Color.lerp(textSecondary,  other.textSecondary,  t)!,
      sparklineColor: Color.lerp(sparklineColor, other.sparklineColor, t)!,
      accent:         Color.lerp(accent,         other.accent,         t)!,
      accentGlow:     Color.lerp(accentGlow,     other.accentGlow,     t)!,
      navBg:          Color.lerp(navBg,          other.navBg,          t)!,
      navActive:      Color.lerp(navActive,      other.navActive,      t)!,
      navInactive:    Color.lerp(navInactive,    other.navInactive,    t)!,
    );
  }

  // ── ThemeData builders ────────────────────────────────────────────────────
  static ThemeData lightTheme() => _buildTheme(brightness: Brightness.light,
      seed: AppPalette.ferrari, ext: _light,
      scaffoldBg: const Color(0xFFFAF5F0));

  static ThemeData darkTheme() => _buildTheme(brightness: Brightness.dark,
      seed: AppPalette.ferrari, ext: _ferrari,
      scaffoldBg: AppPalette.carbon0);

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color seed,
    required RiverColors ext,
    required Color scaffoldBg,
  }) {
    final cs = ColorScheme.fromSeed(seedColor: seed, brightness: brightness)
        .copyWith(
          primary:    AppPalette.ferrari,
          secondary:  AppPalette.gold,
          surface:    brightness == Brightness.dark ? AppPalette.carbon1 : Colors.white,
          onPrimary:  Colors.white,
          onSecondary:Colors.black,
        );
    return ThemeData(
      useMaterial3:           true,
      colorScheme:            cs,
      scaffoldBackgroundColor:scaffoldBg,
      extensions:             <ThemeExtension<dynamic>>[ext],
      // Typography
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900, letterSpacing: -1.0),
        titleLarge:   TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700, letterSpacing: -0.3),
        bodyMedium:   TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w400),
        labelSmall:   TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w600, letterSpacing: 0.8),
      ),
      // Cards
      cardTheme: CardThemeData(
        color:        brightness == Brightness.dark ? AppPalette.carbon2 : Colors.white,
        elevation:    0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: brightness == Brightness.dark ? AppPalette.carbon1 : Colors.white,
        foregroundColor: brightness == Brightness.dark ? AppPalette.textWhite : AppPalette.carbon0,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color:      brightness == Brightness.dark ? AppPalette.textWhite : AppPalette.carbon0,
          fontSize:   20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor:  AppPalette.ferrari,
          foregroundColor:  Colors.white,
          elevation:        4,
          shadowColor:      AppPalette.ferrari.withOpacity(0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
      ),
      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: brightness == Brightness.dark ? AppPalette.carbon3 : const Color(0xFFF5F0F0),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      // ProgressIndicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color:            AppPalette.ferrari,
        linearTrackColor: AppPalette.carbon3,
      ),
      // Divider
      dividerTheme: const DividerThemeData(
        color:  Color(0x22DC0000),
        space:  1,
        thickness: 1,
      ),
    );
  }
}
