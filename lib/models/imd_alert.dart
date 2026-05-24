// lib/models/imd_alert.dart
//
// OpsFlood — ImdAlert
// Parsed representation of a SACHET NDMA CAP alert item.
// Handles both flat and nested (info → …) CAP structures.
library;

import 'package:flutter/material.dart';

enum ImdSeverity { green, yellow, orange, red, unknown }

extension ImdSeverityX on ImdSeverity {
  String get label => switch (this) {
    ImdSeverity.green   => 'Green',
    ImdSeverity.yellow  => 'Yellow',
    ImdSeverity.orange  => 'Orange',
    ImdSeverity.red     => 'Red',
    ImdSeverity.unknown => 'Advisory',
  };

  Color get color => switch (this) {
    ImdSeverity.green   => const Color(0xFF34C759),
    ImdSeverity.yellow  => const Color(0xFFEAB308),
    ImdSeverity.orange  => const Color(0xFFF97316),
    ImdSeverity.red     => const Color(0xFFF44336),
    ImdSeverity.unknown => const Color(0xFF6B7280),
  };

  IconData get icon => switch (this) {
    ImdSeverity.green   => Icons.wb_sunny_outlined,
    ImdSeverity.yellow  => Icons.warning_amber_rounded,
    ImdSeverity.orange  => Icons.thunderstorm_outlined,
    ImdSeverity.red     => Icons.crisis_alert,
    ImdSeverity.unknown => Icons.info_outline,
  };

  int get order => switch (this) {
    ImdSeverity.red     => 4,
    ImdSeverity.orange  => 3,
    ImdSeverity.yellow  => 2,
    ImdSeverity.green   => 1,
    ImdSeverity.unknown => 0,
  };
}

class ImdAlert {
  final String      id;
  final String      headline;
  final String      event;
  final String      description;
  final String      area;
  final String      state;
  final ImdSeverity severity;
  final DateTime?   effective;
  final DateTime?   expires;
  final bool        isNew;

  const ImdAlert({
    required this.id,
    required this.headline,
    required this.event,
    required this.description,
    required this.area,
    required this.state,
    required this.severity,
    this.effective,
    this.expires,
    this.isNew = true,
  });

  /// Parse a raw SACHET CAP item (supports flat + nested 'info' structure).
  factory ImdAlert.fromRaw(dynamic raw) {
    if (raw is! Map) {
      return ImdAlert(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        headline: 'IMD Alert', event: '', description: '',
        area: '', state: '', severity: ImdSeverity.unknown,
      );
    }
    // Flatten: try nested 'info' first, then top-level.
    String _s(List<String> keys) {
      dynamic cur = raw;
      for (final k in keys) {
        if (cur is! Map) return '';
        cur = cur[k];
      }
      return cur?.toString().trim() ?? '';
    }
    String _pick(String key) {
      final nested = _s(['info', key]);
      return nested.isNotEmpty ? nested : _s([key]);
    }

    final headline    = _pick('headline');
    final event       = _pick('event');
    final description = _pick('description');
    final severityStr = _pick('severity');
    final areaDesc    = _s(['info', 'area', 'areaDesc']).isNotEmpty
        ? _s(['info', 'area', 'areaDesc'])
        : _pick('areaDesc');
    final stateVal    = _pick('state');
    final effective   = _parseDate(_pick('effective'));
    final expires     = _parseDate(_pick('expires'));
    final id          = _pick('identifier').isNotEmpty
        ? _pick('identifier')
        : '${event}_${effective?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch}';

    return ImdAlert(
      id:          id,
      headline:    headline,
      event:       event,
      description: description,
      area:        areaDesc,
      state:       stateVal,
      severity:    _parseSeverity(severityStr),
      effective:   effective,
      expires:     expires,
    );
  }

  static ImdSeverity _parseSeverity(String s) {
    final u = s.toUpperCase();
    if (u.contains('RED')    || u.contains('EXTREME') || u.contains('SEVERE')) return ImdSeverity.red;
    if (u.contains('ORANGE') || u.contains('HIGH'))                             return ImdSeverity.orange;
    if (u.contains('YELLOW') || u.contains('MODERATE') || u.contains('MINOR')) return ImdSeverity.yellow;
    if (u.contains('GREEN')  || u.contains('LOW')      || u.contains('MINOR')) return ImdSeverity.green;
    return ImdSeverity.unknown;
  }

  static DateTime? _parseDate(String s) {
    if (s.isEmpty) return null;
    try { return DateTime.parse(s); } catch (_) { return null; }
  }

  ImdAlert copyWith({bool? isNew}) => ImdAlert(
    id: id, headline: headline, event: event,
    description: description, area: area, state: state,
    severity: severity, effective: effective, expires: expires,
    isNew: isNew ?? this.isNew,
  );

  String get displayTitle =>
      headline.isNotEmpty ? headline
      : event.isNotEmpty  ? event
      : 'IMD Weather Alert';
}
