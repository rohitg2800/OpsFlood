// lib/services/fcm_templates.dart
// OpsFlood — Module 4: Notifications & Alerts
//
// FcmTemplates — typed bilingual FCM notification payload builder.
//
// Produces Map<String, dynamic> payloads consumed by fcm_broadcast_service.dart
// for topic-based push delivery.
//
// Payload structure follows FCM HTTP v1 API:
//   https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages
//
// Usage:
//   final payload = FcmTemplates.forAlert(alert);
//   await FcmBroadcastService.instance.broadcast(
//     topic: FcmTopics.forSeverity(alert.severity),
//     payload: payload,
//   );

import 'alert_engine.dart'; // AlertSeverity, AlertType, FloodAlert
import 'alert_share_service.dart'; // AlertShareService (shortLine)

// ── FCM topic constants ────────────────────────────────────────────────

abstract class FcmTopics {
  // Bihar-scoped topics
  static const biharAll       = 'bihar_all';        // all Bihar subscribers
  static const biharEmergency = 'bihar_emergency';  // critical/emergency only
  static const biharWarning   = 'bihar_warning';    // warning+

  // Per-river topics (generated at runtime)
  static String river(String riverName) =>
      'river_${riverName.toLowerCase().replaceAll(' ', '_')}';

  // Per-district topics
  static String district(String districtName) =>
      'district_${districtName.toLowerCase().replaceAll(' ', '_')}';

  /// Returns the most appropriate topic for a given severity.
  static String forSeverity(AlertSeverity sev) {
    switch (sev) {
      case AlertSeverity.emergency:
      case AlertSeverity.critical:
        return biharEmergency;
      case AlertSeverity.warning:
        return biharWarning;
      case AlertSeverity.info:
        return biharAll;
    }
  }
}

// ── Android notification channels ──────────────────────────────────────

abstract class FcmChannels {
  static const emergency = 'opsflood_emergency'; // heads-up, max priority
  static const critical  = 'opsflood_critical';  // heads-up, high priority
  static const warning   = 'opsflood_warning';   // default priority
  static const info      = 'opsflood_info';       // low priority

  static String forSeverity(AlertSeverity sev) {
    switch (sev) {
      case AlertSeverity.emergency: return emergency;
      case AlertSeverity.critical:  return critical;
      case AlertSeverity.warning:   return warning;
      case AlertSeverity.info:      return info;
    }
  }
}

// ── FcmTemplates ────────────────────────────────────────────────────

abstract class FcmTemplates {
  /// Build a complete FCM message payload for the given alert.
  ///
  /// Returns a Map ready to be passed to the FCM HTTP v1
  /// `projects.messages.send` endpoint body as `message`.
  static Map<String, dynamic> forAlert(FloodAlert alert) {
    final sev    = alert.severity;
    final msg    = AlertShareService.instance.buildMessage(alert);
    final titles = _titles(alert);
    final bodies = _bodies(alert);
    final chan   = FcmChannels.forSeverity(sev);

    return {
      'topic': FcmTopics.forSeverity(sev),
      'notification': {
        'title': titles['en'],
        'body':  bodies['en'],
      },
      'android': {
        'priority': sev == AlertSeverity.emergency ||
                sev == AlertSeverity.critical
            ? 'high'
            : 'normal',
        'notification': {
          'channel_id':  chan,
          'title':       titles['en'],
          'body':        bodies['en'],
          'title_loc_key': 'fcm_title_${sev.name}',
          'body_loc_key':  'fcm_body_${alert.type.name}',
          'color':       _hexColor(sev),
          'icon':        'ic_opsflood_notification',
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
      },
      'apns': {
        'payload': {
          'aps': {
            'alert': {
              'title': titles['en'],
              'body':  bodies['en'],
              'subtitle': '${alert.river} — ${alert.district}',
            },
            'sound':             'default',
            'badge':             1,
            'interruption-level': sev == AlertSeverity.emergency
                ? 'critical'
                : 'active',
          },
        },
      },
      'data': {
        // Data payload for Flutter handler (background + foreground)
        'alert_id':     alert.id,
        'alert_type':   alert.type.name,
        'severity':     sev.name,
        'station':      alert.station,
        'river':        alert.river,
        'district':     alert.district,
        'current_level': alert.currentLevel?.toString() ?? '',
        'threshold':     alert.thresholdLevel?.toString() ?? '',
        'short_line_en': msg.shortLine,
        'body_en':       bodies['en'] ?? '',
        'body_hi':       bodies['hi'] ?? '',
        'ts':            DateTime.now().toIso8601String(),
        'screen':        '/bihar_river_map',  // deep-link target
      },
    };
  }

  // ─ Bilingual title map ─────────────────────────────────────────
  static Map<String, String> _titles(FloodAlert alert) {
    final sta = alert.station;
    final sev = alert.severity;
    final String en;
    final String hi;
    switch (sev) {
      case AlertSeverity.emergency:
        en = '🚨 Emergency: $sta';
        hi = '🚨 आपातकाल: $sta';
        break;
      case AlertSeverity.critical:
        en = '🔴 Critical Flood Alert: $sta';
        hi = '🔴 गंभीर बाढ़ अलर्ट: $sta';
        break;
      case AlertSeverity.warning:
        en = '⚠️ Flood Warning: $sta';
        hi = '⚠️ बाढ़ चेतावनी: $sta';
        break;
      case AlertSeverity.info:
        en = 'ℹ️ Flood Advisory: $sta';
        hi = 'ℹ️ बाढ़ सूचना: $sta';
        break;
    }
    return {'en': en, 'hi': hi};
  }

  // ─ Bilingual body map ──────────────────────────────────────────
  static Map<String, String> _bodies(FloodAlert alert) {
    final sta  = alert.station;
    final riv  = alert.river;
    final cur  = alert.currentLevel?.toStringAsFixed(2) ?? '—';
    final thr  = alert.thresholdLevel?.toStringAsFixed(2) ?? '—';
    final String en;
    final String hi;
    switch (alert.type) {
      case AlertType.levelAboveHfl:
        en = '$sta ($riv): $cur m — HFL exceeded ($thr m). Evacuate now.';
        hi = '$sta ($riv): $cur मी. — HFL पार ($thr मी.). तत्काल निकासी करें।';
        break;
      case AlertType.levelAboveDanger:
        en = '$sta ($riv): $cur m — above danger ($thr m). Emergency response needed.';
        hi = '$sta ($riv): $cur मी. — खतरे की सीमा से ऊपर ($thr मी.)।';
        break;
      case AlertType.levelAboveWarning:
        en = '$sta ($riv): $cur m crossed warning ($thr m). Monitor closely.';
        hi = '$sta ($riv): $cur मी. चेतावनी स्तर पार ($thr मी.)।';
        break;
      case AlertType.rapidRise:
        final ror = alert.rateOfRise != null
            ? '+${alert.rateOfRise!.toStringAsFixed(2)} m/h'
            : 'rapid';
        en = '$sta ($riv): rapid rise $ror — flash flood risk. Move to safety.';
        hi = '$sta ($riv): तेज़ वृद्धि $ror — अचानक बाढ़ का खतरा।';
        break;
      case AlertType.forecastDanger24h:
        en = '$sta ($riv): forecast $cur m in 24h, danger at $thr m.';
        hi = '$sta ($riv): 24 घंटे में पूर्वानुमान $cur मी., खतरा $thr मी.।';
        break;
      case AlertType.forecastDanger48h:
        en = '$sta ($riv): forecast may reach $cur m in 48h. Prepare.';
        hi = '$sta ($riv): 48 घंटे में $cur मी. तक पहुँच सकता है। तैयार रहें।';
        break;
      case AlertType.rainfallExtreme:
        final r = alert.rainfall24h != null
            ? '${alert.rainfall24h!.toStringAsFixed(0)} mm'
            : '>100 mm';
        en = 'Extreme rainfall near $sta ($riv): $r in 24h. Flash flood risk.';
        hi = '$sta ($riv) के पास अत्यधिक वर्षा: $r। अचानक बाढ़ का खतरा।';
        break;
      case AlertType.rainfallHeavy:
        final r = alert.rainfall24h != null
            ? '${alert.rainfall24h!.toStringAsFixed(0)} mm'
            : '>64 mm';
        en = 'Heavy rainfall near $sta ($riv): $r in 24h.';
        hi = '$sta ($riv) के पास भारी वर्षा: $r।';
        break;
      case AlertType.upstreamCritical:
        en = '$riv: multiple stations above danger. Downstream breach risk.';
        hi = '$riv: कई स्थान खतरे की सीमा से ऊपर। निचले हिस्से में खतरा।';
        break;
      case AlertType.multiRiverAlert:
        en = 'Bihar multi-river flood crisis. State-wide emergency preparedness.';
        hi = 'बिहार में अनेक नदियां खतरे की सीमा से ऊपर। राज्यव्यापी आपातताल।';
        break;
    }
    return {'en': en, 'hi': hi};
  }

  static String _hexColor(AlertSeverity sev) {
    switch (sev) {
      case AlertSeverity.emergency: return '#FF1744';
      case AlertSeverity.critical:  return '#FF6D00';
      case AlertSeverity.warning:   return '#FFD600';
      case AlertSeverity.info:      return '#00E5FF';
    }
  }
}
