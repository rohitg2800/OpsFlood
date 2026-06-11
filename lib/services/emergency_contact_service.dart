import 'dart:convert';
import 'package:flutter/services.dart';

/// Emergency contact directory – resolves issue #28.
/// Contacts are loaded from assets/data/emergency_contacts.json
/// and keyed by district. Station-name lookup via [getContactsForStation]
/// maps known CWC/WRD Bihar station names to their district.
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

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'category': category,
        if (district != null) 'district': district,
        'is_sos': isSOS,
        if (description != null) 'description': description,
      };
}

class EmergencyContactService {
  static const String _assetPath = 'assets/data/emergency_contacts.json';

  List<EmergencyContact>? _cached;

  // ---------------------------------------------------------------------------
  // Station-name → district mapping for all CWC / WRD Bihar gauging stations
  // ---------------------------------------------------------------------------
  static const Map<String, String> _stationDistrict = {
    // Ganga main-stem
    'Buxar': 'Buxar',
    'Koilwar': 'Bhojpur',
    'Gandhi Ghat': 'Patna',
    'Hathidah': 'Begusarai',
    'Digha Ghat': 'Patna',
    'Munger': 'Munger',
    'Bhagalpur': 'Bhagalpur',
    'Sultanganj': 'Bhagalpur',
    'Kahalgaon': 'Bhagalpur',
    // Gandak
    'Triveni Barrage': 'East Champaran',
    'Bagaha': 'West Champaran',
    'Dumri Ghat': 'Gopalganj',
    'Hajipur': 'Vaishali',
    'Rosera': 'Samastipur',
    // Kosi
    'Birpur': 'Supaul',
    'Baltara': 'Supaul',
    'Basua': 'Supaul',
    'Koparia': 'Saharsa',
    'Kursela': 'Katihar',
    'Nirmali': 'Supaul',
    'Ghonghepur': 'Supaul',
    // Burhi Gandak
    'Dheng': 'Muzaffarpur',
    'Muzaffarpur': 'Muzaffarpur',
    'Sikta': 'West Champaran',
    'Samastipur': 'Samastipur',
    // Bagmati
    'Runisaidpur': 'Sitamarhi',
    'Hayaghat': 'Darbhanga',
    'Benibad': 'Darbhanga',
    // Kamla-Balan
    'Jainagar': 'Madhubani',
    'Jhanjharpur': 'Madhubani',
    'Kamtaul': 'Darbhanga',
    // Mahananda
    'Dhulian': 'Kishanganj',
    'Mirzapur': 'Kishanganj',
    'Jhawa': 'Purnia',
    // Son
    'Dehri-on-Son': 'Rohtas',
    'Indrapuri': 'Rohtas',
    // Ghaghra / Saryu
    'Revelganj': 'Saran',
    'Doriganj': 'Saran',
    // Parman / Bhutahi Balan
    'Naugachia': 'Bhagalpur',
    'Araria': 'Araria',
    // Falgu
    'Gaya': 'Gaya',
  };

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

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
      _cached = _fallbackContacts;
    }
    return _cached!;
  }

  /// Returns global contacts (no district) + contacts for [district].
  Future<List<EmergencyContact>> getContactsByDistrict(
      String district) async {
    final all = await getAllContacts();
    return all
        .where((c) => c.district == null || c.district == district)
        .toList();
  }

  /// Convenience: look up contacts by gauging-station name.
  /// Falls back to all global contacts when the station is unmapped.
  Future<List<EmergencyContact>> getContactsForStation(
      String stationName) async {
    final district = _stationDistrict[stationName];
    if (district == null) return getSOSContacts();
    return getContactsByDistrict(district);
  }

  /// Resolves a station name to its district string (null if unmapped).
  String? districtForStation(String stationName) =>
      _stationDistrict[stationName];

  Future<List<EmergencyContact>> getSOSContacts() async {
    final all = await getAllContacts();
    return all.where((c) => c.isSOS).toList();
  }

  Future<List<String>> getCategories() async {
    final all = await getAllContacts();
    return all.map((c) => c.category).toSet().toList();
  }

  Future<List<EmergencyContact>> getContactsByCategory(
      String category) async {
    final all = await getAllContacts();
    return all.where((c) => c.category == category).toList();
  }

  // ---------------------------------------------------------------------------
  // Fallback (used only when the JSON asset cannot be loaded)
  // ---------------------------------------------------------------------------
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
      description: 'Bihar State EOC – 24×7',
    ),
    const EmergencyContact(
      id: 'bihar_eocc_toll',
      name: 'Bihar Disaster Helpline (Toll-Free)',
      phone: '1070',
      category: 'SDRF Bihar',
      isSOS: true,
    ),
    const EmergencyContact(
      id: 'ndrf_patna',
      name: 'NDRF 9th Battalion – Patna',
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
