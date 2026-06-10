// lib/services/alert_share_service.dart
// Phase 4 — WhatsApp & share-sheet alert sharing
// Closes issue #24

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AlertShareService {
  /// Generates the English flood alert message
  static String buildEnglishMessage({
    required String district,
    required String riverName,
    required String stationName,
    required double currentLevel,
    required double dangerLevel,
    required String severity,
  }) {
    final now = DateTime.now();
    final timeStr =
        '${now.day.toString().padLeft(2, '0')} '
        '${_monthName(now.month)} ${now.year}, '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final emoji = _severityEmoji(severity);
    final diff = (currentLevel - dangerLevel).toStringAsFixed(2);
    final aboveBelow = currentLevel >= dangerLevel
        ? '🔺 ${diff}m ABOVE Danger Level'
        : '🔻 ${diff.replaceAll('-', '')}m below Danger Level';

    return '''
$emoji FLOOD ALERT | $district, Bihar
River: $riverName at $stationName
Current Level: ${currentLevel.toStringAsFixed(2)}m | Danger Level: ${dangerLevel.toStringAsFixed(2)}m
Status: $emoji $severity
$aboveBelow
Time: $timeStr
Monitor live: https://opsflood.onrender.com
— OpsFlood App''';
  }

  /// Generates the Hindi flood alert message
  static String buildHindiMessage({
    required String district,
    required String riverName,
    required String stationName,
    required double currentLevel,
    required double dangerLevel,
    required String severity,
  }) {
    final now = DateTime.now();
    final timeStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final emoji = _severityEmoji(severity);
    final severityHindi = _severityHindi(severity);

    return '''
$emoji बाढ़ चेतावनी | $district, बिहार
नदी: $riverName — $stationName
वर्तमान जल स्तर: ${currentLevel.toStringAsFixed(2)} मीटर
खतरे का स्तर: ${dangerLevel.toStringAsFixed(2)} मीटर
स्थिति: $emoji $severityHindi
समय: $timeStr
लाइव देखें: https://opsflood.onrender.com
— OpsFlood ऐप''';
  }

  /// Share via WhatsApp directly (deep link)
  static Future<void> shareViaWhatsApp({
    required BuildContext context,
    required String message,
  }) async {
    final encoded = Uri.encodeComponent(message);
    final whatsappUri = Uri.parse('whatsapp://send?text=$encoded');

    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri);
    } else {
      // WhatsApp not installed — fall back to generic share sheet
      await shareGeneric(message: message);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WhatsApp not found. Opened share sheet instead.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Generic system share sheet (WhatsApp + SMS + Gmail + etc.)
  static Future<void> shareGeneric({required String message}) async {
    await Share.share(message, subject: '🚨 OpsFlood Alert');
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _severityEmoji(String severity) {
    switch (severity.toUpperCase()) {
      case 'EMERGENCY':
        return '🆘';
      case 'CRITICAL':
      case 'DANGER':
        return '🚨';
      case 'WARNING':
        return '⚠️';
      default:
        return 'ℹ️';
    }
  }

  static String _severityHindi(String severity) {
    switch (severity.toUpperCase()) {
      case 'EMERGENCY':
        return 'अत्यंत खतरनाक';
      case 'CRITICAL':
      case 'DANGER':
        return 'खतरा';
      case 'WARNING':
        return 'चेतावनी';
      default:
        return 'सामान्य';
    }
  }

  static String _monthName(int month) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month];
  }
}
