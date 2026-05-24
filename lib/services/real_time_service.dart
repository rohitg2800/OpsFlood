// lib/services/real_time_service.dart
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  OpsFlood — LAYER 6: Real-Time Service (wired to LiveFetchEngine)     ║
// ║                                                                          ║
// ║  Orchestrates the full data pipeline:                                  ║
// ║    1. Pick city (default or user-selected)                             ║
// ║    2. LiveFetchEngine.fetchCity() → LiveSnapshot (5 sources parallel)  ║
// ║    3. MlInferenceService.infer(snapshot) → InferenceResult             ║
// ║    4. Emit RealTimeState via StreamController                          ║
// ║    5. Auto-refresh every AppConfig.realtimeInterval (45 s default)     ║
// ║                                                                          ║
// ║  Providers / screens listen to stream — no polling logic in UI.        ║
// ╚══════════════════════════════════════════════════════════════════════════╝
library;

import 'dart:async';

import '../config/app_config.dart';
import '../data/india_cities.dart';
import 'live_fetch_engine.dart';
import 'ml_inference.dart';

// ─── State model ──────────────────────────────────────────────────────────────

enum FetchStatus { idle, loading, success, error }

class RealTimeState {
  final FetchStatus status;
  final IndiaCity? city;
  final LiveSnapshot? snapshot;
  final InferenceResult? inference;
  final String? errorMessage;
  final DateTime? lastUpdated;

  const RealTimeState({
    this.status = FetchStatus.idle,
    this.city,
    this.snapshot,
    this.inference,
    this.errorMessage,
    this.lastUpdated,
  });

  RealTimeState copyWith({
    FetchStatus? status,
    IndiaCity? city,
    LiveSnapshot? snapshot,
    InferenceResult? inference,
    String? errorMessage,
    DateTime? lastUpdated,
  }) => RealTimeState(
    status:       status       ?? this.status,
    city:         city         ?? this.city,
    snapshot:     snapshot     ?? this.snapshot,
    inference:    inference    ?? this.inference,
    errorMessage: errorMessage ?? this.errorMessage,
    lastUpdated:  lastUpdated  ?? this.lastUpdated,
  );

  bool get hasData => snapshot != null && inference != null;
  bool get isLoading => status == FetchStatus.loading;

  /// Convenience: flood risk label from inference
  String get riskLabel => inference?.label ?? 'UNKNOWN';
  double get riskProbability => inference?.probability ?? 0.0;

  /// How many live sources are currently healthy
  int get healthySources => snapshot?.healthySourceCount ?? 0;
}

// ─── Service ──────────────────────────────────────────────────────────────────

class RealTimeService {
  RealTimeService._();
  static final RealTimeService instance = RealTimeService._();

  final _engine    = LiveFetchEngine.instance;
  final _inference = MlInferenceService.instance;

  final _controller = StreamController<RealTimeState>.broadcast();
  Stream<RealTimeState> get stream => _controller.stream;

  RealTimeState _state = const RealTimeState();
  RealTimeState get currentState => _state;

  Timer? _timer;
  IndiaCity _city = kIndiaCities.first; // default: Guwahati (highest risk)

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Start polling for [city] (or reuse current city if null).
  void start({IndiaCity? city}) {
    if (city != null) _city = city;
    _timer?.cancel();
    _fetch(); // immediate fetch
    _timer = Timer.periodic(AppConfig.realtimeInterval, (_) => _fetch());
  }

  /// Switch to a different city mid-session.
  void setCity(IndiaCity city) {
    _city = city;
    _fetch();
  }

  /// Switch by city id string (convenience for dropdown / search).
  void setCityById(String id) {
    final c = cityById(id);
    if (c != null) setCity(c);
  }

  /// Force an immediate refresh without resetting the timer.
  void refresh() => _fetch();

  /// Stop all polling (call from dispose).
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }

  // ── Internal fetch pipeline ────────────────────────────────────────────────

  Future<void> _fetch() async {
    _emit(_state.copyWith(status: FetchStatus.loading, city: _city));

    try {
      // Step 1 — parallel fetch from 5 live sources
      final snapshot = await _engine.fetchCity(_city);

      // Step 2 — ML inference using real features
      final result = await _inference.infer(snapshot);

      _emit(_state.copyWith(
        status:      FetchStatus.success,
        city:        _city,
        snapshot:    snapshot,
        inference:   result,
        lastUpdated: DateTime.now(),
        errorMessage: null,
      ));

      if (AppConfig.isDebugLogging) {
        // ignore: avoid_print
        print('[RealTimeService] ${_city.name} → '
            '${result.label} (${(result.probability * 100).toStringAsFixed(1)}%) '
            '| sources: ${snapshot.healthySourceCount}/5');
      }
    } catch (e) {
      _emit(_state.copyWith(
        status: FetchStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  void _emit(RealTimeState s) {
    _state = s;
    if (!_controller.isClosed) _controller.add(s);
  }
}
