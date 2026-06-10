// lib/models/community_incident.dart
// OpsFlood — Module 5: Community & Offline
//
// CommunityIncident model
// ─────────────────────────────────────────────────────────────────────────
// Represents a ground-truth flood event reported by a community member.
// Stored locally in a Hive box ('community_incidents') and optionally
// synced to the OpsFlood backend when connectivity is available.

import 'package:hive/hive.dart';

part 'community_incident.g.dart';

// ── Incident type enum ───────────────────────────────────────────────────

@HiveType(typeId: 30)
enum IncidentType {
  @HiveField(0)
  waterlogging,

  @HiveField(1)
  embankmentBreach,

  @HiveField(2)
  roadBlocked,

  @HiveField(3)
  evacuationNeeded,

  @HiveField(4)
  bridgeDamage,

  @HiveField(5)
  other;

  /// Short English label shown on chip.
  String get label {
    switch (this) {
      case IncidentType.waterlogging:      return 'Waterlogging';
      case IncidentType.embankmentBreach:  return 'Embankment Breach';
      case IncidentType.roadBlocked:       return 'Road Blocked';
      case IncidentType.evacuationNeeded:  return 'Evacuation Needed';
      case IncidentType.bridgeDamage:      return 'Bridge Damage';
      case IncidentType.other:             return 'Other';
    }
  }

  /// Hindi label.
  String get labelHi {
    switch (this) {
      case IncidentType.waterlogging:      return 'जलभराव';
      case IncidentType.embankmentBreach:  return 'तटबंध टूटना';
      case IncidentType.roadBlocked:       return 'सड़क बाधित';
      case IncidentType.evacuationNeeded:  return 'निकासी आवश्यक';
      case IncidentType.bridgeDamage:      return 'पुल क्षति';
      case IncidentType.other:             return 'अन्य';
    }
  }

  String get emoji {
    switch (this) {
      case IncidentType.waterlogging:      return '🌊';
      case IncidentType.embankmentBreach:  return '💥';
      case IncidentType.roadBlocked:       return '🚧';
      case IncidentType.evacuationNeeded:  return '🚨';
      case IncidentType.bridgeDamage:      return '🌉';
      case IncidentType.other:             return '📍';
    }
  }
}

// ── CommunityIncident model ──────────────────────────────────────────────

@HiveType(typeId: 31)
class CommunityIncident extends HiveObject {
  @HiveField(0)
  final String id; // UUID

  @HiveField(1)
  final IncidentType type;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final double lat;

  @HiveField(4)
  final double lon;

  @HiveField(5)
  final String district;

  @HiveField(6)
  final DateTime reportedAt;

  @HiveField(7)
  int upvotes;

  /// Whether this report has been uploaded to the backend.
  @HiveField(8)
  bool synced;

  /// Optional image path (local file, pending upload).
  @HiveField(9)
  final String? imagePath;

  /// Auto-generated short address from reverse geocode (may be null offline).
  @HiveField(10)
  final String? locationLabel;

  CommunityIncident({
    required this.id,
    required this.type,
    required this.description,
    required this.lat,
    required this.lon,
    required this.district,
    required this.reportedAt,
    this.upvotes     = 0,
    this.synced      = false,
    this.imagePath,
    this.locationLabel,
  });

  // ── JSON (for backend sync) ────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id':             id,
        'type':           type.name,
        'description':    description,
        'lat':            lat,
        'lon':            lon,
        'district':       district,
        'reported_at':    reportedAt.toIso8601String(),
        'upvotes':        upvotes,
        'image_path':     imagePath,
        'location_label': locationLabel,
      };

  factory CommunityIncident.fromJson(Map<String, dynamic> json) =>
      CommunityIncident(
        id:            json['id'] as String,
        type:          IncidentType.values.byName(
                           json['type'] as String),
        description:   json['description'] as String,
        lat:           (json['lat'] as num).toDouble(),
        lon:           (json['lon'] as num).toDouble(),
        district:      json['district'] as String,
        reportedAt:    DateTime.parse(json['reported_at'] as String),
        upvotes:       (json['upvotes'] as num?)?.toInt() ?? 0,
        synced:        true,
        imagePath:     json['image_path'] as String?,
        locationLabel: json['location_label'] as String?,
      );
}
