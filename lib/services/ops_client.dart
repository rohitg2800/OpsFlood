// lib/services/ops_client.dart
// EQUINOX-BH — Unified HTTP Client

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../constants/app_constants.dart';

class OpsClient {
  OpsClient._();
  static final OpsClient instance = OpsClient._();

  http.Client _client = http.Client();

  static void overrideForTesting(http.Client client) {
    instance._client = client;
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
    Map<String, String>? queryParams,
    Duration timeout = AppConstants.defaultTimeout,
    int retries = AppConstants.maxRetries,
  }) async {
    final uri = _buildUri(path, query ?? queryParams);
    return _withRetry(
      () => _client.get(uri, headers: _headers()).timeout(timeout),
      retries: retries,
      label: 'GET $path',
    );
  }

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

  Future<bool> isBackendReachable() async {
    try {
      final result =
          await get('/health', timeout: AppConstants.shortTimeout, retries: 1);
      return result['status'] == 'ok' || result.containsKey('status');
    } catch (_) {
      return false;
    }
  }

  Uri _buildUri(String path, Map<String, String>? params) {
    final base     = AppConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final fullPath = path.startsWith('/') ? path : '/$path';
    final uri      = Uri.parse('$base$fullPath');
    return params != null && params.isNotEmpty
        ? uri.replace(queryParameters: params)
        : uri;
  }

  Map<String, String> _headers() => {
        HttpHeaders.contentTypeHeader: 'application/json',
        HttpHeaders.acceptHeader:      'application/json',
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

        if (response.statusCode == 503 && attempt < retries) {
          final delay = AppConstants.retryDelay * attempt;
          if (kDebugMode) debugPrint('[OpsClient] $label 503, retry $attempt in ${delay.inSeconds}s');
          await Future.delayed(delay);
          continue;
        }
        if (response.statusCode >= 400) {
          return {
            'status': 'error',
            'error':  'HTTP ${response.statusCode}: ${response.reasonPhrase}',
            'code':   response.statusCode,
          };
        }
        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (response.body.isEmpty) return {'status': 'ok'};
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) return decoded;
          return {'status': 'success', 'data': decoded};
        }
        return {
          'status': 'error',
          'error':  'HTTP ${response.statusCode}',
          'code':   response.statusCode,
        };
      } on TimeoutException catch (e) {
        if (attempt >= retries) {
          return {'status': 'error', 'error': 'timeout: $e'};
        }
        final delay = AppConstants.retryDelay * attempt;
        if (kDebugMode) debugPrint('[OpsClient] $label timeout, retry $attempt in ${delay.inSeconds}s');
        await Future.delayed(delay);
      } catch (e) {
        if (attempt >= retries) {
          return {'status': 'error', 'error': e.toString()};
        }
        final delay = AppConstants.retryDelay * attempt;
        if (kDebugMode) debugPrint('[OpsClient] $label error ($e), retry $attempt/$retries');
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
