import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/source_policy.dart';

enum PolicyStatus { loading, live, locked, offline }

/// Polls /health every [pollInterval] and exposes [policy] + [status].
/// Option A gate: consumers check [allowLiveCwc] before fetching telemetry.
class SourcePolicyProvider extends ChangeNotifier {
  static const String _baseUrl = 'https://opsflood.onrender.com';
  static const Duration pollInterval = Duration(seconds: 60);

  SourcePolicy _policy = SourcePolicy.fallback();
  PolicyStatus _status = PolicyStatus.loading;
  String? _error;
  Timer? _timer;

  SourcePolicy get policy => _policy;
  PolicyStatus get status => _status;
  String? get error => _error;

  /// Option A: true only when backend confirms allow_live_cwc_in_app = true.
  bool get allowLiveCwc =>
      _status == PolicyStatus.live && _policy.allowLiveCwcInApp;

  SourcePolicyProvider() {
    _fetch();
    _timer = Timer.periodic(pollInterval, (_) => _fetch());
  }

  Future<void> refresh() => _fetch();

  Future<void> _fetch() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final policyJson = json['source_policy'] as Map<String, dynamic>?;
        _policy = policyJson != null
            ? SourcePolicy.fromJson(policyJson)
            : SourcePolicy.fallback();
        _status = _policy.allowLiveCwcInApp
            ? PolicyStatus.live
            : PolicyStatus.locked;
        _error = null;
      } else {
        _policy = SourcePolicy.fallback();
        _status = PolicyStatus.offline;
        _error = 'HTTP ${res.statusCode}';
      }
    } catch (e) {
      _policy = SourcePolicy.fallback();
      _status = PolicyStatus.offline;
      _error = e.toString();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
