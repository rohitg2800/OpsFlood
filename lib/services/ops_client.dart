// lib/services/ops_client.dart
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  EQUINOX-BH — Unified HTTP Client                                         ║
// ╚══════════════════════════════════════════════════════════════════════════╝
//
// All outbound HTTP calls from the Flutter app go through this client.
// ║  PROXIED via the EQUINOX-BH backend. The app has ZERO direct external    ║
// ║  API calls except through this client.                                   ║

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../constants/app_constants.dart';

/// Singleton HTTP client for all EQUINOX-BH backend calls.
///
/// Features:
/// - Automatic retry with exponential back-off
/// - Request/response logging in debug mode
/// - Consistent timeout enforcement
/// - JSON-only interface
class OpsClient {
  OpsClient._();
  static final OpsClient instance = OpsClient._();

  final http.Client _client = http.Client();

  // ---------------------------------------------------------------------------
  // Core GET
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? queryParams,
    Duration timeout = AppConstants.defaultTimeout,
    int retries = AppConstants.maxRetries,
  }) async {
    final uri = _buildUri(path, queryParams);
    return _withRetry(
      () => _client
          .get(uri, headers: _headers())
          .timeout(timeout),
      retries: retries,
      label: 'GET $path',
    );
  }

  // ---------------------------------------------------------------------------
  // Core POST
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = AppConstants.defaultTimeout,
    int retries = 1,
  }) async {
    final uri = _buildUri(path, null);
    return _withRetry(
      () => _client
          .post(uri, headers: _headers(), body: jsonEncode(body))
          .timeout(timeout),
      retries: retries,
      label: 'POST $path',
    );
  }

  // ---------------------------------------------------------------------------
  // Health check
  // ---------------------------------------------------------------------------

  Future<bool> isBackendReachable() async {
    try {
      final result = await get('/health', timeout: AppConstants.shortTimeout, retries: 1);
      return result['status'] == 'ok' || result.containsKey('status');
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Uri _buildUri(String path, Map<String, String>? params) {
    final base = AppConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final fullPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$base$fullPath');
    return params != null && params.isNotEmpty
        ? uri.replace(queryParameters: params)
        : uri;
  }

  Map<String, String> _headers() => {
        HttpHeaders.contentTypeHeader: 'application/json',
        HttpHeaders.acceptHeader: 'application/json',
        if (AppConfig.apiToken.isNotEmpty)
          HttpHeaders.authorizationHeader: 'Bearer ${AppConfig.apiToken}',
      };

  Future<Map<String, dynamic>> _withRetry(
    Future<http.Response> Function() call, {
    required int retries,
    required String label,
  }) async {
    int attempt = 0;
    while (true) {
      try {
        attempt++;
        final response = await call();
        _logResponse(label, response.statusCode);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) return decoded;
          return {'data': decoded};
        }
        throw HttpException(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
          uri: Uri.parse(label),
        );
      } catch (e) {
        if (attempt >= retries) rethrow;
        final delay = AppConstants.retryDelay * attempt;
        if (kDebugMode) debugPrint('[OpsClient] $label failed ($e), retry $attempt/$retries in ${delay.inSeconds}s');
        await Future.delayed(delay);
      }
    }
  }

  void _logResponse(String label, int statusCode) {
    if (AppConfig.isLoggingEnabled) {
      debugPrint('[OpsClient] $label → $statusCode');
    }
  }

  void dispose() => _client.close();
}
