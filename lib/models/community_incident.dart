// lib/models/community_incident.dart
import 'package:hive/hive.dart';

part 'community_incident.g.dart';

@HiveType(typeId: 30)
enum IncidentType {
  @HiveField(0) flooding,
  @HiveField(1) embankmentBreach,
  @HiveField(2) roadBlocked,
  @HiveField(3) waterlogging,
  @HiveField(4) evacuationNeeded,   // was: evacuation -> now evacuationNeeded
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
}

@HiveType(typeId: 31)
class CommunityIncident extends HiveObject {
  @HiveField(0)  final String       id;
  @HiveField(1)  final IncidentType  type;
  @HiveField(2)  final String        headline;      // was: title
  @HiveField(3)  final String        description;
  @HiveField(4)  final double        lat;           // was: latitude
  @HiveField(5)  final double        lng;           // was: longitude
  @HiveField(6)  final String        district;
  @HiveField(7)  final DateTime      reportedAt;
  @HiveField(8)  final String        submittedBy;   // was: reporterName
  @HiveField(9)  final List<String>  photoUrls;     // was: imageUrls
  @HiveField(10) final bool          verified;      // was: isVerified
  @HiveField(11) final int           upvotes;

  CommunityIncident({
    required this.id,
    required this.type,
    required this.headline,
    required this.description,
    required this.lat,
    required this.lng,
    required this.district,
    required this.reportedAt,
    required this.submittedBy,
    required this.photoUrls,
    required this.verified,
    required this.upvotes,
  });

  // Alias getters so existing call-sites keep working
  String       get title        => headline;
  double       get latitude     => lat;
  double       get longitude    => lng;
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
  }) => CommunityIncident(
    id:          id          ?? this.id,
    type:        type        ?? this.type,
    headline:    headline    ?? this.headline,
    description: description ?? this.description,
    lat:         lat         ?? this.lat,
    lng:         lng         ?? this.lng,
    district:    district    ?? this.district,
    reportedAt:  reportedAt  ?? this.reportedAt,
    submittedBy: submittedBy ?? this.submittedBy,
    photoUrls:   photoUrls   ?? this.photoUrls,
    verified:    verified    ?? this.verified,
    upvotes:     upvotes     ?? this.upvotes,
  );
}
