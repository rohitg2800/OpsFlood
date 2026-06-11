// lib/providers/map_command_provider.dart
// Riverpod v3 — StateProvider was removed; use NotifierProvider instead.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/river_station.dart';
import '../providers/real_time_river_provider.dart';
import '../providers/cwc_provider.dart';
import '../services/befiqr_cwc_service.dart';

// Export must come before all declarations (Dart directive rule)
export 'cwc_provider.dart' show biharGeoJsonProvider;

// ─── View-mode toggle ─────────────────────────────────────────────────────────
enum MapViewMode { bihar, national }

class MapViewModeNotifier extends Notifier<MapViewMode> {
  @override
  MapViewMode build() => MapViewMode.bihar;
}

final mapViewModeProvider =
    NotifierProvider<MapViewModeNotifier, MapViewMode>(
        MapViewModeNotifier.new);

// ─── Selected station (popup) ─────────────────────────────────────────────────
class SelectedStationNotifier extends Notifier<RiverStation?> {
  @override
  RiverStation? build() => null;
}

final mapSelectedStationProvider =
    NotifierProvider<SelectedStationNotifier, RiverStation?>(
        SelectedStationNotifier.new);

// ─── Sync metadata ────────────────────────────────────────────────────────────
class SyncMeta {
  final DateTime? cwcUpdated;
  final DateTime? wrdUpdated;
  final DateTime? gloFasUpdated;

  const SyncMeta({
    this.cwcUpdated,
    this.wrdUpdated,
    this.gloFasUpdated,
  });

  String get freshnessLabel {
    final times = <DateTime>[
      if (cwcUpdated    != null) cwcUpdated!,
      if (wrdUpdated    != null) wrdUpdated!,
      if (gloFasUpdated != null) gloFasUpdated!,
    ];
    if (times.isEmpty) return 'No data yet';
    times.sort();
    final diff = DateTime.now().difference(times.last);
    if (diff.inSeconds < 60)  return 'Just now';
    if (diff.inMinutes < 60)  return '${diff.inMinutes} min ago';
    if (diff.inHours   < 24)  return '${diff.inHours} hr ago';
    return '${diff.inDays} day(s) ago';
  }

  String labelFor(String source) {
    switch (source) {
      case 'CWC_FFEM':  return cwcUpdated    == null ? '—' : _fmt(cwcUpdated!);
      case 'WRD_BIHAR': return wrdUpdated    == null ? '—' : _fmt(wrdUpdated!);
      case 'GLOFAS':    return gloFasUpdated == null ? '—' : _fmt(gloFasUpdated!);
      default: return '—';
    }
  }

  String _fmt(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}  '
      '${t.day}/${t.month}';
}

class SyncMetaNotifier extends Notifier<SyncMeta> {
  @override
  SyncMeta build() => const SyncMeta();
}

final mapSyncMetaProvider =
    NotifierProvider<SyncMetaNotifier, SyncMeta>(SyncMetaNotifier.new);

// ─── CwcStation → RiverStation adapter ───────────────────────────────────────
// Kept for any legacy callers; map now uses mergedStationsProvider directly.
extension CwcStationAdapter on CwcStation {
  RiverStation toRiverStation() => RiverStation(
    city:    site,
    state:   'Bihar',
    river:   river,
    station: site,
    current: currentLevel,
    warning: (dangerLevel - 1.5).clamp(0, double.infinity),
    danger:  dangerLevel,
    hfl:     dangerLevel + 1.5,
    dataSource:  'CWC_FFEM',
    lastUpdated: '${fetchedAt.hour.toString().padLeft(2, '0')}:'
                 '${fetchedAt.minute.toString().padLeft(2, '0')}',
    isLive:  true,
  );
}

// ─── Gauge-site → Bihar district lookup ──────────────────────────────────────
// Maps the gauge site name (s.city / s.station) to the Bihar district whose
// GeoJSON polygon should be coloured.  Used by biharDistrictRiskProvider.
const Map<String, String> _kSiteToDistrict = {
  // Adhwara / Darbhanga
  'ekmighat':                'darbhanga',
  'kamtaul':                 'darbhanga',
  'sonbarsa':                'sitamarhi',
  // Bagmati
  'benibad':                 'darbhanga',
  'dheng bridge':            'muzaffarpur',
  'dhengbridge':             'muzaffarpur',
  'hayaghat':                'darbhanga',
  'runnisaidpur':            'sitamarhi',
  'pupri':                   'sitamarhi',
  'lalbakeya':               'sitamarhi',
  'donar':                   'sitamarhi',
  // Burhi Gandak
  'khagaria':                'khagaria',
  'rosera':                  'samastipur',
  'samastipur':              'samastipur',
  'sikandarpur':             'muzaffarpur',
  'gaighat':                 'muzaffarpur',
  // Gandak
  'chatia':                  'east champaran',
  'dumariaghat':             'west champaran',
  'hajipur':                 'vaishali',
  'rewaghat':                'saran',
  'balmikinagar':            'west champaran',
  'balmiki nagar':           'west champaran',
  'turkaulia':               'west champaran',
  'sikta':                   'west champaran',
  'bhitaha':                 'west champaran',
  'bagaha':                  'west champaran',
  'lauriya':                 'west champaran',
  'motihari':                'east champaran',
  'areraj':                  'east champaran',
  // Ganga
  'bhagalpur':               'bhagalpur',
  'buxar':                   'buxar',
  'dighaghat':               'patna',
  'gandhighat':              'patna',
  'hathidah':                'begusarai',
  'kahalgaon':               'bhagalpur',
  'munger':                  'munger',
  'naugachia':               'bhagalpur',
  // Ghaghra / Saran
  'darauli':                 'saran',
  'gangpur siswan':          'siwan',
  'gangpur':                 'siwan',
  // Kamalabalan / Madhubani
  'jhanjharpur':             'madhubani',
  // Kamla / Darbhanga
  'jainagar':                'madhubani',
  'phulparas':               'madhubani',
  'nirmali':                 'supaul',
  // Kosi
  'baltara':                 'khagaria',
  'basua':                   'supaul',
  'birpur':                  'supaul',
  'kursela':                 'katihar',
  'bhim nagar':              'supaul',
  'bhimnagar':               'supaul',
  'katiya':                  'araria',
  'tikulia':                 'supaul',
  // Mahananda
  'dhengraghat':             'katihar',
  'taibpur':                 'katihar',
  // Punpun
  'sripalpur':               'patna',
  // Sheohar
  'sheohar':                 'sitamarhi',
  // Pandaul / Darbhanga
  'pandaul':                 'madhubani',
};

/// Normalise a raw site/city name for district lookup.
String _normSite(String v) => v
    .toLowerCase()
    .replaceAll(RegExp(r'\s*\(.*?\)'), '')
    .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Best-effort: looks up the district for a gauge site name.
/// Falls back to the city name itself so at least partial colouring works.
String _districtFor(RiverStation s) {
  final norm = _normSite(s.city);
  // Exact match
  if (_kSiteToDistrict.containsKey(norm)) return _kSiteToDistrict[norm]!;
  // Substring match (handles minor casing / spacing variants)
  for (final entry in _kSiteToDistrict.entries) {
    if (norm.contains(entry.key) || entry.key.contains(norm)) {
      return entry.value;
    }
  }
  // Final fallback — city as-is (works for stations whose city IS the district)
  return norm;
}

// ─── Map station list — fed from the full merged live pipeline ────────────────
// Uses mergedStationsProvider (CWC-live > DataFetch > WRD > CWC-seed > Birpur)
// so marker colours and pulse animations reflect real-time criticality.
final mapStationsProvider = Provider<List<RiverStation>>((ref) {
  final mode = ref.watch(mapViewModeProvider);
  final all  = ref.watch(mergedStationsProvider);

  final filtered = mode == MapViewMode.bihar
      ? all.where((s) => s.state.toLowerCase().contains('bihar')).toList()
      : all;

  final result = List<RiverStation>.from(filtered)
    ..sort((a, b) => b.riskScore.compareTo(a.riskScore));
  return result;
});

// ─── District risk map (for polygon heatmap layer) ────────────────────────────
// Resolves each gauge site to its Bihar district via _kSiteToDistrict,
// then keeps the worst DangerClass seen per district.
final biharDistrictRiskProvider = Provider<Map<String, DangerClass>>((ref) {
  final stations = ref.watch(mapStationsProvider);
  final map = <String, DangerClass>{};
  for (final s in stations) {
    if (!s.state.toLowerCase().contains('bihar')) continue;
    final district = _districtFor(s);
    final existing = map[district];
    if (existing == null || s.dangerClass.index > existing.index) {
      map[district] = s.dangerClass;
    }
  }
  return map;
});
