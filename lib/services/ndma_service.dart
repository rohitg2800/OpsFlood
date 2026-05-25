// lib/services/ndma_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

// BUG FIX: was using AppEnvironment.apiBaseUrl which defaulted to
// 'https://gdacs.org/' — completely wrong backend URL.
// Now uses AppConfig.baseUrl → 'https://opsflood.onrender.com'

class EmergencyContact {
  final String role;
  final String name;
  final String phone;
  final String state;

  const EmergencyContact({
    required this.role,
    required this.name,
    required this.phone,
    required this.state,
  });
}

class NdmaService {
  static final NdmaService instance = NdmaService._();
  NdmaService._();

  Future<List<dynamic>> fetchAdvisories(String state) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}/api/ndma/advisories'
        '?state=${Uri.encodeComponent(state)}',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.startsWith('<')) return []; // HTML maintenance page guard
        return json.decode(body) as List<dynamic>;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[NdmaService] fetchAdvisories $state: $e');
    }
    return [];
  }

  Future<List<EmergencyContact>> fetchEmergencyContacts(String state) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}/api/ndma/emergency-contacts'
        '?state=${Uri.encodeComponent(state)}',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.startsWith('<')) return [];
        final raw = json.decode(body);
        final list = raw is List ? raw : (raw is Map ? raw['data'] as List? ?? [] : []);
        return list
            .whereType<Map<String, dynamic>>()
            .map((m) => EmergencyContact(
                  role:  m['role']?.toString()  ?? '',
                  name:  m['name']?.toString()  ?? '',
                  phone: m['phone']?.toString() ?? '',
                  state: m['state']?.toString() ?? state,
                ))
            .toList();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[NdmaService] fetchEmergencyContacts $state: $e');
    }
    return [];
  }
}
