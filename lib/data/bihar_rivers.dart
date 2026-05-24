// lib/data/bihar_rivers.dart
//
// OpsFlood — Bihar River Gauge Registry (v1)
//
// Source: WRD Bihar Central Flood Control Cell + CWC FFS
//   Live board: https://irrigation.befiqr.in/state/table/rivers
//   CWC FFS:    https://beams.fmiscwrdbihar.gov.in
//   PDF bulk:   https://www.fmiscwrdbihar.gov.in/bulletin/
//
// 13 rivers | 31 gauge stations
// All levels in metres above mean sea level (m MSL).
// HFL = Highest Flood Level on record (year noted in comments).
// WL  = CWC/WRD Warning Level
// DL  = CWC/WRD Danger Level
//
// WARNING: Do NOT confuse WL (warning) with water level.
library;

class BiharGauge {
  final String river;
  final String station;    // official WRD/CWC station name
  final String district;
  final double lat;
  final double lon;
  final double warningLevel; // m MSL
  final double dangerLevel;  // m MSL
  final double hfl;          // m MSL (highest flood level)
  final String? cwcCode;     // CWC station code (null = WRD only)
  final String? hflYear;     // year HFL was recorded

  const BiharGauge({
    required this.river,
    required this.station,
    required this.district,
    required this.lat,
    required this.lon,
    required this.warningLevel,
    required this.dangerLevel,
    required this.hfl,
    this.cwcCode,
    this.hflYear,
  });
}

/// Complete Bihar gauge network — 31 stations across 13 rivers.
/// Sourced from WRD Bihar Central Flood Control Cell (2024-25).
const List<BiharGauge> kBiharGauges = [

  // ── 1. GANGA ───────────────────────────────────────────────────────────────
  // Gandhighat — primary Patna CWC gauge; DL 48.60, HFL 50.52
  BiharGauge(
    river: 'Ganga', station: 'Gandhighat', district: 'Patna',
    lat: 25.6129, lon: 85.1376, cwcCode: 'PAT',
    warningLevel: 47.50, dangerLevel: 48.60, hfl: 50.52, hflYear: '1994',
  ),
  // Dighaghat — upstream Patna; DL 50.45, HFL 52.52
  BiharGauge(
    river: 'Ganga', station: 'Dighaghat', district: 'Patna',
    lat: 25.5941, lon: 85.0700,
    warningLevel: 49.30, dangerLevel: 50.45, hfl: 52.52, hflYear: '1994',
  ),
  // Hathidah — Patna/Mokameh; DL 41.76, HFL 43.52
  BiharGauge(
    river: 'Ganga', station: 'Hathidah', district: 'Patna',
    lat: 25.4167, lon: 85.7500,
    warningLevel: 40.50, dangerLevel: 41.76, hfl: 43.52, hflYear: '1994',
  ),
  // Munger — DL 39.33, HFL 40.99
  BiharGauge(
    river: 'Ganga', station: 'Munger', district: 'Munger',
    lat: 25.3743, lon: 86.4730,
    warningLevel: 38.20, dangerLevel: 39.33, hfl: 40.99, hflYear: '1987',
  ),
  // Kahalgaon — DL 31.09, HFL 32.87
  BiharGauge(
    river: 'Ganga', station: 'Kahalgaon', district: 'Bhagalpur',
    lat: 25.2167, lon: 87.2667,
    warningLevel: 30.00, dangerLevel: 31.09, hfl: 32.87, hflYear: '1987',
  ),
  // Bhagalpur — CWC gauge; DL 33.68, HFL 34.86
  BiharGauge(
    river: 'Ganga', station: 'Bhagalpur', district: 'Bhagalpur',
    lat: 25.2425, lon: 86.9842, cwcCode: 'BHP',
    warningLevel: 32.50, dangerLevel: 33.68, hfl: 34.86, hflYear: '1987',
  ),
  // Buxar — entry point; DL 60.30, HFL 62.10
  BiharGauge(
    river: 'Ganga', station: 'Buxar', district: 'Buxar',
    lat: 25.5667, lon: 83.9667,
    warningLevel: 59.20, dangerLevel: 60.30, hfl: 62.10, hflYear: '1994',
  ),

  // ── 2. KOSI ────────────────────────────────────────────────────────────────
  // Birpur (CWC) — Nepal border entry; DL 74.70, HFL 76.02; LIVE 23-May-2026: 74.74 (Above Danger)
  BiharGauge(
    river: 'Kosi', station: 'Birpur (CWC)', district: 'Supaul',
    lat: 26.5167, lon: 86.9000, cwcCode: 'BIR',
    warningLevel: 73.70, dangerLevel: 74.70, hfl: 76.02, hflYear: '2008',
  ),
  // Baltara — mid-Kosi; DL 33.85, HFL 36.40
  BiharGauge(
    river: 'Kosi', station: 'Baltara', district: 'Khagaria',
    lat: 25.5000, lon: 86.5833,
    warningLevel: 32.85, dangerLevel: 33.85, hfl: 36.40, hflYear: '2008',
  ),
  // Basua — Supaul town gauge; DL 47.75, HFL 49.24
  BiharGauge(
    river: 'Kosi', station: 'Basua', district: 'Supaul',
    lat: 26.1234, lon: 86.6020, cwcCode: 'SUP',
    warningLevel: 46.50, dangerLevel: 47.75, hfl: 49.24, hflYear: '2008',
  ),
  // Kursela — confluence with Ganga; DL 30.00, HFL 32.10
  BiharGauge(
    river: 'Kosi', station: 'Kursela', district: 'Katihar',
    lat: 25.4800, lon: 87.2600, cwcCode: 'KAT',
    warningLevel: 28.80, dangerLevel: 30.00, hfl: 32.10, hflYear: '2008',
  ),

  // ── 3. GANDAK ─────────────────────────────────────────────────────────────
  // Chatia — E. Champaran; DL 69.15, HFL 70.04
  BiharGauge(
    river: 'Gandak', station: 'Chatia', district: 'East Champaran',
    lat: 26.8500, lon: 84.9000,
    warningLevel: 68.10, dangerLevel: 69.15, hfl: 70.04, hflYear: '1971',
  ),
  // Dumariaghat — Gopalganj; DL 62.22, HFL 63.70
  BiharGauge(
    river: 'Gandak', station: 'Dumariaghat', district: 'Gopalganj',
    lat: 26.4833, lon: 84.4667, cwcCode: 'GKP',
    warningLevel: 61.10, dangerLevel: 62.22, hfl: 63.70, hflYear: '1971',
  ),
  // Rewaghat — Muzaffarpur; DL 54.41, HFL 55.46
  BiharGauge(
    river: 'Gandak', station: 'Rewaghat', district: 'Muzaffarpur',
    lat: 26.1000, lon: 85.3000,
    warningLevel: 53.40, dangerLevel: 54.41, hfl: 55.46, hflYear: '1971',
  ),
  // Hajipur — Vaishali/confluence; DL 50.32, HFL 50.93
  BiharGauge(
    river: 'Gandak', station: 'Hajipur', district: 'Vaishali',
    lat: 25.6933, lon: 85.2094,
    warningLevel: 49.40, dangerLevel: 50.32, hfl: 50.93, hflYear: '1971',
  ),

  // ── 4. BAGMATI ───────────────────────────────────────────────────────────
  // Dheng Bridge — Sitamarhi (Nepal entry); DL 71.00, HFL 73.47 (2024)
  BiharGauge(
    river: 'Bagmati', station: 'Dheng Bridge', district: 'Sitamarhi',
    lat: 26.5800, lon: 85.4900,
    warningLevel: 70.00, dangerLevel: 71.00, hfl: 73.47, hflYear: '2024',
  ),
  // Benibad — Muzaffarpur; DL 48.68, HFL 50.01
  BiharGauge(
    river: 'Bagmati', station: 'Benibad', district: 'Muzaffarpur',
    lat: 26.0500, lon: 85.6500,
    warningLevel: 47.68, dangerLevel: 48.68, hfl: 50.01, hflYear: '2002',
  ),
  // Hayaghat — Darbhanga; DL 45.72, HFL 48.96
  BiharGauge(
    river: 'Bagmati', station: 'Hayaghat', district: 'Darbhanga',
    lat: 26.0200, lon: 85.9500,
    warningLevel: 44.50, dangerLevel: 45.72, hfl: 48.96, hflYear: '2007',
  ),

  // ── 5. BURHI GANDAK ────────────────────────────────────────────────────
  // Sikandarpur — Muzaffarpur; DL 52.53, HFL 54.29
  BiharGauge(
    river: 'Burhi Gandak', station: 'Sikandarpur', district: 'Muzaffarpur',
    lat: 26.1209, lon: 85.3647,
    warningLevel: 51.40, dangerLevel: 52.53, hfl: 54.29, hflYear: '1987',
  ),
  // Samastipur — DL 46.00, HFL 49.40
  BiharGauge(
    river: 'Burhi Gandak', station: 'Samastipur', district: 'Samastipur',
    lat: 25.8620, lon: 85.7812,
    warningLevel: 44.80, dangerLevel: 46.00, hfl: 49.40, hflYear: '1987',
  ),
  // Rosera — DL 42.63, HFL 46.56
  BiharGauge(
    river: 'Burhi Gandak', station: 'Rosera', district: 'Samastipur',
    lat: 25.8600, lon: 85.9800,
    warningLevel: 41.50, dangerLevel: 42.63, hfl: 46.56, hflYear: '1987',
  ),
  // Khagaria — DL 36.58, HFL 39.22
  BiharGauge(
    river: 'Burhi Gandak', station: 'Khagaria', district: 'Khagaria',
    lat: 25.5000, lon: 86.4700,
    warningLevel: 35.40, dangerLevel: 36.58, hfl: 39.22, hflYear: '1987',
  ),

  // ── 6. GHAGHRA (Saryu) ──────────────────────────────────────────────────
  // Darauli — Siwan; DL 60.82, HFL 61.82
  BiharGauge(
    river: 'Ghaghra', station: 'Darauli', district: 'Siwan',
    lat: 25.9500, lon: 84.1500,
    warningLevel: 59.80, dangerLevel: 60.82, hfl: 61.82, hflYear: '1998',
  ),
  // Gangpur Siswan — Siwan; DL 57.04, HFL 58.01
  BiharGauge(
    river: 'Ghaghra', station: 'Gangpur Siswan', district: 'Siwan',
    lat: 26.0500, lon: 84.4000,
    warningLevel: 56.00, dangerLevel: 57.04, hfl: 58.01, hflYear: '1998',
  ),

  // ── 7. MAHANANDA ────────────────────────────────────────────────────────
  // Dhengraghat — Purnia; DL 35.65, HFL 38.20
  BiharGauge(
    river: 'Mahananda', station: 'Dhengraghat', district: 'Purnia',
    lat: 25.7800, lon: 87.4800,
    warningLevel: 34.65, dangerLevel: 35.65, hfl: 38.20, hflYear: '1987',
  ),
  // Taibpur — Kishanganj; DL 66.00, HFL 67.22
  BiharGauge(
    river: 'Mahananda', station: 'Taibpur', district: 'Kishanganj',
    lat: 26.5800, lon: 87.9500,
    warningLevel: 64.80, dangerLevel: 66.00, hfl: 67.22, hflYear: '2017',
  ),

  // ── 8. KAMLA-BALAN ─────────────────────────────────────────────────────
  // Jainagar — Madhubani (Nepal entry); DL 67.75, HFL 71.35
  BiharGauge(
    river: 'Kamla', station: 'Jainagar', district: 'Madhubani',
    lat: 26.6000, lon: 86.2700,
    warningLevel: 66.00, dangerLevel: 67.75, hfl: 71.35, hflYear: '2007',
  ),
  // Jhanjharpur — Madhubani; DL 50.00, HFL 53.11
  BiharGauge(
    river: 'Kamalabalan', station: 'Jhanjharpur', district: 'Madhubani',
    lat: 26.2700, lon: 86.2800,
    warningLevel: 48.80, dangerLevel: 50.00, hfl: 53.11, hflYear: '2007',
  ),

  // ── 9. ADHWARA GROUP ────────────────────────────────────────────────────
  // Sonbarsa — Sitamarhi; DL 81.85, HFL 83.20
  BiharGauge(
    river: 'Adhwara', station: 'Sonbarsa', district: 'Sitamarhi',
    lat: 26.6500, lon: 85.5500,
    warningLevel: 80.70, dangerLevel: 81.85, hfl: 83.20, hflYear: '2008',
  ),
  // Kamtaul — Darbhanga; DL 50.00, HFL 52.99
  BiharGauge(
    river: 'Adhwara', station: 'Kamtaul', district: 'Darbhanga',
    lat: 26.2200, lon: 85.8500,
    warningLevel: 49.00, dangerLevel: 50.00, hfl: 52.99, hflYear: '2008',
  ),
  // Ekmighat — Darbhanga; DL 46.94, HFL 49.52
  BiharGauge(
    river: 'Adhwara', station: 'Ekmighat', district: 'Darbhanga',
    lat: 26.1500, lon: 86.0000,
    warningLevel: 45.80, dangerLevel: 46.94, hfl: 49.52, hflYear: '2007',
  ),

  // ── 10. PUNPUN ───────────────────────────────────────────────────────────
  // Sripalpur — Patna/Phulwari; DL 50.60, HFL 53.91
  BiharGauge(
    river: 'Punpun', station: 'Sripalpur', district: 'Patna',
    lat: 25.4833, lon: 85.1333,
    warningLevel: 49.50, dangerLevel: 50.60, hfl: 53.91, hflYear: '1975',
  ),
];

// ── Convenience helpers ────────────────────────────────────────────────────────────────
List<BiharGauge> gaugesByRiver(String river) =>
    kBiharGauges.where((g) => g.river.toLowerCase() == river.toLowerCase()).toList();

List<BiharGauge> get cwcGauges =>
    kBiharGauges.where((g) => g.cwcCode != null).toList();

/// Returns the downstream-most gauge for a given river (lowest DL).
BiharGauge? outfallGauge(String river) {
  final list = gaugesByRiver(river);
  if (list.isEmpty) return null;
  list.sort((a, b) => a.dangerLevel.compareTo(b.dangerLevel));
  return list.first;
}
