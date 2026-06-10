// lib/services/alert_share_service.dart
// OpsFlood — Module 4: Notifications & Alerts
//
// AlertShareService v2
// ──────────────────────────────────────────────────────────────────────
// Responsibilities:
//   1. Build pre-formatted bilingual (English + Hindi) alert messages for
//      every AlertType, keyed on AlertSeverity for urgency prefix.
//   2. Share via WhatsApp deep-link (wa.me) with URL-encoded message.
//   3. Share via OS share-sheet (share_plus) as fallback.
//   4. Copy to clipboard.
//
// Consumers:
//   • AlertShareSheet widget (lib/widgets/alert_share_sheet.dart)
//   • City detail screen — share FAB
//   • Alert list tile — long-press share action

import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'alert_engine.dart'; // AlertSeverity, AlertType, FloodAlert

// ── Bilingual message data model ──────────────────────────────────────────

class AlertMessage {
  /// Full bilingual message ready to share (EN then HI block).
  final String combined;

  /// English-only block.
  final String english;

  /// Hindi-only block.
  final String hindi;

  /// Short one-liner for notification body.
  final String shortLine;

  const AlertMessage({
    required this.combined,
    required this.english,
    required this.hindi,
    required this.shortLine,
  });
}

// ── AlertShareService ────────────────────────────────────────────────────

class AlertShareService {
  AlertShareService._();
  static final AlertShareService instance = AlertShareService._();

  // ── Message builder ────────────────────────────────────────────────

  AlertMessage buildMessage(FloodAlert alert) {
    final sev   = alert.severity;
    final type  = alert.type;
    final sta   = alert.station;
    final river = alert.river;
    final dist  = alert.district;
    final cur   = alert.currentLevel?.toStringAsFixed(2) ?? '—';
    final thr   = alert.thresholdLevel?.toStringAsFixed(2) ?? '—';
    final ror   = alert.rateOfRise != null
        ? '+${alert.rateOfRise!.toStringAsFixed(2)} m/h'
        : null;
    final rain  = alert.rainfall24h != null
        ? '${alert.rainfall24h!.toStringAsFixed(1)} mm'
        : null;
    final ts    = _timestamp();
    final src   = '🔗 OpsFlood Bihar Flood Intelligence';
    final app   = 'https://opsflood.app'; // deep-link placeholder

    // — Severity prefix (EN)
    final String sevPrefixEn;
    final String sevPrefixHi;
    final String emoji;
    switch (sev) {
      case AlertSeverity.emergency:
        sevPrefixEn = '🚨 EMERGENCY FLOOD ALERT';
        sevPrefixHi = '🚨 आपातकालीन बाढ़ अलर्ट';
        emoji = '🚨';
        break;
      case AlertSeverity.critical:
        sevPrefixEn = '🔴 CRITICAL FLOOD ALERT';
        sevPrefixHi = '🔴 गंभीर बाढ़ अलर्ट';
        emoji = '🔴';
        break;
      case AlertSeverity.warning:
        sevPrefixEn = '⚠️ FLOOD WARNING';
        sevPrefixHi = '⚠️ बाढ़ चेतावनी';
        emoji = '⚠️';
        break;
      case AlertSeverity.info:
        sevPrefixEn = 'ℹ️ FLOOD ADVISORY';
        sevPrefixHi = 'ℹ️ बाढ़ सूचना';
        emoji = 'ℹ️';
        break;
    }

    // — Type-specific body (EN + HI)
    final String bodyEn;
    final String bodyHi;
    switch (type) {
      case AlertType.levelAboveHfl:
        bodyEn =
            'Water level at $sta ($river, $dist) has exceeded the HIGHEST FLOOD LEVEL (HFL).\n'
            'Current: $cur m  |  HFL: $thr m\n'
            '🟥 IMMEDIATE EVACUATION required. SDRF deployment advised.';
        bodyHi =
            '$sta ($river, $dist) में जलस्तर सर्वाधिक बाढ़ स्तर (HFL) से उपर जा चुका है।\n'
            'वर्तमान: $cur मी।  |  HFL: $thr मी।\n'
            '🟥 तत्काल तत्काल निकासी आवश्यक। SDRF तैनाती सुझावित।';
        break;

      case AlertType.levelAboveDanger:
        bodyEn =
            'Water level at $sta ($river, $dist) is ABOVE DANGER LEVEL.\n'
            'Current: $cur m  |  Danger Level: $thr m\n'
            '🟠 Activate emergency response. Embankment vigilance required.';
        bodyHi =
            '$sta ($river, $dist) में जलस्तर खतरे की सीमा से ऊपर है।\n'
            'वर्तमान: $cur मी।  |  खतरे की सीमा: $thr मी।\n'
            '🟠 आपातकालीन प्रतिक्रिया सक्रिय करें। तटबंध निगरानी आवश्यक।';
        break;

      case AlertType.levelAboveWarning:
        bodyEn =
            'Water level at $sta ($river, $dist) has crossed WARNING LEVEL.\n'
            'Current: $cur m  |  Warning Level: $thr m\n'
            '🟡 Close monitoring advised. Prepare evacuation routes.';
        bodyHi =
            '$sta ($river, $dist) में जलस्तर चेतावनी स्तर पार कर गया है।\n'
            'वर्तमान: $cur मी।  |  चेतावनी स्तर: $thr मी।\n'
            '🟡 निरंतर निगरानी करें। निकासी मार्ग तैयार रखें।';
        break;

      case AlertType.rapidRise:
        final rorStr = ror ?? 'तीव्र';
        bodyEn =
            'RAPID RISE detected at $sta ($river, $dist).\n'
            'Rate of rise: ${ror ?? "rapid"} — flash flood risk elevated.\n'
            '🌊 Move to higher ground immediately.';
        bodyHi =
            '$sta ($river, $dist) में जलस्तर तेजी से बढ़ रहा है।\n'
            'वृद्धि दर: $rorStr — अचानक बाढ़ का खतरा विद्यमान।\n'
            '🌊 तत्काल उँचे स्थान की ओर जाएँ।';
        break;

      case AlertType.forecastDanger24h:
        bodyEn =
            'FORECAST: $sta ($river, $dist) water level expected to EXCEED DANGER LEVEL within 24 hours.\n'
            'Forecast level: $cur m  |  Danger Level: $thr m\n'
            '⏰ Pre-emptive action required now.';
        bodyHi =
            'पूर्वानुमान: $sta ($river, $dist) का जलस्तर 24 घंटे में खतरे की सीमा पार कर सकता है।\n'
            'पूर्वानुमानित स्तर: $cur मी।  |  खतरे की सीमा: $thr मी।\n'
            '⏰ अभी से ऊर्जावले कदम ज़रूरी।';
        break;

      case AlertType.forecastDanger48h:
        bodyEn =
            'FORECAST: $sta ($river, $dist) water level may exceed Danger Level within 48 hours.\n'
            'Forecast level: $cur m  |  Danger Level: $thr m\n'
            '📅 Monitor closely and keep evacuation plans ready.';
        bodyHi =
            'पूर्वानुमान: $sta ($river, $dist) का जलस्तर 48 घंटे में खतरे की सीमा पार कर सकता है।\n'
            'पूर्वानुमानित स्तर: $cur मी।  |  खतरे की सीमा: $thr मी।\n'
            '📅 निरंतर नज़र रखें और निकासी योजना तैयार रखें।';
        break;

      case AlertType.rainfallExtreme:
        bodyEn =
            'EXTREME RAINFALL recorded near $sta ($river, $dist).\n'
            '24h rainfall: ${rain ?? "Extreme (>100 mm)"}\n'
            '⚡ Flash flooding risk. Avoid low-lying areas.';
        bodyHi =
            '$sta ($river, $dist) के पास अत्यधिक वर्षा दर्ज।\n'
            '24 घंटे में वर्षा: ${rain ?? "अत्यधिक (>100 ममी)"}\n'
            '⚡ अचानक बाढ़ का खतरा। नाले वाले व नीचे वाले इलाकों से दूर रहें।';
        break;

      case AlertType.rainfallHeavy:
        bodyEn =
            'HEAVY RAINFALL recorded near $sta ($river, $dist).\n'
            '24h rainfall: ${rain ?? "Heavy (>64.5 mm)"}\n'
            '🌧️ River levels may rise. Stay alert.';
        bodyHi =
            '$sta ($river, $dist) के पास भारी वर्षा दर्ज।\n'
            '24 घंटे में वर्षा: ${rain ?? "भारी (>64.5 ममी)"}\n'
            '🌧️ नदी का जलस्तर बढ़ सकता है। सतर्क रहें।';
        break;

      case AlertType.upstreamCritical:
        bodyEn =
            'UPSTREAM CRITICAL: Multiple stations on $river are above Danger Level.\n'
            'Downstream breach risk HIGH — $dist and adjoining districts alert.\n'
            '🟥 Immediate preparedness required.';
        bodyHi =
            'अपस्त्रीम आपात: $river नदी पर कई स्थानों में जलस्तर खतरे की सीमा से ऊपर है।\n'
            'निचले हिस्से में तटबंध टूटने का खतरा अधिक — $dist और संलग्न जिले सतर्क।\n'
            '🟥 तत्काल तैयारी आवश्यक।';
        break;

      case AlertType.multiRiverAlert:
        bodyEn =
            'MULTI-RIVER FLOOD CRISIS: 3 or more rivers in Bihar have stations above Warning Level.\n'
            'State-wide emergency preparedness required.\n'
            '🚨 Follow district administration and NDMA advisories.';
        bodyHi =
            'बिहार में तीन या अधिक नदियों में जलस्तर चेतावनी स्तर से ऊपर।\n'
            'राज्यव्यापी आपातकालीन तैयारी ज़रूरी।\n'
            '🚨 जिला प्रशासन और NDMA निर्देशों का पालन करें।';
        break;
    }

    final footer =
        '⏱ $ts\n$src\n$app';
    final footerHi =
        '⏱ $ts\n$src\n$app';

    final english = '$sevPrefixEn\n\n$bodyEn\n\n$footer';
    final hindi   = '$sevPrefixHi\n\n$bodyHi\n\n$footerHi';
    final combined = '$english\n\n────────────────────\n\n$hindi';
    final shortLine =
        '$emoji ${type.label}: $sta ($river) — ${sev.label.toUpperCase()}';

    return AlertMessage(
      combined:  combined,
      english:   english,
      hindi:     hindi,
      shortLine: shortLine,
    );
  }

  // ── Share actions ─────────────────────────────────────────────────

  /// Share via OS share-sheet (title + combined bilingual message).
  Future<ShareResult> shareViaSheet(FloodAlert alert) async {
    final msg = buildMessage(alert);
    return Share.shareWithResult(
      msg.combined,
      subject: msg.shortLine,
    );
  }

  /// Open WhatsApp with a pre-filled message.
  /// Returns true if WhatsApp was launched, false if not installed.
  Future<bool> shareViaWhatsApp(FloodAlert alert) async {
    final msg     = buildMessage(alert);
    final encoded = Uri.encodeComponent(msg.combined);
    final uri     = Uri.parse('whatsapp://send?text=$encoded');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
    // Fallback: wa.me web URL (works on devices without WA installed)
    final webUri = Uri.parse('https://wa.me/?text=$encoded');
    if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }

  /// Copy bilingual message to clipboard.
  Future<void> copyToClipboard(FloodAlert alert) async {
    final msg = buildMessage(alert);
    await Clipboard.setData(ClipboardData(text: msg.combined));
  }

  // ── Helpers ─────────────────────────────────────────────────────

  static String _timestamp() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.year}  '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')} IST';
  }
}
