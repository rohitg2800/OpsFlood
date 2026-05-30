import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/station.dart';
import '../services/api_service.dart';

enum LoadState { idle, loading, loaded, error }

class StationProvider extends ChangeNotifier {
  List<Station> _stations = [];
  List<Station> _alerts   = [];
  Summary? _summary;
  LoadState _state = LoadState.idle;
  String _error = '';
  DateTime? _lastFetch;
  Timer? _timer;

  List<Station> get stations => _stations;
  List<Station> get alerts   => _alerts;
  Summary?      get summary  => _summary;
  LoadState     get state    => _state;
  String        get error    => _error;
  DateTime?     get lastFetch => _lastFetch;

  // Filtered getters
  List<Station> get dangerStations  => _stations.where((s) => s.isDanger).toList();
  List<Station> get warningStations => _stations.where((s) => s.isWarning).toList();
  List<Station> get normalStations  => _stations.where((s) => s.isNormal).toList();

  /// Group stations by river name
  Map<String, List<Station>> get byRiver {
    final map = <String, List<Station>>{};
    for (final s in _stations) {
      map.putIfAbsent(s.river, () => []).add(s);
    }
    // Sort rivers: rivers with danger first
    final sorted = Map.fromEntries(
      map.entries.toList()
        ..sort((a, b) {
          final aMax = a.value.fold(0, (p, s) => s.isDanger ? 2 : (s.isWarning ? 1 : 0) > p ? (s.isDanger ? 2 : 1) : p);
          final bMax = b.value.fold(0, (p, s) => s.isDanger ? 2 : (s.isWarning ? 1 : 0) > p ? (s.isDanger ? 2 : 1) : p);
          return bMax.compareTo(aMax);
        }),
    );
    return sorted;
  }

  Future<void> loadAll() async {
    _state = LoadState.loading;
    notifyListeners();
    try {
      final results = await Future.wait([
        ApiService.getBiharStations(),
        ApiService.getSummary(),
        ApiService.getCriticalAlerts(),
      ]);
      _stations = results[0] as List<Station>;
      _summary  = results[1] as Summary;
      _alerts   = results[2] as List<Station>;
      _lastFetch = DateTime.now();
      _state = LoadState.loaded;
      _scheduleRefresh();
    } catch (e) {
      _error = e.toString();
      _state = LoadState.error;
    }
    notifyListeners();
  }

  void _scheduleRefresh() {
    _timer?.cancel();
    _timer = Timer(const Duration(minutes: 5), loadAll);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
