// lib/models/community_incident.dart
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
      case IncidentType.flooding:             return '🚨';
      case IncidentType.embankmentBreach:     return '🚧';
      case IncidentType.roadBlocked:          return '🚫';
      case IncidentType.waterlogging:         return '💧';
      case IncidentType.evacuationNeeded:     return '🏎️';
      case IncidentType.rescueNeeded:         return '🚑';
      case IncidentType.infrastructureDamage: return '🏗️';
      case IncidentType.other:                return 'ℹ️';
    }
  }

  // Alias so call-sites using .emoji keep working
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
  @HiveField(11) int                 upvotes;        // mutable so inc.upvotes++ works
  @HiveField(12) final bool          isSynced;       // persisted sync flag
  @HiveField(13) final String?       locationLabel;  // human-readable location

  CommunityIncident({
    required this.id,
    required this.type,
    String?       headline,
    required this.description,
    required this.lat,
    double?       lng,
    double?       lon,       // accept 'lon' as alias for 'lng'
    required this.district,
    required this.reportedAt,
    String?       submittedBy,
    List<String>? photoUrls,
    bool?         verified,
    int?          upvotes,
    bool          synced        = false,
    this.locationLabel,
  })  : headline    = headline    ?? description,
        lng         = lng ?? lon  ?? 0.0,
        submittedBy = submittedBy ?? 'anonymous',
        photoUrls   = photoUrls   ?? const [],
        verified    = verified    ?? false,
        upvotes     = upvotes     ?? 0,
        isSynced    = synced;

  // ── Alias getters so existing call-sites keep working ─────────────────────
  String       get title        => headline;
  double       get latitude     => lat;
  double       get longitude    => lng;
  double       get lon          => lng;   // community_screen uses .lon
  String       get reporterName => submittedBy;
  List<String> get imageUrls    => photoUrls;
  bool         get isVerified   => verified;
  bool         get synced       => isSynced;

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
    bool?         synced,
    String?       locationLabel,
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
    synced:        synced        ?? this.isSynced,
    locationLabel: locationLabel ?? this.locationLabel,
  );
}
