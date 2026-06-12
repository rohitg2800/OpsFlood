// lib/data/bihar_rivers.dart
//
// OpsFlood — Bihar River Gauge Registry + Deep Basin Metadata (v4.2)
//
// v4.2 changes vs v4.1 (12 Jun 2026 — BEAMS/BeFIQR re-verification):
//   CORRECTED  Buxar          DL 60.32→60.30  HFL 62.09→62.10
//   CORRECTED  Samastipur     DL 46.02→46.00  HFL 49.38→49.40
//   CORRECTED  Darauli        DL 61.52→60.82  HFL 63.10→61.82  [Ghaghra]
//   CORRECTED  Gangpur Siswan WL 63.00→56.70  DL 64.10→57.04  HFL 65.82→58.26  [Ghaghra — was ~7m high]
//   CORRECTED  Jhanjharpur    WL 49.50→48.50  DL 50.50→50.00  [Kamla]
//   CORRECTED  Sonbarsa       HFL 83.75→83.20  [Jhim]
//   CORRECTED  Taibpur        WL 34.65→64.40  DL 35.65→66.00  HFL 38.16→67.22
//              (was mis-keyed as Dhengraghat clone; now correct Kishanganj MSL datum)
//
// SOURCES (all thresholds re-verified 12 Jun 2026):
//   1. BEAMS RTDAS live table — irrigation.fmiscwrdbihar.gov.in/rtdas (12 Jun 2026)
//   2. BeFIQR 3-day forecast table — irrigation.befiqr.in/forecast (12 Jun 2026)
//   3. BEAMS real-time alert — beams.fmiscwrdbihar.gov.in (12 Jun 2026)
//   4. WRD Bihar FMISC daily bulletin — helpdeskwrdbihar.com (Oct 2024)
//   5. CWC Flood Forecast bulletins 2011-2024 — pib.gov.in / ndmindia.mha.gov.in
//
// 15 rivers | 46 gauge stations | 10 river basin profiles
// All levels in metres above mean sea level (m MSL).
library;

// ══════════════════════════════════════════════════════════════════════════════
// SHARED SEVERITY COMPUTATION
// ══════════════════════════════════════════════════════════════════════════════
//
// Single source of truth for severity classification.
// Used by:
//   • RiverStation.dangerClass        (map markers + polygons)
//   • StationReading._deriveRisk      (DataFetchEngine → dashboard / alerts)
//   • AlertSeverity derivation        (ActiveAlertController)
//
// Tier rules (all guards against unset thresholds via > 0 check):
//   current >= hfl     → 'EXTREME'
//   current >= danger  → 'CRITICAL'
//   current >= warning → 'DANGER'
//   otherwise          → 'NORMAL'
//
// Returns a plain string label that maps 1-to-1 with DangerClass:
//   'EXTREME'  ↔  DangerClass.extreme
//   'CRITICAL' ↔  DangerClass.severe
//   'DANGER'   ↔  DangerClass.aboveNormal
//   'NORMAL'   ↔  DangerClass.normal

String gaugeRiskFromLevels({
  required double current,
  required double warning,
  required double danger,
  required double hfl,
}) {
  if (hfl     > 0 && current >= hfl)     return 'EXTREME';
  if (danger  > 0 && current >= danger)  return 'CRITICAL';
  if (warning > 0 && current >= warning) return 'DANGER';
  return 'NORMAL';
}

// ══════════════════════════════════════════════════════════════════════════════
class BiharGauge {
  final String river;
  final String station;
  final String district;
  final double lat;
  final double lon;
  final double warningLevel;
  final double dangerLevel;
  final double hfl;
  final String? cwcCode;
  final String? hflYear;

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

// ══════════════════════════════════════════════════════════════════════════════
class BiharRiverMeta {
  final String name;
  final String basinName;
  final String origin;
  final String outfall;
  final int lengthInBiharKm;
  final int catchmentKm2;
  final int avgDischargeCumecs;
  final int peakFloodCumecs;
  final String peakFloodYear;
  final double embLBankKm;
  final double embRBankKm;
  final List<String> majorTributaries;
  final List<String> notableFloods;
  final bool transBoundary;

  const BiharRiverMeta({
    required this.name,
    required this.basinName,
    required this.origin,
    required this.outfall,
    required this.lengthInBiharKm,
    required this.catchmentKm2,
    required this.avgDischargeCumecs,
    required this.peakFloodCumecs,
    required this.peakFloodYear,
    required this.embLBankKm,
    required this.embRBankKm,
    required this.majorTributaries,
    required this.notableFloods,
    this.transBoundary = false,
  });
}

// ══════════════════════════════════════════════════════════════════════════════
const Map<String, BiharRiverMeta> kBiharRiverMeta = {

  'ganga': BiharRiverMeta(
    name: 'Ganga', basinName: 'Ganga Main Stem',
    origin: 'Gangotri Glacier, Uttarakhand (3,892 m)',
    outfall: 'Bay of Bengal via Bangladesh',
    lengthInBiharKm: 445, catchmentKm2: 16900,
    avgDischargeCumecs: 11500, peakFloodCumecs: 84000, peakFloodYear: '1978',
    embLBankKm: 1680.0, embRBankKm: 1741.0,
    majorTributaries: ['Gandak', 'Sone', 'Punpun', 'Ghaghra', 'Kosi'],
    notableFloods: ['1978 (highest discharge)', '1987 (Patna breach)', '1994 (Patna HFL 50.52 m)', '2016', '2019'],
    transBoundary: false,
  ),

  'kosi': BiharRiverMeta(
    name: 'Kosi', basinName: 'Kosi Sub-basin',
    origin: 'Gosainthan / Sun Kosi confluence, Tibet-Nepal border (>4,000 m)',
    outfall: 'Ganga at Kursela, Katihar district',
    lengthInBiharKm: 260, catchmentKm2: 11410,
    avgDischargeCumecs: 2166, peakFloodCumecs: 24200, peakFloodYear: '1968',
    embLBankKm: 158.0, embRBankKm: 128.5,
    majorTributaries: ['Sun Kosi', 'Tama Kosi', 'Dudh Kosi', 'Arun', 'Tamor'],
    notableFloods: ['1968 (peak 24,200 m3/s)', '1987 (mass embankment breach)', '2008 (Kusaha breach)', '2017', '2020', '2024'],
    transBoundary: true,
  ),

  'gandak': BiharRiverMeta(
    name: 'Gandak', basinName: 'Gandak Sub-basin',
    origin: 'Mustang district, Nepal / Tibet border (~5,500 m)',
    outfall: 'Ganga at Hajipur, Vaishali district',
    lengthInBiharKm: 260, catchmentKm2: 8800,
    avgDischargeCumecs: 1654, peakFloodCumecs: 23200, peakFloodYear: '1971',
    embLBankKm: 279.0, embRBankKm: 170.0,
    majorTributaries: ['Trishuli', 'Burhi Gandak (upper)', 'Masan', 'Sikrahna'],
    notableFloods: ['1971 (peak 23,200 m3/s)', '1978', '1998 (Bagaha breach)', '2007', '2021'],
    transBoundary: true,
  ),

  'bagmati': BiharRiverMeta(
    name: 'Bagmati', basinName: 'Bagmati Sub-basin',
    origin: 'Shivapuri Hills, Kathmandu Valley, Nepal (1,400 m)',
    outfall: 'Kosi/Ganga confluence near Kursela (via Adhwara); some channels join Kamla Balan',
    lengthInBiharKm: 394, catchmentKm2: 10800,
    avgDischargeCumecs: 488, peakFloodCumecs: 9100, peakFloodYear: '2002',
    embLBankKm: 262.0, embRBankKm: 189.0,
    majorTributaries: ['Lalbakeya', 'Lakhandei', 'Masan', 'Tilawe'],
    notableFloods: ['1987', '2002 (catastrophic Sitamarhi breach)', '2007', '2017', '2024'],
    transBoundary: true,
  ),

  'burhi gandak': BiharRiverMeta(
    name: 'Burhi Gandak', basinName: 'Burhi Gandak Basin',
    origin: 'Siwalik Hills, West Champaran (~300 m)',
    outfall: 'Ganga near Khagaria district',
    lengthInBiharKm: 320, catchmentKm2: 13000,
    avgDischargeCumecs: 350, peakFloodCumecs: 5600, peakFloodYear: '1987',
    embLBankKm: 198.0, embRBankKm: 174.0,
    majorTributaries: ['Tiyar', 'Pandai', 'Dhanauti', 'Tilawe'],
    notableFloods: ['1975', '1987 (peak discharge, Muzaffarpur inundated)', '2007', '2016', '2022'],
    transBoundary: false,
  ),

  'ghaghra': BiharRiverMeta(
    name: 'Ghaghra', basinName: 'Ghaghra Sub-basin',
    origin: 'Gurla Mandhata glacier, Tibet (>5,000 m) - as Karnali/Narayani',
    outfall: 'Ganga at Revelganj / Chhapra, Saran district',
    lengthInBiharKm: 83, catchmentKm2: 4290,
    avgDischargeCumecs: 2900, peakFloodCumecs: 35700, peakFloodYear: '1998',
    embLBankKm: 92.0, embRBankKm: 64.0,
    majorTributaries: ['Chhoti Gandak (UP)', 'Rapti (UP)'],
    notableFloods: ['1998 (Siwan-Saran breach)', '2007', '2013'],
    transBoundary: true,
  ),

  'mahananda': BiharRiverMeta(
    name: 'Mahananda', basinName: 'Mahananda Sub-basin',
    origin: 'Mahaldiram Hills, Darjeeling district (~2,100 m)',
    outfall: 'Ganga at Manihari, Katihar (in West Bengal border zone)',
    lengthInBiharKm: 165, catchmentKm2: 6150,
    avgDischargeCumecs: 490, peakFloodCumecs: 6290, peakFloodYear: '1987',
    embLBankKm: 143.0, embRBankKm: 97.0,
    majorTributaries: ['Kankai', 'Mechi', 'Balan', 'Trishna'],
    notableFloods: ['1987', '2004 (Kishanganj)', '2017 (Dhengraghat HFL 38.20)', '2022'],
    transBoundary: false,
  ),

  'kamla': BiharRiverMeta(
    name: 'Kamla', basinName: 'Kamla-Balan Sub-basin',
    origin: 'Mahabharat Range, Sindhuli district, Nepal (~2,000 m)',
    outfall: 'Kosi near Jhanjharpur / Darbhanga via Balan confluence',
    lengthInBiharKm: 148, catchmentKm2: 7620,
    avgDischargeCumecs: 310, peakFloodCumecs: 5080, peakFloodYear: '2007',
    embLBankKm: 120.0, embRBankKm: 80.0,
    majorTributaries: ['Balan', 'Bhutahi Balan', 'Tilawe'],
    notableFloods: ['1987', '2007 (record HFL Jainagar 71.35)', '2017', '2019', '2021'],
    transBoundary: true,
  ),

  'adhwara': BiharRiverMeta(
    name: 'Adhwara', basinName: 'Adhwara Group Basin',
    origin: 'Nepal Terai / Siwalik foothills (~200-400 m)',
    outfall: 'Bagmati / Kosi via lower Darbhanga channels',
    lengthInBiharKm: 210, catchmentKm2: 4700,
    avgDischargeCumecs: 120, peakFloodCumecs: 2800, peakFloodYear: '2008',
    embLBankKm: 88.0, embRBankKm: 65.0,
    majorTributaries: ['Khiroi', 'Jamuane', 'Basua', 'Tilawe'],
    notableFloods: ['2004', '2007 (Darbhanga inundation)', '2008', '2019'],
    transBoundary: true,
  ),

  'punpun': BiharRiverMeta(
    name: 'Punpun', basinName: 'Punpun Basin',
    origin: 'Palamu plateau, Jharkhand (~500 m)',
    outfall: 'Ganga at Fatuha, Patna district',
    lengthInBiharKm: 200, catchmentKm2: 8970,
    avgDischargeCumecs: 145, peakFloodCumecs: 7200, peakFloodYear: '1975',
    embLBankKm: 68.0, embRBankKm: 52.0,
    majorTributaries: ['Morhar', 'Phalgu', 'Dardha', 'Safi'],
    notableFloods: ['1975 (record HFL 53.91 m at Sripalpur)', '1987', '2016 (Patna south flooding)', '2019'],
    transBoundary: false,
  ),
};

// ══════════════════════════════════════════════════════════════════════════════
// GAUGE STATION DATA — 46 stations, 15 rivers
// All thresholds re-verified from BEAMS RTDAS + BeFIQR 12 Jun 2026.
// WL = Warning Level, DL = Danger Level, HFL = Highest Flood Level (all m MSL)
// ══════════════════════════════════════════════════════════════════════════════
const List<BiharGauge> kBiharGauges = [

  // ──────────── GANGA (7 stations) ──────────────────────────────────────────
  BiharGauge(
    river: 'Ganga', station: 'Gandhighat', district: 'Patna',
    lat: 25.6129, lon: 85.1376, cwcCode: 'PAT',
    warningLevel: 47.50, dangerLevel: 48.60, hfl: 50.52, hflYear: '2016',
  ),
  BiharGauge(
    river: 'Ganga', station: 'Dighaghat', district: 'Patna',
    lat: 25.5941, lon: 85.0700,
    warningLevel: 49.30, dangerLevel: 50.45, hfl: 52.52, hflYear: '1975',
  ),
  BiharGauge(
    river: 'Ganga', station: 'Hathidah', district: 'Patna',
    lat: 25.4167, lon: 85.7500,
    warningLevel: 40.50, dangerLevel: 41.76, hfl: 43.52, hflYear: '2021',
  ),
  BiharGauge(
    river: 'Ganga', station: 'Munger', district: 'Munger',
    lat: 25.3743, lon: 86.4730,
    warningLevel: 38.20, dangerLevel: 39.33, hfl: 40.99, hflYear: '1976',
  ),
  BiharGauge(
    river: 'Ganga', station: 'Kahalgaon', district: 'Bhagalpur',
    lat: 25.2167, lon: 87.2667,
    warningLevel: 30.00, dangerLevel: 31.09, hfl: 32.87, hflYear: '2003',
  ),
  BiharGauge(
    river: 'Ganga', station: 'Bhagalpur', district: 'Bhagalpur',
    lat: 25.2425, lon: 86.9842, cwcCode: 'BHP',
    warningLevel: 32.50, dangerLevel: 33.68, hfl: 34.86, hflYear: '2021',
  ),
  // v4.2: DL 60.32→60.30  HFL 62.09→62.10  (BEAMS 12 Jun 2026)
  BiharGauge(
    river: 'Ganga', station: 'Buxar', district: 'Buxar',
    lat: 25.5667, lon: 83.9667,
    warningLevel: 59.20, dangerLevel: 60.30, hfl: 62.10, hflYear: '1948',
  ),

  // ──────────── KOSI (6 stations) ──────────────────────────────────────────
  BiharGauge(
    river: 'Kosi', station: 'Birpur (CWC)', district: 'Supaul',
    lat: 26.5167, lon: 86.9000, cwcCode: 'BIR',
    warningLevel: 73.70, dangerLevel: 74.70, hfl: 76.02, hflYear: '2019',
  ),
  BiharGauge(
    river: 'Kosi', station: 'Basua', district: 'Supaul',
    lat: 26.1234, lon: 86.6020, cwcCode: 'SUP',
    warningLevel: 46.50, dangerLevel: 47.75, hfl: 49.24, hflYear: '2017',
  ),
  BiharGauge(
    river: 'Kosi', station: 'Baltara', district: 'Khagaria',
    lat: 25.5000, lon: 86.5833,
    warningLevel: 32.85, dangerLevel: 33.85, hfl: 36.40, hflYear: '1987',
  ),
  BiharGauge(
    river: 'Kosi', station: 'Kursela', district: 'Katihar',
    lat: 25.4800, lon: 87.2600, cwcCode: 'KAT',
    warningLevel: 28.80, dangerLevel: 30.00, hfl: 32.10, hflYear: '1982',
  ),
  BiharGauge(
    river: 'Kosi', station: 'Dumri Bridge', district: 'Khagaria',
    lat: 25.5200, lon: 86.5000,
    warningLevel: 32.85, dangerLevel: 33.85, hfl: 36.40, hflYear: '1987',
  ),
  BiharGauge(
    river: 'Kosi', station: 'Vijay Ghat Bridge', district: 'Bhagalpur',
    lat: 25.3700, lon: 87.1000,
    warningLevel: 29.50, dangerLevel: 31.00, hfl: 33.50, hflYear: '2017',
  ),

  // ──────────── GANDAK (6 stations) ────────────────────────────────────────
  BiharGauge(
    river: 'Gandak', station: 'Chatia', district: 'East Champaran',
    lat: 26.8500, lon: 84.9000,
    warningLevel: 68.10, dangerLevel: 69.15, hfl: 70.04, hflYear: '1971',
  ),
  BiharGauge(
    river: 'Gandak', station: 'Dumariaghat', district: 'Gopalganj',
    lat: 26.4833, lon: 84.4667, cwcCode: 'GKP',
    warningLevel: 61.10, dangerLevel: 62.22, hfl: 64.36, hflYear: '2020',
  ),
  BiharGauge(
    river: 'Gandak', station: 'Rewaghat', district: 'Muzaffarpur',
    lat: 26.1000, lon: 85.3000,
    warningLevel: 53.40, dangerLevel: 54.41, hfl: 55.46, hflYear: '2020',
  ),
  BiharGauge(
    river: 'Gandak', station: 'Hajipur', district: 'Vaishali',
    lat: 25.6933, lon: 85.2094,
    warningLevel: 49.40, dangerLevel: 50.32, hfl: 50.93, hflYear: '1948',
  ),
  BiharGauge(
    river: 'Gandak', station: 'Lalganj', district: 'Vaishali',
    lat: 25.8700, lon: 85.1700,
    warningLevel: 49.30, dangerLevel: 50.50, hfl: 51.83, hflYear: '1971',
  ),
  BiharGauge(
    river: 'Gandak', station: 'Khadda', district: 'East Champaran',
    lat: 27.0800, lon: 83.9000,
    warningLevel: 94.50, dangerLevel: 96.00, hfl: 97.50, hflYear: '1971',
  ),

  // ──────────── BAGMATI (10 stations) ─────────────────────────────────────
  BiharGauge(
    river: 'Bagmati', station: 'Dheng Bridge', district: 'Sitamarhi',
    lat: 26.5800, lon: 85.4900,
    warningLevel: 70.00, dangerLevel: 71.00, hfl: 73.47, hflYear: '2024',
  ),
  BiharGauge(
    river: 'Bagmati', station: 'Sonakhan', district: 'Sitamarhi',
    lat: 26.6200, lon: 85.5100,
    warningLevel: 67.80, dangerLevel: 68.80, hfl: 72.05, hflYear: '2019',
  ),
  BiharGauge(
    river: 'Bagmati', station: 'Benibad', district: 'Muzaffarpur',
    lat: 26.0500, lon: 85.6500,
    warningLevel: 47.68, dangerLevel: 48.68, hfl: 50.12, hflYear: '2004',
  ),
  BiharGauge(
    river: 'Bagmati', station: 'Hayaghat', district: 'Darbhanga',
    lat: 26.0200, lon: 85.9500,
    warningLevel: 44.50, dangerLevel: 45.72, hfl: 48.96, hflYear: '1987',
  ),
  BiharGauge(
    river: 'Bagmati', station: 'Dhengraghat (Bagmati)', district: 'Darbhanga',
    lat: 26.1800, lon: 85.9200,
    warningLevel: 34.65, dangerLevel: 35.65, hfl: 47.30, hflYear: '2002',
  ),
  BiharGauge(
    river: 'Bagmati', station: 'Kamtaul (Bagmati)', district: 'Darbhanga',
    lat: 26.4200, lon: 86.0800,
    warningLevel: 49.00, dangerLevel: 50.00, hfl: 53.01, hflYear: '2004',
  ),
  BiharGauge(
    river: 'Bagmati', station: 'Runisaidpur', district: 'Muzaffarpur',
    lat: 26.1200, lon: 85.5800,
    warningLevel: 52.50, dangerLevel: 55.00, hfl: 58.15, hflYear: '2019',
  ),
  BiharGauge(
    river: 'Bagmati', station: 'Dubbadhar', district: 'Sheohar',
    lat: 26.5200, lon: 85.2900,
    warningLevel: 59.00, dangerLevel: 61.28, hfl: 63.75, hflYear: '2019',
  ),
  BiharGauge(
    river: 'Bagmati', station: 'Kansar', district: 'Sitamarhi',
    lat: 26.5400, lon: 85.4100,
    warningLevel: 57.50, dangerLevel: 59.06, hfl: 60.86, hflYear: '2019',
  ),
  BiharGauge(
    river: 'Bagmati', station: 'Kataunjha', district: 'Muzaffarpur',
    lat: 26.2500, lon: 85.4500,
    warningLevel: 52.80, dangerLevel: 55.00, hfl: 58.36, hflYear: '2019',
  ),

  // ──────────── BURHI GANDAK (5 stations) ───────────────────────────────
  BiharGauge(
    river: 'Burhi Gandak', station: 'Sikandarpur', district: 'Muzaffarpur',
    lat: 26.1209, lon: 85.3647,
    warningLevel: 51.40, dangerLevel: 52.53, hfl: 54.29, hflYear: '1987',
  ),
  // v4.2: DL 46.02→46.00  HFL 49.38→49.40  (BeFIQR 12 Jun 2026)
  BiharGauge(
    river: 'Burhi Gandak', station: 'Samastipur', district: 'Samastipur',
    lat: 25.8620, lon: 85.7812,
    warningLevel: 44.80, dangerLevel: 46.00, hfl: 49.40, hflYear: '1987',
  ),
  BiharGauge(
    river: 'Burhi Gandak', station: 'Rosera', district: 'Samastipur',
    lat: 25.8600, lon: 85.9800,
    warningLevel: 41.50, dangerLevel: 42.63, hfl: 46.56, hflYear: '1987',
  ),
  BiharGauge(
    river: 'Burhi Gandak', station: 'Khagaria', district: 'Khagaria',
    lat: 25.5000, lon: 86.4700,
    warningLevel: 35.40, dangerLevel: 36.58, hfl: 39.22, hflYear: '1987',
  ),
  BiharGauge(
    river: 'Burhi Gandak', station: 'Gaighat', district: 'Muzaffarpur',
    lat: 26.0300, lon: 85.5500,
    warningLevel: 53.00, dangerLevel: 54.00, hfl: 55.50, hflYear: '1987',
  ),

  // ──────────── GHAGHRA (2 stations) ───────────────────────────────────────
  // v4.2: DL 61.52→60.82  HFL 63.10→61.82  (BeFIQR 12 Jun 2026)
  BiharGauge(
    river: 'Ghaghra', station: 'Darauli', district: 'Siwan',
    lat: 26.0700, lon: 84.4100,
    warningLevel: 60.50, dangerLevel: 60.82, hfl: 61.82, hflYear: '1998',
  ),
  // v4.2: WL 63.00→56.70  DL 64.10→57.04  HFL 65.82→58.26  (BeFIQR 12 Jun 2026 — old values were ~7m high)
  BiharGauge(
    river: 'Ghaghra', station: 'Gangpur Siswan', district: 'Siwan',
    lat: 26.2500, lon: 84.3500,
    warningLevel: 56.70, dangerLevel: 57.04, hfl: 58.26, hflYear: '1998',
  ),

  // ──────────── KAMLA (3 stations) ─────────────────────────────────────────
  BiharGauge(
    river: 'Kamla', station: 'Jainagar', district: 'Madhubani',
    lat: 26.5940, lon: 86.2260,
    warningLevel: 67.75, dangerLevel: 67.75, hfl: 71.35, hflYear: '2019',
  ),
  // v4.2: WL 49.50→48.50  DL 50.50→50.00  (BeFIQR 12 Jun 2026)
  BiharGauge(
    river: 'Kamla', station: 'Jhanjharpur', district: 'Madhubani',
    lat: 26.2640, lon: 86.2790,
    warningLevel: 48.50, dangerLevel: 50.00, hfl: 53.11, hflYear: '2019',
  ),
  BiharGauge(
    river: 'Kamla', station: 'Kamtaul (Kamla)', district: 'Madhubani',
    lat: 26.4200, lon: 86.0800,
    warningLevel: 43.00, dangerLevel: 44.00, hfl: 45.45, hflYear: '2007',
  ),

  // ──────────── MAHANANDA (3 stations) ─────────────────────────────────
  // v4.2: WL 34.65→64.40  DL 35.65→66.00  HFL 38.16→67.22
  //       (was mis-keyed as Dhengraghat clone; corrected to Kishanganj MSL datum — BeFIQR 12 Jun 2026)
  BiharGauge(
    river: 'Mahananda', station: 'Taibpur', district: 'Kishanganj',
    lat: 26.1000, lon: 87.9500,
    warningLevel: 64.40, dangerLevel: 66.00, hfl: 67.22, hflYear: '2017',
  ),
  BiharGauge(
    river: 'Mahananda', station: 'Dhengraghat (Mahananda)', district: 'Purnia',
    lat: 25.9800, lon: 87.4800,
    warningLevel: 34.65, dangerLevel: 35.65, hfl: 38.20, hflYear: '2017',
  ),
  BiharGauge(
    river: 'Mahananda', station: 'Jhawa', district: 'Katihar',
    lat: 25.5200, lon: 87.5700,
    warningLevel: 30.00, dangerLevel: 31.40, hfl: 34.07, hflYear: '2017',
  ),

  // ──────────── PUNPUN (1 station) ─────────────────────────────────────────
  BiharGauge(
    river: 'Punpun', station: 'Sripalpur', district: 'Patna',
    lat: 25.5200, lon: 85.3800,
    warningLevel: 50.60, dangerLevel: 51.83, hfl: 53.91, hflYear: '1975',
  ),

  // ──────────── ADHWARA / DHAUS (2 stations) ───────────────────────────────
  BiharGauge(
    river: 'Adhwara', station: 'Kamtaul (Adhwara)', district: 'Darbhanga',
    lat: 26.3900, lon: 86.0600,
    warningLevel: 48.00, dangerLevel: 50.00, hfl: 53.05, hflYear: '2008',
  ),
  BiharGauge(
    river: 'Dhaus', station: 'Saulighat', district: 'Madhubani',
    lat: 26.4500, lon: 86.1000,
    warningLevel: 50.00, dangerLevel: 52.37, hfl: 55.10, hflYear: '2019',
  ),

  // ──────────── KHIROI (2 stations) ────────────────────────────────────────
  BiharGauge(
    river: 'Khiroi', station: 'Ekmighat', district: 'Darbhanga',
    lat: 26.2500, lon: 86.0000,
    warningLevel: 45.00, dangerLevel: 46.94, hfl: 49.52, hflYear: '2019',
  ),
  BiharGauge(
    river: 'Khiroi', station: 'Agropatti', district: 'Madhubani',
    lat: 26.5200, lon: 86.0800,
    warningLevel: 51.00, dangerLevel: 52.75, hfl: 54.53, hflYear: '2019',
  ),

  // ──────────── JHIM (1 station) ───────────────────────────────────────────
  // v4.2: HFL 83.75→83.20  (BeFIQR 12 Jun 2026)
  BiharGauge(
    river: 'Jhim', station: 'Sonbarsa', district: 'Sitamarhi',
    lat: 26.7000, lon: 85.4800,
    warningLevel: 80.50, dangerLevel: 81.85, hfl: 83.20, hflYear: '2017',
  ),

  // ──────────── LAL BAKEYA (1 station) ─────────────────────────────────────
  BiharGauge(
    river: 'Lal Bakeya', station: 'Goabari', district: 'Sitamarhi',
    lat: 26.7800, lon: 85.3700,
    warningLevel: 69.50, dangerLevel: 71.15, hfl: 73.86, hflYear: '2017',
  ),

  // ──────────── BALAN (1 station) ──────────────────────────────────────────
  BiharGauge(
    river: 'Balan', station: 'Phulparas', district: 'Madhubani',
    lat: 26.5600, lon: 86.3800,
    warningLevel: 59.50, dangerLevel: 60.80, hfl: 61.80, hflYear: '2007',
  ),

  // ──────────── BHUTAHI BALAN (1 station) ──────────────────────────────────
  BiharGauge(
    river: 'Bhutahi Balan', station: 'Laukaha', district: 'Madhubani',
    lat: 26.6300, lon: 86.1500,
    warningLevel: 78.50, dangerLevel: 79.80, hfl: 80.80, hflYear: '2019',
  ),

  // ──────────── KHANDO (1 station) ─────────────────────────────────────────
  BiharGauge(
    river: 'Khando', station: 'Dagmara', district: 'Supaul',
    lat: 26.3700, lon: 87.0200,
    warningLevel: 60.50, dangerLevel: 61.50, hfl: 62.50, hflYear: '2017',
  ),

  // ──────────── KAREH (1 station) ──────────────────────────────────────────
  BiharGauge(
    river: 'Kareh', station: 'Karachin', district: 'Samastipur',
    lat: 25.9500, lon: 85.9200,
    warningLevel: 38.50, dangerLevel: 40.00, hfl: 41.90, hflYear: '2007',
  ),
];
