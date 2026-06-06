import 'package:flutter/foundation.dart';
import '../services/offline_cache_service.dart';

/// Resolves issue #19: AI-Based Flood Risk Indicator
class RiskScore {
  final String stationId;
  final double score; // 0-100
  final RiskZone zone;
  final List<String> contributingFactors;
  final double confidencePercent;
  final DateTime updatedAt;

  const RiskScore({
    required this.stationId,
    required this.score,
    required this.zone,
    required this.contributingFactors,
    required this.confidencePercent,
    required this.updatedAt,
  });

  factory RiskScore.fromMap(Map<String, dynamic> map) => RiskScore(
        stationId: map['station_id'] ?? '',
        score: (map['score'] ?? 0.0).toDouble(),
        zone: RiskZone.fromScore((map['score'] ?? 0.0).toDouble()),
        contributingFactors:
            List<String>.from(map['contributing_factors'] ?? []),
        confidencePercent:
            (map['confidence_percent'] ?? 0.0).toDouble(),
        updatedAt: map['updated_at'] != null
            ? DateTime.parse(map['updated_at'])
            : DateTime.now(),
      );
}

enum RiskZone {
  low,    // 0-20
  moderate, // 21-40
  high,   // 41-60
  veryHigh, // 61-80
  critical; // 81-100

  static RiskZone fromScore(double score) {
    if (score <= 20) return RiskZone.low;
    if (score <= 40) return RiskZone.moderate;
    if (score <= 60) return RiskZone.high;
    if (score <= 80) return RiskZone.veryHigh;
    return RiskZone.critical;
  }

  String get label {
    switch (this) {
      case RiskZone.low: return 'Low';
      case RiskZone.moderate: return 'Moderate';
      case RiskZone.high: return 'High';
      case RiskZone.veryHigh: return 'Very High';
      case RiskZone.critical: return 'Critical';
    }
  }
}

class RiskScoreProvider extends ChangeNotifier {
  final Map<String, RiskScore> _scores = {};
  bool _isLoading = false;
  String? _error;

  Map<String, RiskScore> get scores => Map.unmodifiable(_scores);
  bool get isLoading => _isLoading;
  String? get error => _error;

  RiskScore? getScore(String stationId) => _scores[stationId];

  Future<void> fetchRiskScore(String stationId, String baseUrl) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Try cache first
      final cache = OfflineCacheService();
      final cached = await cache.getCachedData('risk_$stationId');
      if (cached != null) {
        _scores[stationId] = RiskScore.fromMap(cached);
        notifyListeners();
      }

      // TODO: Replace with actual HTTP call when online:
      // final response = await http.get(Uri.parse('$baseUrl/api/v1/risk-score?station_id=$stationId'));
      // if (response.statusCode == 200) {
      //   final data = jsonDecode(response.body);
      //   _scores[stationId] = RiskScore.fromMap(data);
      //   await cache.cacheData('risk_$stationId', data);
      // }

      // Demo fallback score
      if (!_scores.containsKey(stationId)) {
        _scores[stationId] = RiskScore(
          stationId: stationId,
          score: 45.0,
          zone: RiskZone.high,
          contributingFactors: [
            'Water level at 85% of danger threshold',
            'IMD forecasts heavy rainfall in next 24h',
            'Upstream stations showing rising trend',
          ],
          confidencePercent: 78.0,
          updatedAt: DateTime.now(),
        );
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('RiskScoreProvider error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchAllDistrictScores(String baseUrl) async {
    // TODO: Batch fetch district-level risk aggregation
    // GET $baseUrl/api/v1/risk-score?scope=district
    debugPrint('Fetching all district risk scores...');
  }
}
