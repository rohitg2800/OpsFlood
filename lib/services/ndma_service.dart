// OpsFlood — NDMA / NDRF Integration Service
// ─────────────────────────────────────────────────────────────────────────────
// P2: Governance + emergency response layer.
//
// PURPOSE
//   Surface official disaster advisories, emergency contacts, and response
//   metadata relevant to a flood event. This is the policy / operations side
//   of the stack, complementing IMD weather and CWC hydrology.
//
// PREFERRED BACKEND CONTRACTS
//   GET /api/ndma/advisories?state=Maharashtra
//   GET /api/ndrf/contacts?state=Maharashtra
//   GET /api/disaster/shelters?district=Pune
//
// Response shapes expected by app:
//   {
//     "status": "ok",
//     "data": [
//       {
//         "title": "Flood preparedness advisory",
//         "state": "Maharashtra",
//         "district": "Pune",
//         "severity": "HIGH",
//         "issued_at": "2026-05-22T12:00:00Z",
//         "source": "NDMA",
//         "message": "Keep emergency kit and monitor official updates"
//       }
//     ]
//   }
//
//   {
//     "status": "ok",
//     "data": [
//       {
//         "agency": "NDRF",
//         "state": "Maharashtra",
//         "district": "Pune",
//         "name": "Regional Emergency Control Room",
//         "phone": "+91-XXXXXXXXXX",
//         "role": "Emergency response"
//       }
//     ]
//   }
// ─────────────────────────────────────────────────────────────────────────────
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/env.dart';

class NdmaAdvisory {
  final String title;
  final String state;
  final String district;
  final String severity;
  final DateTime? issuedAt;
  final String source;
  final String message;

  const NdmaAdvisory({
    required this.title,
    required this.state,
    required this.district,
    required this.severity,
    required this.issuedAt,
    required this.source,
    required this.message,
  });

  factory NdmaAdvisory.fromJson(Map<String, dynamic> j) {
    return NdmaAdvisory(
      title:     (j['title'] ?? 'NDMA Advisory').toString(),
      state:     (j['state'] ?? '').toString(),
      district:  (j['district'] ?? '').toString(),
      severity:  (j['severity'] ?? 'MEDIUM').toString().toUpperCase(),
      issuedAt:  DateTime.tryParse((j['issued_at'] ?? j['timestamp'] ?? '').toString()),
      source:    (j['source'] ?? 'NDMA').toString(),
      message:   (j['message'] ?? j['description'] ?? '').toString(),
    );
  }
}

class EmergencyContact {
  final String agency; // NDMA | NDRF | SDRF | DISTRICT_ADMIN
  final String state;
  final String district;
  final String name;
  final String phone;
  final String role;

  const EmergencyContact({
    required this.agency,
    required this.state,
    required this.district,
    required this.name,
    required this.phone,
    required this.role,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> j) {
    return EmergencyContact(
      agency:   (j['agency'] ?? 'NDRF').toString().toUpperCase(),
      state:    (j['state'] ?? '').toString(),
      district: (j['district'] ?? '').toString(),
      name:     (j['name'] ?? 'Emergency Contact').toString(),
      phone:    (j['phone'] ?? j['mobile'] ?? '').toString(),
      role:     (j['role'] ?? 'Emergency response').toString(),
    );
  }
}

class NdmaService {
  NdmaService._();
  static final NdmaService instance = NdmaService._();

  final http.Client _client = http.Client();
  static const _timeout = Duration(seconds: 12);

  Future<List<NdmaAdvisory>> getAdvisories({required String state}) async {
    try {
      final res = await _client
          .get(Uri.parse('${Env.baseUrl}/api/ndma/advisories?state=${Uri.encodeComponent(state)}'))
          .timeout(_timeout);
      if (res.statusCode != 200) return const <NdmaAdvisory>[];
      final payload = jsonDecode(res.body);
      final items = _extractList(payload);
      return items
          .whereType<Map<String, dynamic>>()
          .map(NdmaAdvisory.fromJson)
          .toList(growable: false);
    } catch (e) {
      if (kDebugMode) debugPrint('[NDMA] advisory error: $e');
      return const <NdmaAdvisory>[];
    }
  }

  Future<List<EmergencyContact>> getContacts({required String state}) async {
    try {
      final res = await _client
          .get(Uri.parse('${Env.baseUrl}/api/ndrf/contacts?state=${Uri.encodeComponent(state)}'))
          .timeout(_timeout);
      if (res.statusCode != 200) return const <EmergencyContact>[];
      final payload = jsonDecode(res.body);
      final items = _extractList(payload);
      return items
          .whereType<Map<String, dynamic>>()
          .map(EmergencyContact.fromJson)
          .toList(growable: false);
    } catch (e) {
      if (kDebugMode) debugPrint('[NDMA] contacts error: $e');
      return const <EmergencyContact>[];
    }
  }

  List<dynamic> _extractList(dynamic payload, {int depth = 0}) {
    if (depth > 5) return const [];
    if (payload is List) return payload;
    if (payload is Map<String, dynamic>) {
      for (final k in const ['data', 'items', 'results', 'advisories', 'contacts', 'records']) {
        final v = payload[k];
        if (v is List) return v;
        if (v is Map<String, dynamic>) {
          final inner = _extractList(v, depth: depth + 1);
          if (inner.isNotEmpty) return inner;
        }
      }
    }
    return const [];
  }
}
