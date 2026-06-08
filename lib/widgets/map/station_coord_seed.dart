// lib/widgets/map/station_coord_seed.dart
// Static coordinate lookup for all known Bihar + national stations.
// coordFor() returns null when a station has no known coordinates;
// callers must guard against null before rendering a Marker.
import 'package:latlong2/latlong.dart';
import '../../models/river_station.dart';

const Map<String, LatLng> kStationCoords = {
  // ── Bihar districts ───────────────────────────────────────────────────
  'patna':             LatLng(25.5941,  85.1376),
  'gaya':              LatLng(24.7955,  85.0002),
  'bhagalpur':         LatLng(25.2425,  86.9842),
  'muzaffarpur':       LatLng(26.1209,  85.3647),
  'darbhanga':         LatLng(26.1542,  85.8918),
  'araria':            LatLng(26.1475,  87.4733),
  'sitamarhi':         LatLng(26.5921,  85.4879),
  'supaul':            LatLng(26.1237,  86.6032),
  'vaishali':          LatLng(25.6938,  85.2001),
  'saran':             LatLng(25.9177,  84.7430),
  'east champaran':    LatLng(26.6539,  84.9184),
  'west champaran':    LatLng(27.0,     84.4),
  'gopalganj':         LatLng(26.4699,  84.4341),
  'siwan':             LatLng(26.2215,  84.3547),
  'begusarai':         LatLng(25.4182,  86.1272),
  'samastipur':        LatLng(25.8627,  85.7816),
  'madhubani':         LatLng(26.3566,  86.0711),
  'khagaria':          LatLng(25.5014,  86.4717),
  'katihar':           LatLng(25.5398,  87.5677),
  'purnea':            LatLng(25.7771,  87.4753),
  // ── CWC gauge sites ──────────────────────────────────────────────────
  'ekmighat':          LatLng(26.45,    86.12),
  'kamtaul':           LatLng(26.3,     85.8),
  'sonbarsa':          LatLng(27.1,     85.5),
  'benibad':           LatLng(25.9,     85.5),
  'hayaghat':          LatLng(25.7,     85.7),
  'rosera':            LatLng(25.9,     85.9),
  'hajipur':           LatLng(25.6853,  85.2093),
  'dumariaghat':       LatLng(27.0,     84.15),
  'chatia':            LatLng(26.6,     84.8),
  'rewaghat':          LatLng(26.0,     84.5),
  'dighaghat':         LatLng(25.6,     85.1),
  'gandhighat':        LatLng(25.58,    85.13),
  'hathidah':          LatLng(25.38,    85.8),
  'kahalgaon':         LatLng(25.24,    87.25),
  'munger':            LatLng(25.375,   86.474),
  'buxar':             LatLng(25.565,   83.981),
  'birpur':            LatLng(26.51,    87.0),
  'baltara':           LatLng(25.4,     86.6),
  'basua':             LatLng(25.75,    87.0),
  'kursela':           LatLng(25.47,    87.27),
  'jhanjharpur':       LatLng(26.26,    86.28),
  'jainagar':          LatLng(26.6,     86.25),
  'dhengraghat':       LatLng(25.6,     87.8),
  'taibpur':           LatLng(26.0,     87.2),
  'sripalpur':         LatLng(25.18,    85.33),
  'darauli':           LatLng(26.05,    84.48),
  'gangpur siswan':    LatLng(26.35,    84.4),
  // ── National sites ───────────────────────────────────────────────────
  'prayagraj':         LatLng(25.4358,  81.8463),
  'varanasi':          LatLng(25.3176,  82.9739),
  'lucknow':           LatLng(26.8467,  80.9462),
  'guwahati':          LatLng(26.1445,  91.7362),
  'dibrugarh':         LatLng(27.4728,  94.9120),
  'kolkata':           LatLng(22.5726,  88.3639),
  'bhubaneswar':       LatLng(20.2961,  85.8189),
  'delhi':             LatLng(28.6139,  77.2090),
  'srinagar':          LatLng(34.0837,  74.7973),
};

/// Returns the best-guess [LatLng] for [s], or null if unknown.
LatLng? coordFor(RiverStation s) {
  final cityKey    = s.city.toLowerCase();
  final stationKey = s.station.toLowerCase();
  for (final entry in kStationCoords.entries) {
    if (cityKey.contains(entry.key)    || entry.key.contains(cityKey) ||
        stationKey.contains(entry.key) || entry.key.contains(stationKey)) {
      return entry.value;
    }
  }
  return null;
}
