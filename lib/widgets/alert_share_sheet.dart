// lib/widgets/alert_share_sheet.dart
// OpsFlood — Module 4: Notifications & Alerts
//
// AlertShareSheet — modal bottom-sheet for sharing a FloodAlert.
//
// Features:
//   • Bilingual (EN + HI) preview with scrollable card
//   • WhatsApp deep-link button (green, shows lock if WA unavailable)
//   • OS share-sheet button
//   • Copy-to-clipboard button with confirmation snack
//   • Severity colour accent & badge
//   • Uses OpsIcon from Module 2 where available
//
// Usage:
//   showAlertShareSheet(context, alert);

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/alert_engine.dart';
import '../services/alert_share_service.dart';
import '../theme/river_theme.dart';
import 'ops_icon.dart';

// ── Public helper ────────────────────────────────────────────────────

void showAlertShareSheet(BuildContext context, FloodAlert alert) {
  HapticFeedback.mediumImpact();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AlertShareSheet(alert: alert),
  );
}

// ── Widget ─────────────────────────────────────────────────────────────

class AlertShareSheet extends StatefulWidget {
  final FloodAlert alert;
  const AlertShareSheet({super.key, required this.alert});

  @override
  State<AlertShareSheet> createState() => _AlertShareSheetState();
}

class _AlertShareSheetState extends State<AlertShareSheet> {
  bool _copying     = false;
  bool _waSharing   = false;
  bool _sysSharing  = false;

  AlertMessage? _msg;

  @override
  void initState() {
    super.initState();
    _msg = AlertShareService.instance.buildMessage(widget.alert);
  }

  Color _sevColor(RiverColors t) {
    switch (widget.alert.severity) {
      case AlertSeverity.emergency: return AppPalette.critical;
      case AlertSeverity.critical:  return AppPalette.danger;
      case AlertSeverity.warning:   return AppPalette.warning;
      case AlertSeverity.info:      return AppPalette.safe;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t      = RiverColors.of(context);
    final msg    = _msg!;
    final accent = _sevColor(t);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.40)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 0),
            child: Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: t.stroke,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          // ─ Header ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                OpsIcon(OpsIcons.alert, size: 22, color: accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Share Alert',
                    style: TextStyle(
                      color: t.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                ),
                _SevBadge(alert: widget.alert, color: accent, t: t),
              ],
            ),
          ),

          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              msg.shortLine,
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),

          // ─ Preview card ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                color: t.cardBgElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: t.stroke),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // English block
                    _LangLabel(label: 'English', color: accent, t: t),
                    const SizedBox(height: 6),
                    Text(
                      msg.english,
                      style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 11,
                        height: 1.55,
                        fontFamily: 'JetBrainsMono',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Divider(height: 1, color: t.stroke),
                    const SizedBox(height: 14),
                    // Hindi block
                    _LangLabel(
                        label: 'हिन्दी',
                        color: accent.withValues(alpha: 0.8),
                        t: t),
                    const SizedBox(height: 6),
                    Text(
                      msg.hindi,
                      style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 11,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─ Action buttons ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Row(
              children: [

                // WhatsApp button
                Expanded(
                  flex: 3,
                  child: _ActionButton(
                    icon: const _WhatsAppIcon(),
                    label: 'WhatsApp',
                    color: const Color(0xFF25D366),
                    loading: _waSharing,
                    t: t,
                    onTap: () async {
                      setState(() => _waSharing = true);
                      final ok = await AlertShareService.instance
                          .shareViaWhatsApp(widget.alert);
                      if (mounted) setState(() => _waSharing = false);
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                                'WhatsApp not found — copied to clipboard instead'),
                            backgroundColor: t.cardBg,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        await AlertShareService.instance
                            .copyToClipboard(widget.alert);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),

                // Share button
                Expanded(
                  flex: 3,
                  child: _ActionButton(
                    icon: Icon(Icons.share_rounded,
                        color: accent, size: 18),
                    label: 'Share',
                    color: accent,
                    loading: _sysSharing,
                    t: t,
                    onTap: () async {
                      setState(() => _sysSharing = true);
                      await AlertShareService.instance
                          .shareViaSheet(widget.alert);
                      if (mounted) setState(() => _sysSharing = false);
                    },
                  ),
                ),
                const SizedBox(width: 8),

                // Copy button
                Expanded(
                  flex: 2,
                  child: _ActionButton(
                    icon: _copying
                        ? Icon(Icons.check_rounded,
                            color: AppPalette.safe, size: 18)
                        : Icon(Icons.copy_rounded,
                            color: t.textSecondary, size: 18),
                    label: _copying ? 'Copied!' : 'Copy',
                    color: _copying
                        ? AppPalette.safe
                        : t.textSecondary,
                    loading: false,
                    t: t,
                    onTap: () async {
                      await AlertShareService.instance
                          .copyToClipboard(widget.alert);
                      if (!mounted) return;
                      setState(() => _copying = true);
                      await Future.delayed(
                          const Duration(seconds: 2));
                      if (mounted) setState(() => _copying = false);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                const Text('Alert copied to clipboard'),
                            backgroundColor: t.cardBg,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ─────────────────────────────────────────────────────

class _LangLabel extends StatelessWidget {
  final String      label;
  final Color       color;
  final RiverColors t;
  const _LangLabel(
      {required this.label, required this.color, required this.t});
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(width: 3, height: 12,
              decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2)),
        ],
      );
}

class _SevBadge extends StatelessWidget {
  final FloodAlert  alert;
  final Color       color;
  final RiverColors t;
  const _SevBadge(
      {required this.alert, required this.color, required this.t});
  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: color.withValues(alpha: 0.50)),
        ),
        child: Text(
          alert.severity.label.toUpperCase(),
          style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 9),
        ),
      );
}

class _ActionButton extends StatelessWidget {
  final Widget       icon;
  final String       label;
  final Color        color;
  final bool         loading;
  final RiverColors  t;
  final VoidCallback onTap;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.loading,
    required this.t,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: loading ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: loading
              ? Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    icon,
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
      );
}

/// WhatsApp brand icon drawn with Canvas (no asset needed).
class _WhatsAppIcon extends StatelessWidget {
  const _WhatsAppIcon();
  @override
  Widget build(BuildContext context) => const Icon(
        Icons.chat_rounded,
        color: Color(0xFF25D366),
        size: 18,
      );
}
