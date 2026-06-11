// lib/models/community_incident.dart
// v2.1: added emoji/synced/locationLabel/lon alias getters;
//       made upvotes mutable for in-place increment from UI.
import 'package:hive/hive.dart';

part 'community_incident.g.dart';

@HiveType(typeId: 30)
enum IncidentType {
  @HiveField(0) flooding,
  @HiveField(1) embankmentBreach,
  @HiveField(2) roadBlocked,
  @HiveField(3) waterlogging,
  @HiveField(4) evacuationNeeded,
  @HiveField(5) rescueNeeded,
  @HiveField(6) infrastructureDamage,
  @HiveField(7) other,
}

extension IncidentTypeLabel on IncidentType {
  String get label {
    switch (this) {
      case IncidentType.flooding:             return 'Flooding';
      case IncidentType.embankmentBreach:     return 'Embankment Breach';
      case IncidentType.roadBlocked:          return 'Road Blocked';
      case IncidentType.waterlogging:         return 'Waterlogging';
      case IncidentType.evacuationNeeded:     return 'Evacuation Needed';
      case IncidentType.rescueNeeded:         return 'Rescue Needed';
      case IncidentType.infrastructureDamage: return 'Infrastructure Damage';
      case IncidentType.other:                return 'Other';
    }
  }

  String get icon {
    switch (this) {
      case IncidentType.flooding:             return '\u{1F6A8}';  // 🚨
      case IncidentType.embankmentBreach:     return '\u{1F6A7}';  // 🚧
      case IncidentType.roadBlocked:          return '\u{1F6AB}';  // 🚫
      case IncidentType.waterlogging:         return '\u{1F4A7}';  // 💧
      case IncidentType.evacuationNeeded:     return '\u{1F3CE}\uFE0F'; // 🏎️
      case IncidentType.rescueNeeded:         return '\u{1F691}';  // 🚑
      case IncidentType.infrastructureDamage: return '\u{1F3D7}\uFE0F'; // 🏗️
      case IncidentType.other:                return '\u2139\uFE0F'; // ℹ️
    }
  }

  /// Alias so call-sites using .emoji work identically to .icon
  String get emoji => icon;
}

@HiveType(typeId: 31)
class CommunityIncident extends HiveObject {
  @HiveField(0)  final String       id;
  @HiveField(1)  final IncidentType  type;
  @HiveField(2)  final String        headline;
  @HiveField(3)  final String        description;
  @HiveField(4)  final double        lat;
  @HiveField(5)  final double        lng;
  @HiveField(6)  final String        district;
  @HiveField(7)  final DateTime      reportedAt;
  @HiveField(8)  final String        submittedBy;
  @HiveField(9)  final List<String>  photoUrls;
  @HiveField(10) final bool          verified;
  // upvotes is intentionally non-final so UI can do inc.upvotes++; inc.save()
  @HiveField(11) int                 upvotes;
  // Optional fields written by community_screen submit sheet
  @HiveField(12) final String?       locationLabel;
  @HiveField(13) final bool          synced;

  CommunityIncident({
    required this.id,
    required this.type,
    required this.headline,
    required this.description,
    required this.lat,
    required this.lng,
    required this.district,
    required this.reportedAt,
    this.submittedBy  = 'anonymous',
    this.photoUrls    = const [],
    this.verified     = false,
    this.upvotes      = 0,
    this.locationLabel,
    this.synced       = false,
  });

  // ── Backward-compat alias getters ──────────────────────────────────────
  String       get title        => headline;
  double       get latitude     => lat;
  double       get longitude    => lng;
  /// lon alias used by community_screen.dart submit sheet
  double       get lon          => lng;
  String       get reporterName => submittedBy;
  List<String> get imageUrls    => photoUrls;
  bool         get isVerified   => verified;

  CommunityIncident copyWith({
    String?       id,
    IncidentType? type,
    String?       headline,
    String?       description,
    double?       lat,
    double?       lng,
    String?       district,
    DateTime?     reportedAt,
    String?       submittedBy,
    List<String>? photoUrls,
    bool?         verified,
    int?          upvotes,
    String?       locationLabel,
    bool?         synced,
  }) => CommunityIncident(
    id:            id            ?? this.id,
    type:          type          ?? this.type,
    headline:      headline      ?? this.headline,
    description:   description   ?? this.description,
    lat:           lat           ?? this.lat,
    lng:           lng           ?? this.lng,
    district:      district      ?? this.district,
    reportedAt:    reportedAt    ?? this.reportedAt,
    submittedBy:   submittedBy   ?? this.submittedBy,
    photoUrls:     photoUrls     ?? this.photoUrls,
    verified:      verified      ?? this.verified,
    upvotes:       upvotes       ?? this.upvotes,
    locationLabel: locationLabel ?? this.locationLabel,
    synced:        synced        ?? this.synced,
  );
}
