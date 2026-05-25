// lib/services/wris_service.dart
//
// OpsFlood — WrisService  (DISABLED — indiawris.gov.in is not publicly
// accessible; /wrisapi/v2 has a broken server-side rewrite rule that
// produces an infinite redirect loop:
//   /wrisapi/v2/… → /wriswrisapi/v2/… → /wriswriswrisapi/v2/…
// ffs.india.gov.in also does not resolve DNS from the public internet.
//
// The class is kept as a no-op stub so live_fetch_engine.dart continues
// to compile.  fetch() returns null immediately without any network I/O,
// so no timeout is burned per city.
//
// Re-enable once a working public CWC gauge API becomes available.
library;

import '../data/india_cities.dart';

class WrisReading {
  final double?  level;
  final double?  danger;
  final double?  warning;
  final double?  discharge;
  final String   source;
  final DateTime fetchedAt;

  const WrisReading({
    this.level,
    this.danger,
    this.warning,
    this.discharge,
    this.source = 'WRIS',
    required this.fetchedAt,
  });

  bool get hasLevel => level != null && level! > 0;
}

class WrisService {
  WrisService._();
  static final WrisService instance = WrisService._();

  /// Always returns null — WRIS API is inaccessible from the public internet.
  /// No network call is made; no timeout is burned.
  // ignore: avoid_unused_parameters
  Future<WrisReading?> fetch(IndiaCity city) async => null;
}
