// lib/services/alert_share_service.dart
// OpsFlood — Alert Share Service (Phase 4)
//
// Generates bilingual (EN/HI) flood alert messages and
// shares them via WhatsApp deep-link or system share sheet.
//
// Dependencies: share_plus: ^9.0.0, url_launcher: ^6.3.0
library;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/locale_provider.dart';

// ── Message builders ─────────────────────────────────────────────────────────

String _buildEnMessage({
  required String district, required String river, required String station,
  required double currentLevel, required double dangerLevel,
  required String severity, required DateTime timestamp,
}) {
  final diff = currentLevel - dangerLevel;
  final diffStr = diff >= 0
      ? '+${diff.toStringAsFixed(2)} m above DL'
      : '${diff.abs().toStringAsFixed(2)} m below DL';
  return '${_severityIcon(severity)} FLOOD ALERT | $district, Bihar\n'
      'River: $river at $station\n'
      'Level: ${currentLevel.toStringAsFixed(2)} m | DL: ${dangerLevel.toStringAsFixed(2)} m ($diffStr)\n'
      'Status: $severity\n'
      'Time: ${DateFormat("dd MMM yyyy, HH:mm").format(timestamp)}\n'
      'Track live → https://opsflood.page.link/app\n'
      '— OpsFlood Flood Intelligence';
}

String _buildHiMessage({
  required String district, required String river, required String station,
  required double currentLevel, required double dangerLevel,
  required String severity, required DateTime timestamp,
}) {
  final diff = currentLevel - dangerLevel;
  final diffStr = diff >= 0
      ? '+${diff.toStringAsFixed(2)} मी (खतरे के स्तर से ऊपर)'
      : '${diff.abs().toStringAsFixed(2)} मी (खतरे के स्तर से नीचे)';
  return '${_severityIcon(severity)} बाढ़ चेतावनी | $district, बिहार\n'
      'नदी: $river ($station)\n'
      'वर्तमान: ${currentLevel.toStringAsFixed(2)} मी | खतरा: ${dangerLevel.toStringAsFixed(2)} मी ($diffStr)\n'
      'स्थिति: ${_severityHindi(severity)}\n'
      'समय: ${DateFormat("dd MMM yyyy, HH:mm").format(timestamp)}\n'
      'लाइव देखें → https://opsflood.page.link/app\n'
      '— OpsFlood बाढ़ सूचना प्रणाली';
}

String _severityIcon(String s) {
  switch (s.toUpperCase()) {
    case 'EMERGENCY': return '🚨';
    case 'CRITICAL':  return '🔴';
    case 'SEVERE':    return '⚠️';
    case 'MODERATE':  return '🟡';
    default:          return '✅';
  }
}

String _severityHindi(String s) {
  switch (s.toUpperCase()) {
    case 'EMERGENCY': return 'आपातकाल';
    case 'CRITICAL':  return 'खतरा';
    case 'SEVERE':    return 'चेतावनी';
    case 'MODERATE':  return 'सतर्क';
    default:          return 'सामान्य';
  }
}

// ── Service ───────────────────────────────────────────────────────────────────

class AlertShareService {
  final Ref _ref;
  AlertShareService(this._ref);

  String buildMessage({
    required String district, required String river, required String station,
    required double currentLevel, required double dangerLevel,
    required String severity, DateTime? timestamp,
  }) {
    final ts = timestamp ?? DateTime.now();
    final locale = _ref.read(localeProvider);
    if (locale.languageCode == 'hi') {
      return _buildHiMessage(district: district, river: river, station: station,
          currentLevel: currentLevel, dangerLevel: dangerLevel, severity: severity, timestamp: ts);
    }
    return _buildEnMessage(district: district, river: river, station: station,
        currentLevel: currentLevel, dangerLevel: dangerLevel, severity: severity, timestamp: ts);
  }

  Future<void> shareViaWhatsApp(String message) async {
    final encoded = Uri.encodeComponent(message);
    final waUri = Uri.parse('whatsapp://send?text=$encoded');
    if (await canLaunchUrl(waUri)) {
      await launchUrl(waUri);
    } else {
      await Share.share(message, subject: '🚨 Flood Alert — OpsFlood');
    }
  }

  Future<void> shareGeneric(String message) async {
    await Share.share(message, subject: '🚨 Flood Alert — OpsFlood');
  }
}

final alertShareServiceProvider =
    Provider<AlertShareService>((ref) => AlertShareService(ref));

// ── Drop-in Share Button widget ───────────────────────────────────────────────

class AlertShareButton extends ConsumerWidget {
  final String district, river, station, severity;
  final double currentLevel, dangerLevel;
  final DateTime? timestamp;
  final bool compact;

  const AlertShareButton({
    super.key,
    required this.district, required this.river, required this.station,
    required this.currentLevel, required this.dangerLevel, required this.severity,
    this.timestamp, this.compact = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc = ref.read(alertShareServiceProvider);

    void onShare() {
      final msg = svc.buildMessage(
        district: district, river: river, station: station,
        currentLevel: currentLevel, dangerLevel: dangerLevel,
        severity: severity, timestamp: timestamp,
      );
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => _ShareSheet(message: msg, svc: svc),
      );
    }

    if (compact) {
      return Tooltip(
        message: 'Share alert',
        child: InkWell(
          onTap: onShare,
          borderRadius: BorderRadius.circular(10),
          child: const SizedBox(width: 44, height: 44,
              child: Center(child: Icon(Icons.share_rounded, size: 20))),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onShare,
      icon: const Icon(Icons.share_rounded, size: 16),
      label: const Text('Share Alert'),
    );
  }
}

class _ShareSheet extends StatelessWidget {
  final String message;
  final AlertShareService svc;
  const _ShareSheet({required this.message, required this.svc});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Share Alert', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Text(message, style: const TextStyle(fontSize: 12, height: 1.5)),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _ShareOption(
              icon: Icons.chat_rounded, label: 'WhatsApp',
              color: const Color(0xFF25D366),
              onTap: () { Navigator.pop(context); svc.shareViaWhatsApp(message); },
            )),
            const SizedBox(width: 10),
            Expanded(child: _ShareOption(
              icon: Icons.more_horiz_rounded, label: 'More Apps',
              color: Colors.blueAccent,
              onTap: () { Navigator.pop(context); svc.shareGeneric(message); },
            )),
          ]),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ShareOption({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}
