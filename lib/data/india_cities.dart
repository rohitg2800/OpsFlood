// lib/data/india_cities.dart
//
// OpsFlood Bihar — IndiaCity registry (v3.0)
//
// 31 WRD Bihar gauge stations across 10 rivers.
// wrdSite = EXACT site name used on irrigation.befiqr.in/state/table/rivers
// This field drives the WrdBiharService alias map (no fuzzy match needed).
//
// Danger/warning levels: WRD Bihar Central Flood Control Cell (2025)
// Coordinates: verified against WRD district locations
//
// DATA STATUS (27 Mar 2026 — pre-monsoon):
//   LIVE (22): Dheng Bridge, Khagaria, Rosera, Samastipur, Sikandarpur,
//              Chatia, Dumariaghat, Hajipur, Rewaghat, Bhagalpur, Buxar,
//              Dighaghat, Gandhighat, Hathidah, Kahalgaon, Munger,
//              Darauli, Gangpur Siswan, Baltara, Basua, Birpur, Kursela,
//              Dhengraghat, Taibpur, Sripalpur  (25 live)
//   NA  (6):   Ekmighat, Kamtaul, Sonbarsa (Adhwara — dry season),
//              Benibad, Hayaghat (Bagmati partial), Jhanjharpur, Jainagar
library;

class IndiaCity {
  final String  id;
  final String  name;          // display name
  final String  state;
  final String  river;
  final double  lat;
  final double  lon;
  final double  dangerLevel;   // m MSL (WRD)
  final double  warningLevel;  // m MSL (WRD)
  final double  hfl;           // Highest Flood Level
  final String? cwcStation;    // CWC FFS station code (null = WRD-only)
  final String  wrdSite;       // Exact WRD portal site name

  const IndiaCity({
    required this.id,
    required this.name,
    required this.state,
    required this.river,
    required this.lat,
    required this.lon,
    required this.dangerLevel,
    required this.warningLevel,
    required this.wrdSite,
    double? hfl,
    this.cwcStation,
  }) : hfl = hfl ?? dangerLevel * 1.10;
}

const List<IndiaCity> kIndiaCities = [

  // ── GANGA (7 stations) ──────────────────────────────────────────────────────────────
  // Live: Gandhighat 42.27m, Dighaghat 42.94m, Hathidah 34.06m
  //       Munger 30.81m, Kahalgaon 24.53m, Bhagalpur 25.71m, Buxar 50.02m
  IndiaCity(
    id: 'gandhighat', name: 'Gandhighat', state: 'Bihar',
    river: 'Ganga', lat: 25.6129, lon: 85.1376,
    dangerLevel: 48.60, warningLevel: 47.50,
    hfl: 50.52, wrdSite: 'Gandhighat', cwcStation: 'PAT',
  ),
  IndiaCity(
    id: 'dighaghat', name: 'Dighaghat', state: 'Bihar',
    river: 'Ganga', lat: 25.5941, lon: 85.0700,
    dangerLevel: 50.45, warningLevel: 49.30,
    hfl: 52.52, wrdSite: 'Dighaghat',
  ),
  IndiaCity(
    id: 'hathidah', name: 'Hathidah', state: 'Bihar',
    river: 'Ganga', lat: 25.4167, lon: 85.7500,
    dangerLevel: 41.76, warningLevel: 40.50,
    hfl: 43.52, wrdSite: 'Hathidah',
  ),
  IndiaCity(
    id: 'munger', name: 'Munger', state: 'Bihar',
    river: 'Ganga', lat: 25.3743, lon: 86.4730,
    dangerLevel: 39.33, warningLevel: 38.20,
    hfl: 40.99, wrdSite: 'Munger',
  ),
  IndiaCity(
    id: 'kahalgaon', name: 'Kahalgaon', state: 'Bihar',
    river: 'Ganga', lat: 25.2167, lon: 87.2667,
    dangerLevel: 31.09, warningLevel: 30.00,
    hfl: 32.87, wrdSite: 'Kahalgaon',
  ),
  IndiaCity(
    id: 'bhagalpur', name: 'Bhagalpur', state: 'Bihar',
    river: 'Ganga', lat: 25.2425, lon: 86.9842,
    dangerLevel: 33.68, warningLevel: 32.50,
    hfl: 34.86, wrdSite: 'Bhagalpur', cwcStation: 'BHP',
  ),
  IndiaCity(
    id: 'buxar', name: 'Buxar', state: 'Bihar',
    river: 'Ganga', lat: 25.5667, lon: 83.9667,
    dangerLevel: 60.30, warningLevel: 59.20,
    hfl: 62.10, wrdSite: 'Buxar',
  ),

  // ── KOSI (5 stations) ───────────────────────────────────────────────────────────────
  // Birpur 74.86m (LIVE, at danger), Baltara 30.56m, Basua 45.39m,
  // Kursela 23.99m — all live
  IndiaCity(
    id: 'birpur', name: 'Birpur', state: 'Bihar',
    river: 'Kosi', lat: 26.5167, lon: 86.9000,
    dangerLevel: 74.70, warningLevel: 73.70,
    hfl: 76.00, wrdSite: 'Birpur', cwcStation: 'BIR',
  ),
  IndiaCity(
    id: 'baltara', name: 'Baltara', state: 'Bihar',
    river: 'Kosi', lat: 25.5000, lon: 86.5833,
    dangerLevel: 33.85, warningLevel: 32.85,
    hfl: 36.40, wrdSite: 'Baltara',
  ),
  IndiaCity(
    id: 'basua', name: 'Basua', state: 'Bihar',
    river: 'Kosi', lat: 26.1234, lon: 86.6020,
    dangerLevel: 47.75, warningLevel: 46.50,
    hfl: 49.24, wrdSite: 'Basua', cwcStation: 'SUP',
  ),
  IndiaCity(
    id: 'kursela', name: 'Kursela', state: 'Bihar',
    river: 'Kosi', lat: 25.4800, lon: 87.2600,
    dangerLevel: 30.00, warningLevel: 28.80,
    hfl: 32.10, wrdSite: 'Kursela', cwcStation: 'KAT',
  ),

  // ── GANDAK (4 stations) ────────────────────────────────────────────────────────────
  // All 4 live: Chatia 65.13m, Dumariaghat 59.50m, Rewaghat 49.94m, Hajipur 44.72m
  IndiaCity(
    id: 'chatia', name: 'Chatia', state: 'Bihar',
    river: 'Gandak', lat: 26.8500, lon: 84.9000,
    dangerLevel: 69.15, warningLevel: 68.10,
    hfl: 70.04, wrdSite: 'Chatia',
  ),
  IndiaCity(
    id: 'dumariaghat', name: 'Dumariaghat', state: 'Bihar',
    river: 'Gandak', lat: 26.4833, lon: 84.4667,
    dangerLevel: 62.22, warningLevel: 61.10,
    hfl: 63.70, wrdSite: 'Dumariaghat', cwcStation: 'GKP',
  ),
  IndiaCity(
    id: 'rewaghat', name: 'Rewaghat', state: 'Bihar',
    river: 'Gandak', lat: 26.1000, lon: 85.3000,
    dangerLevel: 54.41, warningLevel: 53.40,
    hfl: 55.46, wrdSite: 'Rewaghat',
  ),
  IndiaCity(
    id: 'hajipur', name: 'Hajipur', state: 'Bihar',
    river: 'Gandak', lat: 25.6933, lon: 85.2094,
    dangerLevel: 50.32, warningLevel: 49.40,
    hfl: 50.93, wrdSite: 'Hajipur',
  ),

  // ── BAGMATI (3 stations) ───────────────────────────────────────────────────────────
  // Dheng Bridge 68.20m (live), Benibad NA, Hayaghat NA
  IndiaCity(
    id: 'dheng_bridge', name: 'Dheng Bridge', state: 'Bihar',
    river: 'Bagmati', lat: 26.5800, lon: 85.4900,
    dangerLevel: 71.00, warningLevel: 70.00,
    hfl: 73.47, wrdSite: 'Dheng Bridge',
  ),
  IndiaCity(
    id: 'benibad', name: 'Benibad', state: 'Bihar',
    river: 'Bagmati', lat: 26.0500, lon: 85.6500,
    dangerLevel: 48.68, warningLevel: 47.68,
    hfl: 50.01, wrdSite: 'Benibad',
  ),
  IndiaCity(
    id: 'hayaghat', name: 'Hayaghat', state: 'Bihar',
    river: 'Bagmati', lat: 26.0200, lon: 85.9500,
    dangerLevel: 45.72, warningLevel: 44.50,
    hfl: 48.96, wrdSite: 'Hayaghat',
  ),

  // ── BURHI GANDAK (4 stations) ────────────────────────────────────────────────────────
  // All 4 live: Sikandarpur 45.60m, Samastipur 39.50m, Rosera 36.65m, Khagaria 30.32m
  IndiaCity(
    id: 'sikandarpur', name: 'Sikandarpur', state: 'Bihar',
    river: 'Burhi Gandak', lat: 26.1209, lon: 85.3647,
    dangerLevel: 52.53, warningLevel: 51.40,
    hfl: 54.29, wrdSite: 'Sikandarpur (Muzzafarpur)',
  ),
  IndiaCity(
    id: 'samastipur', name: 'Samastipur', state: 'Bihar',
    river: 'Burhi Gandak', lat: 25.8620, lon: 85.7812,
    dangerLevel: 46.00, warningLevel: 44.80,
    hfl: 49.40, wrdSite: 'Samastipur',
  ),
  IndiaCity(
    id: 'rosera', name: 'Rosera', state: 'Bihar',
    river: 'Burhi Gandak', lat: 25.8600, lon: 85.9800,
    dangerLevel: 42.63, warningLevel: 41.50,
    hfl: 46.56, wrdSite: 'Rosera',
  ),
  IndiaCity(
    id: 'khagaria', name: 'Khagaria', state: 'Bihar',
    river: 'Burhi Gandak', lat: 25.5000, lon: 86.4700,
    dangerLevel: 36.58, warningLevel: 35.40,
    hfl: 39.22, wrdSite: 'Khagaria',
  ),

  // ── GHAGHRA (2 stations) ─────────────────────────────────────────────────────────────
  // Both live: Darauli 55.69m, Gangpur Siswan 51.45m
  IndiaCity(
    id: 'darauli', name: 'Darauli', state: 'Bihar',
    river: 'Ghaghra', lat: 25.9500, lon: 84.1500,
    dangerLevel: 60.82, warningLevel: 59.80,
    hfl: 61.82, wrdSite: 'Darauli',
  ),
  IndiaCity(
    id: 'gangpur_siswan', name: 'Gangpur Siswan', state: 'Bihar',
    river: 'Ghaghra', lat: 26.0500, lon: 84.4000,
    dangerLevel: 57.04, warningLevel: 56.00,
    hfl: 58.01, wrdSite: 'Gangpur Siswan',
  ),

  // ── MAHANANDA (2 stations) ───────────────────────────────────────────────────────────
  // Both live: Dhengraghat 33.12m, Taibpur 62.84m
  IndiaCity(
    id: 'dhengraghat', name: 'Dhengraghat', state: 'Bihar',
    river: 'Mahananda', lat: 25.7800, lon: 87.4800,
    dangerLevel: 35.65, warningLevel: 34.65,
    hfl: 38.20, wrdSite: 'Dhengraghat',
  ),
  IndiaCity(
    id: 'taibpur', name: 'Taibpur', state: 'Bihar',
    river: 'Mahananda', lat: 26.5800, lon: 87.9500,
    dangerLevel: 66.00, warningLevel: 64.80,
    hfl: 67.22, wrdSite: 'Taibpur',
  ),

  // ── KAMLA (1 station — NA pre-monsoon) ─────────────────────────────────────────
  IndiaCity(
    id: 'jainagar', name: 'Jainagar', state: 'Bihar',
    river: 'Kamla', lat: 26.6000, lon: 86.2700,
    dangerLevel: 67.75, warningLevel: 66.00,
    hfl: 71.35, wrdSite: 'Jainagar',
  ),

  // ── KAMALABALAN (1 station — NA pre-monsoon) ───────────────────────────────
  IndiaCity(
    id: 'jhanjharpur', name: 'Jhanjharpur', state: 'Bihar',
    river: 'Kamalabalan', lat: 26.2700, lon: 86.2800,
    dangerLevel: 50.00, warningLevel: 48.80,
    hfl: 53.11, wrdSite: 'Jhanjharpur',
  ),

  // ── ADHWARA (3 stations — all NA pre-monsoon) ───────────────────────────────
  IndiaCity(
    id: 'sonbarsa', name: 'Sonbarsa', state: 'Bihar',
    river: 'Adhwara', lat: 26.6500, lon: 85.5500,
    dangerLevel: 81.85, warningLevel: 80.70,
    hfl: 83.20, wrdSite: 'Sonbarsa',
  ),
  IndiaCity(
    id: 'kamtaul', name: 'Kamtaul', state: 'Bihar',
    river: 'Adhwara', lat: 26.2200, lon: 85.8500,
    dangerLevel: 50.00, warningLevel: 49.00,
    hfl: 52.99, wrdSite: 'Kamtaul',
  ),
  IndiaCity(
    id: 'ekmighat', name: 'Ekmighat', state: 'Bihar',
    river: 'Adhwara', lat: 26.1500, lon: 86.0000,
    dangerLevel: 46.94, warningLevel: 45.80,
    hfl: 49.52, wrdSite: 'Ekmighat',
  ),

  // ── PUNPUN (1 station) ──────────────────────────────────────────────────────────────
  // Live: Sripalpur 45.46m
  IndiaCity(
    id: 'sripalpur', name: 'Sripalpur', state: 'Bihar',
    river: 'Punpun', lat: 25.4833, lon: 85.1333,
    dangerLevel: 50.60, warningLevel: 49.50,
    hfl: 53.91, wrdSite: 'Sripalpur',
  ),
];
