import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/source_policy.dart';

enum PolicyStatus { loading, live, locked, offline }

class SourcePolicyNotifier extends ChangeNotifier {
  static const String _baseUrl = 'https://opsflood.onrender.com';
  static const Duration _pollInterval = Duration(seconds: 60);

  SourcePolicy _policy = SourcePolicy.fallback();
  PolicyStatus _status = PolicyStatus.loading;
  String? _error;
  Timer? _timer;

  SourcePolicy get policy => _policy;
  PolicyStatus get status => _status;
  String? get error => _error;

  /// Option A gate: true only when backend confirms allow_live_cwc_in_app = true.
  bool get allowLiveCwc =>
      _status == PolicyStatus.live && _policy.allowLiveCwcInApp;

  SourcePolicyNotifier() {
    _fetch();
    _timer = Timer.periodic(_pollInterval, (_) => _fetch());
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

/// Riverpod provider — drop-in alongside existing ChangeNotifierProviders.
final sourcePolicyProvider =
    ChangeNotifierProvider<SourcePolicyNotifier>((ref) {
  final notifier = SourcePolicyNotifier();
  ref.onDispose(notifier.dispose);
  return notifier;
});

/// Convenience derived providers — use these in widgets.
final allowLiveCwcProvider = Provider<bool>((ref) {
  return ref.watch(sourcePolicyProvider).allowLiveCwc;
});

final policyStatusProvider = Provider<PolicyStatus>((ref) {
  return ref.watch(sourcePolicyProvider).status;
});
