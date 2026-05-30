// lib/data/india_cities.dart
//
// OpsFlood — Bihar Flood-Prone Cities Registry (v6 — Bihar only)
//
// Only Bihar WRD / CWC monitored stations are kept.
// All other states have been removed.
//
// Fields:
//   lat / lon        — city centroid for Open-Meteo & GloFAS API calls
//   river            — primary flood river (CWC / WRD Bihar published names)
//   state            — always 'Bihar'
//   cwcStation       — CWC FFS station code (null if not CWC-monitored)
//   warningLevel     — WRD / CWC published warning gauge (m MSL)
//   dangerLevel      — WRD / CWC published danger gauge (m MSL)
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

  // ── BIHAR ────────────────────────────────────────────────────────────
  IndiaCity(id:'patna',       name:'Patna',       state:'Bihar', river:'Ganga',
      lat:25.5941, lon:85.1376, cwcStation:'PAT',
      warningLevel:47.50, dangerLevel:48.60, hfl:50.52),

  IndiaCity(id:'bhagalpur',   name:'Bhagalpur',   state:'Bihar', river:'Ganga',
      lat:25.2425, lon:86.9842, cwcStation:'BHP',
      warningLevel:32.50, dangerLevel:33.68, hfl:34.86),

  IndiaCity(id:'darbhanga',   name:'Darbhanga',   state:'Bihar', river:'Bagmati',
      lat:26.1542, lon:85.8918,
      warningLevel:44.50, dangerLevel:45.72, hfl:48.96),

  IndiaCity(id:'muzaffarpur', name:'Muzaffarpur', state:'Bihar', river:'Burhi Gandak',
      lat:26.1209, lon:85.3647,
      warningLevel:51.40, dangerLevel:52.53, hfl:54.29),

  IndiaCity(id:'samastipur',  name:'Samastipur',  state:'Bihar', river:'Burhi Gandak',
      lat:25.8620, lon:85.7812,
      warningLevel:44.80, dangerLevel:46.00, hfl:49.40),

  IndiaCity(id:'katihar',     name:'Katihar',     state:'Bihar', river:'Kosi',
      lat:25.5391, lon:87.5717, cwcStation:'KAT',
      warningLevel:28.80, dangerLevel:30.00, hfl:32.10),

  IndiaCity(id:'supaul',      name:'Supaul',      state:'Bihar', river:'Kosi',
      lat:26.1234, lon:86.6020, cwcStation:'SUP',
      warningLevel:46.50, dangerLevel:47.75, hfl:49.24),

  IndiaCity(id:'sitamarhi',   name:'Sitamarhi',   state:'Bihar', river:'Bagmati',
      lat:26.5800, lon:85.4900,
      warningLevel:70.00, dangerLevel:71.00, hfl:73.47),

  IndiaCity(id:'gopalganj',   name:'Gopalganj',   state:'Bihar', river:'Gandak',
      lat:26.4833, lon:84.4667,
      warningLevel:61.10, dangerLevel:62.22, hfl:63.70),

  IndiaCity(id:'purnia',      name:'Purnia',      state:'Bihar', river:'Mahananda',
      lat:25.7800, lon:87.4800,
      warningLevel:34.65, dangerLevel:35.65, hfl:38.20),

  IndiaCity(id:'siwan',       name:'Siwan',       state:'Bihar', river:'Ghaghra',
      lat:26.2200, lon:84.3600,
      warningLevel:59.80, dangerLevel:60.82, hfl:61.82),

  IndiaCity(id:'madhubani',   name:'Madhubani',   state:'Bihar', river:'Kamla',
      lat:26.3500, lon:86.0700,
      warningLevel:66.00, dangerLevel:67.75, hfl:71.35),

  IndiaCity(id:'khagaria',    name:'Khagaria',    state:'Bihar', river:'Burhi Gandak',
      lat:25.5000, lon:86.4700,
      warningLevel:35.40, dangerLevel:36.58, hfl:39.22),

  IndiaCity(id:'gaya',        name:'Gaya',        state:'Bihar', river:'Falgu',
      lat:24.7900, lon:85.0000,
      warningLevel:94.00, dangerLevel:96.00, hfl:98.50),

  IndiaCity(id:'begusarai',   name:'Begusarai',   state:'Bihar', river:'Ganga',
      lat:25.4100, lon:86.1300,
      warningLevel:33.00, dangerLevel:34.50, hfl:36.00),

  IndiaCity(id:'hajipur',     name:'Hajipur',     state:'Bihar', river:'Gandak',
      lat:25.6833, lon:85.2167,
      warningLevel:50.40, dangerLevel:52.00, hfl:54.00),

  IndiaCity(id:'bettiah',     name:'Bettiah',     state:'Bihar', river:'Gandak',
      lat:26.8000, lon:84.5000,
      warningLevel:63.00, dangerLevel:64.50, hfl:66.00),

  IndiaCity(id:'motihari',    name:'Motihari',    state:'Bihar', river:'Burhi Gandak',
      lat:26.6500, lon:84.9200,
      warningLevel:60.00, dangerLevel:61.50, hfl:63.00),

  IndiaCity(id:'munger',      name:'Munger',      state:'Bihar', river:'Ganga',
      lat:25.3700, lon:86.4700, cwcStation:'MNG',
      warningLevel:36.60, dangerLevel:38.10, hfl:40.00),

  IndiaCity(id:'purnea',      name:'Purnea',      state:'Bihar', river:'Mahananda',
      lat:25.7800, lon:87.4800,
      warningLevel:34.65, dangerLevel:35.65, hfl:38.20),

  IndiaCity(id:'araria',      name:'Araria',      state:'Bihar', river:'Kosi',
      lat:26.1500, lon:87.5200,
      warningLevel:48.00, dangerLevel:49.50, hfl:51.00),

  IndiaCity(id:'kishanganj',  name:'Kishanganj',  state:'Bihar', river:'Mahananda',
      lat:26.1000, lon:87.9400,
      warningLevel:30.00, dangerLevel:31.50, hfl:33.50),

  IndiaCity(id:'chapra',      name:'Chapra',      state:'Bihar', river:'Ghaghra',
      lat:25.7800, lon:84.7500,
      warningLevel:57.50, dangerLevel:59.00, hfl:61.00),

  IndiaCity(id:'vaishali',    name:'Vaishali',    state:'Bihar', river:'Gandak',
      lat:25.6800, lon:85.1700,
      warningLevel:49.00, dangerLevel:50.50, hfl:52.00),

  IndiaCity(id:'nawada',      name:'Nawada',      state:'Bihar', river:'Panchane',
      lat:24.8800, lon:85.5400,
      warningLevel:82.00, dangerLevel:84.00, hfl:86.00),

  IndiaCity(id:'aurangabad_br', name:'Aurangabad', state:'Bihar', river:'Sone',
      lat:24.7500, lon:84.3700,
      warningLevel:78.00, dangerLevel:80.00, hfl:82.50),

  IndiaCity(id:'rohtas',      name:'Rohtas',      state:'Bihar', river:'Sone',
      lat:24.9500, lon:83.8000,
      warningLevel:68.00, dangerLevel:70.00, hfl:72.00),

  IndiaCity(id:'buxar',       name:'Buxar',       state:'Bihar', river:'Ganga',
      lat:25.5600, lon:83.9800, cwcStation:'BUX',
      warningLevel:55.00, dangerLevel:56.50, hfl:59.00),

  IndiaCity(id:'bhojpur',     name:'Bhojpur',     state:'Bihar', river:'Sone',
      lat:25.5500, lon:84.4500,
      warningLevel:52.00, dangerLevel:53.50, hfl:55.00),

  IndiaCity(id:'nalanda',     name:'Nalanda',     state:'Bihar', river:'Panchane',
      lat:25.1000, lon:85.4400,
      warningLevel:62.00, dangerLevel:64.00, hfl:66.00),

  IndiaCity(id:'sheikhpura',  name:'Sheikhpura',  state:'Bihar', river:'Ulai',
      lat:25.1400, lon:85.8500,
      warningLevel:42.00, dangerLevel:44.00, hfl:46.00),

  IndiaCity(id:'lakhisarai',  name:'Lakhisarai',  state:'Bihar', river:'Kiul',
      lat:25.1600, lon:86.0900,
      warningLevel:38.00, dangerLevel:40.00, hfl:42.00),

  IndiaCity(id:'jamui',       name:'Jamui',       state:'Bihar', river:'Kiul',
      lat:24.9200, lon:86.2200,
      warningLevel:85.00, dangerLevel:87.00, hfl:89.00),

  IndiaCity(id:'banka',       name:'Banka',       state:'Bihar', river:'Chandan',
      lat:24.8800, lon:86.9200,
      warningLevel:80.00, dangerLevel:82.00, hfl:84.00),
];

IndiaCity? cityById(String id) =>
    kIndiaCities.where((c) => c.id == id).firstOrNull;

List<IndiaCity> citiesByState(String state) =>
    kIndiaCities.where((c) => c.state == state).toList();

List<IndiaCity> get monitoredCities =>
    kIndiaCities.where((c) => c.dangerLevel > 0).toList();
