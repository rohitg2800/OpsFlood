// Model: CWC River Station with danger classification
class RiverStation {
  final String city;
  final String state;
  final String river;
  final String station;
  final double current;    // m – current gauge reading
  final double warning;   // m – CWC warning level
  final double danger;    // m – CWC danger level
  final double hfl;       // m – highest flood level

  const RiverStation({
    required this.city,
    required this.state,
    required this.river,
    required this.station,
    required this.current,
    required this.warning,
    required this.danger,
    required this.hfl,
  });

  /// CWC 4-tier classification
  DangerClass get dangerClass {
    if (current >= hfl) return DangerClass.extreme;
    if (current >= danger) return DangerClass.severe;
    if (current >= warning) return DangerClass.aboveNormal;
    return DangerClass.normal;
  }

  /// 0-100 progress against HFL
  double get progressPct => (current / hfl).clamp(0.0, 1.0);

  /// Risk sort score
  int get riskScore => dangerClass.index;

  RiverStation copyWith({double? current}) => RiverStation(
        city: city,
        state: state,
        river: river,
        station: station,
        current: current ?? this.current,
        warning: warning,
        danger: danger,
        hfl: hfl,
      );
}

enum DangerClass { normal, aboveNormal, severe, extreme }

extension DangerClassExt on DangerClass {
  String get label {
    switch (this) {
      case DangerClass.normal:      return 'Normal';
      case DangerClass.aboveNormal: return 'Above Normal';
      case DangerClass.severe:      return 'Severe';
      case DangerClass.extreme:     return 'Extreme';
    }
  }
}
