// lib/data/bihar_rivers.dart
//
// OpsFlood — Bihar River Gauge Registry + Deep Basin Metadata (v2)
//
// Sources:
//   WRD Bihar Central Flood Control Cell
//   CWC FFS:    https://beams.fmiscwrdbihar.gov.in
//   NWDA River Basin Atlas of India (2014)
//   NIH Roorkee — Kosi & Gandak basin studies
//   Bihar State Flood Control Dept Annual Reports 2022-24
//   NDMA Bihar Flood Hazard Atlas 2023
//
// 13 rivers | 31 gauge stations | 10 river basin profiles
// All levels in metres above mean sea level (m MSL).
library;

// ══════════════════════════════════════════════════════════════════════════════
// GAUGE STATION MODEL
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
// DEEP RIVER METADATA MODEL
// ══════════════════════════════════════════════════════════════════════════════
class BiharRiverMeta {
  /// Full river/basin name
  final String name;
  /// Hydrological basin name (e.g. "Ganga Basin", "Kosi Sub-basin")
  final String basinName;
  /// Origin / source description
  final String origin;
  /// Outfall — river/confluence it drains into
  final String outfall;
  /// Total length of river within Bihar state (km)
  final int lengthInBiharKm;
  /// Catchment area within Bihar (km²)
  final int catchmentKm2;
  /// Average annual discharge at Bihar outfall (m³/s)
  final int avgDischargeCumecs;
  /// Recorded peak flood discharge (m³/s)
  final int peakFloodCumecs;
  /// Year of peak flood discharge
  final String peakFloodYear;
  /// Left bank embankment length in Bihar (km)
  final double embLBankKm;
  /// Right bank embankment length in Bihar (km)
  final double embRBankKm;
  /// Major tributaries (in Bihar reach)
  final List<String> majorTributaries;
  /// Notable flood years with brief note
  final List<String> notableFloods;
  /// Is this a trans-boundary river (originates in Nepal)?
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
// DEEP METADATA — 10 RIVERS
// Source: NWDA Basin Atlas, NIH, Bihar Flood Bulletins, NDMA
// ══════════════════════════════════════════════════════════════════════════════
const Map<String, BiharRiverMeta> kBiharRiverMeta = {

  // ── 1. GANGA ───────────────────────────────────────────────────────────────
  // Bihar reach: Buxar (entry) → Colgong/Bhagalpur (exit) — ~445 km
  // Catchment in Bihar ~16,900 km² of direct draining area.
  // Peak discharge: 84,000 m³/s recorded at Farakka in 1978.
  // Total embankments in Bihar: 3,421 km (L+R both banks).
  'ganga': BiharRiverMeta(
    name: 'Ganga', basinName: 'Ganga Main Stem',
    origin: 'Gangotri Glacier, Uttarakhand (3,892 m)',
    outfall: 'Bay of Bengal via Bangladesh',
    lengthInBiharKm: 445,
    catchmentKm2: 16900,
    avgDischargeCumecs: 11500,
    peakFloodCumecs: 84000,
    peakFloodYear: '1978',
    embLBankKm: 1680.0, embRBankKm: 1741.0,
    majorTributaries: ['Gandak', 'Sone', 'Punpun', 'Ghaghra', 'Kosi'],
    notableFloods: ['1978 (highest discharge)', '1987 (Patna breach)', '1994 (Patna HFL 50.52 m)', '2016', '2019'],
    transBoundary: false,
  ),

  // ── 2. KOSI ────────────────────────────────────────────────────────────────
  // Known as "Sorrow of Bihar". Originates in Tibet/Nepal Himalaya.
  // Enters Bihar at Bhimnagar (Supaul) from Nepal after Kosi Barrage.
  // Notorious for lateral channel migration — shifted ~113 km westward in 250 yrs.
  // 2008 breach at Kusaha (Nepal) caused catastrophic flooding in 5 Bihar districts.
  // Catchment: 69,300 km² (mostly Nepal & Tibet); Bihar portion ~11,410 km².
  'kosi': BiharRiverMeta(
    name: 'Kosi', basinName: 'Kosi Sub-basin',
    origin: 'Gosainthan / Sun Kosi confluence, Tibet–Nepal border (>4,000 m)',
    outfall: 'Ganga at Kursela, Katihar district',
    lengthInBiharKm: 260,
    catchmentKm2: 11410,
    avgDischargeCumecs: 2166,
    peakFloodCumecs: 24200,
    peakFloodYear: '1968',
    embLBankKm: 158.0, embRBankKm: 128.5,
    majorTributaries: ['Sun Kosi', 'Tama Kosi', 'Dudh Kosi', 'Arun', 'Tamor'],
    notableFloods: ['1968 (peak 24,200 m³/s)', '1987 (mass embankment breach)', '2008 (Kusaha breach, 527 km² inundated)', '2017', '2020', '2024'],
    transBoundary: true,
  ),

  // ── 3. GANDAK (Narayani) ───────────────────────────────────────────────────
  // Originates in Tibet as Kali Gandaki; enters Bihar after Gandak Barrage (Valmiki Nagar).
  // Drains W Champaran, Gopalganj, Muzaffarpur, Vaishali before meeting Ganga at Hajipur.
  // Catchment: 46,300 km² total; ~8,800 km² in Bihar.
  'gandak': BiharRiverMeta(
    name: 'Gandak', basinName: 'Gandak Sub-basin',
    origin: 'Mustang district, Nepal / Tibet border (~5,500 m)',
    outfall: 'Ganga at Hajipur, Vaishali district',
    lengthInBiharKm: 260,
    catchmentKm2: 8800,
    avgDischargeCumecs: 1654,
    peakFloodCumecs: 23200,
    peakFloodYear: '1971',
    embLBankKm: 279.0, embRBankKm: 170.0,
    majorTributaries: ['Trishuli', 'Burhi Gandak (upper)', 'Masan', 'Sikrahna'],
    notableFloods: ['1971 (peak 23,200 m³/s)', '1978', '1998 (Bagaha breach)', '2007', '2021'],
    transBoundary: true,
  ),

  // ── 4. BAGMATI ─────────────────────────────────────────────────────────────
  // Rises in Shivapuri Hills near Kathmandu (1,400 m); enters Bihar at Dheng Bridge (Sitamarhi).
  // Flows through Sitamarhi → Muzaffarpur → Darbhanga → Samastipur before joining Ganga.
  // Bihar catchment ~10,800 km². Highly flood-prone due to heavy Nepal monsoon.
  'bagmati': BiharRiverMeta(
    name: 'Bagmati', basinName: 'Bagmati Sub-basin',
    origin: 'Shivapuri Hills, Kathmandu Valley, Nepal (1,400 m)',
    outfall: 'Kosi/Ganga confluence near Kursela (via Adhwara)
  — some channels join Kamla Balan',
    lengthInBiharKm: 394,
    catchmentKm2: 10800,
    avgDischargeCumecs: 488,
    peakFloodCumecs: 9100,
    peakFloodYear: '2002',
    embLBankKm: 262.0, embRBankKm: 189.0,
    majorTributaries: ['Lalbakeya', 'Lakhandei', 'Masan', 'Tilawe'],
    notableFloods: ['1987', '2002 (catastrophic Sitamarhi breach)', '2007', '2017 (record HFL Dheng 73.47 m in 2024)'],
    transBoundary: true,
  ),

  // ── 5. BURHI GANDAK ────────────────────────────────────────────────────────
  // Entirely within Bihar — originates in W. Champaran Siwalik foothills.
  // Flows 320 km through Muzaffarpur, Samastipur, Khagaria before joining Ganga.
  // Catchment ~13,000 km². Major flood risk for Muzaffarpur city.
  'burhi gandak': BiharRiverMeta(
    name: 'Burhi Gandak', basinName: 'Burhi Gandak Basin',
    origin: 'Siwalik Hills, West Champaran (~300 m)',
    outfall: 'Ganga near Khagaria district',
    lengthInBiharKm: 320,
    catchmentKm2: 13000,
    avgDischargeCumecs: 350,
    peakFloodCumecs: 5600,
    peakFloodYear: '1987',
    embLBankKm: 198.0, embRBankKm: 174.0,
    majorTributaries: ['Tiyar', 'Pandai', 'Dhanauti', 'Tilawe'],
    notableFloods: ['1975', '1987 (peak discharge, Muzaffarpur inundated)', '2007', '2016', '2022'],
    transBoundary: false,
  ),

  // ── 6. GHAGHRA (Saryu / Karnali) ───────────────────────────────────────────
  // Enters Bihar from UP through Siwan district. Only a short stretch (~80 km) in Bihar
  // before meeting Ganga near Revelganj (Saran). Catchment in Bihar ~4,290 km².
  'ghaghra': BiharRiverMeta(
    name: 'Ghaghra', basinName: 'Ghaghra Sub-basin',
    origin: 'Gurla Mandhata glacier, Tibet (>5,000 m) — as Karnali/Narayani',
    outfall: 'Ganga at Revelganj / Chhapra, Saran district',
    lengthInBiharKm: 83,
    catchmentKm2: 4290,
    avgDischargeCumecs: 2900,
    peakFloodCumecs: 35700,
    peakFloodYear: '1998',
    embLBankKm: 92.0, embRBankKm: 64.0,
    majorTributaries: ['Chhoti Gandak (UP)', 'Rapti (UP)'],
    notableFloods: ['1998 (Siwan–Saran breach)', '2007', '2013'],
    transBoundary: true,
  ),

  // ── 7. MAHANANDA ───────────────────────────────────────────────────────────
  // Originates in Darjeeling Himalayas; flows through Kishanganj & Purnia before
  // joining Ganga in West Bengal. Drains Bihar's extreme east / Seemanchal region.
  // Highly flood-vulnerable — narrow valley, heavy monsoonal rainfall (>2,000 mm/yr).
  'mahananda': BiharRiverMeta(
    name: 'Mahananda', basinName: 'Mahananda Sub-basin',
    origin: 'Mahaldiram Hills, Darjeeling district (~2,100 m)',
    outfall: 'Ganga at Manihari, Katihar (in West Bengal border zone)',
    lengthInBiharKm: 165,
    catchmentKm2: 6150,
    avgDischargeCumecs: 490,
    peakFloodCumecs: 6290,
    peakFloodYear: '1987',
    embLBankKm: 143.0, embRBankKm: 97.0,
    majorTributaries: ['Kankai', 'Mechi', 'Balan', 'Trishna'],
    notableFloods: ['1987', '2004 (Kishanganj)', '2017 (Taibpur HFL)', '2022'],
    transBoundary: false,
  ),

  // ── 8. KAMLA-BALAN ─────────────────────────────────────────────────────────
  // Enters Bihar from Nepal at Jainagar (Madhubani). Flows through Madhubani and
  // Darbhanga before merging with Balan river to form Kamla Balan.
  // Nepal monsoonal peak causes rapid flash-flood conditions in Terai zone.
  'kamla': BiharRiverMeta(
    name: 'Kamla', basinName: 'Kamla-Balan Sub-basin',
    origin: 'Mahabharat Range, Sindhuli district, Nepal (~2,000 m)',
    outfall: 'Kosi near Jhanjharpur / Darbhanga via Balan confluence',
    lengthInBiharKm: 148,
    catchmentKm2: 7620,
    avgDischargeCumecs: 310,
    peakFloodCumecs: 5080,
    peakFloodYear: '2007',
    embLBankKm: 120.0, embRBankKm: 80.0,
    majorTributaries: ['Balan', 'Bhutahi Balan', 'Tilawe'],
    notableFloods: ['1987', '2007 (record HFL Jainagar)', '2017', '2021'],
    transBoundary: true,
  ),

  // ── 9. ADHWARA GROUP ────────────────────────────────────────────────────────
  // A network of small rivers (Adhwara, Khiroi, Jamuane, Basua) draining N Mithila.
  // Originate in Nepal Terai / Siwalik foothills. Highly braided, frequently change course.
  // Join Bagmati or Kosi in lower reaches. Bihar catchment ~4,700 km².
  'adhwara': BiharRiverMeta(
    name: 'Adhwara', basinName: 'Adhwara Group Basin',
    origin: 'Nepal Terai / Siwalik foothills (~200–400 m)',
    outfall: 'Bagmati / Kosi via lower Darbhanga channels',
    lengthInBiharKm: 210,
    catchmentKm2: 4700,
    avgDischargeCumecs: 120,
    peakFloodCumecs: 2800,
    peakFloodYear: '2008',
    embLBankKm: 88.0, embRBankKm: 65.0,
    majorTributaries: ['Khiroi', 'Jamuane', 'Basua', 'Tilawe'],
    notableFloods: ['2004', '2007 (Darbhanga inundation)', '2008', '2019'],
    transBoundary: true,
  ),

  // ── 10. PUNPUN ──────────────────────────────────────────────────────────────
  // Originates in Palamu (Jharkhand). Flows through Gaya, Aurangabad, Nalanda,
  // Patna before joining Ganga south of Patna at Fatuha/Sripalpur.
  // Entirely within Bihar-Jharkhand; carries significant Jharkhand plateau runoff.
  'punpun': BiharRiverMeta(
    name: 'Punpun', basinName: 'Punpun Basin',
    origin: 'Palamu plateau, Jharkhand (~500 m)',
    outfall: 'Ganga at Fatuha, Patna district',
    lengthInBiharKm: 200,
    catchmentKm2: 8970,
    avgDischargeCumecs: 145,
    peakFloodCumecs: 7200,
    peakFloodYear: '1975',
    embLBankKm: 68.0, embRBankKm: 52.0,
    majorTributaries: ['Morhar', 'Phalgu', 'Dardha', 'Safi'],
    notableFloods: ['1975 (record HFL 53.91 m at Sripalpur)', '1987', '2016 (Patna south flooding)', '2019'],
    transBoundary: false,
  ),
};

// ══════════════════════════════════════════════════════════════════════════════
// GAUGE STATION DATA — 31 stations, 13 rivers
// ══════════════════════════════════════════════════════════════════════════════
const List<BiharGauge> kBiharGauges = [

  // ── 1. GANGA ────────────────────────────────────────────────────────────────
  BiharGauge(
    river: 'Ganga', station: 'Gandhighat', district: 'Patna',
    lat: 25.6129, lon: 85.1376, cwcCode: 'PAT',
    warningLevel: 47.50, dangerLevel: 48.60, hfl: 50.52, hflYear: '1994',
  ),
  BiharGauge(
    river: 'Ganga', station: 'Dighaghat', district: 'Patna',
    lat: 25.5941, lon: 85.0700,
    warningLevel: 49.30, dangerLevel: 50.45, hfl: 52.52, hflYear: '1994',
  ),
  BiharGauge(
    river: 'Ganga', station: 'Hathidah', district: 'Patna',
    lat: 25.4167, lon: 85.7500,
    warningLevel: 40.50, dangerLevel: 41.76, hfl: 43.52, hflYear: '1994',
  ),
  BiharGauge(
    river: 'Ganga', station: 'Munger', district: 'Munger',
    lat: 25.3743, lon: 86.4730,
    warningLevel: 38.20, dangerLevel: 39.33, hfl: 40.99, hflYear: '1987',
  ),
  BiharGauge(
    river: 'Ganga', station: 'Kahalgaon', district: 'Bhagalpur',
    lat: 25.2167, lon: 87.2667,
    warningLevel: 30.00, dangerLevel: 31.09, hfl: 32.87, hflYear: '1987',
  ),
  BiharGauge(
    river: 'Ganga', station: 'Bhagalpur', district: 'Bhagalpur',
    lat: 25.2425, lon: 86.9842, cwcCode: 'BHP',
    warningLevel: 32.50, dangerLevel: 33.68, hfl: 34.86, hflYear: '1987',
  ),
  BiharGauge(
    river: 'Ganga', station: 'Buxar', district: 'Buxar',
    lat: 25.5667, lon: 83.9667,
    warningLevel: 59.20, dangerLevel: 60.30, hfl: 62.10, hflYear: '1994',
  ),

  // ── 2. KOSI ─────────────────────────────────────────────────────────────────
  BiharGauge(
    river: 'Kosi', station: 'Birpur (CWC)', district: 'Supaul',
    lat: 26.5167, lon: 86.9000, cwcCode: 'BIR',
    warningLevel: 73.70, dangerLevel: 74.70, hfl: 76.02, hflYear: '2008',
  ),
  BiharGauge(
    river: 'Kosi', station: 'Baltara', district: 'Khagaria',
    lat: 25.5000, lon: 86.5833,
    warningLevel: 32.85, dangerLevel: 33.85, hfl: 36.40, hflYear: '2008',
  ),
  BiharGauge(
    river: 'Kosi', station: 'Basua', district: 'Supaul',
    lat: 26.1234, lon: 86.6020, cwcCode: 'SUP',
    warningLevel: 46.50, dangerLevel: 47.75, hfl: 49.24, hflYear: '2008',
  ),
  BiharGauge(
    river: 'Kosi', station: 'Kursela', district: 'Katihar',
    lat: 25.4800, lon: 87.2600, cwcCode: 'KAT',
    warningLevel: 28.80, dangerLevel: 30.00, hfl: 32.10, hflYear: '2008',
  ),

  // ── 3. GANDAK ───────────────────────────────────────────────────────────────
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
    warningLevel: 49.40, dangerLevel: 50.32, hfl: 50.93, hflYear: '1971',
  ),

  // ── 4. BAGMATI ──────────────────────────────────────────────────────────────
  BiharGauge(
    river: 'Bagmati', station: 'Dheng Bridge', district: 'Sitamarhi',
    lat: 26.5800, lon: 85.4900,
    warningLevel: 70.00, dangerLevel: 71.00, hfl: 73.47, hflYear: '2024',
  ),
  BiharGauge(
    river: 'Bagmati', station: 'Benibad', district: 'Muzaffarpur',
    lat: 26.0500, lon: 85.6500,
    warningLevel: 47.68, dangerLevel: 48.68, hfl: 50.01, hflYear: '2002',
  ),
  BiharGauge(
    river: 'Bagmati', station: 'Hayaghat', district: 'Darbhanga',
    lat: 26.0200, lon: 85.9500,
    warningLevel: 44.50, dangerLevel: 45.72, hfl: 48.96, hflYear: '2007',
  ),

  // ── 5. BURHI GANDAK ─────────────────────────────────────────────────────────
  BiharGauge(
    river: 'Burhi Gandak', station: 'Sikandarpur', district: 'Muzaffarpur',
    lat: 26.1209, lon: 85.3647,
    warningLevel: 51.40, dangerLevel: 52.53, hfl: 54.29, hflYear: '1987',
  ),
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

  // ── 6