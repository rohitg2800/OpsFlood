// lib/widgets/alert_share_button.dart
// Phase 4 — Reusable share button for Station Detail, Dashboard, Bihar Map
// Closes issue #24

import 'package:flutter/material.dart';
import '../services/alert_share_service.dart';

class AlertShareButton extends StatelessWidget {
  final String district;
  final String riverName;
  final String stationName;
  final double currentLevel;
  final double dangerLevel;
  final String severity;

  /// If [iconOnly] is true, renders just an icon button (for AppBar/cards).
  /// If false, renders a full outlined button (for bottom sheets/detail screens).
  final bool iconOnly;

  const AlertShareButton({
    super.key,
    required this.district,
    required this.riverName,
    required this.stationName,
    required this.currentLevel,
    required this.dangerLevel,
    required this.severity,
    this.iconOnly = false,
  });

  void _showShareOptions(BuildContext context) {
    final englishMsg = AlertShareService.buildEnglishMessage(
      district: district,
      riverName: riverName,
      stationName: stationName,
      currentLevel: currentLevel,
      dangerLevel: dangerLevel,
      severity: severity,
    );
    final hindiMsg = AlertShareService.buildHindiMessage(
      district: district,
      riverName: riverName,
      stationName: stationName,
      currentLevel: currentLevel,
      dangerLevel: dangerLevel,
      severity: severity,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0d1b2a),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📤 Share Alert',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _ShareTile(
              icon: '💬',
              label: 'WhatsApp (English)',
              onTap: () {
                Navigator.pop(context);
                AlertShareService.shareViaWhatsApp(
                  context: context,
                  message: englishMsg,
                );
              },
            ),
            _ShareTile(
              icon: '🇮🇳',
              label: 'WhatsApp (हिन्दी)',
              onTap: () {
                Navigator.pop(context);
                AlertShareService.shareViaWhatsApp(
                  context: context,
                  message: hindiMsg,
                );
              },
            ),
            _ShareTile(
              icon: '📲',
              label: 'Share via other apps (English)',
              onTap: () {
                Navigator.pop(context);
                AlertShareService.shareGeneric(message: englishMsg);
              },
            ),
            _ShareTile(
              icon: '📲',
              label: 'Share via other apps (हिन्दी)',
              onTap: () {
                Navigator.pop(context);
                AlertShareService.shareGeneric(message: hindiMsg);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (iconOnly) {
      return IconButton(
        tooltip: 'Share Alert',
        icon: const Icon(Icons.share_rounded, color: Colors.white70),
        onPressed: () => _showShareOptions(context),
      );
    }

    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white30),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      icon: const Icon(Icons.share_rounded, size: 18),
      label: const Text('Share Alert'),
      onPressed: () => _showShareOptions(context),
    );
  }
}

class _ShareTile extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;

  const _ShareTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Text(icon, style: const TextStyle(fontSize: 22)),
      title: Text(label, style: const TextStyle(color: Colors.white70)),
      onTap: onTap,
    );
  }
}
