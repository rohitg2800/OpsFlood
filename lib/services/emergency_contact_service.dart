import 'dart:convert';
import 'package:flutter/services.dart';

/// Resolves issue #28: Emergency Contact Directory
class EmergencyContact {
  final String id;
  final String name;
  final String phone;
  final String category;
  final String? district;
  final bool isSOS;
  final String? description;

  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.category,
    this.district,
    this.isSOS = false,
    this.description,
  });

  factory EmergencyContact.fromMap(Map<String, dynamic> map) =>
      EmergencyContact(
        id: map['id'] ?? '',
        name: map['name'] ?? '',
        phone: map['phone'] ?? '',
        category: map['category'] ?? '',
        district: map['district'],
        isSOS: map['is_sos'] ?? false,
        description: map['description'],
      );
}

class EmergencyContactService {
  static const String _assetPath =
      'assets/data/emergency_contacts.json';

  List<EmergencyContact>? _cached;

  Future<List<EmergencyContact>> getAllContacts() async {
    if (_cached != null) return _cached!;
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final data = jsonDecode(raw) as List<dynamic>;
      _cached = data
          .cast<Map<String, dynamic>>()
          .map(EmergencyContact.fromMap)
          .toList();
    } catch (_) {
      // Return hardcoded fallback contacts if asset not found
      _cached = _fallbackContacts;
    }
    return _cached!;
  }

  Future<List<EmergencyContact>> getContactsByDistrict(
      String district) async {
    final all = await getAllContacts();
    return all.where((c) => c.district == null || c.district == district).toList();
  }

  Future<List<EmergencyContact>> getSOSContacts() async {
    final all = await getAllContacts();
    return all.where((c) => c.isSOS).toList();
  }

  Future<List<String>> getCategories() async {
    final all = await getAllContacts();
    return all.map((c) => c.category).toSet().toList();
  }

  static final List<EmergencyContact> _fallbackContacts = [
    const EmergencyContact(
      id: 'ndrf_hq',
      name: 'NDRF Headquarters',
      phone: '011-24363260',
      category: 'NDRF',
      isSOS: true,
      description: 'National Disaster Response Force HQ',
    ),
    const EmergencyContact(
      id: 'ndma',
      name: 'NDMA Helpline',
      phone: '1078',
      category: 'NDMA',
      isSOS: true,
      description: 'National Disaster Management Authority',
    ),
    const EmergencyContact(
      id: 'bihar_eocc',
      name: 'Bihar State Emergency Operation Centre',
      phone: '0612-2294204',
      category: 'SDRF Bihar',
      isSOS: true,
      description: 'Bihar State EOC - 24x7',
    ),
    const EmergencyContact(
      id: 'ndrf_patna',
      name: 'NDRF 9th Battalion Patna',
      phone: '0612-2594112',
      category: 'NDRF',
      district: 'Patna',
      isSOS: true,
    ),
    const EmergencyContact(
      id: 'police',
      name: 'Police Emergency',
      phone: '100',
      category: 'Emergency',
      isSOS: true,
    ),
    const EmergencyContact(
      id: 'ambulance',
      name: 'Ambulance',
      phone: '108',
      category: 'Medical',
      isSOS: true,
    ),
    const EmergencyContact(
      id: 'fire',
      name: 'Fire Emergency',
      phone: '101',
      category: 'Emergency',
      isSOS: true,
    ),
  ];
}
