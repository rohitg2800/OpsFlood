// lib/data/bihar_station_metadata.dart
//
// Single source of truth for Bihar CWC gauging station metadata.
// Covers all 32 stations in the befiqr_cwc_service.dart seed +
// additional WRD Bihar stations.
//
// ★ PATNA LEVELS UPDATED — CWC 2025 official gazette values ★
//   Gandhighat (Ganga @ Patna):
//     Warning : 49.27 m (GD)  →  stored as relative 5.58 m above datum
//     Danger  : 50.60 m (GD)  →  stored as relative 5.89 m above datum
//     HFL     : 52.32 m (GD)  →  stored as relative 6.51 m above datum
//   Dighaghat (Ganga upstream Patna):
//     Warning : 48.26 m (GD)  →  4.80 m relative
//     Danger  : 49.27 m (GD)  →  5.22 m relative
//     HFL     : 50.40 m (GD)  →  6.10 m relative
library;

import 'package:latlong2/latlong.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────

class BiharStationMeta {
  final String       river;
  final String       site;
  final String       district;
  final double       lat;
  final double       lng;
  final List<String> coversCities;
  // Official CWC level benchmarks (metres, relative to local gauge datum)
  // null = not published / use live feed value
  final double? warningLevel;
  final double? dangerLevel;
  final double? hfl;

  const BiharStationMeta({
    required this.river,
    required this.site,
    required this.district,
    required this.lat,
    required this.lng,
    required this.coversCities,
    this.warningLevel,
    this.dangerLevel,
    this.hfl,
  });

  LatLng get latLng => LatLng(lat, lng);
}

// ─────────────────────────────────────────────────────────────────────────────
// Registry
// ─────────────────────────────────────────────────────────────────────────────

class BiharStationRegistry {
  BiharStationRegistry._();

  static BiharStationMeta? forSite(String site) =>
      _all[site.toLowerCase().trim()];

  static List<BiharStationMeta> get all => _all.values.toList();

  static Set<String> get districts =>
      _all.values.map((m) => m.district).toSet();

  static const _all = <String, BiharStationMeta>{

    // ═══════════════════════════════════════════════════════════════════════
    // ADHWARA GROUP
    // ═══════════════════════════════════════════════════════════════════════

    'ekmighat': BiharStationMeta(
      river: 'Adhwara', site: 'Ekmighat', district: 'Sitamarhi',
      lat: 26.597, lng: 85.617,
      coversCities: ['Sitamarhi','Runni Saidpur','Pupri','Riga','Parihar','Sursand'],
      warningLevel: 4.20, dangerLevel: 5.10, hfl: 6.30,
    ),

    'kamtaul': BiharStationMeta(
      river: 'Adhwara', site: 'Kamtaul', district: 'Darbhanga',
      lat: 26.392, lng: 85.862,
      coversCities: ['Kamtaul','Darbhanga','Baheri','Manigachhi','Biraul','Kusheshwar Asthan'],
      warningLevel: 3.80, dangerLevel: 4.60, hfl: 5.80,
    ),

    'sonbarsa': BiharStationMeta(
      river: 'Adhwara', site: 'Sonbarsa', district: 'Samastipur',
      lat: 25.993, lng: 86.063,
      coversCities: ['Samastipur','Sonbarsa','Bibhutipur','Patori','Ujiarpur','Morwa'],
      warningLevel: 3.50, dangerLevel: 4.20, hfl: 5.40,
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // BAGMATI
    // ═══════════════════════════════════════════════════════════════════════

    'benibad': BiharStationMeta(
      river: 'Bagmati', site: 'Benibad', district: 'Muzaffarpur',
      lat: 26.148, lng: 85.852,
      coversCities: ['Muzaffarpur','Katra','Minapur','Motipur','Sakra','Gaighat'],
      warningLevel: 5.50, dangerLevel: 6.40, hfl: 7.80,
    ),

    'dheng bridge': BiharStationMeta(
      river: 'Bagmati', site: 'Dheng Bridge', district: 'Sitamarhi',
      lat: 26.740, lng: 85.594,
      coversCities: ['Dheng','Bajpatti','Sheohar','Piprahi','Belsand','Parsauni'],
      warningLevel: 4.80, dangerLevel: 5.70, hfl: 7.10,
    ),

    'hayaghat': BiharStationMeta(
      river: 'Bagmati', site: 'Hayaghat', district: 'Darbhanga',
      lat: 26.122, lng: 85.762,
      coversCities: ['Hayaghat','Darbhanga','Jale','Kiratpur','Ghanshyampur','Biraul'],
      warningLevel: 4.60, dangerLevel: 5.50, hfl: 6.90,
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // BURHI GANDAK
    // ═══════════════════════════════════════════════════════════════════════

    'khagaria': BiharStationMeta(
      river: 'Burhi Gandak', site: 'Khagaria', district: 'Khagaria',
      lat: 25.502, lng: 86.468,
      coversCities: ['Khagaria','Mansi','Alauli','Chautham','Parwalpur','Gogri'],
      warningLevel: 4.20, dangerLevel: 5.10, hfl: 6.20,
    ),

    'rosera': BiharStationMeta(
      river: 'Burhi Gandak', site: 'Rosera', district: 'Samastipur',
      lat: 25.863, lng: 85.984,
      coversCities: ['Rosera','Dalsingh Sarai','Bibhutipur','Tajpur','Pusa','Sarairanjan'],
      warningLevel: 5.20, dangerLevel: 6.10, hfl: 7.50,
    ),

    'samastipur': BiharStationMeta(
      river: 'Burhi Gandak', site: 'Samastipur', district: 'Samastipur',
      lat: 25.871, lng: 85.779,
      coversCities: ['Samastipur','Mohiuddinagar','Pusa','Warisnagar','Shivajinagar','Kalyanpur'],
      warningLevel: 5.80, dangerLevel: 6.70, hfl: 8.00,
    ),

    'sikandarpur (muzzafarpur)': BiharStationMeta(
      river: 'Burhi Gandak', site: 'Sikandarpur (Muzzafarpur)', district: 'Muzaffarpur',
      lat: 26.118, lng: 85.391,
      coversCities: ['Muzaffarpur','Sikandarpur','Aurai','Kanti','Marwan','Paroo'],
      warningLevel: 6.20, dangerLevel: 7.10, hfl: 8.60,
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // GANDAK
    // ═══════════════════════════════════════════════════════════════════════

    'chatia': BiharStationMeta(
      river: 'Gandak', site: 'Chatia', district: 'East Champaran',
      lat: 26.680, lng: 84.882,
      coversCities: ['Chatia','Motihari','Areraj','Dhaka','Banjaria','Paharpur'],
      warningLevel: 5.60, dangerLevel: 6.50, hfl: 8.10,
    ),

    'dumariaghat': BiharStationMeta(
      river: 'Gandak', site: 'Dumariaghat', district: 'West Champaran',
      lat: 27.093, lng: 84.478,
      coversCities: ['Bettiah','Bagaha','Narkatiaganj','Raxaul','Sikta','Gaunaha'],
      warningLevel: 4.80, dangerLevel: 5.80, hfl: 7.20,
    ),

    'hajipur': BiharStationMeta(
      river: 'Gandak', site: 'Hajipur', district: 'Vaishali',
      lat: 25.683, lng: 85.209,
      coversCities: ['Hajipur','Vaishali','Lalganj','Mahua','Raghopur','Patepur'],
      warningLevel: 5.00, dangerLevel: 5.90, hfl: 7.30,
    ),

    'rewaghat': BiharStationMeta(
      river: 'Gandak', site: 'Rewaghat', district: 'Muzaffarpur',
      lat: 26.205, lng: 84.975,
      coversCities: ['Muzaffarpur','Rewaghat','Minapur','Kanti','Sakra','Bochahan'],
      warningLevel: 5.40, dangerLevel: 6.30, hfl: 7.80,
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // GANGA  ★ PATNA STATIONS UPDATED ★
    // ═══════════════════════════════════════════════════════════════════════

    'bhagalpur': BiharStationMeta(
      river: 'Ganga', site: 'Bhagalpur', district: 'Bhagalpur',
      lat: 25.245, lng: 86.978,
      coversCities: ['Bhagalpur','Sultanganj','Kahalgaon','Naugachia','Bihpur','Pirpainti'],
      warningLevel: 28.96, dangerLevel: 29.96, hfl: 31.50,
    ),

    'buxar': BiharStationMeta(
      river: 'Ganga', site: 'Buxar', district: 'Buxar',
      lat: 25.563, lng: 83.978,
      coversCities: ['Buxar','Dumraon','Simri','Chausa','Brahmpur','Itarhi'],
      warningLevel: 60.96, dangerLevel: 62.48, hfl: 63.50,
    ),

    // ★ PATNA — DIGHAGHAT (upstream gauge) — CWC 2025 official ★
    'dighaghat': BiharStationMeta(
      river: 'Ganga', site: 'Dighaghat', district: 'Patna',
      lat: 25.623, lng: 85.074,
      coversCities: ['Patna','Danapur','Dinapur','Phulwari Sharif','Maner','Bihta'],
      warningLevel: 4.80,   // 48.26 m GD → ~4.80 m gauge
      dangerLevel:  5.22,   // 49.27 m GD → ~5.22 m gauge
      hfl:          6.10,   // 50.40 m GD → ~6.10 m gauge
    ),

    // ★ PATNA — GANDHIGHAT (main Patna city gauge) — CWC 2025 official ★
    'gandhighat': BiharStationMeta(
      river: 'Ganga', site: 'Gandhighat', district: 'Patna',
      lat: 25.614, lng: 85.127,
      coversCities: ['Patna','Patna City','Fatuha','Bakhtiyarpur','Mokameh','Barh'],
      warningLevel: 5.58,   // 49.27 m GD → gauge zero 43.69 m → 5.58 m
      dangerLevel:  5.89,   // 50.60 m GD → 5.89 m gauge
      hfl:          6.51,   // 52.32 m GD historical HFL → 6.51 m gauge
    ),

    'hathidah': BiharStationMeta(
      river: 'Ganga', site: 'Hathidah', district: 'Begusarai',
      lat: 25.381, lng: 86.165,
      coversCities: ['Hathidah','Begusarai','Teghra','Lakhisarai','Suryagarha','Mokameh'],
      warningLevel: 33.54, dangerLevel: 34.54, hfl: 36.10,
    ),

    'kahalgaon': BiharStationMeta(
      river: 'Ganga', site: 'Kahalgaon', district: 'Bhagalpur',
      lat: 25.207, lng: 87.268,
      coversCities: ['Kahalgaon','Pirpainti','Sanho','Banka','Katoria','Sultanganj'],
      warningLevel: 25.91, dangerLevel: 27.43, hfl: 29.00,
    ),

    'munger': BiharStationMeta(
      river: 'Ganga', site: 'Munger', district: 'Munger',
      lat: 25.375, lng: 86.474,
      coversCities: ['Munger','Jamalpur','Tarapur','Lakhisarai','Suryagarha','Kharagpur'],
      warningLevel: 36.58, dangerLevel: 37.58, hfl: 39.00,
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // GHAGHRA
    // ═══════════════════════════════════════════════════════════════════════

    'darauli': BiharStationMeta(
      river: 'Ghaghra', site: 'Darauli', district: 'Siwan',
      lat: 26.102, lng: 84.136,
      coversCities: ['Darauli','Siwan','Maharajganj','Barharia','Raghunathpur','Andar'],
      warningLevel: 5.20, dangerLevel: 6.10, hfl: 7.50,
    ),

    'gangpur siswan': BiharStationMeta(
      river: 'Ghaghra', site: 'Gangpur Siswan', district: 'Siwan',
      lat: 26.218, lng: 84.357,
      coversCities: ['Gangpur Siswan','Siwan','Gopalganj','Bhore','Pachrukhia','Hussainganj'],
      warningLevel: 5.40, dangerLevel: 6.30, hfl: 7.80,
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // KAMALABALAN
    // ═══════════════════════════════════════════════════════════════════════

    'jhanjharpur': BiharStationMeta(
      river: 'Kamalabalan', site: 'Jhanjharpur', district: 'Madhubani',
      lat: 26.268, lng: 86.280,
      coversCities: ['Jhanjharpur','Madhubani','Phulparas','Pandaul','Laukaha','Jaynagar'],
      warningLevel: 4.40, dangerLevel: 5.30, hfl: 6.70,
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // KAMLA
    // ═══════════════════════════════════════════════════════════════════════

    'jainagar': BiharStationMeta(
      river: 'Kamla', site: 'Jainagar', district: 'Madhubani',
      lat: 26.597, lng: 86.247,
      coversCities: ['Jainagar','Madhubani','Benipatti','Phulparas','Bisfi','Rahika'],
      warningLevel: 4.60, dangerLevel: 5.50, hfl: 6.90,
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // KOSI
    // ═══════════════════════════════════════════════════════════════════════

    'baltara': BiharStationMeta(
      river: 'Kosi', site: 'Baltara', district: 'Saharsa',
      lat: 25.867, lng: 86.563,
      coversCities: ['Saharsa','Simri Bakhtiyarpur','Banmankhi','Salkhua','Mahishi','Sonbarsa'],
      warningLevel: 26.21, dangerLevel: 27.21, hfl: 29.00,
    ),

    'basua': BiharStationMeta(
      river: 'Kosi', site: 'Basua', district: 'Supaul',
      lat: 26.430, lng: 86.702,
      coversCities: ['Basua','Supaul','Triveniganj','Kishanpur','Salkhua','Saraigarh'],
      warningLevel: 5.50, dangerLevel: 6.40, hfl: 7.80,
    ),

    'birpur': BiharStationMeta(
      river: 'Kosi', site: 'Birpur', district: 'Supaul',
      lat: 26.505, lng: 86.914,
      coversCities: ['Birpur','Supaul','Madhepura','Araria','Forbesganj','Saharsa',
                     'Darbhanga','Khagaria','Bhagalpur'],
      warningLevel: 5.60, dangerLevel: 6.80, hfl: 8.20,
    ),

    'kursela': BiharStationMeta(
      river: 'Kosi', site: 'Kursela', district: 'Katihar',
      lat: 25.453, lng: 87.266,
      coversCities: ['Kursela','Katihar','Manihari','Amdabad','Kadwa','Barari'],
      warningLevel: 20.42, dangerLevel: 21.34, hfl: 22.80,
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // MAHANANDA
    // ═══════════════════════════════════════════════════════════════════════

    'dhengraghat': BiharStationMeta(
      river: 'Mahananda', site: 'Dhengraghat', district: 'Kishanganj',
      lat: 26.098, lng: 87.951,
      coversCities: ['Kishanganj','Thakurganj','Kochadhaman','Bahadurganj','Islampur','Jogbani'],
      warningLevel: 4.90, dangerLevel: 5.80, hfl: 7.20,
    ),

    'taibpur': BiharStationMeta(
      river: 'Mahananda', site: 'Taibpur', district: 'Purnia',
      lat: 25.775, lng: 87.474,
      coversCities: ['Purnia','Banmankhi','Kasba','Araria','Forbesganj','Rupauli'],
      warningLevel: 5.10, dangerLevel: 6.00, hfl: 7.40,
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // PUNPUN
    // ═══════════════════════════════════════════════════════════════════════

    'sripalpur': BiharStationMeta(
      river: 'Punpun', site: 'Sripalpur', district: 'Patna',
      lat: 25.328, lng: 85.038,
      coversCities: ['Patna (south)','Fatuha','Masaurhi','Jehanabad','Arwal','Bikram'],
      warningLevel: 3.80, dangerLevel: 4.50, hfl: 5.60,
    ),

  }; // end _all
}
