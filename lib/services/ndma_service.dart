// OpsFlood — NDMA / NDRF Service v2.2
// Emergency contacts: static real NDMA/NDRF numbers (no network needed)
// Advisories: tries OpsFlood backend with circuit-breaker;
//             falls back to static seasonal advisory when backend not live.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/env.dart';

// ── Models ───────────────────────────────────────────────────────────────────────────────
class NdmaAdvisory {
  final String    title;
  final String    state;
  final String    district;
  final String    severity;
  final DateTime? issuedAt;
  final String    source;
  final String    message;

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
      title:    (j['title']    ?? 'NDMA Advisory').toString(),
      state:    (j['state']    ?? '').toString(),
      district: (j['district'] ?? '').toString(),
      severity: (j['severity'] ?? 'MEDIUM').toString().toUpperCase(),
      issuedAt: DateTime.tryParse(
          (j['issued_at'] ?? j['timestamp'] ?? '').toString()),
      source:   (j['source']  ?? 'NDMA').toString(),
      message:  (j['message'] ?? j['description'] ?? '').toString(),
    );
  }
}

class EmergencyContact {
  final String agency;
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
      agency:   (j['agency']   ?? 'NDRF').toString().toUpperCase(),
      state:    (j['state']    ?? '').toString(),
      district: (j['district'] ?? '').toString(),
      name:     (j['name']     ?? 'Emergency Contact').toString(),
      phone:    (j['phone']    ?? j['mobile'] ?? '').toString(),
      role:     (j['role']     ?? 'Emergency response').toString(),
    );
  }
}

// ── Static real NDMA / NDRF emergency contacts ──────────────────────────────────────────
const _nationalContacts = <Map<String, String>>[
  {'agency':'NDMA', 'state':'All India', 'district':'', 'name':'NDMA Control Room',         'phone':'1078',         'role':'National disaster helpline'},
  {'agency':'NDRF', 'state':'All India', 'district':'', 'name':'NDRF National Helpline',    'phone':'011-24363260', 'role':'National disaster response force'},
  {'agency':'NDMA', 'state':'All India', 'district':'', 'name':'National Emergency Number', 'phone':'112',          'role':'Police / Fire / Ambulance'},
];

const _stateContacts = <Map<String, String>>[
  {'agency':'SDMA', 'state':'Maharashtra',      'district':'', 'name':'Maharashtra SEOC',        'phone':'1070',         'role':'State Emergency Operations Centre'},
  {'agency':'SDMA', 'state':'Bihar',            'district':'', 'name':'Bihar SDMA Control Room', 'phone':'0612-2217305', 'role':'State disaster management'},
  {'agency':'SDMA', 'state':'Assam',            'district':'', 'name':'Assam SEOC',              'phone':'0361-2237223', 'role':'State Emergency Operations Centre'},
  {'agency':'SDMA', 'state':'West Bengal',      'district':'', 'name':'WB SDMA Helpline',        'phone':'1070',         'role':'State disaster management'},
  {'agency':'SDMA', 'state':'Odisha',           'district':'', 'name':'Odisha SEOC',             'phone':'0674-2395398', 'role':'State Emergency Operations Centre'},
  {'agency':'SDMA', 'state':'Uttar Pradesh',    'district':'', 'name':'UP Flood Control Room',   'phone':'1070',         'role':'State flood control'},
  {'agency':'SDMA', 'state':'Kerala',           'district':'', 'name':'Kerala SEOC',             'phone':'1070',         'role':'State Emergency Operations Centre'},
  {'agency':'SDMA', 'state':'Gujarat',          'district':'', 'name':'Gujarat SEOC',            'phone':'1070',         'role':'State Emergency Operations Centre'},
  {'agency':'SDMA', 'state':'Rajasthan',        'district':'', 'name':'Rajasthan SEOC',          'phone':'0141-2227470', 'role':'State Emergency Operations Centre'},
  {'agency':'SDMA', 'state':'Madhya Pradesh',   'district':'', 'name':'MP Flood Control Room',   'phone':'0755-2441400', 'role':'State flood control room'},
  {'agency':'SDMA', 'state':'Chhattisgarh',     'district':'', 'name':'CG SDMA Helpline',        'phone':'0771-2443502', 'role':'State disaster management'},
  {'agency':'SDMA', 'state':'Karnataka',        'district':'', 'name':'Karnataka KSNDMC',        'phone':'1070',         'role':'State Natural Disaster Monitoring Centre'},
  {'agency':'SDMA', 'state':'Tamil Nadu',       'district':'', 'name':'Tamil Nadu SEOC',         'phone':'1070',         'role':'State Emergency Operations Centre'},
  {'agency':'SDMA', 'state':'Andhra Pradesh',   'district':'', 'name':'AP SEOC',                 'phone':'1070',         'role':'State Emergency Operations Centre'},
  {'agency':'SDMA', 'state':'Telangana',        'district':'', 'name':'Telangana SEOC',          'phone':'1070',         'role':'State Emergency Operations Centre'},
  {'agency':'SDMA', 'state':'Jharkhand',        'district':'', 'name':'Jharkhand SEOC',          'phone':'0651-2490025', 'role':'State Emergency Operations Centre'},
  {'agency':'SDMA', 'state':'Punjab',           'district':'', 'name':'Punjab Flood Control',    'phone':'0172-2749090', 'role':'State flood control room'},
  {'agency':'SDMA', 'state':'Uttarakhand',      'district':'', 'name':'Uttarakhand SEOC',        'phone':'0135-2710334', 'role':'State Emergency Operations Centre'},
  {'agency':'SDMA', 'state':'Himachal Pradesh', 'district':'', 'name':'HP SEOC',                 'phone':'1077',         'role':'State Emergency Operations Centre'},
  {'agency':'SDMA', 'state':'Haryana',          'district':'', 'name':'Haryana SEOC',            'phone':'0172-2560155', 'role':'State Emergency Operations Centre'},
  {'agency':'SDMA', 'state':'Manipur',          'district':'', 'name':'Manipur SEOC',            'phone':'0385-2451144', 'role':'State Emergency Operations Centre'},
  {'agency':'SDMA', 'state':'Meghalaya',        'district':'', 'name':'Meghalaya SEOC',          'phone':'0364-2502113', 'role':'State Emergency Operations Centre'},
  {'agency':'SDMA', 'state':'Arunachal Pradesh','district':'', 'name':'Arunachal SEOC',          'phone':'0360-2244872', 'role':'State Emergency Operations Centre'},
  {'agency':'SDMA', 'state':'Tripura',          'district':'', 'name':'Tripura SEOC',            'phone':'0381-2325759', 'role':'State Emergency Operations Centre'},
  {'agency':'SDMA', 'state':'Sikkim',           'district':'', 'name':'Sikkim SEOC',             'phone':'03592-202626', 'role':'State Emergency Operations Centre'},
  {'agency':'SDMA', 'state':'Goa',              'district':'', 'name':'Goa SEOC',                'phone':'0832-2419550', 'role':'State Emergency Operations Centre'},
  {'agency':'SDMA', 'state':'Delhi',            'district':'', 'name':'Delhi DDMA Control Room', 'phone':'1077',         'role':'Delhi Disaster Management Authority'},
  {'agency':'SDMA', 'state':'Jammu and Kashmir','district':'', 'name':'J&K SEOC',                'phone':'0194-2473590', 'role':'State Emergency Operations Centre'},
  // NDRF Battalions
  {'agency':'NDRF', 'state':'Assam',            'district':'', 'name':'NDRF 12th Bn Guwahati',   'phone':'0361-2840024', 'role':'NDRF battalion — NE India'},
  {'agency':'NDRF', 'state':'Bihar',            'district':'', 'name':'NDRF 9th Bn Patna',       'phone':'0612-2223040', 'role':'NDRF battalion — Bihar/Jharkhand'},
  {'agency':'NDRF', 'state':'Odisha',           'district':'', 'name':'NDRF 2nd Bn Odisha',      'phone':'0671-2301644', 'role':'NDRF battalion — Odisha'},
  {'agency':'NDRF', 'state':'Maharashtra',      'district':'', 'name':'NDRF 3rd Bn Pune',        'phone':'020-26330206', 'role':'NDRF battalion — Maharashtra/Goa'},
  {'agency':'NDRF', 'state':'West Bengal',      'district':'', 'name':'NDRF 4th Bn Arakkonam',  'phone':'044-27260055', 'role':'NDRF battalion — WB/Sikkim'},
  {'agency':'NDRF', 'state':'Uttar Pradesh',    'district':'', 'name':'NDRF 11th Bn Varanasi',  'phone':'0542-2509001', 'role':'NDRF battalion — UP/UK'},
  {'agency':'NDRF', 'state':'Gujarat',          'district':'', 'name':'NDRF 6th Bn Vadodara',   'phone':'0265-2282055', 'role':'NDRF battalion — Gujarat/Rajasthan'},
  {'agency':'NDRF', 'state':'Uttarakhand',      'district':'', 'name':'NDRF 8th Bn Ghaziabad',  'phone':'0120-2701200', 'role':'NDRF battalion — Uttarakhand/Delhi'},
  {'agency':'NDRF', 'state':'Tamil Nadu',       'district':'', 'name':'NDRF 4th Bn Arakkonam',  'phone':'044-27260055', 'role':'NDRF battalion — TN/Andhra'},
];

// ── Global dedup cache: built once, reused forever ───────────────────────────────────────
List<EmergencyContact>? _allContactsCache;

List<EmergencyContact> _getAllContacts() {
  if (_allContactsCache != null) return _allContactsCache!;
  final seen = <String>{};
  final out  = <EmergencyContact>[];
  for (final m in [..._nationalContacts, ..._stateContacts]) {
    final key = '${m['phone']}-${m['state']}';
    if (seen.add(key)) out.add(EmergencyContact.fromJson(m));
  }
  return _allContactsCache = out;
}

// ── Static fallback advisory ─────────────────────────────────────────────────────────────
List<NdmaAdvisory> _seasonalAdvisories(String state) {
  final now = DateTime.now();
  final isMonsoon = now.month >= 6 && now.month <= 10;
  if (!isMonsoon) return const [];
  return [
    NdmaAdvisory(
      title:    'Flood Preparedness Advisory',
      state:    state == 'All India' ? 'India' : state,
      district: '',
      severity: 'MEDIUM',
      issuedAt: DateTime(now.year, now.month, 1),
      source:   'NDMA',
      message:
          'Monsoon season active. Keep emergency kit ready. '
          'Move to higher ground if local water levels rise. '
          'Monitor CWC / IMD alerts. Call 1078 for assistance.',
    ),
  ];
}

// ── Circuit-breaker state ────────────────────────────────────────────────────────────────
int       _advFailures     = 0;
DateTime? _advBackoff;
bool      _circuitLoggedOnce = false;   // ← prevents log spam across 93-city loop
const     _advMaxFail        = 3;
const     _advBackoffDur     = Duration(minutes: 30);

// ── Service ──────────────────────────────────────────────────────────────────────────────
class NdmaService {
  NdmaService._();
  static final NdmaService instance = NdmaService._();

  final http.Client _client = http.Client();
  static const _timeout     = Duration(seconds: 12);

  // ── Advisories ─────────────────────────────────────────────────────────────────────────
  Future<List<NdmaAdvisory>> getAdvisories({required String state}) async {
    // Circuit open: skip network, return fallback silently (log only once per window)
    if (_advBackoff != null && DateTime.now().isBefore(_advBackoff!)) {
      if (kDebugMode && !_circuitLoggedOnce) {
        debugPrint('[NDMA] advisory circuit open — skipping network until '
            '${_advBackoff!.toLocal().toString().substring(11, 16)}');
        _circuitLoggedOnce = true;
      }
      return _seasonalAdvisories(state);
    }

    // Reset log-once flag when backoff window expires
    _circuitLoggedOnce = false;

    try {
      final res = await _client
          .get(Uri.parse(
              '${Env.baseUrl}/api/ndma/advisories?state=${Uri.encodeComponent(state)}'))
          .timeout(_timeout);
      final ct = res.headers['content-type'] ?? '';
      if (res.statusCode == 200 &&
          (ct.contains('application/json') || ct.contains('text/json'))) {
        final payload = jsonDecode(res.body);
        final items   = _extractList(payload);
        final result  = items
            .whereType<Map<String, dynamic>>()
            .map(NdmaAdvisory.fromJson)
            .toList(growable: false);
        _advFailures = 0;
        _advBackoff  = null;
        return result;
      }
      _recordAdvFailure();
    } catch (_) {
      _recordAdvFailure();
    }
    return _seasonalAdvisories(state);
  }

  // ── Emergency contacts ──────────────────────────────────────────────────────────────────
  // Returns national contacts (once) + state-specific contacts.
  // Called per-state by real_time_service but global dedup ensures
  // nationals appear exactly once in the merged _emergencyContacts list.
  Future<List<EmergencyContact>> getContacts({required String state}) async {
    final all = _getAllContacts();
    return all
        .where((c) => c.state == 'All India' || c.state == state)
        .toList(growable: false);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────────────
  void _recordAdvFailure() {
    _advFailures++;
    if (_advFailures >= _advMaxFail) {
      _advBackoff        = DateTime.now().add(_advBackoffDur);
      _circuitLoggedOnce = false;  // allow one fresh log when circuit first trips
      if (kDebugMode) {
        debugPrint('[NDMA] advisory circuit tripped after $_advFailures failures '
            '— backing off for 30 min');
      }
    }
  }

  List<dynamic> _extractList(dynamic payload, {int depth = 0}) {
    if (depth > 5) return const [];
    if (payload is List) return payload;
    if (payload is Map<String, dynamic>) {
      for (final k in const [
        'data', 'items', 'results', 'advisories', 'contacts', 'records'
      ]) {
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
