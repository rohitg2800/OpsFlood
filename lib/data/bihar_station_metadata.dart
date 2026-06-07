// lib/data/bihar_station_metadata.dart
//
// Single source of truth for Bihar CWC gauging station metadata.
// Covers all 32 stations in the befiqr_cwc_service.dart seed +
// additional WRD Bihar stations.
//
// Each entry specifies:
//   • river      — river name (matches CwcStation.river)
//   • site       — site name  (matches CwcStation.site, lower-cased for lookup)
//   • district   — Bihar district the gauge is located in
//   • lat / lng  — geographic coordinates
//   • coversCities — cities / blocks / talukas whose flood risk this
//                     station primarily represents (within ~30-50 km
//                     downstream / floodplain influence zone)
//
// Usage
// ─────
//   final meta = BiharStationRegistry.forSite('Benibad');
//   print(meta?.district);       // 'Muzaffarpur'
//   print(meta?.coversCities);   // ['Muzaffarpur', 'Katra', ...]
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

  const BiharStationMeta({
    required this.river,
    required this.site,
    required this.district,
    required this.lat,
    required this.lng,
    required this.coversCities,
  });

  LatLng get latLng => LatLng(lat, lng);
}

// ─────────────────────────────────────────────────────────────────────────────
// Registry
// ─────────────────────────────────────────────────────────────────────────────

class BiharStationRegistry {
  BiharStationRegistry._();

  /// Look up metadata by site name (case-insensitive).
  static BiharStationMeta? forSite(String site) =>
      _all[site.toLowerCase().trim()];

  /// All registered stations as a flat list.
  static List<BiharStationMeta> get all => _all.values.toList();

  /// Districts covered by at least one station.
  static Set<String> get districts =>
      _all.values.map((m) => m.district).toSet();

  // ───────────────────────────────────────────────────────────────────────────
  // Internal lookup map  (key = site name, lower-cased)
  // ───────────────────────────────────────────────────────────────────────────

  static const _all = <String, BiharStationMeta>{

    // ═══════════════════════════════════════════════════════════════════════
    // ADHWARA GROUP  (north Bihar, Sitamarhi / Darbhanga plain)
    // ═══════════════════════════════════════════════════════════════════════

    'ekmighat': BiharStationMeta(
      river:       'Adhwara',
      site:        'Ekmighat',
      district:    'Sitamarhi',
      lat:          26.597,
      lng:          85.617,
      coversCities: [
        'Sitamarhi', 'Runni Saidpur', 'Pupri', 'Riga',
        'Parihar', 'Sursand',
      ],
    ),

    'kamtaul': BiharStationMeta(
      river:       'Adhwara',
      site:        'Kamtaul',
      district:    'Darbhanga',
      lat:          26.392,
      lng:          85.862,
      coversCities: [
        'Kamtaul', 'Darbhanga', 'Baheri', 'Manigachhi',
        'Biraul', 'Kusheshwar Asthan',
      ],
    ),

    'sonbarsa': BiharStationMeta(
      river:       'Adhwara',
      site:        'Sonbarsa',
      district:    'Samastipur',
      lat:          25.993,
      lng:          86.063,
      coversCities: [
        'Samastipur', 'Sonbarsa', 'Bibhutipur', 'Patori',
        'Ujiarpur', 'Morwa',
      ],
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // BAGMATI  (north-central Bihar)
    // ═══════════════════════════════════════════════════════════════════════

    'benibad': BiharStationMeta(
      river:       'Bagmati',
      site:        'Benibad',
      district:    'Muzaffarpur',
      lat:          26.148,
      lng:          85.852,
      coversCities: [
        'Muzaffarpur', 'Katra', 'Minapur', 'Motipur',
        'Sakra', 'Gaighat',
      ],
    ),

    'dheng bridge': BiharStationMeta(
      river:       'Bagmati',
      site:        'Dheng Bridge',
      district:    'Sitamarhi',
      lat:          26.740,
      lng:          85.594,
      coversCities: [
        'Dheng', 'Bajpatti', 'Sheohar', 'Piprahi',
        'Belsand', 'Parsauni',
      ],
    ),

    'hayaghat': BiharStationMeta(
      river:       'Bagmati',
      site:        'Hayaghat',
      district:    'Darbhanga',
      lat:          26.122,
      lng:          85.762,
      coversCities: [
        'Hayaghat', 'Darbhanga', 'Jale', 'Kiratpur',
        'Ghanshyampur', 'Biraul',
      ],
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // BURHI GANDAK  (central Bihar)
    // ═══════════════════════════════════════════════════════════════════════

    'khagaria': BiharStationMeta(
      river:       'Burhi Gandak',
      site:        'Khagaria',
      district:    'Khagaria',
      lat:          25.502,
      lng:          86.468,
      coversCities: [
        'Khagaria', 'Mansi', 'Alauli', 'Chautham',
        'Parwalpur', 'Gogri',
      ],
    ),

    'rosera': BiharStationMeta(
      river:       'Burhi Gandak',
      site:        'Rosera',
      district:    'Samastipur',
      lat:          25.863,
      lng:          85.984,
      coversCities: [
        'Rosera', 'Dalsingh Sarai', 'Bibhutipur',
        'Tajpur', 'Pusa', 'Sarairanjan',
      ],
    ),

    'samastipur': BiharStationMeta(
      river:       'Burhi Gandak',
      site:        'Samastipur',
      district:    'Samastipur',
      lat:          25.871,
      lng:          85.779,
      coversCities: [
        'Samastipur', 'Mohiuddinagar', 'Pusa', 'Warisnagar',
        'Shivajinagar', 'Kalyanpur',
      ],
    ),

    'sikandarpur (muzzafarpur)': BiharStationMeta(
      river:       'Burhi Gandak',
      site:        'Sikandarpur (Muzzafarpur)',
      district:    'Muzaffarpur',
      lat:          26.118,
      lng:          85.391,
      coversCities: [
        'Muzaffarpur', 'Sikandarpur', 'Aurai', 'Kanti',
        'Marwan', 'Paroo',
      ],
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // GANDAK  (west-north Bihar)
    // ═══════════════════════════════════════════════════════════════════════

    'chatia': BiharStationMeta(
      river:       'Gandak',
      site:        'Chatia',
      district:    'East Champaran',
      lat:          26.680,
      lng:          84.882,
      coversCities: [
        'Chatia', 'Motihari', 'Areraj', 'Dhaka',
        'Banjaria', 'Paharpur',
      ],
    ),

    'dumariaghat': BiharStationMeta(
      river:       'Gandak',
      site:        'Dumariaghat',
      district:    'West Champaran',
      lat:          27.093,
      lng:          84.478,
      coversCities: [
        'Bettiah', 'Bagaha', 'Narkatiaganj',
        'Raxaul', 'Sikta', 'Gaunaha',
      ],
    ),

    'hajipur': BiharStationMeta(
      river:       'Gandak',
      site:        'Hajipur',
      district:    'Vaishali',
      lat:          25.683,
      lng:          85.209,
      coversCities: [
        'Hajipur', 'Vaishali', 'Lalganj', 'Mahua',
        'Raghopur', 'Patepur',
      ],
    ),

    'rewaghat': BiharStationMeta(
      river:       'Gandak',
      site:        'Rewaghat',
      district:    'Muzaffarpur',
      lat:          26.205,
      lng:          84.975,
      coversCities: [
        'Muzaffarpur', 'Rewaghat', 'Minapur', 'Kanti',
        'Sakra', 'Bochahan',
      ],
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // GANGA  (Bihar's main axis — 7 stations)
    // ═══════════════════════════════════════════════════════════════════════

    'bhagalpur': BiharStationMeta(
      river:       'Ganga',
      site:        'Bhagalpur',
      district:    'Bhagalpur',
      lat:          25.245,
      lng:          86.978,
      coversCities: [
        'Bhagalpur', 'Sultanganj', 'Kahalgaon',
        'Naugachia', 'Bihpur', 'Pirpainti',
      ],
    ),

    'buxar': BiharStationMeta(
      river:       'Ganga',
      site:        'Buxar',
      district:    'Buxar',
      lat:          25.563,
      lng:          83.978,
      coversCities: [
        'Buxar', 'Dumraon', 'Simri', 'Chausa',
        'Brahmpur', 'Itarhi',
      ],
    ),

    'dighaghat': BiharStationMeta(
      river:       'Ganga',
      site:        'Dighaghat',
      district:    'Patna',
      lat:          25.623,
      lng:          85.074,
      coversCities: [
        'Patna', 'Danapur', 'Dinapur', 'Phulwari Sharif',
        'Maner', 'Bihta',
      ],
    ),

    'gandhighat': BiharStationMeta(
      river:       'Ganga',
      site:        'Gandhighat',
      district:    'Patna',
      lat:          25.614,
      lng:          85.127,
      coversCities: [
        'Patna', 'Patna City', 'Fatuha', 'Bakhtiyarpur',
        'Mokameh', 'Barh',
      ],
    ),

    'hathidah': BiharStationMeta(
      river:       'Ganga',
      site:        'Hathidah',
      district:    'Begusarai',
      lat:          25.381,
      lng:          86.165,
      coversCities: [
        'Hathidah', 'Begusarai', 'Teghra', 'Lakhisarai',
        'Suryagarha', 'Mokameh',
      ],
    ),

    'kahalgaon': BiharStationMeta(
      river:       'Ganga',
      site:        'Kahalgaon',
      district:    'Bhagalpur',
      lat:          25.207,
      lng:          87.268,
      coversCities: [
        'Kahalgaon', 'Pirpainti', 'Sanho',
        'Banka', 'Katoria', 'Sultanganj',
      ],
    ),

    'munger': BiharStationMeta(
      river:       'Ganga',
      site:        'Munger',
      district:    'Munger',
      lat:          25.375,
      lng:          86.474,
      coversCities: [
        'Munger', 'Jamalpur', 'Tarapur', 'Lakhisarai',
        'Suryagarha', 'Kharagpur',
      ],
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // GHAGHRA  (west Bihar  — Saran / Siwan districts)
    // ═══════════════════════════════════════════════════════════════════════

    'darauli': BiharStationMeta(
      river:       'Ghaghra',
      site:        'Darauli',
      district:    'Siwan',
      lat:          26.102,
      lng:          84.136,
      coversCities: [
        'Darauli', 'Siwan', 'Maharajganj', 'Barharia',
        'Raghunathpur', 'Andar',
      ],
    ),

    'gangpur siswan': BiharStationMeta(
      river:       'Ghaghra',
      site:        'Gangpur Siswan',
      district:    'Siwan',
      lat:          26.218,
      lng:          84.357,
      coversCities: [
        'Gangpur Siswan', 'Siwan', 'Gopalganj',
        'Bhore', 'Pachrukhia', 'Hussainganj',
      ],
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // KAMALABALAN  (north Bihar)
    // ═══════════════════════════════════════════════════════════════════════

    'jhanjharpur': BiharStationMeta(
      river:       'Kamalabalan',
      site:        'Jhanjharpur',
      district:    'Madhubani',
      lat:          26.268,
      lng:          86.280,
      coversCities: [
        'Jhanjharpur', 'Madhubani', 'Phulparas',
        'Pandaul', 'Laukaha', 'Jaynagar',
      ],
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // KAMLA  (north Bihar — Madhubani / Darbhanga)
    // ═══════════════════════════════════════════════════════════════════════

    'jainagar': BiharStationMeta(
      river:       'Kamla',
      site:        'Jainagar',
      district:    'Madhubani',
      lat:          26.597,
      lng:          86.247,
      coversCities: [
        'Jainagar', 'Madhubani', 'Benipatti', 'Phulparas',
        'Bisfi', 'Rahika',
      ],
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // KOSI  (north-east Bihar — most flood-prone river)
    // ═══════════════════════════════════════════════════════════════════════

    'baltara': BiharStationMeta(
      river:       'Kosi',
      site:        'Baltara',
      district:    'Saharsa',
      lat:          25.867,
      lng:          86.563,
      coversCities: [
        'Saharsa', 'Simri Bakhtiyarpur', 'Banmankhi',
        'Salkhua', 'Mahishi', 'Sonbarsa',
      ],
    ),

    'basua': BiharStationMeta(
      river:       'Kosi',
      site:        'Basua',
      district:    'Supaul',
      lat:          26.430,
      lng:          86.702,
      coversCities: [
        'Basua', 'Supaul', 'Triveniganj', 'Kishanpur',
        'Salkhua', 'Saraigarh',
      ],
    ),

    'birpur': BiharStationMeta(
      river:       'Kosi',
      site:        'Birpur',
      district:    'Supaul',
      lat:          26.505,
      lng:          86.914,
      coversCities: [
        'Birpur', 'Supaul', 'Madhepura', 'Araria',
        'Forbesganj', 'Saharsa',
        // Kosi barrage — monitors entire downstream Bihar
        'Darbhanga', 'Khagaria', 'Bhagalpur',
      ],
    ),

    'kursela': BiharStationMeta(
      river:       'Kosi',
      site:        'Kursela',
      district:    'Katihar',
      lat:          25.453,
      lng:          87.266,
      coversCities: [
        'Kursela', 'Katihar', 'Manihari', 'Amdabad',
        'Kadwa', 'Barari',
      ],
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // MAHANANDA  (north-east Bihar — Kishanganj / Purnia)
    // ═══════════════════════════════════════════════════════════════════════

    'dhengraghat': BiharStationMeta(
      river:       'Mahananda',
      site:        'Dhengraghat',
      district:    'Kishanganj',
      lat:          26.098,
      lng:          87.951,
      coversCities: [
        'Kishanganj', 'Thakurganj', 'Kochadhaman',
        'Bahadurganj', 'Islampur', 'Jogbani',
      ],
    ),

    'taibpur': BiharStationMeta(
      river:       'Mahananda',
      site:        'Taibpur',
      district:    'Purnia',
      lat:          25.775,
      lng:          87.474,
      coversCities: [
        'Purnia', 'Banmankhi', 'Kasba',
        'Araria', 'Forbesganj', 'Rupauli',
      ],
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // PUNPUN  (south Bihar — Gaya / Patna)
    // ═══════════════════════════════════════════════════════════════════════

    'sripalpur': BiharStationMeta(
      river:       'Punpun',
      site:        'Sripalpur',
      district:    'Patna',
      lat:          25.328,
      lng:          85.038,
      coversCities: [
        'Patna (south)', 'Fatuha', 'Masaurhi',
        'Jehanabad', 'Arwal', 'Bikram',
      ],
    ),

  }; // end _all
}
