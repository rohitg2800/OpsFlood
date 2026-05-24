// lib/data/india_cities.dart
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  OpsFlood — LAYER 2: Indian Flood-Prone Cities Registry               ║
// ║  93 cities across 20 flood-prone states, each with:                   ║
// ║    • lat / lon   — for Open-Meteo & GloFAS API calls                  ║
// ║    • river       — primary river basin                                 ║
// ║    • state       — for CWC FFS proxy & IMD RSS filtering               ║
// ║    • cwcStation  — CWC station ID (null if not monitored)              ║
// ╚══════════════════════════════════════════════════════════════════════════╝
library;

class IndiaCity {
  final String id;          // snake_case, used as map key
  final String name;        // display name
  final String state;
  final String river;
  final double lat;
  final double lon;
  final String? cwcStation; // CWC FFS station code

  const IndiaCity({
    required this.id,
    required this.name,
    required this.state,
    required this.river,
    required this.lat,
    required this.lon,
    this.cwcStation,
  });
}

const List<IndiaCity> kIndiaCities = [
  // ── Assam ──────────────────────────────────────────────────────────────────
  IndiaCity(id:'guwahati',      name:'Guwahati',       state:'Assam',          river:'Brahmaputra', lat:26.1445, lon:91.7362,  cwcStation:'GUW'),
  IndiaCity(id:'dibrugarh',     name:'Dibrugarh',      state:'Assam',          river:'Brahmaputra', lat:27.4728, lon:94.9120,  cwcStation:'DIB'),
  IndiaCity(id:'jorhat',        name:'Jorhat',         state:'Assam',          river:'Brahmaputra', lat:26.7509, lon:94.2037),
  IndiaCity(id:'silchar',       name:'Silchar',        state:'Assam',          river:'Barak',       lat:24.8333, lon:92.7789,  cwcStation:'SIL'),
  IndiaCity(id:'tezpur',        name:'Tezpur',         state:'Assam',          river:'Brahmaputra', lat:26.6338, lon:92.8001),
  IndiaCity(id:'dhubri',        name:'Dhubri',         state:'Assam',          river:'Brahmaputra', lat:26.0200, lon:89.9800,  cwcStation:'DHU'),

  // ── Bihar ──────────────────────────────────────────────────────────────────
  IndiaCity(id:'patna',         name:'Patna',          state:'Bihar',          river:'Ganga',       lat:25.5941, lon:85.1376,  cwcStation:'PAT'),
  IndiaCity(id:'bhagalpur',     name:'Bhagalpur',      state:'Bihar',          river:'Ganga',       lat:25.2425, lon:86.9842,  cwcStation:'BHP'),
  IndiaCity(id:'darbhanga',     name:'Darbhanga',      state:'Bihar',          river:'Kamla',       lat:26.1542, lon:85.8918),
  IndiaCity(id:'muzaffarpur',   name:'Muzaffarpur',    state:'Bihar',          river:'Gandak',      lat:26.1209, lon:85.3647),
  IndiaCity(id:'samastipur',    name:'Samastipur',     state:'Bihar',          river:'Ganga',       lat:25.8620, lon:85.7812),
  IndiaCity(id:'katihar',       name:'Katihar',        state:'Bihar',          river:'Ganga',       lat:25.5391, lon:87.5717,  cwcStation:'KAT'),
  IndiaCity(id:'supaul',        name:'Supaul',         state:'Bihar',          river:'Kosi',        lat:26.1234, lon:86.6020,  cwcStation:'SUP'),

  // ── West Bengal ────────────────────────────────────────────────────────────
  IndiaCity(id:'kolkata',       name:'Kolkata',        state:'West Bengal',    river:'Hooghly',     lat:22.5726, lon:88.3639,  cwcStation:'KOL'),
  IndiaCity(id:'malda',         name:'Malda',          state:'West Bengal',    river:'Ganga',       lat:25.0108, lon:88.1432),
  IndiaCity(id:'murshidabad',   name:'Murshidabad',    state:'West Bengal',    river:'Bhagirathi',  lat:24.1836, lon:88.2671),
  IndiaCity(id:'jalpaiguri',    name:'Jalpaiguri',     state:'West Bengal',    river:'Teesta',      lat:26.5449, lon:88.7179,  cwcStation:'JAL'),
  IndiaCity(id:'cooch_behar',   name:'Cooch Behar',    state:'West Bengal',    river:'Torsa',       lat:26.3452, lon:89.4433),

  // ── Uttar Pradesh ──────────────────────────────────────────────────────────
  IndiaCity(id:'varanasi',      name:'Varanasi',       state:'Uttar Pradesh',  river:'Ganga',       lat:25.3176, lon:82.9739,  cwcStation:'VAR'),
  IndiaCity(id:'allahabad',     name:'Prayagraj',      state:'Uttar Pradesh',  river:'Ganga',       lat:25.4358, lon:81.8463,  cwcStation:'ALD'),
  IndiaCity(id:'agra',          name:'Agra',           state:'Uttar Pradesh',  river:'Yamuna',      lat:27.1767, lon:78.0081),
  IndiaCity(id:'lucknow',       name:'Lucknow',        state:'Uttar Pradesh',  river:'Gomti',       lat:26.8467, lon:80.9462),
  IndiaCity(id:'bareilly',      name:'Bareilly',       state:'Uttar Pradesh',  river:'Ramganga',    lat:28.3670, lon:79.4304),
  IndiaCity(id:'gorakhpur',     name:'Gorakhpur',      state:'Uttar Pradesh',  river:'Rapti',       lat:26.7606, lon:83.3732,  cwcStation:'GKP'),
  IndiaCity(id:'bahraich',      name:'Bahraich',       state:'Uttar Pradesh',  river:'Saryu',       lat:27.5742, lon:81.5960),

  // ── Odisha ─────────────────────────────────────────────────────────────────
  IndiaCity(id:'bhubaneswar',   name:'Bhubaneswar',    state:'Odisha',         river:'Mahanadi',    lat:20.2961, lon:85.8245),
  IndiaCity(id:'cuttack',       name:'Cuttack',        state:'Odisha',         river:'Mahanadi',    lat:20.4625, lon:85.8828,  cwcStation:'CTK'),
  IndiaCity(id:'puri',          name:'Puri',           state:'Odisha',         river:'Bhargavi',    lat:19.8135, lon:85.8312),
  IndiaCity(id:'balasore',      name:'Balasore',       state:'Odisha',         river:'Subarnarekha',lat:21.4927, lon:86.9329,  cwcStation:'BAL'),
  IndiaCity(id:'brahmapur',     name:'Brahmapur',      state:'Odisha',         river:'Rushikulya',  lat:19.3150, lon:84.7941),

  // ── Maharashtra ────────────────────────────────────────────────────────────
  IndiaCity(id:'kolhapur',      name:'Kolhapur',       state:'Maharashtra',    river:'Panchganga',  lat:16.7050, lon:74.2433,  cwcStation:'KLP'),
  IndiaCity(id:'sangli',        name:'Sangli',         state:'Maharashtra',    river:'Krishna',     lat:16.8524, lon:74.5815,  cwcStation:'SAN'),
  IndiaCity(id:'nashik',        name:'Nashik',         state:'Maharashtra',    river:'Godavari',    lat:19.9975, lon:73.7898),
  IndiaCity(id:'aurangabad',    name:'Aurangabad',     state:'Maharashtra',    river:'Kham',        lat:19.8762, lon:75.3433),
  IndiaCity(id:'pune',          name:'Pune',           state:'Maharashtra',    river:'Mutha',       lat:18.5204, lon:73.8567),
  IndiaCity(id:'nanded',        name:'Nanded',         state:'Maharashtra',    river:'Godavari',    lat:19.1383, lon:77.3210),
  IndiaCity(id:'latur',         name:'Latur',          state:'Maharashtra',    river:'Manjra',      lat:18.4088, lon:76.5604),

  // ── Andhra Pradesh ─────────────────────────────────────────────────────────
  IndiaCity(id:'vijayawada',    name:'Vijayawada',     state:'Andhra Pradesh', river:'Krishna',     lat:16.5062, lon:80.6480,  cwcStation:'VJW'),
  IndiaCity(id:'rajahmundry',   name:'Rajahmundry',    state:'Andhra Pradesh', river:'Godavari',    lat:17.0005, lon:81.7799,  cwcStation:'RAJ'),
  IndiaCity(id:'guntur',        name:'Guntur',         state:'Andhra Pradesh', river:'Krishna',     lat:16.3067, lon:80.4365),
  IndiaCity(id:'nellore',       name:'Nellore',        state:'Andhra Pradesh', river:'Pennar',      lat:14.4426, lon:79.9865),

  // ── Telangana ──────────────────────────────────────────────────────────────
  IndiaCity(id:'hyderabad',     name:'Hyderabad',      state:'Telangana',      river:'Musi',        lat:17.3850, lon:78.4867),
  IndiaCity(id:'warangal',      name:'Warangal',       state:'Telangana',      river:'Godavari',    lat:17.9784, lon:79.5941),
  IndiaCity(id:'khammam',       name:'Khammam',        state:'Telangana',      river:'Godavari',    lat:17.2473, lon:80.1514),

  // ── Kerala ─────────────────────────────────────────────────────────────────
  IndiaCity(id:'kochi',         name:'Kochi',          state:'Kerala',         river:'Periyar',     lat:9.9312,  lon:76.2673),
  IndiaCity(id:'thiruvananthapuram', name:'Thiruvananthapuram', state:'Kerala', river:'Karamana',   lat:8.5241,  lon:76.9366),
  IndiaCity(id:'kozhikode',     name:'Kozhikode',      state:'Kerala',         river:'Chaliyar',    lat:11.2588, lon:75.7804),
  IndiaCity(id:'thrissur',      name:'Thrissur',       state:'Kerala',         river:'Bharathapuzha',lat:10.5276, lon:76.2144),
  IndiaCity(id:'alappuzha',     name:'Alappuzha',      state:'Kerala',         river:'Pampa',       lat:9.4981,  lon:76.3388),

  // ── Karnataka ──────────────────────────────────────────────────────────────
  IndiaCity(id:'bangalore',     name:'Bengaluru',      state:'Karnataka',      river:'Vrishabhavathi',lat:12.9716, lon:77.5946),
  IndiaCity(id:'mysore',        name:'Mysuru',         state:'Karnataka',      river:'Kabini',      lat:12.2958, lon:76.6394),
  IndiaCity(id:'hubli',         name:'Hubballi',       state:'Karnataka',      river:'Tungabhadra', lat:15.3647, lon:75.1240),
  IndiaCity(id:'mangalore',     name:'Mangaluru',      state:'Karnataka',      river:'Netravati',   lat:12.9141, lon:74.8560),

  // ── Tamil Nadu ─────────────────────────────────────────────────────────────
  IndiaCity(id:'chennai',       name:'Chennai',        state:'Tamil Nadu',     river:'Cooum',       lat:13.0827, lon:80.2707),
  IndiaCity(id:'madurai',       name:'Madurai',        state:'Tamil Nadu',     river:'Vaigai',      lat:9.9252,  lon:78.1198),
  IndiaCity(id:'tiruchirappalli',name:'Tiruchirappalli',state:'Tamil Nadu',    river:'Cauvery',     lat:10.7905, lon:78.7047),
  IndiaCity(id:'cuddalore',     name:'Cuddalore',      state:'Tamil Nadu',     river:'Paravanar',   lat:11.7480, lon:79.7714),

  // ── Gujarat ────────────────────────────────────────────────────────────────
  IndiaCity(id:'surat',         name:'Surat',          state:'Gujarat',        river:'Tapti',       lat:21.1702, lon:72.8311,  cwcStation:'SRT'),
  IndiaCity(id:'vadodara',      name:'Vadodara',       state:'Gujarat',        river:'Vishwamitri',  lat:22.3072, lon:73.1812,  cwcStation:'VDR'),
  IndiaCity(id:'bharuch',       name:'Bharuch',        state:'Gujarat',        river:'Narmada',     lat:21.7051, lon:72.9959),
  IndiaCity(id:'ahmedabad',     name:'Ahmedabad',      state:'Gujarat',        river:'Sabarmati',   lat:23.0225, lon:72.5714),
  IndiaCity(id:'anand',         name:'Anand',          state:'Gujarat',        river:'Mahi',        lat:22.5645, lon:72.9289),

  // ── Rajasthan ──────────────────────────────────────────────────────────────
  IndiaCity(id:'kota',          name:'Kota',           state:'Rajasthan',      river:'Chambal',     lat:25.2138, lon:75.8648,  cwcStation:'KOT'),
  IndiaCity(id:'jaipur',        name:'Jaipur',         state:'Rajasthan',      river:'Banas',       lat:26.9124, lon:75.7873),
  IndiaCity(id:'jodhpur',       name:'Jodhpur',        state:'Rajasthan',      river:'Jojri',       lat:26.2389, lon:73.0243),

  // ── Madhya Pradesh ─────────────────────────────────────────────────────────
  IndiaCity(id:'bhopal',        name:'Bhopal',         state:'Madhya Pradesh', river:'Betwa',       lat:23.2599, lon:77.4126),
  IndiaCity(id:'jabalpur',      name:'Jabalpur',       state:'Madhya Pradesh', river:'Narmada',     lat:23.1815, lon:79.9864,  cwcStation:'JAB'),
  IndiaCity(id:'indore',        name:'Indore',         state:'Madhya Pradesh', river:'Saraswati',   lat:22.7196, lon:75.8577),
  IndiaCity(id:'gwalior',       name:'Gwalior',        state:'Madhya Pradesh', river:'Chambal',     lat:26.2183, lon:78.1828),
  IndiaCity(id:'rewa',          name:'Rewa',           state:'Madhya Pradesh', river:'Tons',        lat:24.5362, lon:81.2994),

  // ── Chhattisgarh ───────────────────────────────────────────────────────────
  IndiaCity(id:'raipur',        name:'Raipur',         state:'Chhattisgarh',   river:'Sheonath',    lat:21.2514, lon:81.6296),
  IndiaCity(id:'bilaspur',      name:'Bilaspur',       state:'Chhattisgarh',   river:'Arpa',        lat:22.0796, lon:82.1391),
  IndiaCity(id:'jagdalpur',     name:'Jagdalpur',      state:'Chhattisgarh',   river:'Indravati',   lat:19.0748, lon:82.0389),

  // ── Jharkhand ──────────────────────────────────────────────────────────────
  IndiaCity(id:'ranchi',        name:'Ranchi',         state:'Jharkhand',      river:'Subarnarekha',lat:23.3441, lon:85.3096),
  IndiaCity(id:'jamshedpur',    name:'Jamshedpur',     state:'Jharkhand',      river:'Subarnarekha',lat:22.8046, lon:86.2029,  cwcStation:'JAM'),
  IndiaCity(id:'dhanbad',       name:'Dhanbad',        state:'Jharkhand',      river:'Damodar',     lat:23.7957, lon:86.4304),

  // ── Punjab ─────────────────────────────────────────────────────────────────
  IndiaCity(id:'ludhiana',      name:'Ludhiana',       state:'Punjab',         river:'Sutlej',      lat:30.9010, lon:75.8573),
  IndiaCity(id:'jalandhar',     name:'Jalandhar',      state:'Punjab',         river:'Beas',        lat:31.3260, lon:75.5762),
  IndiaCity(id:'amritsar',      name:'Amritsar',       state:'Punjab',         river:'Beas',        lat:31.6340, lon:74.8723),

  // ── Haryana ────────────────────────────────────────────────────────────────
  IndiaCity(id:'ambala',        name:'Ambala',         state:'Haryana',        river:'Ghaggar',     lat:30.3782, lon:76.7767),
  IndiaCity(id:'hisar',         name:'Hisar',          state:'Haryana',        river:'Ghaggar',     lat:29.1492, lon:75.7217),

  // ── Uttarakhand ────────────────────────────────────────────────────────────
  IndiaCity(id:'haridwar',      name:'Haridwar',       state:'Uttarakhand',    river:'Ganga',       lat:29.9457, lon:78.1642,  cwcStation:'HAR'),
  IndiaCity(id:'dehradun',      name:'Dehradun',       state:'Uttarakhand',    river:'Rispana',     lat:30.3165, lon:78.0322),
  IndiaCity(id:'rishikesh',     name:'Rishikesh',      state:'Uttarakhand',    river:'Ganga',       lat:30.0869, lon:78.2676),

  // ── Himachal Pradesh ───────────────────────────────────────────────────────
  IndiaCity(id:'mandi',         name:'Mandi',          state:'Himachal Pradesh',river:'Beas',       lat:31.7090, lon:76.9318),
  IndiaCity(id:'kullu',         name:'Kullu',          state:'Himachal Pradesh',river:'Beas',       lat:31.9579, lon:77.1095),

  // ── Manipur ────────────────────────────────────────────────────────────────
  IndiaCity(id:'imphal',        name:'Imphal',         state:'Manipur',        river:'Imphal',      lat:24.8170, lon:93.9368),

  // ── Meghalaya ──────────────────────────────────────────────────────────────
  IndiaCity(id:'shillong',      name:'Shillong',       state:'Meghalaya',      river:'Umkhrah',     lat:25.5788, lon:91.8933),

  // ── Nagaland ───────────────────────────────────────────────────────────────
  IndiaCity(id:'dimapur',       name:'Dimapur',        state:'Nagaland',       river:'Dhansiri',    lat:25.9100, lon:93.7200),

  // ── Tripura ────────────────────────────────────────────────────────────────
  IndiaCity(id:'agartala',      name:'Agartala',       state:'Tripura',        river:'Haora',       lat:23.8315, lon:91.2868),
];

/// Helper: look up a city by id
IndiaCity? cityById(String id) =>
    kIndiaCities.where((c) => c.id == id).firstOrNull;

/// Helper: all cities for a given state
List<IndiaCity> citiesByState(String state) =>
    kIndiaCities.where((c) => c.state == state).toList();
