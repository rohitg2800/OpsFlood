import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/env.dart';

class EmergencyContact {
  final String role;
  final String name;
  final String phone;
  final String state;

  const EmergencyContact({
    required this.role, 
    required this.name, 
    required this.phone, 
    required this.state
  });
}

class NdmaService {
  Future<List<dynamic>> fetchAdvisories(String state) async {
    try {
      final response = await http.get(Uri.parse(
        '${AppEnvironment.apiBaseUrl}/api/ndma/advisories?state=${Uri.encodeComponent(state)}'
      )).timeout(const Duration(seconds: 4));
      
      if (response.statusCode == 200) {
        return json.decode(response.body) as List<dynamic>;
      }
    } catch (_) {}
    return [];
  }
}
