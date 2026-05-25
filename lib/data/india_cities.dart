// lib/data/india_cities.dart
//
// Static registry of CWC-monitored Indian cities used by CwcLiveProvider
// and related services. Add entries here to expand coverage.

library;

/// Represents a CWC-monitored river gauge station in India.
class IndiaCity {
  final String id;
  final String name;
  final String state;
  final String river;
  final double lat;
  final double lon;
  final double warningLevel; // metres MSL
  final double dangerLevel;  // metres MSL

  const IndiaCity({
    required this.id,
    required this.name,
    required this.state,
    required this.river,
    required this.lat,
    required this.lon,
    required this.warningLevel,
    required this.dangerLevel,
  });

  Map<String, dynamic> toMap() => {
        'id':            id,
        'name':          name,
        'state':         state,
        'river':         river,
        'lat':           lat,
        'lon':           lon,
        'warning_level': warningLevel,
        'danger_level':  dangerLevel,
      };
}

/// Static registry of all monitored cities.
/// Source: CWC Central Flood Forecasting stations list.
class IndiaCities {
  IndiaCities._();

  static const List<IndiaCity> all = [
    IndiaCity(
      id:           'patna',
      name:         'Patna',
      state:        'Bihar',
      river:        'Ganga',
      lat:          25.5941,
      lon:          85.1376,
      warningLevel: 48.60,
      dangerLevel:  50.27,
    ),
    IndiaCity(
      id:           'varanasi',
      name:         'Varanasi',
      state:        'Uttar Pradesh',
      river:        'Ganga',
      lat:          25.3176,
      lon:          82.9739,
      warningLevel: 70.26,
      dangerLevel:  71.26,
    ),
    IndiaCity(
      id:           'prayagraj',
      name:         'Prayagraj',
      state:        'Uttar Pradesh',
      river:        'Ganga',
      lat:          25.4358,
      lon:          81.8463,
      warningLevel: 84.73,
      dangerLevel:  85.73,
    ),
    IndiaCity(
      id:           'haridwar',
      name:         'Haridwar',
      state:        'Uttarakhand',
      river:        'Ganga',
      lat:          29.9457,
      lon:          78.1642,
      warningLevel: 293.80,
      dangerLevel:  294.00,
    ),
    IndiaCity(
      id:           'lucknow',
      name:         'Lucknow',
      state:        'Uttar Pradesh',
      river:        'Gomti',
      lat:          26.8467,
      lon:          80.9462,
      warningLevel: 103.84,
      dangerLevel:  104.84,
    ),
    IndiaCity(
      id:           'guwahati',
      name:         'Guwahati',
      state:        'Assam',
      river:        'Brahmaputra',
      lat:          26.1445,
      lon:          91.7362,
      warningLevel: 49.68,
      dangerLevel:  51.68,
    ),
    IndiaCity(
      id:           'dibrugarh',
      name:         'Dibrugarh',
      state:        'Assam',
      river:        'Brahmaputra',
      lat:          27.4728,
      lon:          94.9120,
      warningLevel: 105.00,
      dangerLevel:  107.29,
    ),
    IndiaCity(
      id:           'silchar',
      name:         'Silchar',
      state:        'Assam',
      river:        'Barak',
      lat:          24.8333,
      lon:          92.7789,
      warningLevel: 17.37,
      dangerLevel:  19.51,
    ),
    IndiaCity(
      id:           'bhagalpur',
      name:         'Bhagalpur',
      state:        'Bihar',
      river:        'Ganga',
      lat:          25.2425,
      lon:          86.9842,
      warningLevel: 33.53,
      dangerLevel:  35.08,
    ),
    IndiaCity(
      id:           'munger',
      name:         'Munger',
      state:        'Bihar',
      river:        'Ganga',
      lat:          25.3756,
      lon:          86.4733,
      warningLevel: 38.46,
      dangerLevel:  40.21,
    ),
    IndiaCity(
      id:           'cuttack',
      name:         'Cuttack',
      state:        'Odisha',
      river:        'Mahanadi',
      lat:          20.4625,
      lon:          85.8830,
      warningLevel: 18.29,
      dangerLevel:  19.81,
    ),
    IndiaCity(
      id:           'hyderabad',
      name:         'Hyderabad',
      state:        'Telangana',
      river:        'Musi',
      lat:          17.3850,
      lon:          78.4867,
      warningLevel: 497.00,
      dangerLevel:  499.00,
    ),
    IndiaCity(
      id:           'vijayawada',
      name:         'Vijayawada',
      state:        'Andhra Pradesh',
      river:        'Krishna',
      lat:          16.5062,
      lon:          80.6480,
      warningLevel: 12.19,
      dangerLevel:  13.41,
    ),
    IndiaCity(
      id:           'surat',
      name:         'Surat',
      state:        'Gujarat',
      river:        'Tapti',
      lat:          21.1702,
      lon:          72.8311,
      warningLevel: 7.00,
      dangerLevel:  9.00,
    ),
    IndiaCity(
      id:           'vadodara',
      name:         'Vadodara',
      state:        'Gujarat',
      river:        'Vishwamitri',
      lat:          22.3072,
      lon:          73.1812,
      warningLevel: 12.00,
      dangerLevel:  14.00,
    ),
    IndiaCity(
      id:           'kolkata',
      name:         'Kolkata',
      state:        'West Bengal',
      river:        'Hooghly',
      lat:          22.5726,
      lon:          88.3639,
      warningLevel: 5.00,
      dangerLevel:  6.00,
    ),
    IndiaCity(
      id:           'pune',
      name:         'Pune',
      state:        'Maharashtra',
      river:        'Mutha',
      lat:          18.5204,
      lon:          73.8567,
      warningLevel: 555.00,
      dangerLevel:  557.00,
    ),
    IndiaCity(
      id:           'nashik',
      name:         'Nashik',
      state:        'Maharashtra',
      river:        'Godavari',
      lat:          19.9975,
      lon:          73.7898,
      warningLevel: 572.90,
      dangerLevel:  574.40,
    ),
    IndiaCity(
      id:           'aurangabad',
      name:         'Aurangabad',
      state:        'Maharashtra',
      river:        'Kham',
      lat:          19.8762,
      lon:          75.3433,
      warningLevel: 568.20,
      dangerLevel:  569.70,
    ),
    IndiaCity(
      id:           'agra',
      name:         'Agra',
      state:        'Uttar Pradesh',
      river:        'Yamuna',
      lat:          27.1767,
      lon:          78.0081,
      warningLevel: 166.59,
      dangerLevel:  167.59,
    ),
  ];

  /// Lookup by city name (case-insensitive).
  static IndiaCity? find(String name) {
    try {
      return all.firstWhere(
        (c) => c.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Lookup by state (case-insensitive), returns all matching cities.
  static List<IndiaCity> byState(String state) =>
      all.where((c) => c.state.toLowerCase() == state.toLowerCase()).toList();
}
