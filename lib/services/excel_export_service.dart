// lib/services/excel_export_service.dart
// OpsFlood — Module 11: Excel (.xlsx) Export Service
//
// Uses syncfusion_flutter_xlsio (free community licence).
// Add to pubspec.yaml:
//   syncfusion_flutter_xlsio: ^25.1.35
//   path_provider: ^2.1.2
//   share_plus: ^9.0.0
//
// Public API:
//   ExcelExportService.exportStations(stations) → saves + shares .xlsx
//   ExcelExportService.exportAlerts(alerts)     → saves + shares .xlsx

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xl;

// ---------------------------------------------------------------------------
// Stub models (replace with real imports)
// ---------------------------------------------------------------------------

class ExportStation {
  final String id;
  final String name;
  final String river;
  final String district;
  final double currentLevel;
  final double dangerLevel;
  final double warningLevel;
  final String lastUpdated;
  final String severity;
  const ExportStation({
    required this.id,
    required this.name,
    required this.river,
    required this.district,
    required this.currentLevel,
    required this.dangerLevel,
    required this.warningLevel,
    required this.lastUpdated,
    required this.severity,
  });
}

class ExportAlert {
  final String stationId;
  final String stationName;
  final String river;
  final String severity;
  final double level;
  final double threshold;
  final String triggeredAt;
  const ExportAlert({
    required this.stationId,
    required this.stationName,
    required this.river,
    required this.severity,
    required this.level,
    required this.threshold,
    required this.triggeredAt,
  });
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

class ExcelExportService {
  ExcelExportService._();

  // ────────────────────────────────────────────────────────────────────────────
  // Export stations as Excel workbook
  // ────────────────────────────────────────────────────────────────────────────
  static Future<void> exportStations(
    List<ExportStation> stations, {
    String? filename,
  }) async {
    final workbook = xl.Workbook();
    final sheet    = workbook.worksheets[0];
    sheet.name     = 'River Stations';

    // Header row
    final headers = [
      'Station ID', 'Station Name', 'River',
      'District', 'Current Level (m)', 'Warning Level (m)',
      'Danger Level (m)', 'Severity', 'Last Updated',
    ];
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.getRangeByIndex(1, i + 1);
      cell.setText(headers[i]);
      cell.cellStyle.bold = true;
      cell.cellStyle.backColor = '#1565C0';
      cell.cellStyle.fontColor = '#FFFFFF';
      cell.cellStyle.hAlign    = xl.HAlignType.center;
    }

    // Data rows
    for (var r = 0; r < stations.length; r++) {
      final s   = stations[r];
      final row = r + 2;
      sheet.getRangeByIndex(row, 1).setText(s.id);
      sheet.getRangeByIndex(row, 2).setText(s.name);
      sheet.getRangeByIndex(row, 3).setText(s.river);
      sheet.getRangeByIndex(row, 4).setText(s.district);
      sheet.getRangeByIndex(row, 5).setNumber(s.currentLevel);
      sheet.getRangeByIndex(row, 6).setNumber(s.warningLevel);
      sheet.getRangeByIndex(row, 7).setNumber(s.dangerLevel);
      sheet.getRangeByIndex(row, 8).setText(s.severity);
      sheet.getRangeByIndex(row, 9).setText(s.lastUpdated);

      // Colour severity cells
      final severityCell = sheet.getRangeByIndex(row, 8);
      severityCell.cellStyle.backColor = switch (s.severity.toLowerCase()) {
        'emergency' => '#FF1744',
        'danger'    => '#FF6D00',
        'warning'   => '#FFB300',
        _           => '#4CAF50',
      };
      severityCell.cellStyle.fontColor = '#FFFFFF';
    }

    // Auto-fit columns
    for (var i = 1; i <= headers.length; i++) {
      sheet.autoFitColumn(i);
    }

    await _saveAndShare(
      workbook,
      filename ?? 'opsflood_stations_${_ts()}.xlsx',
    );
    workbook.dispose();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Export alerts as Excel workbook
  // ────────────────────────────────────────────────────────────────────────────
  static Future<void> exportAlerts(
    List<ExportAlert> alerts, {
    String? filename,
  }) async {
    final workbook = xl.Workbook();
    final sheet    = workbook.worksheets[0];
    sheet.name     = 'Flood Alerts';

    final headers = [
      'Station ID', 'Station Name', 'River',
      'Severity', 'Level (m)', 'Threshold (m)',
      'Exceeded By (m)', 'Triggered At',
    ];
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.getRangeByIndex(1, i + 1);
      cell.setText(headers[i]);
      cell.cellStyle.bold      = true;
      cell.cellStyle.backColor = '#B71C1C';
      cell.cellStyle.fontColor = '#FFFFFF';
      cell.cellStyle.hAlign    = xl.HAlignType.center;
    }

    for (var r = 0; r < alerts.length; r++) {
      final a     = alerts[r];
      final row   = r + 2;
      final exceeded = (a.level - a.threshold).clamp(0.0, double.infinity);
      sheet.getRangeByIndex(row, 1).setText(a.stationId);
      sheet.getRangeByIndex(row, 2).setText(a.stationName);
      sheet.getRangeByIndex(row, 3).setText(a.river);
      sheet.getRangeByIndex(row, 4).setText(a.severity);
      sheet.getRangeByIndex(row, 5).setNumber(a.level);
      sheet.getRangeByIndex(row, 6).setNumber(a.threshold);
      sheet.getRangeByIndex(row, 7).setNumber(exceeded);
      sheet.getRangeByIndex(row, 8).setText(a.triggeredAt);

      final sevCell = sheet.getRangeByIndex(row, 4);
      sevCell.cellStyle.backColor = switch (a.severity.toLowerCase()) {
        'emergency' => '#FF1744',
        'danger'    => '#FF6D00',
        'warning'   => '#FFB300',
        _           => '#4CAF50',
      };
      sevCell.cellStyle.fontColor = '#FFFFFF';
    }

    for (var i = 1; i <= headers.length; i++) {
      sheet.autoFitColumn(i);
    }

    await _saveAndShare(
      workbook,
      filename ?? 'opsflood_alerts_${_ts()}.xlsx',
    );
    workbook.dispose();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static Future<void> _saveAndShare(
    xl.Workbook workbook,
    String filename,
  ) async {
    final bytes = workbook.saveAsStream();
    final dir   = kIsWeb
        ? Directory.systemTemp
        : await getTemporaryDirectory();
    final file  = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      [XFile(file.path,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
      text: 'OpsFlood data export',
    );
  }

  static String _ts() {
    final now = DateTime.now();
    return '${now.year}${_p(now.month)}${_p(now.day)}_'
        '${_p(now.hour)}${_p(now.minute)}';
  }

  static String _p(int n) => n.toString().padLeft(2, '0');
}
