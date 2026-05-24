// lib/services/ops_client.dart
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  OpsFlood — Unified HTTP Client                                         ║
// ║                                                                          ║
// ║  Single http.Client. Single retry/timeout policy. One base URL.        ║
// ║  ALL network calls in the app go through OpsClient.                    ║
// ║                                                                          ║
// ║  Every external service (CWC, GloFAS, IMD, NDMA, OpenMeteo) is        ║
// ║  PROXIED via the OpsFlood backend. The app has ZERO direct external    ║
// ║  calls, eliminating CORS issues and external API fragility.             ║
// ╚══════════════════════════════════════════════════════════════════════════╝
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class OpsClient {
  OpsClient._();
  static final OpsClient instance = OpsClient._();

  final http.Client _http = http.Client();

  // ── GET ───────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
    Duration? timeout,
  }) =>
      _request(
        method: 'GET',
        path: _withQuery(path, query),
        timeout: timeout ?? AppConfig.requestTimeout,
      );

  // ── POST ──────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    Duration? timeout,
  }) =>
      _request(
        method: 'POST',
        path: path,
        body: body,
        timeout: timeout ?? AppConfig.requestTimeout,
      );

  // ── Core dispatcher ───────────────────────────────────────────────────────
  Future<Map<String, dynamic>> _request({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    required Duration timeout,
  }) async {
    Object? lastError;

    for (int attempt = 1; attempt <= AppConfig.maxRetries; attempt++) {
      try {
        final uri  = Uri.parse('${AppConfig.baseUrl}$path');
        late final http.Response res;

        if (method == 'POST') {
          res = await _http
              .post(uri,
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode(body ?? <String, dynamic>{}))
              .timeout(timeout);
        } else {
          res = await _http.get(uri).timeout(timeout);
        }

        _log('${res.statusCode} $method $path (attempt $attempt)');

        // 2xx — success
        if (res.statusCode >= 200 && res.statusCode < 300) {
          return _normalize(_decode(res.body));
        }

        // 404 — wrong endpoint, no point retrying
        if (res.statusCode == 404) {
          lastError = '404 Not Found: $path';
          break;
        }

        // 503 — server overloaded, exponential back-off
        if (res.statusCode == 503) {
          lastError = '503 Server Overloaded (attempt $attempt)';
          if (attempt < AppConfig.maxRetries) {
            await _wait(AppConfig.serverOverloadWait * attempt);
          }
          continue;
        }

        // Other 4xx — fast fail
        if (res.statusCode >= 400 && res.statusCode < 500) {
          lastError = '${res.statusCode} Client Error: $path';
          break;
        }

        // Other 5xx — standard backoff
        lastError = '${res.statusCode} Server Error';
        if (attempt < AppConfig.maxRetries) {
          await _wait(AppConfig.retryBackoff);
        }
      } on TimeoutException {
        lastError = 'Timeout after ${timeout.inSeconds}s';
        _log('⏱ Timeout on attempt $attempt — $method $path');
        if (attempt < AppConfig.maxRetries) await _wait(AppConfig.retryBackoff);
      } catch (e) {
        lastError = e;
        _log('❌ Error on attempt $attempt — $e');
        if (attempt < AppConfig.maxRetries) await _wait(AppConfig.retryBackoff);
      }
    }

    _log('⛔ All attempts failed — $method $path — $lastError');
    return {
      'status': 'error',
      'error' : lastError?.toString() ?? 'Unknown error',
      'data'  : <dynamic>[],
    };
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _withQuery(String path, Map<String, String>? query) {
    if (query == null || query.isEmpty) return path;
    final qs = query.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return '$path?$qs';
  }

  dynamic _decode(String body) {
    try { return jsonDecode(body); } catch (_) { return body; }
  }

  Map<String, dynamic> _normalize(dynamic parsed) {
    if (parsed is Map<String, dynamic>) return parsed;
    return {'status': 'success', 'data': parsed};
  }

  void _log(String msg) {
    if (AppConfig.isDebugLogging || !AppConfig.isProduction) {
      debugPrint('[OpsClient] $msg');
    }
  }

  static Future<void> _wait(Duration d) => Future<void>.delayed(d);
}
