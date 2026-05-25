// lib/constants/app_config.dart
//
// ── RE-EXPORT SHIM ────────────────────────────────────────────────────────────
// The canonical AppConfig class lives in lib/config/app_config.dart.
// That file uses --dart-define env vars (const-safe, no flutter_dotenv).
//
// This file previously contained a DUPLICATE AppConfig that used flutter_dotenv
// and had stale endpoint names (predictLegacyEndpoint, pollingInterval, etc.)
// that diverged from the real config.
//
// All imports that pointed here (import '../constants/app_config.dart') will
// now get the correct AppConfig transparently.
//
// DO NOT add anything new here. Add to lib/config/app_config.dart.
// ─────────────────────────────────────────────────────────────────────────────
export '../config/app_config.dart';
