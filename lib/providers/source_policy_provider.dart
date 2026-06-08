// lib/providers/source_policy_provider.dart
// Fallback source-chain manager.
//
// Chain: WRD Bihar → Befiqr CWC → Local Seed
// Each hop goes through DataValidator. The first source that passes wins.
// Emits SourcePolicyState — widgets consume dataQualityProvider and
// fallbackBannerProvider without ever knowing which source was used.
library;

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/befiqr_cwc_service.dart';
import '../services/data_validator.dart';

// ─── Source registry ──────────────────────────────────────────────────────────

enum DataSource {
  wrdBihar,   // Primary — Bihar WRD portal
  befiqrCwc,  // Secondary — irrigation.befiqr.in scrape
  localSeed,  // Tertiary — embedded 32-station snapshot
}

extension DataSourceLabel on DataSource {
  String get label => switch (this) {
    DataSource.wrdBihar  => 'WRD Bihar',
    DataSource.befiqrCwc => 'Befiqr CWC',
    DataSource.localSeed => 'Local Seed',
  };
}

// ─── State ────────────────────────────────────────────────────────────────────

class SourcePolicyState {
  final List<CwcStation>      stations;
  final DataQualityState      quality;
  final DataSource            activeSource;
  final DataSource?           failedSource;       // null when primary succeeded
  final ValidationFailure?    lastFailure;        // most recent failure detail
  final bool                  showFallbackBanner;

  const SourcePolicyState({
    required this.stations,
    required this.quality,
    required this.activeSource,
    this.failedSource,
    this.lastFailure,
    this.showFallbackBanner = false,
  });

  String? get subtleBannerMessage {
    if (!showFallbackBanner) return null;
    if (failedSource == null) return null;
    final fs  = failedSource!.label;
    final as_ = activeSource.label;
    return switch (quality) {
      DataQualityState.stale       => '$fs data is stale — showing $as_',
      DataQualityState.sourceError => '$fs unavailable — switched to $as_',
      DataQualityState.fresh       => 'Using $as_ (primary $fs unavailable)',
    };
  }

  SourcePolicyState copyWith({
    List<CwcStation>?   stations,
    DataQualityState?   quality,
    DataSource?         activeSource,
    DataSource?         failedSource,
    ValidationFailure?  lastFailure,
    bool?               showFallbackBanner,
  }) =>
      SourcePolicyState(
        stations:           stations           ?? this.stations,
        quality:            quality            ?? this.quality,
        activeSource:       activeSource       ?? this.activeSource,
        failedSource:       failedSource,
        lastFailure:        lastFailure,
        showFallbackBanner: showFallbackBanner ?? this.showFallbackBanner,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class SourcePolicyNotifier extends AsyncNotifier<SourcePolicyState> {

  static const _chain = [
    DataSource.wrdBihar,
    DataSource.befiqrCwc,
    DataSource.localSeed,
  ];

  @override
  Future<SourcePolicyState> build() => _fetch();

  /// Pull-to-refresh or timer-triggered re-fetch
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  /// User dismissed the fallback banner
  void dismissBanner() {
    state.whenData((s) =>
        state = AsyncData(s.copyWith(showFallbackBanner: false)));
  }

  Future<SourcePolicyState> _fetch() async {
    DataSource?        failedSource;
    ValidationFailure? lastFailure;

    for (final source in _chain) {
      try {
        final raw    = await _fetchFromSource(source);
        final result = DataValidator.validateStationListJson(raw);

        if (result.isOk) {
          final stations = result.valueOrNull!;
          final (:valid, :failures) = DataValidator.partitionList(
              stations, DataValidator.validateStation);

          // Determine quality from per-station failures
          DataQualityState quality = DataQualityState.fresh;
          if (failures.isNotEmpty) {
            final hasStale = failures.any(
                (f) => f.kind == ValidationFailureKind.staleTimestamp);
            quality = hasStale ? DataQualityState.stale : DataQualityState.fresh;
          }

          return SourcePolicyState(
            stations:           valid.isEmpty ? stations : valid,
            quality:            quality,
            activeSource:       source,
            failedSource:       failedSource,
            lastFailure:        lastFailure,
            showFallbackBanner: failedSource != null,
          );
        }

        lastFailure  = result.failureOrNull;
        failedSource ??= source;

      } catch (_) {
        failedSource ??= source;
      }
    }

    // All sources failed
    return SourcePolicyState(
      stations:           const [],
      quality:            DataQualityState.sourceError,
      activeSource:       DataSource.localSeed,
      failedSource:       failedSource,
      lastFailure:        lastFailure,
      showFallbackBanner: true,
    );
  }

  Future<String?> _fetchFromSource(DataSource source) async {
    switch (source) {
      case DataSource.wrdBihar:
        // TODO: replace with real WRD Bihar HTTP call
        // return await WrdBiharService().fetchRaw();
        throw UnimplementedError('WRD Bihar not yet integrated');

      case DataSource.befiqrCwc:
        final stations = await BefiqrCwcService().fetchStations();
        if (stations.isEmpty) return null;
        return jsonEncode(stations.map((s) => s.toJson()).toList());

      case DataSource.localSeed:
        final seed = await BefiqrCwcService().fetchStations();
        return jsonEncode(seed.map((s) => s.toJson()).toList());
    }
  }
}

final sourcePolicyProvider =
    AsyncNotifierProvider<SourcePolicyNotifier, SourcePolicyState>(
  SourcePolicyNotifier.new,
);

// ─── Derived providers — subscribe to only what you need ─────────────────────

/// Quality state only — widgets that show badges subscribe here
final dataQualityProvider = Provider<DataQualityState>((ref) =>
    ref.watch(sourcePolicyProvider).maybeWhen(
      data:   (s) => s.quality,
      orElse: ()  => DataQualityState.fresh,
    ));

/// Banner message — null when fresh or user dismissed
final fallbackBannerProvider = Provider<String?>((ref) =>
    ref.watch(sourcePolicyProvider).maybeWhen(
      data:   (s) => s.subtleBannerMessage,
      orElse: ()  => null,
    ));
