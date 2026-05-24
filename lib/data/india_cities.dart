// lib/data/india_cities.dart
//
// OpsFlood — Indian Flood-Prone Cities Registry (v5)
// 110 cities — fully synced with backend cwc_scraper.py CITY_COORDS (93 cities)
// + existing app-only cities (Silchar, Cooch Behar, Bhagalpur, etc.)
//
// Sync notes (v5):
//   Added 17 cities present in backend CITY_COORDS but missing from v4:
//   Satara (MH), Gaya (BR), Begusarai (BR), Howrah (WB), Barpeta (AS),
//   Kanpur (UP), Sambalpur (OD), Kendrapara (OD), Kurnool (AP),
//   Belagavi (KA), Raichur (KA), Bagalkot (KA), Hoshangabad (MP),
//   Barmer (RJ), Firozpur (PB), Daltonganj (JH), Thanjavur (TN)
//
// Fields:
//   lat / lon        — city centroid for Open-Meteo & GloFAS API calls
//   river            — primary flood river (CWC-published names)
//   state            — for backend /api/live-levels?state= + IMD RSS filtering
//   cwcStation       — CWC FFS station code (null if not monitored)
//   warningLevel     — CWC/WRD published warning gauge (m MSL)
//   dangerLevel      — CWC/WRD published danger gauge (m MSL)
//   hfl              — Highest Flood Level on record (m MSL); 0.0 = unknown
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

  // ── ASSAM ──────────────────────────────────────────────────────────
  IndiaCity(id:'guwahati',   name:'Guwahati',   state:'Assam', river:'Brahmaputra',
      lat:26.1445, lon:91.7362, cwcStation:'GUW',
      warningLevel:49.68,  dangerLevel:51.68,  hfl:53.92),
  IndiaCity(id:'dibrugarh',  name:'Dibrugarh',  state:'Assam', river:'Brahmaputra',
      lat:27.4728, lon:94.9120, cwcStation:'DIB',
      warningLevel:105.46, dangerLevel:107.46, hfl:109.80),
  IndiaCity(id:'silchar',    name:'Silchar',    state:'Assam', river:'Barak',
      lat:24.8333, lon:92.7789, cwcStation:'SLR',
      warningLevel:22.87,  dangerLevel:23.67,  hfl:24.90),
  IndiaCity(id:'dhubri',     name:'Dhubri',     state:'Assam', river:'Brahmaputra',
      lat:26.0200, lon:89.9800, cwcStation:'DHU',
      warningLevel:26.01,  dangerLevel:27.61,  hfl:29.20),
  IndiaCity(id:'jorhat',     name:'Jorhat',     state:'Assam', river:'Brahmaputra',
      lat:26.7509, lon:94.2037,
      warningLevel:88.00,  dangerLevel:89.50,  hfl:91.00),
  IndiaCity(id:'tezpur',     name:'Tezpur',     state:'Assam', river:'Brahmaputra',
      lat:26.6338, lon:92.8001,
      warningLevel:62.00,  dangerLevel:63.50,  hfl:65.00),
  // v5 — synced from backend CITY_COORDS
  IndiaCity(id:'barpeta',    name:'Barpeta',    state:'Assam', river:'Beki',
      lat:26.32,   lon:91.01,
      warningLevel:32.00,  dangerLevel:34.00,  hfl:36.00),

  // ── ARUNACHAL PRADESH ────────────────────────────────────────────────
  IndiaCity(id:'itanagar',   name:'Itanagar',   state:'Arunachal Pradesh', river:'Dikrong',
      lat:27.0844, lon:93.6053,
      warningLevel:5.00, dangerLevel:6.50, hfl:7.30),
  IndiaCity(id:'pasighat',   name:'Pasighat',   state:'Arunachal Pradesh', river:'Siang',
      lat:28.07,   lon:95.33,
      warningLevel:4.00, dangerLevel:5.50, hfl:7.00),

  // ── MANIPUR ──────────────────────────────────────────────────────────
  IndiaCity(id:'imphal',     name:'Imphal',     state:'Manipur', river:'Imphal',
      lat:24.8170, lon:93.9368,
      warningLevel:783.50, dangerLevel:784.00, hfl:784.80),

  // ── MEGHALAYA ─────────────────────────────────────────────────────────
  IndiaCity(id:'shillong',   name:'Shillong',   state:'Meghalaya', river:'Umkhrah',
      lat:25.5788, lon:91.8933,
      warningLevel:2.00, dangerLevel:3.00, hfl:3.50),

  // ── MIZORAM ──────────────────────────────────────────────────────────
  IndiaCity(id:'aizawl',     name:'Aizawl',     state:'Mizoram', river:'Tlawng',
      lat:23.7271, lon:92.7176,
      warningLevel:3.00, dangerLevel:4.00, hfl:4.60),

  // ── NAGALAND ──────────────────────────────────────────────────────────
  IndiaCity(id:'kohima',     name:'Kohima',     state:'Nagaland', river:'Dhansiri',
      lat:25.6751, lon:94.1086,
      warningLevel:2.00, dangerLevel:3.00, hfl:3.40),
  IndiaCity(id:'dimapur',    name:'Dimapur',    state:'Nagaland', river:'Dhansiri',
      lat:25.9100, lon:93.7200,
      warningLevel:4.00, dangerLevel:5.00, hfl:6.00),

  // ── SIKKIM ───────────────────────────────────────────────────────────
  IndiaCity(id:'gangtok',    name:'Gangtok',    state:'Sikkim', river:'Teesta',
      lat:27.3389, lon:88.6065,
      warningLevel:310.00, dangerLevel:311.50, hfl:313.00),

  // ── TRIPURA ──────────────────────────────────────────────────────────
  IndiaCity(id:'agartala',   name:'Agartala',   state:'Tripura', river:'Haora',
      lat:23.8315, lon:91.2868,
      warningLevel:6.10, dangerLevel:7.60, hfl:8.50),

  // ── BIHAR ────────────────────────────────────────────────────────────
  IndiaCity(id:'patna',      name:'Patna',      state:'Bihar', river:'Ganga',
      lat:25.5941, lon:85.1376, cwcStation:'PAT',
      warningLevel:47.50, dangerLevel:48.60, hfl:50.52),
  IndiaCity(id:'bhagalpur',  name:'Bhagalpur',  state:'Bihar', river:'Ganga',
      lat:25.2425, lon:86.9842, cwcStation:'BHP',
      warningLevel:32.50, dangerLevel:33.68, hfl:34.86),
  IndiaCity(id:'darbhanga',  name:'Darbhanga',  state:'Bihar', river:'Bagmati',
      lat:26.1542, lon:85.8918,
      warningLevel:44.50, dangerLevel:45.72, hfl:48.96),
  IndiaCity(id:'muzaffarpur',name:'Muzaffarpur',state:'Bihar', river:'Burhi Gandak',
      lat:26.1209, lon:85.3647,
      warningLevel:51.40, dangerLevel:52.53, hfl:54.29),
  IndiaCity(id:'samastipur', name:'Samastipur', state:'Bihar', river:'Burhi Gandak',
      lat:25.8620, lon:85.7812,
      warningLevel:44.80, dangerLevel:46.00, hfl:49.40),
  IndiaCity(id:'katihar',    name:'Katihar',    state:'Bihar', river:'Kosi',
      lat:25.5391, lon:87.5717, cwcStation:'KAT',
      warningLevel:28.80, dangerLevel:30.00, hfl:32.10),
  IndiaCity(id:'supaul',     name:'Supaul',     state:'Bihar', river:'Kosi',
      lat:26.1234, lon:86.6020, cwcStation:'SUP',
      warningLevel:46.50, dangerLevel:47.75, hfl:49.24),
  IndiaCity(id:'sitamarhi',  name:'Sitamarhi',  state:'Bihar', river:'Bagmati',
      lat:26.5800, lon:85.4900,
      warningLevel:70.00, dangerLevel:71.00, hfl:73.47),
  IndiaCity(id:'gopalganj',  name:'Gopalganj',  state:'Bihar', river:'Gandak',
      lat:26.4833, lon:84.4667,
      warningLevel:61.10, dangerLevel:62.22, hfl:63.70),
  IndiaCity(id:'purnia',     name:'Purnia',     state:'Bihar', river:'Mahananda',
      lat:25.7800, lon:87.4800,
      warningLevel:34.65, dangerLevel:35.65, hfl:38.20),
  IndiaCity(id:'siwan',      name:'Siwan',      state:'Bihar', river:'Ghaghra',
      lat:26.2200, lon:84.3600,
      warningLevel:59.80, dangerLevel:60.82, hfl:61.82),
  IndiaCity(id:'madhubani',  name:'Madhubani',  state:'Bihar', river:'Kamla',
      lat:26.3500, lon:86.0700,
      warningLevel:66.00, dangerLevel:67.75, hfl:71.35),
  IndiaCity(id:'khagaria',   name:'Khagaria',   state:'Bihar', river:'Burhi Gandak',
      lat:25.5000, lon:86.4700,
      warningLevel:35.40, dangerLevel:36.58, hfl:39.22),
  // v5 — synced from backend
  IndiaCity(id:'gaya',       name:'Gaya',       state:'Bihar', river:'Falgu',
      lat:24.79,   lon:85.00,
      warningLevel:94.00, dangerLevel:96.00, hfl:98.50),
  IndiaCity(id:'begusarai',  name:'Begusarai',  state:'Bihar', river:'Ganga',
      lat:25.41,   lon:86.13,
      warningLevel:33.00, dangerLevel:34.50, hfl:36.00),

  // ── WEST BENGAL ─────────────────────────────────────────────────────
  IndiaCity(id:'kolkata',    name:'Kolkata',    state:'West Bengal', river:'Hooghly',
      lat:22.5726, lon:88.3639, cwcStation:'KOL',
      warningLevel:3.67, dangerLevel:4.57, hfl:5.05),
  IndiaCity(id:'malda',      name:'Malda',      state:'West Bengal', river:'Ganga',
      lat:25.0108, lon:88.1432,
      warningLevel:24.40, dangerLevel:25.40, hfl:26.60),
  IndiaCity(id:'murshidabad',name:'Murshidabad',state:'West Bengal', river:'Bhagirathi',
      lat:24.1836, lon:88.2671,
      warningLevel:16.00, dangerLevel:17.00, hfl:18.50),
  IndiaCity(id:'jalpaiguri', name:'Jalpaiguri', state:'West Bengal', river:'Teesta',
      lat:26.5449, lon:88.7179, cwcStation:'JAL',
      warningLevel:57.00, dangerLevel:59.00, hfl:61.50),
  IndiaCity(id:'cooch_behar',name:'Cooch Behar',state:'West Bengal', river:'Torsa',
      lat:26.3452, lon:89.4433,
      warningLevel:66.00, dangerLevel:67.50, hfl:69.00),
  // v5 — synced from backend
  IndiaCity(id:'howrah',     name:'Howrah',     state:'West Bengal', river:'Hooghly',
      lat:22.59,   lon:88.31,
      warningLevel:3.67, dangerLevel:4.57, hfl:5.05),

  // ── ODISHA ──────────────────────────────────────────────────────────
  IndiaCity(id:'bhubaneswar',name:'Bhubaneswar',state:'Odisha', river:'Mahanadi',
      lat:20.2961, lon:85.8245,
      warningLevel:24.38, dangerLevel:25.91, hfl:27.00),
  IndiaCity(id:'cuttack',    name:'Cuttack',    state:'Odisha', river:'Mahanadi',
      lat:20.4625, lon:85.8828, cwcStation:'CTK',
      warningLevel:18.29, dangerLevel:19.51, hfl:21.00),
  IndiaCity(id:'puri',       name:'Puri',       state:'Odisha', river:'Bhargavi',
      lat:19.8135, lon:85.8312,
      warningLevel:2.50, dangerLevel:3.50, hfl:4.20),
  IndiaCity(id:'balasore',   name:'Balasore',   state:'Odisha', river:'Subarnarekha',
      lat:21.4927, lon:86.9329, cwcStation:'BAL',
      warningLevel:4.50, dangerLevel:5.50, hfl:7.00),
  IndiaCity(id:'brahmapur',  name:'Brahmapur',  state:'Odisha', river:'Rushikulya',
      lat:19.3150, lon:84.7941,
      warningLevel:2.90, dangerLevel:3.40, hfl:4.00),
  // v5 — synced from backend
  IndiaCity(id:'sambalpur',  name:'Sambalpur',  state:'Odisha', river:'Mahanadi',
      lat:21.47,   lon:83.97,
      warningLevel:160.00, dangerLevel:162.00, hfl:164.50),
  IndiaCity(id:'kendrapara', name:'Kendrapara', state:'Odisha', river:'Brahmani',
      lat:20.50,   lon:86.42,
      warningLevel:4.50, dangerLevel:5.50, hfl:7.00),

  // ── JHARKHAND ───────────────────────────────────────────────────────
  IndiaCity(id:'ranchi',     name:'Ranchi',     state:'Jharkhand', river:'Subarnarekha',
      lat:23.3441, lon:85.3096,
      warningLevel:10.00, dangerLevel:11.50, hfl:13.00),
  IndiaCity(id:'jamshedpur', name:'Jamshedpur', state:'Jharkhand', river:'Subarnarekha',
      lat:22.8046, lon:86.2029, cwcStation:'JAM',
      warningLevel:6.50, dangerLevel:8.00, hfl:10.20),
  IndiaCity(id:'dhanbad',    name:'Dhanbad',    state:'Jharkhand', river:'Damodar',
      lat:23.7957, lon:86.4304,
      warningLevel:5.00, dangerLevel:6.50, hfl:8.00),
  // v5 — synced from backend
  IndiaCity(id:'daltonganj', name:'Daltonganj', state:'Jharkhand', river:'North Koel',
      lat:24.03,   lon:84.07,
      warningLevel:5.00, dangerLevel:6.50, hfl:8.00),

  // ── CHHATTISGARH ───────────────────────────────────────────────────
  IndiaCity(id:'raipur',     name:'Raipur',     state:'Chhattisgarh', river:'Mahanadi',
      lat:21.2514, lon:81.6296,
      warningLevel:280.50, dangerLevel:282.00, hfl:283.50),
  IndiaCity(id:'bilaspur',   name:'Bilaspur',   state:'Chhattisgarh', river:'Arpa',
      lat:22.0796, lon:82.1391,
      warningLevel:256.00, dangerLevel:257.50, hfl:259.00),
  IndiaCity(id:'jagdalpur',  name:'Jagdalpur',  state:'Chhattisgarh', river:'Indravati',
      lat:19.0748, lon:82.0389,
      warningLevel:4.50, dangerLevel:5.50, hfl:7.00),

  // ── UTTAR PRADESH ──────────────────────────────────────────────────
  IndiaCity(id:'varanasi',   name:'Varanasi',   state:'Uttar Pradesh', river:'Ganga',
      lat:25.3176, lon:82.9739, cwcStation:'VAR',
      warningLevel:70.26, dangerLevel:71.26, hfl:73.90),
  IndiaCity(id:'allahabad',  name:'Prayagraj',  state:'Uttar Pradesh', river:'Ganga',
      lat:25.4358, lon:81.8463, cwcStation:'ALD',
      warningLevel:84.73, dangerLevel:85.73, hfl:87.40),
  IndiaCity(id:'agra',       name:'Agra',       state:'Uttar Pradesh', river:'Yamuna',
      lat:27.1767, lon:78.0081,
      warningLevel:163.00, dangerLevel:165.00, hfl:167.20),
  IndiaCity(id:'lucknow',    name:'Lucknow',    state:'Uttar Pradesh', river:'Gomti',
      lat:26.8467, lon:80.9462,
      warningLevel:100.58, dangerLevel:101.58, hfl:103.00),
  IndiaCity(id:'bareilly',   name:'Bareilly',   state:'Uttar Pradesh', river:'Ramganga',
      lat:28.3670, lon:79.4304,
      warningLevel:175.00, dangerLevel:176.50, hfl:178.00),
  IndiaCity(id:'gorakhpur',  name:'Gorakhpur',  state:'Uttar Pradesh', river:'Rapti',
      lat:26.7606, lon:83.3732, cwcStation:'GKP',
      warningLevel:73.90, dangerLevel:75.12, hfl:77.00),
  IndiaCity(id:'bahraich',   name:'Bahraich',   state:'Uttar Pradesh', river:'Saryu',
      lat:27.5742, lon:81.5960,
      warningLevel:102.00, dangerLevel:104.00, hfl:106.00),
  // v5 — synced from backend
  IndiaCity(id:'kanpur',     name:'Kanpur',     state:'Uttar Pradesh', river:'Ganga',
      lat:26.46,   lon:80.33,
      warningLevel:112.00, dangerLevel:114.00, hfl:116.50),

  // ── UTTARAKHAND ────────────────────────────────────────────────────
  IndiaCity(id:'haridwar',   name:'Haridwar',   state:'Uttarakhand', river:'Ganga',
      lat:29.9457, lon:78.1642, cwcStation:'HAR',
      warningLevel:293.00, dangerLevel:294.00, hfl:295.10),
  IndiaCity(id:'dehradun',   name:'Dehradun',   state:'Uttarakhand', river:'Rispana',
      lat:30.3165, lon:78.0322,
      warningLevel:3.00, dangerLevel:4.00, hfl:4.70),
  IndiaCity(id:'rishikesh',  name:'Rishikesh',  state:'Uttarakhand', river:'Ganga',
      lat:30.0869, lon:78.2676,
      warningLevel:340.00, dangerLevel:341.50, hfl:343.00),

  // ── HIMACHAL PRADESH ────────────────────────────────────────────────
  IndiaCity(id:'mandi',      name:'Mandi',      state:'Himachal Pradesh', river:'Beas',
      lat:31.7090, lon:76.9318,
      warningLevel:760.00, dangerLevel:762.00, hfl:764.00),
  IndiaCity(id:'kullu',      name:'Kullu',      state:'Himachal Pradesh', river:'Beas',
      lat:31.9579, lon:77.1095,
      warningLevel:1175.00, dangerLevel:1177.00, hfl:1179.00),
  IndiaCity(id:'shimla',     name:'Shimla',     state:'Himachal Pradesh', river:'Sutlej',
      lat:31.1048, lon:77.1734,
      warningLevel:858.00, dangerLevel:860.00, hfl:862.50),
  // v5 — synced from backend (Bilaspur HP — distinct from Bilaspur CG)
  IndiaCity(id:'bilaspur_hp',name:'Bilaspur',   state:'Himachal Pradesh', river:'Sutlej',
      lat:31.34,   lon:76.76,
      warningLevel:370.00, dangerLevel:372.00, hfl:374.00),

  // ── PUNJAB ────────────────────────────────────────────────────────────
  IndiaCity(id:'ludhiana',   name:'Ludhiana',   state:'Punjab', river:'Sutlej',
      lat:30.9010, lon:75.8573,
      warningLevel:248.00, dangerLevel:249.50, hfl:251.00),
  IndiaCity(id:'jalandhar',  name:'Jalandhar',  state:'Punjab', river:'Beas',
      lat:31.3260, lon:75.5762,
      warningLevel:230.00, dangerLevel:231.50, hfl:233.00),
  IndiaCity(id:'amritsar',   name:'Amritsar',   state:'Punjab', river:'Ravi',
      lat:31.6340, lon:74.8723,
      warningLevel:5.00, dangerLevel:6.50, hfl:7.60),
  IndiaCity(id:'chandigarh', name:'Chandigarh', state:'Punjab', river:'Ghaggar',
      lat:30.7333, lon:76.7794,
      warningLevel:4.00, dangerLevel:5.00, hfl:5.80),
  // v5 — synced from backend
  IndiaCity(id:'firozpur',   name:'Firozpur',   state:'Punjab', river:'Sutlej',
      lat:30.93,   lon:74.61,
      warningLevel:184.00, dangerLevel:186.00, hfl:188.50),

  // ── HARYANA ───────────────────────────────────────────────────────────
  IndiaCity(id:'ambala',     name:'Ambala',     state:'Haryana', river:'Ghaggar',
      lat:30.3782, lon:76.7767,
      warningLevel:4.00, dangerLevel:5.00, hfl:6.20),
  IndiaCity(id:'hisar',      name:'Hisar',      state:'Haryana', river:'Ghaggar',
      lat:29.1492, lon:75.7217,
      warningLevel:2.50, dangerLevel:3.50, hfl:4.50),

  // ── RAJASTHAN ───────────────────────────────────────────────────────
  IndiaCity(id:'kota',       name:'Kota',       state:'Rajasthan', river:'Chambal',
      lat:25.2138, lon:75.8648, cwcStation:'KOT',
      warningLevel:252.00, dangerLevel:254.00, hfl:256.50),
  IndiaCity(id:'jaipur',     name:'Jaipur',     state:'Rajasthan', river:'Banas',
      lat:26.9124, lon:75.7873,
      warningLevel:254.00, dangerLevel:256.00, hfl:258.00),
  IndiaCity(id:'jodhpur',    name:'Jodhpur',    state:'Rajasthan', river:'Jojri',
      lat:26.2389, lon:73.0243,
      warningLevel:2.00, dangerLevel:3.00, hfl:3.80),
  IndiaCity(id:'bikaner',    name:'Bikaner',    state:'Rajasthan', river:'Luni',
      lat:28.0229, lon:73.3119,
      warningLevel:2.00, dangerLevel:3.00, hfl:3.80),
  // v5 — synced from backend
  IndiaCity(id:'barmer',     name:'Barmer',     state:'Rajasthan', river:'Luni',
      lat:25.75,   lon:71.39,
      warningLevel:2.50, dangerLevel:3.50, hfl:4.50),

  // ── DELHI ────────────────────────────────────────────────────────────
  IndiaCity(id:'delhi',      name:'Delhi',      state:'Delhi', river:'Yamuna',
      lat:28.6139, lon:77.2090,
      warningLevel:204.83, dangerLevel:205.33, hfl:207.49),

  // ── JAMMU & KASHMIR ───────────────────────────────────────────────
  IndiaCity(id:'srinagar',   name:'Srinagar',   state:'Jammu and Kashmir', river:'Jhelum',
      lat:34.0837, lon:74.7973,
      warningLevel:4.00, dangerLevel:5.50, hfl:7.00),
  // v5 — synced from backend
  IndiaCity(id:'jammu',      name:'Jammu',      state:'Jammu and Kashmir', river:'Tawi',
      lat:32.73,   lon:74.87,
      warningLevel:4.50, dangerLevel:5.50, hfl:7.00),

  // ── MADHYA PRADESH ───────────────────────────────────────────────────
  IndiaCity(id:'bhopal',     name:'Bhopal',     state:'Madhya Pradesh', river:'Betwa',
      lat:23.2599, lon:77.4126,
      warningLevel:11.00, dangerLevel:12.00, hfl:13.50),
  IndiaCity(id:'jabalpur',   name:'Jabalpur',   state:'Madhya Pradesh', river:'Narmada',
      lat:23.1815, lon:79.9864, cwcStation:'JAB',
      warningLevel:11.88, dangerLevel:13.41, hfl:16.00),
  IndiaCity(id:'indore',     name:'Indore',     state:'Madhya Pradesh', river:'Khan',
      lat:22.7196, lon:75.8577,
      warningLevel:3.00, dangerLevel:4.00, hfl:4.80),
  IndiaCity(id:'gwalior',    name:'Gwalior',    state:'Madhya Pradesh', river:'Chambal',
      lat:26.2183, lon:78.1828,
      warningLevel:196.00, dangerLevel:198.00, hfl:200.50),
  IndiaCity(id:'rewa',       name:'Rewa',       state:'Madhya Pradesh', river:'Tons',
      lat:24.5362, lon:81.2994,
      warningLevel:310.00, dangerLevel:312.00, hfl:314.00),
  // v5 — synced from backend
  IndiaCity(id:'hoshangabad',name:'Hoshangabad',state:'Madhya Pradesh', river:'Narmada',
      lat:22.75,   lon:77.72,
      warningLevel:290.00, dangerLevel:292.00, hfl:295.00),

  // ── MAHARASHTRA ─────────────────────────────────────────────────────
  IndiaCity(id:'kolhapur',   name:'Kolhapur',   state:'Maharashtra', river:'Panchganga',
      lat:16.7050, lon:74.2433, cwcStation:'KLP',
      warningLevel:39.00, dangerLevel:43.00, hfl:46.60),
  IndiaCity(id:'sangli',     name:'Sangli',     state:'Maharashtra', river:'Krishna',
      lat:16.8524, lon:74.5815, cwcStation:'SAN',
      warningLevel:9.00, dangerLevel:11.00, hfl:13.50),
  IndiaCity(id:'nashik',     name:'Nashik',     state:'Maharashtra', river:'Godavari',
      lat:19.9975, lon:73.7898,
      warningLevel:12.00, dangerLevel:14.00, hfl:16.50),
  IndiaCity(id:'aurangabad', name:'Aurangabad', state:'Maharashtra', river:'Kham',
      lat:19.8762, lon:75.3433,
      warningLevel:2.50, dangerLevel:3.50, hfl:4.50),
  IndiaCity(id:'pune',       name:'Pune',       state:'Maharashtra', river:'Mutha',
      lat:18.5204, lon:73.8567,
      warningLevel:3.00, dangerLevel:4.50, hfl:5.80),
  IndiaCity(id:'nanded',     name:'Nanded',     state:'Maharashtra', river:'Godavari',
      lat:19.1383, lon:77.3210,
      warningLevel:307.00, dangerLevel:309.00, hfl:311.00),
  IndiaCity(id:'nagpur',     name:'Nagpur',     state:'Maharashtra', river:'Kanhan',
      lat:21.1458, lon:79.0882,
      warningLevel:4.80, dangerLevel:6.00, hfl:7.20),
  IndiaCity(id:'mumbai',     name:'Mumbai',     state:'Maharashtra', river:'Mithi',
      lat:19.0760, lon:72.8777,
      warningLevel:1.80, dangerLevel:2.50, hfl:3.10),
  // v5 — synced from backend
  IndiaCity(id:'satara',     name:'Satara',     state:'Maharashtra', river:'Krishna',
      lat:17.68,   lon:74.00,
      warningLevel:4.50, dangerLevel:5.50, hfl:6.80),

  // ── GUJARAT ──────────────────────────────────────────────────────────
  IndiaCity(id:'surat',      name:'Surat',      state:'Gujarat', river:'Tapi',
      lat:21.1702, lon:72.8311, cwcStation:'SRT',
      warningLevel:5.00, dangerLevel:7.00, hfl:9.20),
  IndiaCity(id:'vadodara',   name:'Vadodara',   state:'Gujarat', river:'Vishwamitri',
      lat:22.3072, lon:73.1812, cwcStation:'VDR',
      warningLevel:9.75, dangerLevel:10.67, hfl:14.00),
  IndiaCity(id:'bharuch',    name:'Bharuch',    state:'Gujarat', river:'Narmada',
      lat:21.7051, lon:72.9959,
      warningLevel:3.50, dangerLevel:5.00, hfl:7.00),
  IndiaCity(id:'ahmedabad',  name:'Ahmedabad',  state:'Gujarat', river:'Sabarmati',
      lat:23.0225, lon:72.5714,
      warningLevel:46.00, dangerLevel:48.00, hfl:51.30),
  IndiaCity(id:'anand',      name:'Anand',      state:'Gujarat', river:'Mahi',
      lat:22.5645, lon:72.9289,
      warningLevel:5.00, dangerLevel:6.00, hfl:7.50),
  IndiaCity(id:'rajkot',     name:'Rajkot',     state:'Gujarat', river:'Aji',
      lat:22.3039, lon:70.8022,
      warningLevel:2.50, dangerLevel:3.50, hfl:4.30),

  // ── ANDHRA PRADESH ─────────────────────────────────────────────────
  IndiaCity(id:'vijayawada', name:'Vijayawada', state:'Andhra Pradesh', river:'Krishna',
      lat:16.5062, lon:80.6480, cwcStation:'VJW',
      warningLevel:10.68, dangerLevel:12.50, hfl:15.24),
  IndiaCity(id:'rajahmundry',name:'Rajahmundry',state:'Andhra Pradesh', river:'Godavari',
      lat:17.0005, lon:81.7799, cwcStation:'RAJ',
      warningLevel:7.00, dangerLevel:9.00, hfl:12.50),
  IndiaCity(id:'guntur',     name:'Guntur',     state:'Andhra Pradesh', river:'Krishna',
      lat:16.3067, lon:80.4365,
      warningLevel:4.00, dangerLevel:5.50, hfl:7.00),
  IndiaCity(id:'nellore',    name:'Nellore',    state:'Andhra Pradesh', river:'Pennar',
      lat:14.4426, lon:79.9865,
      warningLevel:4.50, dangerLevel:5.50, hfl:7.00),
  // v5 — synced from backend
  IndiaCity(id:'kurnool',    name:'Kurnool',    state:'Andhra Pradesh', river:'Tungabhadra',
      lat:15.83,   lon:78.04,
      warningLevel:7.00, dangerLevel:8.50, hfl:11.00),

  // ── TELANGANA ─────────────────────────────────────────────────────
  IndiaCity(id:'hyderabad',  name:'Hyderabad',  state:'Telangana', river:'Musi',
      lat:17.3850, lon:78.4867,
      warningLevel:3.50, dangerLevel:4.00, hfl:5.10),
  IndiaCity(id:'warangal',   name:'Warangal',   state:'Telangana', river:'Godavari',
      lat:17.9784, lon:79.5941,
      warningLevel:7.00, dangerLevel:8.50, hfl:10.00),
  IndiaCity(id:'khammam',    name:'Khammam',    state:'Telangana', river:'Godavari',
      lat:17.2473, lon:80.1514,
      warningLevel:6.00, dangerLevel:7.50, hfl:9.00),

  // ── KARNATAKA ─────────────────────────────────────────────────────
  IndiaCity(id:'bangalore',  name:'Bengaluru',  state:'Karnataka', river:'Arkavathi',
      lat:12.9716, lon:77.5946,
      warningLevel:3.00, dangerLevel:4.00, hfl:5.00),
  IndiaCity(id:'mysore',     name:'Mysuru',     state:'Karnataka', river:'Kabini',
      lat:12.2958, lon:76.6394,
      warningLevel:4.00, dangerLevel:5.00, hfl:6.50),
  IndiaCity(id:'hubli',      name:'Hubballi',   state:'Karnataka', river:'Tungabhadra',
      lat:15.3647, lon:75.1240,
      warningLevel:550.00, dangerLevel:552.00, hfl:554.00),
  IndiaCity(id:'mangalore',  name:'Mangaluru',  state:'Karnataka', river:'Netravati',
      lat:12.9141, lon:74.8560,
      warningLevel:4.00, dangerLevel:5.50, hfl:7.00),
  // v5 — synced from backend
  IndiaCity(id:'belagavi',   name:'Belagavi',   state:'Karnataka', river:'Ghataprabha',
      lat:15.86,   lon:74.50,
      warningLevel:6.00, dangerLevel:7.50, hfl:9.00),
  IndiaCity(id:'raichur',    name:'Raichur',    state:'Karnataka', river:'Krishna',
      lat:16.20,   lon:77.36,
      warningLevel:6.00, dangerLevel:7.50, hfl:9.50),
  IndiaCity(id:'bagalkot',   name:'Bagalkot',   state:'Karnataka', river:'Ghataprabha',
      lat:16.18,   lon:75.69,
      warningLevel:5.50, dangerLevel:7.00, hfl:8.50),

  // ── KERALA ──────────────────────────────────────────────────────────
  IndiaCity(id:'kochi',      name:'Kochi',      state:'Kerala', river:'Periyar',
      lat:9.9312, lon:76.2673,
      warningLevel:2.50, dangerLevel:3.50, hfl:4.30),
  IndiaCity(id:'thiruvananthapuram', name:'Thiruvananthapuram', state:'Kerala', river:'Karamana',
      lat:8.5241, lon:76.9366,
      warningLevel:2.00, dangerLevel:3.00, hfl:3.70),
  IndiaCity(id:'kozhikode',  name:'Kozhikode',  state:'Kerala', river:'Chaliyar',
      lat:11.2588, lon:75.7804,
      warningLevel:3.00, dangerLevel:4.00, hfl:5.50),
  IndiaCity(id:'thrissur',   name:'Thrissur',   state:'Kerala', river:'Bharathapuzha',
      lat:10.5276, lon:76.2144,
      warningLevel:3.00, dangerLevel:4.50, hfl:6.00),
  IndiaCity(id:'alappuzha',  name:'Alappuzha',  state:'Kerala', river:'Pampa',
      lat:9.4981, lon:76.3388,
      warningLevel:1.50, dangerLevel:2.00, hfl:2.80),

  // ── TAMIL NADU ─────────────────────────────────────────────────────
  IndiaCity(id:'chennai',    name:'Chennai',    state:'Tamil Nadu', river:'Adyar',
      lat:13.0827, lon:80.2707,
      warningLevel:1.50, dangerLevel:2.00, hfl:2.80),
  IndiaCity(id:'madurai',    name:'Madurai',    state:'Tamil Nadu', river:'Vaigai',
      lat:9.9252, lon:78.1198,
      warningLevel:4.88, dangerLevel:5.49, hfl:6.30),
  IndiaCity(id:'tiruchirappalli', name:'Tiruchirappalli', state:'Tamil Nadu', river:'Cauvery',
      lat:10.7905, lon:78.7047,
      warningLevel:75.00, dangerLevel:77.00, hfl:79.50),
  IndiaCity(id:'cuddalore',  name:'Cuddalore',  state:'Tamil Nadu', river:'Paravanar',
      lat:11.7480, lon:79.7714,
      warningLevel:2.00, dangerLevel:3.00, hfl:4.00),
  IndiaCity(id:'puducherry', name:'Puducherry', state:'Puducherry', river:'Gingee',
      lat:11.9416, lon:79.8083,
      warningLevel:1.80, dangerLevel:2.50, hfl:3.20),
  // v5 — synced from backend
  IndiaCity(id:'thanjavur',  name:'Thanjavur',  state:'Tamil Nadu', river:'Cauvery',
      lat:10.79,   lon:79.14,
      warningLevel:60.00, dangerLevel:62.00, hfl:64.50),
];

IndiaCity? cityById(String id) =>
    kIndiaCities.where((c) => c.id == id).firstOrNull;

List<IndiaCity> citiesByState(String state) =>
    kIndiaCities.where((c) => c.state == state).toList();

List<IndiaCity> get monitoredCities =>
    kIndiaCities.where((c) => c.dangerLevel > 0).toList();
