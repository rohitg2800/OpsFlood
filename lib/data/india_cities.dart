// lib/data/india_cities.dart
//
// OpsFlood Bihar — IndiaCity registry (v2.1 Bihar-only)
//
// 31 WRD Bihar gauge stations across 9 rivers.
// Danger/warning levels sourced from:
//   WRD Bihar Central Flood Control Cell (2024-25)
//   CWC FFS: https://beams.fmiscwrdbihar.gov.in
//
// hfl (highest flood level) is derived as dangerLevel × 1.10,
// matching the convention used by AlertEvaluator.fromDischarge().
library;

class IndiaCity {
  final String id;
  final String name;
  final String state;
  final String river;
  final double lat;
  final double lon;
  final double dangerLevel;   // m MSL
  final double warningLevel;  // m MSL
  final double hfl;           // m MSL — danger × 1.10
  final String? cwcStation;   // CWC station code (null = WRD-only gauge)

  const IndiaCity({
    required this.id,
    required this.name,
    required this.state,
    required this.river,
    required this.lat,
    required this.lon,
    required this.dangerLevel,
    required this.warningLevel,
    double? hfl,
    this.cwcStation,
  }) : hfl = hfl ?? dangerLevel * 1.10;
}

/// 31 WRD Bihar gauge stations — the only monitored cities in this app.
const List<IndiaCity> kIndiaCities = [

  // ── GANGA ──────────────────────────────────────────────────────────────────
  IndiaCity(
    id: 'gandhighat', name: 'Gandhighat', state: 'Bihar',
    river: 'Ganga', lat: 25.6129, lon: 85.1376,
    dangerLevel: 48.60, warningLevel: 47.50, cwcStation: 'PAT',
  ),
  IndiaCity(
    id: 'dighaghat', name: 'Dighaghat', state: 'Bihar',
    river: 'Ganga', lat: 25.5941, lon: 85.0700,
    dangerLevel: 50.45, warningLevel: 49.30,
  ),
  IndiaCity(
    id: 'hathidah', name: 'Hathidah', state: 'Bihar',
    river: 'Ganga', lat: 25.4167, lon: 85.7500,
    dangerLevel: 41.76, warningLevel: 40.50,
  ),
  IndiaCity(
    id: 'munger', name: 'Munger', state: 'Bihar',
    river: 'Ganga', lat: 25.3743, lon: 86.4730,
    dangerLevel: 39.33, warningLevel: 38.20,
  ),
  IndiaCity(
    id: 'kahalgaon', name: 'Kahalgaon', state: 'Bihar',
    river: 'Ganga', lat: 25.2167, lon: 87.2667,
    dangerLevel: 31.09, warningLevel: 30.00,
  ),
  IndiaCity(
    id: 'bhagalpur', name: 'Bhagalpur', state: 'Bihar',
    river: 'Ganga', lat: 25.2425, lon: 86.9842,
    dangerLevel: 33.68, warningLevel: 32.50, cwcStation: 'BHP',
  ),
  IndiaCity(
    id: 'buxar', name: 'Buxar', state: 'Bihar',
    river: 'Ganga', lat: 25.5667, lon: 83.9667,
    dangerLevel: 60.30, warningLevel: 59.20,
  ),

  // ── KOSI ───────────────────────────────────────────────────────────────────
  IndiaCity(
    id: 'birpur', name: 'Birpur', state: 'Bihar',
    river: 'Kosi', lat: 26.5167, lon: 86.9000,
    dangerLevel: 74.70, warningLevel: 73.70, cwcStation: 'BIR',
  ),
  IndiaCity(
    id: 'baltara', name: 'Baltara', state: 'Bihar',
    river: 'Kosi', lat: 25.5000, lon: 86.5833,
    dangerLevel: 33.85, warningLevel: 32.85,
  ),
  IndiaCity(
    id: 'basua', name: 'Basua', state: 'Bihar',
    river: 'Kosi', lat: 26.1234, lon: 86.6020,
    dangerLevel: 47.75, warningLevel: 46.50, cwcStation: 'SUP',
  ),
  IndiaCity(
    id: 'kursela', name: 'Kursela', state: 'Bihar',
    river: 'Kosi', lat: 25.4800, lon: 87.2600,
    dangerLevel: 30.00, warningLevel: 28.80, cwcStation: 'KAT',
  ),

  // ── GANDAK ─────────────────────────────────────────────────────────────────
  IndiaCity(
    id: 'chatia', name: 'Chatia', state: 'Bihar',
    river: 'Gandak', lat: 26.8500, lon: 84.9000,
    dangerLevel: 69.15, warningLevel: 68.10,
  ),
  IndiaCity(
    id: 'dumariaghat', name: 'Dumariaghat', state: 'Bihar',
    river: 'Gandak', lat: 26.4833, lon: 84.4667,
    dangerLevel: 62.22, warningLevel: 61.10, cwcStation: 'GKP',
  ),
  IndiaCity(
    id: 'rewaghat', name: 'Rewaghat', state: 'Bihar',
    river: 'Gandak', lat: 26.1000, lon: 85.3000,
    dangerLevel: 54.41, warningLevel: 53.40,
  ),
  IndiaCity(
    id: 'hajipur', name: 'Hajipur', state: 'Bihar',
    river: 'Gandak', lat: 25.6933, lon: 85.2094,
    dangerLevel: 50.32, warningLevel: 49.40,
  ),

  // ── BAGMATI ────────────────────────────────────────────────────────────────
  IndiaCity(
    id: 'dheng_bridge', name: 'Dheng Bridge', state: 'Bihar',
    river: 'Bagmati', lat: 26.5800, lon: 85.4900,
    dangerLevel: 71.00, warningLevel: 70.00,
  ),
  IndiaCity(
    id: 'benibad', name: 'Benibad', state: 'Bihar',
    river: 'Bagmati', lat: 26.0500, lon: 85.6500,
    dangerLevel: 48.68, warningLevel: 47.68,
  ),
  IndiaCity(
    id: 'hayaghat', name: 'Hayaghat', state: 'Bihar',
    river: 'Bagmati', lat: 26.0200, lon: 85.9500,
    dangerLevel: 45.72, warningLevel: 44.50,
  ),

  // ── BURHI GANDAK ───────────────────────────────────────────────────────────
  IndiaCity(
    id: 'sikandarpur', name: 'Sikandarpur', state: 'Bihar',
    river: 'Burhi Gandak', lat: 26.1209, lon: 85.3647,
    dangerLevel: 52.53, warningLevel: 51.40,
  ),
  IndiaCity(
    id: 'samastipur', name: 'Samastipur', state: 'Bihar',
    river: 'Burhi Gandak', lat: 25.8620, lon: 85.7812,
    dangerLevel: 46.00, warningLevel: 44.80,
  ),
  IndiaCity(
    id: 'rosera', name: 'Rosera', state: 'Bihar',
    river: 'Burhi Gandak', lat: 25.8600, lon: 85.9800,
    dangerLevel: 42.63, warningLevel: 41.50,
  ),
  IndiaCity(
    id: 'khagaria', name: 'Khagaria', state: 'Bihar',
    river: 'Burhi Gandak', lat: 25.5000, lon: 86.4700,
    dangerLevel: 36.58, warningLevel: 35.40,
  ),

  // ── GHAGHRA ────────────────────────────────────────────────────────────────
  IndiaCity(
    id: 'darauli', name: 'Darauli', state: 'Bihar',
    river: 'Ghaghra', lat: 25.9500, lon: 84.1500,
    dangerLevel: 60.82, warningLevel: 59.80,
  ),
  IndiaCity(
    id: 'gangpur_siswan', name: 'Gangpur Siswan', state: 'Bihar',
    river: 'Ghaghra', lat: 26.0500, lon: 84.4000,
    dangerLevel: 57.04, warningLevel: 56.00,
  ),

  // ── MAHANANDA ──────────────────────────────────────────────────────────────
  IndiaCity(
    id: 'dhengraghat', name: 'Dhengraghat', state: 'Bihar',
    river: 'Mahananda', lat: 25.7800, lon: 87.4800,
    dangerLevel: 35.65, warningLevel: 34.65,
  ),
  IndiaCity(
    id: 'taibpur', name: 'Taibpur', state: 'Bihar',
    river: 'Mahananda', lat: 26.5800, lon: 87.9500,
    dangerLevel: 66.00, warningLevel: 64.80,
  ),

  // ── KAMLA / KAMALABALAN ────────────────────────────────────────────────────
  IndiaCity(
    id: 'jainagar', name: 'Jainagar', state: 'Bihar',
    river: 'Kamla', lat: 26.6000, lon: 86.2700,
    dangerLevel: 67.75, warningLevel: 66.00,
  ),
  IndiaCity(
    id: 'jhanjharpur', name: 'Jhanjharpur', state: 'Bihar',
    river: 'Kamalabalan', lat: 26.2700, lon: 86.2800,
    dangerLevel: 50.00, warningLevel: 48.80,
  ),

  // ── ADHWARA ────────────────────────────────────────────────────────────────
  IndiaCity(
    id: 'sonbarsa', name: 'Sonbarsa', state: 'Bihar',
    river: 'Adhwara', lat: 26.6500, lon: 85.5500,
    dangerLevel: 81.85, warningLevel: 80.70,
  ),
  IndiaCity(
    id: 'kamtaul', name: 'Kamtaul', state: 'Bihar',
    river: 'Adhwara', lat: 26.2200, lon: 85.8500,
    dangerLevel: 50.00, warningLevel: 49.00,
  ),
  IndiaCity(
    id: 'ekmighat', name: 'Ekmighat', state: 'Bihar',
    river: 'Adhwara', lat: 26.1500, lon: 86.0000,
    dangerLevel: 46.94, warningLevel: 45.80,
  ),

  // ── PUNPUN ─────────────────────────────────────────────────────────────────
  IndiaCity(
    id: 'sripalpur', name: 'Sripalpur', state: 'Bihar',
    river: 'Punpun', lat: 25.4833, lon: 85.1333,
    dangerLevel: 50.60, warningLevel: 49.50,
  ),
];
