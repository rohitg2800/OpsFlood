// lib/services/export_service.dart
// OpsFlood — Module 6: Media, Image Attachments & Export
//
// ExportService
// ─────────────────────────────────────────────────────────────────────────
// Two export formats:
//   1. CSV  — RFC-4180 with UTF-8 BOM; sharable via share_plus
//   2. PDF  — multi-page via 'pdf' package; OpsFlood header,
//             per-station tables, severity-colour row coding
//
// Both formats write to the app's temp directory, then offer
// the file via share_plus share-sheet or save to Downloads.

import 'dart:io';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/river_station.dart';   // RiverStation
import 'alert_engine.dart';              // AlertSeverity

// ── ExportRow ────────────────────────────────────────────────────────────────
// Flat data bag for one station reading at one point in time.
// Populated by the caller (ExportScreen, AlertsScreen) from
// whatever live/cached data is available.

class ExportRow {
  final String       stationName;
  final String       river;
  final String       district;
  final double?      currentLevel;   // m
  final double?      dangerLevel;    // m
  final double?      warningLevel;   // m
  final double?      hfl;            // m
  final double?      rateOfRise;     // m/h
  final double?      rainfall24h;    // mm
  final AlertSeverity? severity;
  final DateTime     observedAt;

  const ExportRow({
    required this.stationName,
    required this.river,
    required this.district,
    required this.observedAt,
    this.currentLevel,
    this.dangerLevel,
    this.warningLevel,
    this.hfl,
    this.rateOfRise,
    this.rainfall24h,
    this.severity,
  });
}

// ── ExportService ────────────────────────────────────────────────────────────

class ExportService {
  ExportService._();
  static final ExportService instance = ExportService._();

  // ── CSV export ───────────────────────────────────────────────────────

  /// Build and share a CSV file for [rows].
  /// Returns the saved file path.
  Future<String> exportAndShareCsv(
    List<ExportRow> rows, {
    String? fileName,
  }) async {
    final csvString = _buildCsvString(rows);
    final path = await _writeTempFile(
      fileName ?? _defaultFileName('csv'),
      // UTF-8 BOM so Excel opens correctly
      Uint8List.fromList([0xEF, 0xBB, 0xBF, ...csvString.codeUnits]),
    );
    await _share(path, 'text/csv',
        subject: 'OpsFlood Station Data Export');
    return path;
  }

  String _buildCsvString(List<ExportRow> rows) {
    final header = [
      'Station', 'River', 'District',
      'Current Level (m)', 'Danger Level (m)', 'Warning Level (m)',
      'HFL (m)', 'Rate of Rise (m/h)', '24h Rainfall (mm)',
      'Severity', 'Observed At (IST)',
    ];
    final data = <List<dynamic>>[header];
    for (final r in rows) {
      data.add([
        r.stationName,
        r.river,
        r.district,
        r.currentLevel  ?? '',
        r.dangerLevel   ?? '',
        r.warningLevel  ?? '',
        r.hfl           ?? '',
        r.rateOfRise    ?? '',
        r.rainfall24h   ?? '',
        r.severity?.name ?? 'normal',
        _fmtDt(r.observedAt),
      ]);
    }
    return const ListToCsvConverter().convert(data);
  }

  // ── PDF export ───────────────────────────────────────────────────────

  /// Build and share a PDF report for [rows].
  /// Returns the saved file path.
  Future<String> exportAndSharePdf(
    List<ExportRow> rows, {
    String? reportTitle,
    String? fileName,
  }) async {
    final pdfBytes = await _buildPdf(rows, reportTitle: reportTitle);
    final path = await _writeTempFile(
      fileName ?? _defaultFileName('pdf'),
      pdfBytes,
    );
    await _share(path, 'application/pdf',
        subject: reportTitle ?? 'OpsFlood Station Report');
    return path;
  }

  Future<Uint8List> _buildPdf(
    List<ExportRow> rows, {
    String? reportTitle,
  }) async {
    final doc   = pw.Document();
    final title = reportTitle ?? 'OpsFlood Bihar Flood Station Report';
    final now   = _fmtDt(DateTime.now());

    // Colour palette
    const headerBg   = PdfColor.fromInt(0xFF0D1B2A);
    const accentBlue = PdfColor.fromInt(0xFF00B4D8);
    const sevEmergency = PdfColor.fromInt(0xFFFF1744);
    const sevCritical  = PdfColor.fromInt(0xFFFF6D00);
    const sevWarning   = PdfColor.fromInt(0xFFFFD600);
    const sevInfo      = PdfColor.fromInt(0xFF00E5FF);
    const sevNormal    = PdfColor.fromInt(0xFFE0E0E0);

    PdfColor _rowColor(AlertSeverity? sev) {
      switch (sev) {
        case AlertSeverity.emergency: return sevEmergency.shade(0.15);
        case AlertSeverity.critical:  return sevCritical.shade(0.15);
        case AlertSeverity.warning:   return sevWarning.shade(0.15);
        case AlertSeverity.info:      return sevInfo.shade(0.15);
        default:                      return PdfColors.white;
      }
    }

    // Column definitions
    final columns = [
      'Station', 'River', 'District',
      'Level\n(m)', 'Danger\n(m)', 'Warn\n(m)',
      'RoR\n(m/h)', 'Rain\n(mm)', 'Severity',
    ];
    final colWidths = [
      90.0, 60.0, 70.0, 44.0, 44.0, 44.0, 40.0, 40.0, 52.0,
    ];

    // Split into pages of 30 rows
    const rowsPerPage = 30;
    final pages = <List<ExportRow>>[];
    for (var i = 0; i < rows.length; i += rowsPerPage) {
      pages.add(rows.sublist(
          i, (i + rowsPerPage).clamp(0, rows.length)));
    }
    if (pages.isEmpty) pages.add([]);

    for (var p = 0; p < pages.length; p++) {
      final pageRows = pages[p];
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ─ Header band
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                color: headerBg,
                child: pw.Row(
                  mainAxisAlignment:
                      pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      title,
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    pw.Text(
                      'Generated: $now  •  Page ${p + 1}/${pages.length}',
                      style: const pw.TextStyle(
                          color: PdfColors.white70,
                          fontSize: 8),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              // ─ Table
              pw.Table(
                columnWidths: {
                  for (var i = 0; i < colWidths.length; i++)
                    i: pw.FixedColumnWidth(colWidths[i]),
                },
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                children: [
                  // Header row
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: accentBlue),
                    children: columns
                        .map((c) => pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text(
                                c,
                                style: pw.TextStyle(
                                  color: PdfColors.white,
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 7,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  // Data rows
                  ...pageRows.map((r) {
                    final cells = [
                      r.stationName,
                      r.river,
                      r.district,
                      r.currentLevel?.toStringAsFixed(2) ?? '—',
                      r.dangerLevel?.toStringAsFixed(2)  ?? '—',
                      r.warningLevel?.toStringAsFixed(2) ?? '—',
                      r.rateOfRise?.toStringAsFixed(2)   ?? '—',
                      r.rainfall24h?.toStringAsFixed(1)  ?? '—',
                      r.severity?.name ?? 'normal',
                    ];
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                          color: _rowColor(r.severity)),
                      children: cells
                          .map((c) => pw.Padding(
                                padding:
                                    const pw.EdgeInsets.all(3),
                                child: pw.Text(c,
                                    style: const pw.TextStyle(
                                        fontSize: 7)),
                              ))
                          .toList(),
                    );
                  }),
                ],
              ),
              pw.Spacer(),
              // ─ Footer
              pw.Divider(color: PdfColors.grey300),
              pw.Text(
                'OpsFlood Bihar Flood Intelligence  •  opsflood.app  •  Data source: CWC / Bihar WRD',
                style: const pw.TextStyle(
                    color: PdfColors.grey500, fontSize: 6),
              ),
            ],
          ),
        ),
      );
    }
    return doc.save();
  }

  // ── File I/O ────────────────────────────────────────────────────────────

  Future<String> _writeTempFile(
      String fileName, Uint8List bytes) async {
    final dir  = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<void> _share(
    String filePath,
    String mimeType, {
    String? subject,
  }) async {
    await Share.shareXFiles(
      [XFile(filePath, mimeType: mimeType)],
      subject: subject,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  String _defaultFileName(String ext) {
    final now = DateTime.now();
    return 'opsflood_export_'
        '${now.year}${_p(now.month)}${_p(now.day)}_'
        '${_p(now.hour)}${_p(now.minute)}.$ext';
  }

  static String _fmtDt(DateTime dt) =>
      '${_p(dt.day)}-${_p(dt.month)}-${dt.year} '
      '${_p(dt.hour)}:${_p(dt.minute)} IST';

  static String _p(int n) => n.toString().padLeft(2, '0');
}
