// lib/theme/robotic_theme.dart
// Robotic design language — sharp corners, glow effects, monospaced type.
// Two faces: Tactical-Dark (isDark=true) / System-Light (isDark=false).
// toThemeData() — used by main.dart as roboticTheme.toThemeData()
// toFlutterTheme() — alias kept for backward compat with any other callers.
library;

import 'package:flutter/material.dart';

// ─── Robotic palette ──────────────────────────────────────────────────────────

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
  static const rdDanger      = Color(0xFFFF3B3B);
  static const rdWarning     = Color(0xFFFFAA00);
  static const rdText        = Color(0xFFE0F0FF);
  static const rdTextMuted   = Color(0xFF5A7080);

  // SYSTEM LIGHT
  static const rlBg          = Color(0xFFF4F7FA);
  static const rlSurface     = Color(0xFFFFFFFF);
  static const rlSurface2    = Color(0xFFEBF0F5);
  static const rlBorder      = Color(0xFFCDD8E3);
  static const rlAccent      = Color(0xFF007ACC);
  static const rlAccentGlow  = Color(0x22007ACC);
  static const rlAccent2     = Color(0xFF00A86B);
  static const rlAccent2Glow = Color(0x2200A86B);
  static const rlDanger      = Color(0xFFD32F2F);
  static const rlWarning     = Color(0xFFF57C00);
  static const rlText        = Color(0xFF0D1B2A);
  static const rlTextMuted   = Color(0xFF5A7080);
}

// ─── RoboticTheme ─────────────────────────────────────────────────────────────

class RoboticTheme {
  final bool isDark;
  const RoboticTheme({required this.isDark});

  Color get bg          => isDark ? RoboticColors.rdBg          : RoboticColors.rlBg;
  Color get surface     => isDark ? RoboticColors.rdSurface     : RoboticColors.rlSurface;
  Color get surface2    => isDark ? RoboticColors.rdSurface2    : RoboticColors.rlSurface2;
  Color get border      => isDark ? RoboticColors.rdBorder      : RoboticColors.rlBorder;
  Color get accent      => isDark ? RoboticColors.rdAccent      : RoboticColors.rlAccent;
  Color get accentGlow  => isDark ? RoboticColors.rdAccentGlow  : RoboticColors.rlAccentGlow;
  Color get accent2     => isDark ? RoboticColors.rdAccent2     : RoboticColors.rlAccent2;
  Color get accent2Glow => isDark ? RoboticColors.rdAccent2Glow : RoboticColors.rlAccent2Glow;
  Color get danger      => isDark ? RoboticColors.rdDanger      : RoboticColors.rlDanger;
  Color get warning     => isDark ? RoboticColors.rdWarning     : RoboticColors.rlWarning;
  Color get text        => isDark ? RoboticColors.rdText        : RoboticColors.rlText;
  Color get textMuted   => isDark ? RoboticColors.rdTextMuted   : RoboticColors.rlTextMuted;

  /// Primary method — called as roboticTheme.toThemeData() in main.dart
  ThemeData toThemeData() {
    final brightness = isDark ? Brightness.dark : Brightness.light;
    final cs = ColorScheme.fromSeed(
      seedColor:  accent,
      brightness: brightness,
    ).copyWith(
      primary:   accent,
      secondary: accent2,
      surface:   surface,
      onPrimary: isDark ? const Color(0xFF030508) : Colors.white,
      error:     danger,
    );

    return ThemeData(
      useMaterial3:            true,
      colorScheme:             cs,
      scaffoldBackgroundColor: bg,
      fontFamily:              'RobotoMono',
      cardTheme: CardThemeData(
        color:     surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: border, width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor:  bg,
        foregroundColor:  text,
        elevation:        0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color:       text,
          fontSize:    16,
          fontWeight:  FontWeight.w700,
          letterSpacing: 1.5,
          fontFamily:  'RobotoMono',
        ),
      ),
      dividerTheme: DividerThemeData(color: border, space: 1, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled:    true,
        fillColor: surface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        hintStyle: TextStyle(color: textMuted),
      ),
    );
  }

  /// Alias — keeps backward compatibility if any file calls toFlutterTheme()
  ThemeData toFlutterTheme() => toThemeData();
}
