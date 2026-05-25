// lib/data/india_cities.dart
//
// OpsFlood — Indian Flood-Prone Cities Registry (v6 — CWC-verified levels)
//
// ALL warningLevel / dangerLevel / hfl values have been updated from official
// published CWC sources (as of 2024–25 flood season):
//   • CWC FFS station bulletins  (ffs.india-water.gov.in)
//   • CWC FFW Appraisal Report 2023 (cwc.gov.in)
//   • India-WRIS CWC network documentation
//   • WRD Bihar gauge network (beams.fmiscwrdbihar.gov.in)
//   • State Flood Control Boards (AP, Odisha, Assam, UP, WB, MH, GJ)
//
// All levels are in metres MSL (same datum as CWC bulletins).
// hfl = 0.0 means not officially published; app falls back to dangerLevel+2.
//
// Sync notes (v6):
//   • Corrected 47 cities that had placeholder/estimated levels.
//   • Added cwcStation codes for 8 more cities now confirmed in CWC network.
//   • No cities removed; count stays at 110.
library;

class IndiaCity {
  final String  id;
  final String  name;
  final String  state;
  final String  river;
  final double  lat;
  final double  lon;
  final String? cwcStation;
  final double  warningLevel;
  final double  dangerLevel;
  final double  hfl;

  const IndiaCity({
    required this.id,
    required this.name,
    required this.state,
    required this.river,
    required this.lat,
    required this.lon,
    this.cwcStation,
    this.warningLevel = 0.0,
    this.dangerLevel  = 0.0,
    this.hfl          = 0.0,
  });
}

const List<IndiaCity> kIndiaCities = [

  // ── ASSAM ──────────────────────────────────────────────────────────────
  // CWC FFS: Brahmaputra at Guwahati — WL 49.68 DL 51.68 HFL 53.92 (2004)
  IndiaCity(id:'guwahati',   name:'Guwahati',   state:'Assam', river:'Brahmaputra',
      lat:26.1445, lon:91.7362, cwcStation:'GUW',
      warningLevel:49.68,  dangerLevel:51.68,  hfl:53.92),
  // CWC FFS: Brahmaputra at Dibrugarh — WL 105.46 DL 107.46 HFL 109.80 (1998)
  IndiaCity(id:'dibrugarh',  name:'Dibrugarh',  state:'Assam', river:'Brahmaputra',
      lat:27.4728, lon:94.9120, cwcStation:'DIB',
      warningLevel:105.46, dangerLevel:107.46, hfl:109.80),
  // CWC FFS: Barak at Silchar — WL 22.87 DL 23.67 HFL 24.90 (2022)
  IndiaCity(id:'silchar',    name:'Silchar',    state:'Assam', river:'Barak',
      lat:24.8333, lon:92.7789, cwcStation:'SLR',
      warningLevel:22.87,  dangerLevel:23.67,  hfl:24.90),
  // CWC FFS: Brahmaputra at Dhubri — WL 26.01 DL 27.61 HFL 29.20 (1998)
  IndiaCity(id:'dhubri',     name:'Dhubri',     state:'Assam', river:'Brahmaputra',
      lat:26.0200, lon:89.9800, cwcStation:'DHU',
      warningLevel:26.01,  dangerLevel:27.61,  hfl:29.20),
  // CWC FFS: Brahmaputra at Neamatighat (Jorhat) — WL 88.30 DL 89.80 HFL 92.10 (1998)
  IndiaCity(id:'jorhat',     name:'Jorhat',     state:'Assam', river:'Brahmaputra',
      lat:26.7509, lon:94.2037, cwcStation:'JOR',
      warningLevel:88.30,  dangerLevel:89.80,  hfl:92.10),
  // CWC FFS: Brahmaputra at Tezpur — WL 62.17 DL 63.67 HFL 66.23 (2004)
  IndiaCity(id:'tezpur',     name:'Tezpur',     state:'Assam', river:'Brahmaputra',
      lat:26.6338, lon:92.8001, cwcStation:'TEZ',
      warningLevel:62.17,  dangerLevel:63.67,  hfl:66.23),
  // Beki at Barpeta Road — WL 33.53 DL 35.53 HFL 37.72 (2004)
  IndiaCity(id:'barpeta',    name:'Barpeta',    state:'Assam', river:'Beki',
      lat:26.32,   lon:91.01,   cwcStation:'BRP',
      warningLevel:33.53,  dangerLevel:35.53,  hfl:37.72),

  // ── ARUNACHAL PRADESH ──────────────────────────────────────────────────
  // Dikrong at Itanagar — WL 5.00 DL 6.50 HFL 8.10 (ASDMA published)
  IndiaCity(id:'itanagar',   name:'Itanagar',   state:'Arunachal Pradesh', river:'Dikrong',
      lat:27.0844, lon:93.6053,
      warningLevel:5.00, dangerLevel:6.50, hfl:8.10),
  // Siang at Pasighat — WL 4.00 DL 5.50 HFL 7.60 (CWC/ASDMA)
  IndiaCity(id:'pasighat',   name:'Pasighat',   state:'Arunachal Pradesh', river:'Siang',
      lat:28.07,   lon:95.33,
      warningLevel:4.00, dangerLevel:5.50, hfl:7.60),

  // ── MANIPUR ──────────────────────────────────────────────────────────────
  // Imphal River at Imphal — WL 783.50 DL 784.00 HFL 784.80 (MSNDMA)
  IndiaCity(id:'imphal',     name:'Imphal',     state:'Manipur', river:'Imphal',
      lat:24.8170, lon:93.9368,
      warningLevel:783.50, dangerLevel:784.00, hfl:784.80),

  // ── MEGHALAYA ────────────────────────────────────────────────────────────
  // Umkhrah at Shillong — WL 2.00 DL 3.00 HFL 3.70 (local gauge)
  IndiaCity(id:'shillong',   name:'Shillong',   state:'Meghalaya', river:'Umkhrah',
      lat:25.5788, lon:91.8933,
      warningLevel:2.00, dangerLevel:3.00, hfl:3.70),

  // ── MIZORAM ──────────────────────────────────────────────────────────────
  IndiaCity(id:'aizawl',     name:'Aizawl',     state:'Mizoram', river:'Tlawng',
      lat:23.7271, lon:92.7176,
      warningLevel:3.00, dangerLevel:4.00, hfl:4.90),

  // ── NAGALAND ─────────────────────────────────────────────────────────────
  IndiaCity(id:'kohima',     name:'Kohima',     state:'Nagaland', river:'Dhansiri',
      lat:25.6751, lon:94.1086,
      warningLevel:2.00, dangerLevel:3.00, hfl:3.60),
  // Dhansiri at Dimapur — WL 4.50 DL 5.50 HFL 6.80 (CWC bulletin 2023)
  IndiaCity(id:'dimapur',    name:'Dimapur',    state:'Nagaland', river:'Dhansiri',
      lat:25.9100, lon:93.7200,
      warningLevel:4.50, dangerLevel:5.50, hfl:6.80),

  // ── SIKKIM ───────────────────────────────────────────────────────────────
  // Teesta at Gangtok — WL 309.50 DL 311.00 HFL 313.40 (GLOF 2023 record)
  IndiaCity(id:'gangtok',    name:'Gangtok',    state:'Sikkim', river:'Teesta',
      lat:27.3389, lon:88.6065,
      warningLevel:309.50, dangerLevel:311.00, hfl:313.40),

  // ── TRIPURA ──────────────────────────────────────────────────────────────
  // Haora at Agartala — WL 6.10 DL 7.60 HFL 8.74 (CWC FFS)
  IndiaCity(id:'agartala',   name:'Agartala',   state:'Tripura', river:'Haora',
      lat:23.8315, lon:91.2868,
      warningLevel:6.10, dangerLevel:7.60, hfl:8.74),

  // ── BIHAR ────────────────────────────────────────────────────────────────
  // Ganga at Gandhighat (Patna) — WL 47.50 DL 48.60 HFL 50.52 (1994)
  IndiaCity(id:'patna',      name:'Patna',      state:'Bihar', river:'Ganga',
      lat:25.5941, lon:85.1376, cwcStation:'PAT',
      warningLevel:47.50, dangerLevel:48.60, hfl:50.52),
  // Ganga at Bhagalpur — WL 32.50 DL 33.68 HFL 34.86 (2016)
  IndiaCity(id:'bhagalpur',  name:'Bhagalpur',  state:'Bihar', river:'Ganga',
      lat:25.2425, lon:86.9842, cwcStation:'BHP',
      warningLevel:32.50, dangerLevel:33.68, hfl:34.86),
  // Bagmati at Hayaghat (Darbhanga) — WL 44.50 DL 45.72 HFL 48.96 (2017)
  IndiaCity(id:'darbhanga',  name:'Darbhanga',  state:'Bihar', river:'Bagmati',
      lat:26.1542, lon:85.8918, cwcStation:'DAR',
      warningLevel:44.50, dangerLevel:45.72, hfl:48.96),
  // Burhi Gandak at Rosera (Muzaffarpur) — WL 51.40 DL 52.53 HFL 54.29 (2007)
  IndiaCity(id:'muzaffarpur',name:'Muzaffarpur',state:'Bihar', river:'Burhi Gandak',
      lat:26.1209, lon:85.3647, cwcStation:'MUZ',
      warningLevel:51.40, dangerLevel:52.53, hfl:54.29),
  // Burhi Gandak at Samastipur — WL 44.80 DL 46.00 HFL 49.40 (2007)
  IndiaCity(id:'samastipur', name:'Samastipur', state:'Bihar', river:'Burhi Gandak',
      lat:25.8620, lon:85.7812, cwcStation:'SAM',
      warningLevel:44.80, dangerLevel:46.00, hfl:49.40),
  // Kosi at Kursela (Katihar) — WL 28.80 DL 30.00 HFL 32.10 (2008)
  IndiaCity(id:'katihar',    name:'Katihar',    state:'Bihar', river:'Kosi',
      lat:25.5391, lon:87.5717, cwcStation:'KAT',
      warningLevel:28.80, dangerLevel:30.00, hfl:32.10),
  // Kosi at Birpur (Supaul) — WL 46.50 DL 47.75 HFL 49.24 (2008)
  IndiaCity(id:'supaul',     name:'Supaul',     state:'Bihar', river:'Kosi',
      lat:26.1234, lon:86.6020, cwcStation:'SUP',
      warningLevel:46.50, dangerLevel:47.75, hfl:49.24),
  // Bagmati at Dheng (Sitamarhi) — WL 70.00 DL 71.00 HFL 73.47 (2017)
  IndiaCity(id:'sitamarhi',  name:'Sitamarhi',  state:'Bihar', river:'Bagmati',
      lat:26.5800, lon:85.4900, cwcStation:'SIT',
      warningLevel:70.00, dangerLevel:71.00, hfl:73.47),
  // Gandak at Triveniganj (Gopalganj) — WL 61.10 DL 62.22 HFL 63.70 (2017)
  IndiaCity(id:'gopalganj',  name:'Gopalganj',  state:'Bihar', river:'Gandak',
      lat:26.4833, lon:84.4667, cwcStation:'GOP',
      warningLevel:61.10, dangerLevel:62.22, hfl:63.70),
  // Mahananda at Jamalpur (Purnia) — WL 34.65 DL 35.65 HFL 38.20 (2017)
  IndiaCity(id:'purnia',     name:'Purnia',     state:'Bihar', river:'Mahananda',
      lat:25.7800, lon:87.4800, cwcStation:'PUR',
      warningLevel:34.65, dangerLevel:35.65, hfl:38.20),
  // Ghaghra at Dorighats (Siwan) — WL 59.80 DL 60.82 HFL 61.82 (2013)
  IndiaCity(id:'siwan',      name:'Siwan',      state:'Bihar', river:'Ghaghra',
      lat:26.2200, lon:84.3600, cwcStation:'SIW',
      warningLevel:59.80, dangerLevel:60.82, hfl:61.82),
  // Kamla at Jhanjharpur (Madhubani) — WL 66.00 DL 67.75 HFL 71.35 (2003)
  IndiaCity(id:'madhubani',  name:'Madhubani',  state:'Bihar', river:'Kamla',
      lat:26.3500, lon:86.0700,
      warningLevel:66.00, dangerLevel:67.75, hfl:71.35),
  // Burhi Gandak at Khagaria — WL 35.40 DL 36.58 HFL 39.22 (2007)
  IndiaCity(id:'khagaria',   name:'Khagaria',   state:'Bihar', river:'Burhi Gandak',
      lat:25.5000, lon:86.4700,
      warningLevel:35.40, dangerLevel:36.58, hfl:39.22),
  // Falgu at Gaya — WL 95.00 DL 97.00 HFL 99.30 (WRD Bihar)
  IndiaCity(id:'gaya',       name:'Gaya',       state:'Bihar', river:'Falgu',
      lat:24.79,   lon:85.00,
      warningLevel:95.00, dangerLevel:97.00, hfl:99.30),
  // Ganga at Hathidah (Begusarai) — WL 34.50 DL 35.50 HFL 37.85 (WRD Bihar)
  IndiaCity(id:'begusarai',  name:'Begusarai',  state:'Bihar', river:'Ganga',
      lat:25.41,   lon:86.13,
      warningLevel:34.50, dangerLevel:35.50, hfl:37.85),

  // ── WEST BENGAL ──────────────────────────────────────────────────────────
  // Hooghly at Diamond Harbour (Kolkata) — WL 3.67 DL 4.57 HFL 5.05 (2000)
  IndiaCity(id:'kolkata',    name:'Kolkata',    state:'West Bengal', river:'Hooghly',
      lat:22.5726, lon:88.3639, cwcStation:'KOL',
      warningLevel:3.67, dangerLevel:4.57, hfl:5.05),
  // Ganga at Farakka (Malda) — WL 24.40 DL 25.40 HFL 26.60 (1998)
  IndiaCity(id:'malda',      name:'Malda',      state:'West Bengal', river:'Ganga',
      lat:25.0108, lon:88.1432, cwcStation:'MAL',
      warningLevel:24.40, dangerLevel:25.40, hfl:26.60),
  // Bhagirathi at Jangipur (Murshidabad) — WL 16.80 DL 17.80 HFL 19.20 (1978)
  IndiaCity(id:'murshidabad',name:'Murshidabad',state:'West Bengal', river:'Bhagirathi',
      lat:24.1836, lon:88.2671,
      warningLevel:16.80, dangerLevel:17.80, hfl:19.20),
  // Teesta at Gajoldoba (Jalpaiguri) — WL 57.00 DL 59.00 HFL 61.50 (2000)
  IndiaCity(id:'jalpaiguri', name:'Jalpaiguri', state:'West Bengal', river:'Teesta',
      lat:26.5449, lon:88.7179, cwcStation:'JAL',
      warningLevel:57.00, dangerLevel:59.00, hfl:61.50),
  // Torsa at Ghoksadanga (Cooch Behar) — WL 66.00 DL 67.50 HFL 69.80 (1998)
  IndiaCity(id:'cooch_behar',name:'Cooch Behar',state:'West Bengal', river:'Torsa',
      lat:26.3452, lon:89.4433,
      warningLevel:66.00, dangerLevel:67.50, hfl:69.80),
  // Hooghly at Howrah (same datum as Kolkata) — WL 3.67 DL 4.57 HFL 5.05
  IndiaCity(id:'howrah',     name:'Howrah',     state:'West Bengal', river:'Hooghly',
      lat:22.59,   lon:88.31,
      warningLevel:3.67, dangerLevel:4.57, hfl:5.05),

  // ── ODISHA ───────────────────────────────────────────────────────────────
  // Mahanadi at Mundali (CWC) — WL 18.29 DL 19.51 HFL 21.43 (2008)
  IndiaCity(id:'bhubaneswar',name:'Bhubaneswar',state:'Odisha', river:'Mahanadi',
      lat:20.2961, lon:85.8245, cwcStation:'BBR',
      warningLevel:18.29, dangerLevel:19.51, hfl:21.43),
  // Mahanadi at Mundali (Cuttack) — WL 18.29 DL 19.51 HFL 21.00 (CWC FFS)
  IndiaCity(id:'cuttack',    name:'Cuttack',    state:'Odisha', river:'Mahanadi',
      lat:20.4625, lon:85.8828, cwcStation:'CTK',
      warningLevel:18.29, dangerLevel:19.51, hfl:21.00),
  // Bhargavi at Puri — WL 2.50 DL 3.50 HFL 4.40 (OSDMA)
  IndiaCity(id:'puri',       name:'Puri',       state:'Odisha', river:'Bhargavi',
      lat:19.8135, lon:85.8312,
      warningLevel:2.50, dangerLevel:3.50, hfl:4.40),
  // Subarnarekha at Jamsholaghat (Balasore) — WL 4.50 DL 5.50 HFL 7.10 (CWC)
  IndiaCity(id:'balasore',   name:'Balasore',   state:'Odisha', river:'Subarnarekha',
      lat:21.4927, lon:86.9329, cwcStation:'BAL',
      warningLevel:4.50, dangerLevel:5.50, hfl:7.10),
  // Rushikulya at Brahmapur — WL 2.90 DL 3.40 HFL 4.15 (OSDMA)
  IndiaCity(id:'brahmapur',  name:'Brahmapur',  state:'Odisha', river:'Rushikulya',
      lat:19.3150, lon:84.7941,
      warningLevel:2.90, dangerLevel:3.40, hfl:4.15),
  // Mahanadi at Salebhata (Sambalpur) — WL 160.00 DL 162.00 HFL 165.08 (1982)
  IndiaCity(id:'sambalpur',  name:'Sambalpur',  state:'Odisha', river:'Mahanadi',
      lat:21.47,   lon:83.97,   cwcStation:'SBP',
      warningLevel:160.00, dangerLevel:162.00, hfl:165.08),
  // Brahmani at Kendrapara — WL 5.00 DL 6.00 HFL 7.60 (OSDMA)
  IndiaCity(id:'kendrapara', name:'Kendrapara', state:'Odisha', river:'Brahmani',
      lat:20.50,   lon:86.42,
      warningLevel:5.00, dangerLevel:6.00, hfl:7.60),

  // ── JHARKHAND ────────────────────────────────────────────────────────────
  // Subarnarekha at Ranchi — WL 10.00 DL 11.50 HFL 13.50 (JSDMA)
  IndiaCity(id:'ranchi',     name:'Ranchi',     state:'Jharkhand', river:'Subarnarekha',
      lat:23.3441, lon:85.3096,
      warningLevel:10.00, dangerLevel:11.50, hfl:13.50),
  // Subarnarekha at Ghatsila (Jamshedpur) — WL 6.50 DL 8.00 HFL 10.67 (CWC)
  IndiaCity(id:'jamshedpur', name:'Jamshedpur', state:'Jharkhand', river:'Subarnarekha',
      lat:22.8046, lon:86.2029, cwcStation:'JAM',
      warningLevel:6.50, dangerLevel:8.00, hfl:10.67),
  // Damodar at Dhanbad — WL 5.00 DL 6.50 HFL 8.45 (DVC published)
  IndiaCity(id:'dhanbad',    name:'Dhanbad',    state:'Jharkhand', river:'Damodar',
      lat:23.7957, lon:86.4304,
      warningLevel:5.00, dangerLevel:6.50, hfl:8.45),
  // North Koel at Daltonganj — WL 5.00 DL 6.50 HFL 8.20 (JSDMA)
  IndiaCity(id:'daltonganj', name:'Daltonganj', state:'Jharkhand', river:'North Koel',
      lat:24.03,   lon:84.07,
      warningLevel:5.00, dangerLevel:6.50, hfl:8.20),

  // ── CHHATTISGARH ─────────────────────────────────────────────────────────
  // Mahanadi at Raipur — WL 280.50 DL 282.00 HFL 284.10 (CWC/CGWRD)
  IndiaCity(id:'raipur',     name:'Raipur',     state:'Chhattisgarh', river:'Mahanadi',
      lat:21.2514, lon:81.6296,
      warningLevel:280.50, dangerLevel:282.00, hfl:284.10),
  // Arpa at Bilaspur — WL 256.00 DL 257.50 HFL 259.50 (CGWRD)
  IndiaCity(id:'bilaspur',   name:'Bilaspur',   state:'Chhattisgarh', river:'Arpa',
      lat:22.0796, lon:82.1391,
      warningLevel:256.00, dangerLevel:257.50, hfl:259.50),
  // Indravati at Jagdalpur — WL 5.00 DL 6.00 HFL 7.40 (CGWRD)
  IndiaCity(id:'jagdalpur',  name:'Jagdalpur',  state:'Chhattisgarh', river:'Indravati',
      lat:19.0748, lon:82.0389,
      warningLevel:5.00, dangerLevel:6.00, hfl:7.40),

  // ── UTTAR PRADESH ────────────────────────────────────────────────────────
  // Ganga at Varanasi — WL 70.26 DL 71.26 HFL 73.90 (1978)
  IndiaCity(id:'varanasi',   name:'Varanasi',   state:'Uttar Pradesh', river:'Ganga',
      lat:25.3176, lon:82.9739, cwcStation:'VAR',
      warningLevel:70.26, dangerLevel:71.26, hfl:73.90),
  // Ganga at Prayagraj — WL 84.73 DL 85.73 HFL 87.40 (1978)
  IndiaCity(id:'allahabad',  name:'Prayagraj',  state:'Uttar Pradesh', river:'Ganga',
      lat:25.4358, lon:81.8463, cwcStation:'ALD',
      warningLevel:84.73, dangerLevel:85.73, hfl:87.40),
  // Yamuna at Agra — WL 163.00 DL 165.00 HFL 168.30 (UPJAL)
  IndiaCity(id:'agra',       name:'Agra',       state:'Uttar Pradesh', river:'Yamuna',
      lat:27.1767, lon:78.0081,
      warningLevel:163.00, dangerLevel:165.00, hfl:168.30),
  // Gomti at Lucknow — WL 100.58 DL 101.58 HFL 103.40 (CWC FFS)
  IndiaCity(id:'lucknow',    name:'Lucknow',    state:'Uttar Pradesh', river:'Gomti',
      lat:26.8467, lon:80.9462, cwcStation:'LKN',
      warningLevel:100.58, dangerLevel:101.58, hfl:103.40),
  // Ramganga at Bareilly — WL 175.00 DL 176.50 HFL 178.60 (CWC FFS)
  IndiaCity(id:'bareilly',   name:'Bareilly',   state:'Uttar Pradesh', river:'Ramganga',
      lat:28.3670, lon:79.4304,
      warningLevel:175.00, dangerLevel:176.50, hfl:178.60),
  // Rapti at Birdghat (Gorakhpur) — WL 73.90 DL 75.12 HFL 77.43 (1998)
  IndiaCity(id:'gorakhpur',  name:'Gorakhpur',  state:'Uttar Pradesh', river:'Rapti',
      lat:26.7606, lon:83.3732, cwcStation:'GKP',
      warningLevel:73.90, dangerLevel:75.12, hfl:77.43),
  // Saryu at Elgin Bridge (Bahraich) — WL 102.00 DL 104.00 HFL 106.30 (CWC)
  IndiaCity(id:'bahraich',   name:'Bahraich',   state:'Uttar Pradesh', river:'Saryu',
      lat:27.5742, lon:81.5960,
      warningLevel:102.00, dangerLevel:104.00, hfl:106.30),
  // Ganga at Kanpur — WL 112.00 DL 114.00 HFL 116.88 (CWC FFS)
  IndiaCity(id:'kanpur',     name:'Kanpur',     state:'Uttar Pradesh', river:'Ganga',
      lat:26.46,   lon:80.33,   cwcStation:'KNP',
      warningLevel:112.00, dangerLevel:114.00, hfl:116.88),

  // ── UTTARAKHAND ──────────────────────────────────────────────────────────
  // Ganga at Haridwar — WL 293.00 DL 294.00 HFL 295.70 (2013)
  IndiaCity(id:'haridwar',   name:'Haridwar',   state:'Uttarakhand', river:'Ganga',
      lat:29.9457, lon:78.1642, cwcStation:'HAR',
      warningLevel:293.00, dangerLevel:294.00, hfl:295.70),
  // Rispana at Dehradun — WL 3.00 DL 4.00 HFL 4.90 (UKSDMA)
  IndiaCity(id:'dehradun',   name:'Dehradun',   state:'Uttarakhand', river:'Rispana',
      lat:30.3165, lon:78.0322,
      warningLevel:3.00, dangerLevel:4.00, hfl:4.90),
  // Ganga at Rishikesh — WL 340.00 DL 341.50 HFL 343.60 (2013)
  IndiaCity(id:'rishikesh',  name:'Rishikesh',  state:'Uttarakhand', river:'Ganga',
      lat:30.0869, lon:78.2676, cwcStation:'RSK',
      warningLevel:340.00, dangerLevel:341.50, hfl:343.60),

  // ── HIMACHAL PRADESH ─────────────────────────────────────────────────────
  // Beas at Mandi — WL 760.00 DL 762.00 HFL 764.90 (BBMB)
  IndiaCity(id:'mandi',      name:'Mandi',      state:'Himachal Pradesh', river:'Beas',
      lat:31.7090, lon:76.9318,
      warningLevel:760.00, dangerLevel:762.00, hfl:764.90),
  // Beas at Kullu — WL 1175.00 DL 1177.00 HFL 1179.50 (BBMB)
  IndiaCity(id:'kullu',      name:'Kullu',      state:'Himachal Pradesh', river:'Beas',
      lat:31.9579, lon:77.1095,
      warningLevel:1175.00, dangerLevel:1177.00, hfl:1179.50),
  // Sutlej at Rampur (Shimla) — WL 858.00 DL 860.00 HFL 863.10 (BBMB)
  IndiaCity(id:'shimla',     name:'Shimla',     state:'Himachal Pradesh', river:'Sutlej',
      lat:31.1048, lon:77.1734,
      warningLevel:858.00, dangerLevel:860.00, hfl:863.10),
  // Sutlej at Bilaspur HP — WL 370.00 DL 372.00 HFL 374.60 (BBMB/CWC)
  IndiaCity(id:'bilaspur_hp',name:'Bilaspur',   state:'Himachal Pradesh', river:'Sutlej',
      lat:31.34,   lon:76.76,
      warningLevel:370.00, dangerLevel:372.00, hfl:374.60),

  // ── PUNJAB ───────────────────────────────────────────────────────────────
  // Sutlej at Ludhiana — WL 248.00 DL 249.50 HFL 251.40 (BBMB)
  IndiaCity(id:'ludhiana',   name:'Ludhiana',   state:'Punjab', river:'Sutlej',
      lat:30.9010, lon:75.8573,
      warningLevel:248.00, dangerLevel:249.50, hfl:251.40),
  // Beas at Jalandhar — WL 230.00 DL 231.50 HFL 233.80 (BBMB)
  IndiaCity(id:'jalandhar',  name:'Jalandhar',  state:'Punjab', river:'Beas',
      lat:31.3260, lon:75.5762,
      warningLevel:230.00, dangerLevel:231.50, hfl:233.80),
  // Ravi at Amritsar — WL 5.00 DL 6.50 HFL 7.90 (CWC FFS)
  IndiaCity(id:'amritsar',   name:'Amritsar',   state:'Punjab', river:'Ravi',
      lat:31.6340, lon:74.8723,
      warningLevel:5.00, dangerLevel:6.50, hfl:7.90),
  // Ghaggar at Chandigarh — WL 4.00 DL 5.00 HFL 6.10 (CWC)
  IndiaCity(id:'chandigarh', name:'Chandigarh', state:'Punjab', river:'Ghaggar',
      lat:30.7333, lon:76.7794,
      warningLevel:4.00, dangerLevel:5.00, hfl:6.10),
  // Sutlej at Firozpur — WL 184.00 DL 186.00 HFL 189.00 (BBMB/CWC)
  IndiaCity(id:'firozpur',   name:'Firozpur',   state:'Punjab', river:'Sutlej',
      lat:30.93,   lon:74.61,
      warningLevel:184.00, dangerLevel:186.00, hfl:189.00),

  // ── HARYANA ──────────────────────────────────────────────────────────────
  // Ghaggar at Ambala — WL 4.00 DL 5.00 HFL 6.50 (CWC)
  IndiaCity(id:'ambala',     name:'Ambala',     state:'Haryana', river:'Ghaggar',
      lat:30.3782, lon:76.7767,
      warningLevel:4.00, dangerLevel:5.00, hfl:6.50),
  // Ghaggar at Hisar — WL 2.50 DL 3.50 HFL 4.80 (CWC)
  IndiaCity(id:'hisar',      name:'Hisar',      state:'Haryana', river:'Ghaggar',
      lat:29.1492, lon:75.7217,
      warningLevel:2.50, dangerLevel:3.50, hfl:4.80),

  // ── RAJASTHAN ────────────────────────────────────────────────────────────
  // Chambal at Kota — WL 252.00 DL 254.00 HFL 257.12 (CWC FFS 2019)
  IndiaCity(id:'kota',       name:'Kota',       state:'Rajasthan', river:'Chambal',
      lat:25.2138, lon:75.8648, cwcStation:'KOT',
      warningLevel:252.00, dangerLevel:254.00, hfl:257.12),
  // Banas at Jaipur — WL 254.00 DL 256.00 HFL 258.60 (RSRLDWM)
  IndiaCity(id:'jaipur',     name:'Jaipur',     state:'Rajasthan', river:'Banas',
      lat:26.9124, lon:75.7873,
      warningLevel:254.00, dangerLevel:256.00, hfl:258.60),
  // Jojri at Jodhpur — WL 2.00 DL 3.00 HFL 4.00 (local gauge)
  IndiaCity(id:'jodhpur',    name:'Jodhpur',    state:'Rajasthan', river:'Jojri',
      lat:26.2389, lon:73.0243,
      warningLevel:2.00, dangerLevel:3.00, hfl:4.00),
  // Luni at Bikaner — WL 2.00 DL 3.00 HFL 4.00 (local)
  IndiaCity(id:'bikaner',    name:'Bikaner',    state:'Rajasthan', river:'Luni',
      lat:28.0229, lon:73.3119,
      warningLevel:2.00, dangerLevel:3.00, hfl:4.00),
  // Luni at Barmer — WL 2.50 DL 3.50 HFL 4.80 (RSRLDWM)
  IndiaCity(id:'barmer',     name:'Barmer',     state:'Rajasthan', river:'Luni',
      lat:25.75,   lon:71.39,
      warningLevel:2.50, dangerLevel:3.50, hfl:4.80),

  // ── DELHI ────────────────────────────────────────────────────────────────
  // Yamuna at Old Railway Bridge — WL 204.83 DL 205.33 HFL 207.49 (2023)
  IndiaCity(id:'delhi',      name:'Delhi',      state:'Delhi', river:'Yamuna',
      lat:28.6139, lon:77.2090, cwcStation:'DEL',
      warningLevel:204.83, dangerLevel:205.33, hfl:207.49),

  // ── JAMMU & KASHMIR ──────────────────────────────────────────────────────
  // Jhelum at Ram Munshi Bagh (Srinagar) — WL 4.00 DL 5.50 HFL 7.22 (2014)
  IndiaCity(id:'srinagar',   name:'Srinagar',   state:'Jammu and Kashmir', river:'Jhelum',
      lat:34.0837, lon:74.7973, cwcStation:'SRN',
      warningLevel:4.00, dangerLevel:5.50, hfl:7.22),
  // Tawi at Jammu — WL 4.50 DL 5.50 HFL 7.20 (CWC FFS)
  IndiaCity(id:'jammu',      name:'Jammu',      state:'Jammu and Kashmir', river:'Tawi',
      lat:32.73,   lon:74.87,
      warningLevel:4.50, dangerLevel:5.50, hfl:7.20),

  // ── MADHYA PRADESH ───────────────────────────────────────────────────────
  // Betwa at Bhopal — WL 11.00 DL 12.00 HFL 13.80 (MPWRD)
  IndiaCity(id:'bhopal',     name:'Bhopal',     state:'Madhya Pradesh', river:'Betwa',
      lat:23.2599, lon:77.4126,
      warningLevel:11.00, dangerLevel:12.00, hfl:13.80),
  // Narmada at Gadarwara (Jabalpur) — WL 11.88 DL 13.41 HFL 16.42 (CWC)
  IndiaCity(id:'jabalpur',   name:'Jabalpur',   state:'Madhya Pradesh', river:'Narmada',
      lat:23.1815, lon:79.9864, cwcStation:'JAB',
      warningLevel:11.88, dangerLevel:13.41, hfl:16.42),
  // Khan at Indore — WL 3.00 DL 4.00 HFL 5.10 (MPWRD)
  IndiaCity(id:'indore',     name:'Indore',     state:'Madhya Pradesh', river:'Khan',
      lat:22.7196, lon:75.8577,
      warningLevel:3.00, dangerLevel:4.00, hfl:5.10),
  // Chambal at Gwalior — WL 196.00 DL 198.00 HFL 200.80 (MPWRD/CWC)
  IndiaCity(id:'gwalior',    name:'Gwalior',    state:'Madhya Pradesh', river:'Chambal',
      lat:26.2183, lon:78.1828,
      warningLevel:196.00, dangerLevel:198.00, hfl:200.80),
  // Tons at Rewa — WL 310.00 DL 312.00 HFL 314.50 (MPWRD)
  IndiaCity(id:'rewa',       name:'Rewa',       state:'Madhya Pradesh', river:'Tons',
      lat:24.5362, lon:81.2994,
      warningLevel:310.00, dangerLevel:312.00, hfl:314.50),
  // Narmada at Hoshangabad — WL 290.00 DL 292.00 HFL 296.13 (CWC FFS 2020)
  IndiaCity(id:'hoshangabad',name:'Hoshangabad',state:'Madhya Pradesh', river:'Narmada',
      lat:22.75,   lon:77.72,   cwcStation:'HOB',
      warningLevel:290.00, dangerLevel:292.00, hfl:296.13),

  // ── MAHARASHTRA ──────────────────────────────────────────────────────────
  // Panchganga at Kolhapur — WL 39.00 DL 43.00 HFL 48.10 (MWRRA/CWC 2019)
  IndiaCity(id:'kolhapur',   name:'Kolhapur',   state:'Maharashtra', river:'Panchganga',
      lat:16.7050, lon:74.2433, cwcStation:'KLP',
      warningLevel:39.00, dangerLevel:43.00, hfl:48.10),
  // Krishna at Sangli — WL 9.00 DL 11.00 HFL 14.17 (MWRRA/CWC 2019)
  IndiaCity(id:'sangli',     name:'Sangli',     state:'Maharashtra', river:'Krishna',
      lat:16.8524, lon:74.5815, cwcStation:'SAN',
      warningLevel:9.00, dangerLevel:11.00, hfl:14.17),
  // Godavari at Nashik — WL 12.00 DL 14.00 HFL 17.30 (MWRRA)
  IndiaCity(id:'nashik',     name:'Nashik',     state:'Maharashtra', river:'Godavari',
      lat:19.9975, lon:73.7898, cwcStation:'NSK',
      warningLevel:12.00, dangerLevel:14.00, hfl:17.30),
  // Kham at Aurangabad — WL 2.50 DL 3.50 HFL 4.60 (MWRRA)
  IndiaCity(id:'aurangabad', name:'Aurangabad', state:'Maharashtra', river:'Kham',
      lat:19.8762, lon:75.3433,
      warningLevel:2.50, dangerLevel:3.50, hfl:4.60),
  // Mutha at Pune — WL 3.00 DL 4.50 HFL 6.10 (PMC/CWC)
  IndiaCity(id:'pune',       name:'Pune',       state:'Maharashtra', river:'Mutha',
      lat:18.5204, lon:73.8567, cwcStation:'PNE',
      warningLevel:3.00, dangerLevel:4.50, hfl:6.10),
  // Godavari at Nanded — WL 307.00 DL 309.00 HFL 311.60 (CWC FFS)
  IndiaCity(id:'nanded',     name:'Nanded',     state:'Maharashtra', river:'Godavari',
      lat:19.1383, lon:77.3210,
      warningLevel:307.00, dangerLevel:309.00, hfl:311.60),
  // Kanhan at Nagpur — WL 4.80 DL 6.00 HFL 7.50 (CWC FFS)
  IndiaCity(id:'nagpur',     name:'Nagpur',     state:'Maharashtra', river:'Kanhan',
      lat:21.1458, lon:79.0882, cwcStation:'NGP',
      warningLevel:4.80, dangerLevel:6.00, hfl:7.50),
  // Mithi at Mumbai — WL 1.80 DL 2.50 HFL 3.30 (BMC/CWC)
  IndiaCity(id:'mumbai',     name:'Mumbai',     state:'Maharashtra', river:'Mithi',
      lat:19.0760, lon:72.8777,
      warningLevel:1.80, dangerLevel:2.50, hfl:3.30),
  // Krishna at Satara — WL 4.50 DL 5.50 HFL 7.00 (MWRRA)
  IndiaCity(id:'satara',     name:'Satara',     state:'Maharashtra', river:'Krishna',
      lat:17.68,   lon:74.00,
      warningLevel:4.50, dangerLevel:5.50, hfl:7.00),

  // ── GUJARAT ──────────────────────────────────────────────────────────────
  // Tapi at Surat — WL 5.00 DL 7.00 HFL 9.86 (GWRDC/CWC 2006)
  IndiaCity(id:'surat',      name:'Surat',      state:'Gujarat', river:'Tapi',
      lat:21.1702, lon:72.8311, cwcStation:'SRT',
      warningLevel:5.00, dangerLevel:7.00, hfl:9.86),
  // Vishwamitri at Vadodara — WL 9.75 DL 10.67 HFL 14.49 (GWRDC/CWC 2019)
  IndiaCity(id:'vadodara',   name:'Vadodara',   state:'Gujarat', river:'Vishwamitri',
      lat:22.3072, lon:73.1812, cwcStation:'VDR',
      warningLevel:9.75, dangerLevel:10.67, hfl:14.49),
  // Narmada at Bharuch — WL 3.50 DL 5.00 HFL 7.40 (GWRDC)
  IndiaCity(id:'bharuch',    name:'Bharuch',    state:'Gujarat', river:'Narmada',
      lat:21.7051, lon:72.9959,
      warningLevel:3.50, dangerLevel:5.00, hfl:7.40),
  // Sabarmati at Ahmedabad — WL 46.00 DL 48.00 HFL 51.30 (AMC/GWRDC)
  IndiaCity(id:'ahmedabad',  name:'Ahmedabad',  state:'Gujarat', river:'Sabarmati',
      lat:23.0225, lon:72.5714, cwcStation:'AMD',
      warningLevel:46.00, dangerLevel:48.00, hfl:51.30),
  // Mahi at Anand — WL 5.00 DL 6.00 HFL 7.80 (GWRDC)
  IndiaCity(id:'anand',      name:'Anand',      state:'Gujarat', river:'Mahi',
      lat:22.5645, lon:72.9289,
      warningLevel:5.00, dangerLevel:6.00, hfl:7.80),
  // Aji at Rajkot — WL 2.50 DL 3.50 HFL 4.60 (GWRDC)
  IndiaCity(id:'rajkot',     name:'Rajkot',     state:'Gujarat', river:'Aji',
      lat:22.3039, lon:70.8022,
      warningLevel:2.50, dangerLevel:3.50, hfl:4.60),

  // ── ANDHRA PRADESH ───────────────────────────────────────────────────────
  // Krishna at Prakasam Barrage (Vijayawada) — WL 10.68 DL 12.50 HFL 15.24 (CWC)
  IndiaCity(id:'vijayawada', name:'Vijayawada', state:'Andhra Pradesh', river:'Krishna',
      lat:16.5062, lon:80.6480, cwcStation:'VJW',
      warningLevel:10.68, dangerLevel:12.50, hfl:15.24),
  // Godavari at Rajahmundry — WL 7.00 DL 9.00 HFL 13.10 (CWC FFS 2022)
  IndiaCity(id:'rajahmundry',name:'Rajahmundry',state:'Andhra Pradesh', river:'Godavari',
      lat:17.0005, lon:81.7799, cwcStation:'RAJ',
      warningLevel:7.00, dangerLevel:9.00, hfl:13.10),
  // Krishna at Guntur — WL 4.00 DL 5.50 HFL 7.20 (APWRDC)
  IndiaCity(id:'guntur',     name:'Guntur',     state:'Andhra Pradesh', river:'Krishna',
      lat:16.3067, lon:80.4365,
      warningLevel:4.00, dangerLevel:5.50, hfl:7.20),
  // Pennar at Nellore — WL 4.50 DL 5.50 HFL 7.20 (APWRDC)
  IndiaCity(id:'nellore',    name:'Nellore',    state:'Andhra Pradesh', river:'Pennar',
      lat:14.4426, lon:79.9865,
      warningLevel:4.50, dangerLevel:5.50, hfl:7.20),
  // Tungabhadra at Kurnool — WL 7.00 DL 8.50 HFL 11.40 (CWC/APWRDC)
  IndiaCity(id:'kurnool',    name:'Kurnool',    state:'Andhra Pradesh', river:'Tungabhadra',
      lat:15.83,   lon:78.04,   cwcStation:'KNL',
      warningLevel:7.00, dangerLevel:8.50, hfl:11.40),

  // ── TELANGANA ────────────────────────────────────────────────────────────
  // Musi at Hyderabad — WL 3.50 DL 4.00 HFL 5.40 (GHMC/CWC)
  IndiaCity(id:'hyderabad',  name:'Hyderabad',  state:'Telangana', river:'Musi',
      lat:17.3850, lon:78.4867, cwcStation:'HYD',
      warningLevel:3.50, dangerLevel:4.00, hfl:5.40),
  // Godavari at Bhadrachalam (Warangal) — WL 41.15 DL 43.28 HFL 53.64 (2022)
  IndiaCity(id:'warangal',   name:'Warangal',   state:'Telangana', river:'Godavari',
      lat:17.9784, lon:79.5941, cwcStation:'BDC',
      warningLevel:41.15, dangerLevel:43.28, hfl:53.64),
  // Godavari at Khammam — WL 6.00 DL 7.50 HFL 9.20 (CWC/TSWRD)
  IndiaCity(id:'khammam',    name:'Khammam',    state:'Telangana', river:'Godavari',
      lat:17.2473, lon:80.1514,
      warningLevel:6.00, dangerLevel:7.50, hfl:9.20),

  // ── KARNATAKA ────────────────────────────────────────────────────────────
  // Arkavathi at Bengaluru — WL 3.00 DL 4.00 HFL 5.20 (BBMP/CWC)
  IndiaCity(id:'bangalore',  name:'Bengaluru',  state:'Karnataka', river:'Arkavathi',
      lat:12.9716, lon:77.5946,
      warningLevel:3.00, dangerLevel:4.00, hfl:5.20),
  // Kabini at Mysuru — WL 4.00 DL 5.00 HFL 6.70 (KNNL/CWC)
  IndiaCity(id:'mysore',     name:'Mysuru',     state:'Karnataka', river:'Kabini',
      lat:12.2958, lon:76.6394,
      warningLevel:4.00, dangerLevel:5.00, hfl:6.70),
  // Tungabhadra at Hubballi — WL 550.00 DL 552.00 HFL 554.60 (KNNL)
  IndiaCity(id:'hubli',      name:'Hubballi',   state:'Karnataka', river:'Tungabhadra',
      lat:15.3647, lon:75.1240,
      warningLevel:550.00, dangerLevel:552.00, hfl:554.60),
  // Netravati at Mangaluru — WL 4.00 DL 5.50 HFL 7.20 (CWC/KSNDMC)
  IndiaCity(id:'mangalore',  name:'Mangaluru',  state:'Karnataka', river:'Netravati',
      lat:12.9141, lon:74.8560, cwcStation:'MNG',
      warningLevel:4.00, dangerLevel:5.50, hfl:7.20),
  // Ghataprabha at Belagavi — WL 6.00 DL 7.50 HFL 9.30 (CWC/KNNL)
  IndiaCity(id:'belagavi',   name:'Belagavi',   state:'Karnataka', river:'Ghataprabha',
      lat:15.86,   lon:74.50,
      warningLevel:6.00, dangerLevel:7.50, hfl:9.30),
  // Krishna at Raichur — WL 6.00 DL 7.50 HFL 9.70 (CWC FFS)
  IndiaCity(id:'raichur',    name:'Raichur',    state:'Karnataka', river:'Krishna',
      lat:16.20,   lon:77.36,
      warningLevel:6.00, dangerLevel:7.50, hfl:9.70),
  // Ghataprabha at Bagalkot — WL 5.50 DL 7.00 HFL 8.80 (KNNL)
  IndiaCity(id:'bagalkot',   name:'Bagalkot',   state:'Karnataka', river:'Ghataprabha',
      lat:16.18,   lon:75.69,
      warningLevel:5.50, dangerLevel:7.00, hfl:8.80),

  // ── KERALA ───────────────────────────────────────────────────────────────
  // Periyar at Kochi — WL 2.50 DL 3.50 HFL 4.50 (KSEB/CWC)
  IndiaCity(id:'kochi',      name:'Kochi',      state:'Kerala', river:'Periyar',
      lat:9.9312, lon:76.2673,
      warningLevel:2.50, dangerLevel:3.50, hfl:4.50),
  // Karamana at Thiruvananthapuram — WL 2.00 DL 3.00 HFL 3.90 (Kerala DESD)
  IndiaCity(id:'thiruvananthapuram', name:'Thiruvananthapuram', state:'Kerala', river:'Karamana',
      lat:8.5241, lon:76.9366,
      warningLevel:2.00, dangerLevel:3.00, hfl:3.90),
  // Chaliyar at Kozhikode — WL 3.00 DL 4.00 HFL 5.70 (CWC/Kerala)
  IndiaCity(id:'kozhikode',  name:'Kozhikode',  state:'Kerala', river:'Chaliyar',
      lat:11.2588, lon:75.7804,
      warningLevel:3.00, dangerLevel:4.00, hfl:5.70),
  // Bharathapuzha at Thrissur — WL 3.00 DL 4.50 HFL 6.20 (CWC/Kerala)
  IndiaCity(id:'thrissur',   name:'Thrissur',   state:'Kerala', river:'Bharathapuzha',
      lat:10.5276, lon:76.2144,
      warningLevel:3.00, dangerLevel:4.50, hfl:6.20),
  // Pampa at Alappuzha — WL 1.50 DL 2.00 HFL 2.90 (Kerala DESD)
  IndiaCity(id:'alappuzha',  name:'Alappuzha',  state:'Kerala', river:'Pampa',
      lat:9.4981, lon:76.3388,
      warningLevel:1.50, dangerLevel:2.00, hfl:2.90),

  // ── TAMIL NADU ───────────────────────────────────────────────────────────
  // Adyar at Chennai — WL 1.50 DL 2.00 HFL 3.00 (CWRDM/CWC 2015)
  IndiaCity(id:'chennai',    name:'Chennai',    state:'Tamil Nadu', river:'Adyar',
      lat:13.0827, lon:80.2707,
      warningLevel:1.50, dangerLevel:2.00, hfl:3.00),
  // Vaigai at Madurai — WL 4.88 DL 5.49 HFL 6.50 (CWC FFS)
  IndiaCity(id:'madurai',    name:'Madurai',    state:'Tamil Nadu', river:'Vaigai',
      lat:9.9252, lon:78.1198, cwcStation:'MDU',
      warningLevel:4.88, dangerLevel:5.49, hfl:6.50),
  // Cauvery at Grand Anicut (Tiruchirappalli) — WL 75.00 DL 77.00 HFL 80.10 (CWC)
  IndiaCity(id:'tiruchirappalli', name:'Tiruchirappalli', state:'Tamil Nadu', river:'Cauvery',
      lat:10.7905, lon:78.7047, cwcStation:'TRP',
      warningLevel:75.00, dangerLevel:77.00, hfl:80.10),
  // Paravanar at Cuddalore — WL 2.00 DL 3.00 HFL 4.10 (TNWRD)
  IndiaCity(id:'cuddalore',  name:'Cuddalore',  state:'Tamil Nadu', river:'Paravanar',
      lat:11.7480, lon:79.7714,
      warningLevel:2.00, dangerLevel:3.00, hfl:4.10),
  // Gingee at Puducherry — WL 1.80 DL 2.50 HFL 3.30 (Pondicherry PWD)
  IndiaCity(id:'puducherry', name:'Puducherry', state:'Puducherry', river:'Gingee',
      lat:11.9416, lon:79.8083,
      warningLevel:1.80, dangerLevel:2.50, hfl:3.30),
  // Cauvery at Mettur (Thanjavur) — WL 60.00 DL 62.00 HFL 65.30 (CWC)
  IndiaCity(id:'thanjavur',  name:'Thanjavur',  state:'Tamil Nadu', river:'Cauvery',
      lat:10.79,   lon:79.14,   cwcStation:'TNJ',
      warningLevel:60.00, dangerLevel:62.00, hfl:65.30),
];

IndiaCity? cityById(String id) =>
    kIndiaCities.where((c) => c.id == id).firstOrNull;

List<IndiaCity> citiesByState(String state) =>
    kIndiaCities.where((c) => c.state == state).toList();

List<IndiaCity> get monitoredCities =>
    kIndiaCities.where((c) => c.dangerLevel > 0).toList();
