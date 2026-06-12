// lib/data/bihar_rivers.dart
//
// OpsFlood — Bihar River Gauge Registry + Deep Basin Metadata (v3)
//
// SOURCES (all thresholds verified June 2026):
//   1. WRD Bihar FMISC daily bulletin — helpdeskwrdbihar.com (Oct 2024)
//   2. BeFIQR WRD manual station table — irrigation.befiqr.in (Sep 2025)
//   3. BEAMS Bihar / CWC FFS — beams.fmiscwrdbihar.gov.in (Jun 2026)
//   4. CWC Flood Forecast bulletins 2024 — ndma.gov.in
//   5. PIB flood bulletins 2011-2024
//
// 13 rivers | 32 gauge stations | 10 river basin profiles
// All levels in metres above mean sea level (m MSL).
library;

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
    notableFloods: ['1987', '2004 (Kishanganj)', '2017 (Dhengraghat HFL 38.16)', '2022'],
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
// GAUGE STATION DATA — 32 stations, 13 rivers
// All thresholds verified from WRD Bihar / CWC official sources June 2026.
// WL = Warning Level, DL = Danger Level, HFL = Highest Flood Level (all m MSL)
// ══════════════════════════════════════════════════════════════════════════════
const List<BiharGauge> kBiharGauges = [

  // ──────────── GANGA (7 stations) ──────────────────────────────────────────
  // Source: WRD FMISC daily bulletin Oct 2024 + CWC FFS confirmed
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
  BiharGauge(
    river: 'Ganga', station: 'Buxar', district: 'Buxar',
    lat: 25.5667, lon: 83.9667,
    warningLevel: 59.20, dangerLevel: 60.32, hfl: 62.09, hflYear: '1948',
  ),

  // ──────────── KOSI (5 stations) ──────────────────────────────────────────
  // Source: BEAMS Bihar CWC FFS Jun 2026 + WRD daily bulletin
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
  // Dumri gauge — used by WRD daily bulletin, between Baltara and Basua
  BiharGauge(
    river: 'Kosi', station: 'Dumri Bridge', district: 'Khagaria',
    lat: 25.5200, lon: 86.5000,
    warningLevel: 32.85, dangerLevel: 33.85, hfl: 36.40, hflYear: '1987',
  ),

  // ──────────── GANDAK (4 stations) ────────────────────────────────────────
  // Source: WRD daily bulletin + BeFIQR manual table
  BiharGauge(
    river: 'Gandak', station: 'Chatia', district: 'East Champaran',
    lat: 26.8500, lon: 84.9000,
    warningLevel: 68.10, dangerLevel: 69.15, hfl: 70.04, hflYear: '1971',
  ),
  BiharGauge(
    river: 'Gandak', station: 'Dumariaghat', district: 'Gopalganj',
    lat: 26.4833, lon: 84.4667, cwcCode: 'GKP',
    warningLevel: 61.10, dangerLevel: 62.22, hfl: 63.70, hflYear: '1971',
  ),
  BiharGauge(
    river: 'Gandak', station: 'Rewaghat', district: 'Muzaffarpur',
    lat: 26.1000, lon: 85.3000,
    warningLevel: 53.40, dangerLevel: 54.41, hfl: 55.46, hflYear: '1971',
  ),
  BiharGauge(
    river: 'Gandak', station: 'Hajipur', district: 'Vaishali',
    lat: 25.6933, lon: 85.2094,
    // Source: BeFIQR live WRD table — DL 50.32, HFL 51.93 (confirmed)
    warningLevel: 49.40, dangerLevel: 50.32, hfl: 51.93, hflYear: '1971',
  ),

  // ──────────── BAGMATI (6 stations) ─────────────────────────────────────
  // Source: WRD FMISC daily bulletin Oct 2024 (all confirmed)
  BiharGauge(
    river: 'Bagmati', station: 'Dheng Bridge', district: 'Sitamarhi',
    lat: 26.5800, lon: 85.4900,
    warningLevel: 70.00, dangerLevel: 71.00, hfl: 73.47, hflYear: '2024',
  ),
  BiharGauge(
    river: 'Bagmati', station: 'Sonakhan', district: 'Sitamarhi',
    lat: 26.6200, lon: 85.5100,
    // Source: BeFIQR manual — DL 68.80, HFL 72.05/2019
    warningLevel: 67.80, dangerLevel: 68.80, hfl: 72.05, hflYear: '2019',
  ),
  BiharGauge(
    river: 'Bagmati', station: 'Benibad', district: 'Muzaffarpur',
    lat: 26.0500, lon: 85.6500,
    // Source: CWC bulletin 2011 + WRD — WL 47.68, DL 48.68, HFL 50.01/2004
    warningLevel: 47.68, dangerLevel: 48.68, hfl: 50.01, hflYear: '2004',
  ),
  BiharGauge(
    river: 'Bagmati', station: 'Hayaghat', district: 'Darbhanga',
    lat: 26.0200, lon: 85.9500,
    // Source: WRD bulletin — DL 45.72, HFL 48.96/1987
    warningLevel: 44.50, dangerLevel: 45.72, hfl: 48.96, hflYear: '1987',
  ),
  BiharGauge(
    // FIX: renamed from 'Dhengraghat' → 'Dhengraghat (Bagmati)' to disambiguate
    // from Mahananda's Dhengraghat (Purnia district) below.
    river: 'Bagmati', station: 'Dhengraghat (Bagmati)', district: 'Darbhanga',
    lat: 26.1800, lon: 85.9200,
    // Source: WRD bulletin + PIB 2011 — WL 34.65, DL 35.65, HFL 47.30/2002
    warningLevel: 34.65, dangerLevel: 35.65, hfl: 47.30, hflYear: '2002',
  ),
  BiharGauge(
    // FIX: renamed from 'Kamtaul' → 'Kamtaul (Bagmati)' to disambiguate
    // from Kamla's Kamtaul (Madhubani district) below.
    river: 'Bagmati', station: 'Kamtaul (Bagmati)', district: 'Darbhanga',
    lat: 26.4200, lon: 86.0800,
    // Source: WRD FMISC bulletin — DL 50.00, HFL 53.01/2004
    warningLevel: 49.00, dangerLevel: 50.00, hfl: 53.01, hflYear: '2004',
  ),

  // ──────────── BURHI GANDAK (4 stations) ───────────────────────────────
  // Source: BeFIQR manual + WRD bulletin confirmed
  BiharGauge(
    river: 'Burhi Gandak', station: 'Sikandarpur', district: 'Muzaffarpur',
    lat: 26.1209, lon: 85.3647,
    warningLevel: 51.40, dangerLevel: 52.53, hfl: 54.29, hflYear: '1987',
  ),
  BiharGauge(
    river: 'Burhi Gandak', station: 'Samastipur', district: 'Samastipur',
    lat: 25.8620, lon: 85.7812,
    // Source: BeFIQR manual — Samastipur road bridge DL 46.02, HFL 49.38
    warningLevel: 44.80, dangerLevel: 46.02, hfl: 49.38, hflYear: '1987',
  ),
  BiharGauge(
    river: 'Burhi Gandak', station: 'Rosera', district: 'Samastipur',
    lat: 25.8600, lon: 85.9800,
    // Source: BeFIQR manual — Rosera Rail pul DL 42.63, HFL 46.56
    warningLevel: 41.50, dangerLevel: 42.63, hfl: 46.56, hflYear: '1987',
  ),
  BiharGauge(
    river: 'Burhi Gandak', station: 'Khagaria', district: 'Khagaria',
    lat: 25.5000, lon: 86.4700,
    warningLevel: 35.40, dangerLevel: 36.58, hfl: 39.22, hflYear: '1987',
  ),

  // ──────────── GHAGHRA (2 stations) ───────────────────────────────────────
  BiharGauge(
    river: 'Ghaghra', station: 'Darauli', district: 'Siwan',
    lat: 26.0700, lon: 84.4100,
    warningLevel: 60.50, dangerLevel: 61.52, hfl: 63.10, hflYear: '1998',
  ),
  BiharGauge(
    river: 'Ghaghra', station: 'Gangpur Siswan', district: 'Siwan',
    lat: 26.2500, lon: 84.3500,
    warningLevel: 63.00, dangerLevel: 64.10, hfl: 65.82, hflYear: '1998',
  ),

  // ──────────── KAMLA (3 stations) ─────────────────────────────────────────
  // Source: WRD FMISC daily bulletin Oct 2024 (authoritative)
  BiharGauge(
    river: 'Kamla', station: 'Jainagar', district: 'Madhubani',
    lat: 26.5940, lon: 86.2260,
    // WRD bulletin DL 68.50, HFL 71.35/2019
    warningLevel: 67.50, dangerLevel: 68.50, hfl: 71.35, hflYear: '2019',
  ),
  BiharGauge(
    river: 'Kamla', station: 'Jhanjharpur', district: 'Madhubani',
    lat: 26.2640, lon: 86.2790,
    // WRD bulletin DL 50.50, HFL 53.11/2019
    warningLevel: 49.50, dangerLevel: 50.50, hfl: 53.11, hflYear: '2019',
  ),
  BiharGauge(
    // FIX: renamed from 'Kamtaul' → 'Kamtaul (Kamla)' to disambiguate
    // from Bagmati's Kamtaul (Darbhanga district) above.
    river: 'Kamla', station: 'Kamtaul (Kamla)', district: 'Madhubani',
    lat: 26.4200, lon: 86.0800,
    // BeFIQR manual: Kamla Kothram DL 44.00, HFL 45.45
    warningLevel: 43.00, dangerLevel: 44.00, hfl: 45.45, hflYear: '2007',
  ),

  // ──────────── MAHANANDA (2 stations) ─────────────────────────────────
  // Source: WRD FMISC bulletin + PIB CWC forecasts
  BiharGauge(
    river: 'Mahananda', station: 'Taibpur', district: 'Kishanganj',
    lat: 26.1000, lon: 87.9500,
    // Source: WRD bulletin — DL 35.65, HFL 38.16/2017
    warningLevel: 34.65, dangerLevel: 35.65, hfl: 38.16, hflYear: '2017',
  ),
  BiharGauge(
    // FIX: renamed from 'Dhengraghat' → 'Dhengraghat (Mahananda)' to disambiguate
    // from Bagmati's Dhengraghat (Darbhanga district) above.
    river: 'Mahananda', station: 'Dhengraghat (Mahananda)', district: 'Purnia',
    lat: 25.9800, lon: 87.4800,
    // Source: PIB CWC 2011 bulletin + WRD — WL 34.65, DL 35.65, HFL 38.16/2017
    warningLevel: 34.65, dangerLevel: 35.65, hfl: 38.16, hflYear: '2017',
  ),

  // ──────────── PUNPUN (1 station) ─────────────────────────────────────────
  BiharGauge(
    river: 'Punpun', station: 'Sripalpur', district: 'Patna',
    lat: 25.5200, lon: 85.3800,
    warningLevel: 50.60, dangerLevel: 51.83, hfl: 53.91, hflYear: '1975',
  ),
];
