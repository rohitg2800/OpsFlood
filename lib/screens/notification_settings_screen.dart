// lib/screens/notification_settings_screen.dart
// OpsFlood — Module 7: Push Notifications & FCM Topics
//
// NotificationSettingsScreen
// ─────────────────────────────────────────────────────────────────────────
// Full notification preferences screen:
//   • Per-severity toggle row (Emergency / Critical / Warning / Info)
//   • District multi-select chip grid (38 Bihar districts)
//   • River multi-select chip grid
//   • Quiet hours time picker (start / end)
//   • "Send Test Notification" button for each severity
//   All settings persisted to SharedPreferences.
//   FCM topic subscriptions updated in real time.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/fcm_topic_manager.dart';
import '../services/notification_service.dart';
import '../services/notification_channel_service.dart';
import '../theme/river_theme.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});
  static const String route = '/notification_settings';

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsState();
}

class _NotificationSettingsState
    extends State<NotificationSettingsScreen> {
  // ─ Severity prefs
  final _sevEnabled = <String, bool>{
    'emergency': true,
    'critical':  true,
    'warning':   true,
    'info':      true,
  };

  // ─ Quiet hours
  bool      _quietEnabled  = false;
  TimeOfDay _quietStart    = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietEnd      = const TimeOfDay(hour:  7, minute: 0);

  // ─ District & river selection (chip grid)
  final Set<String> _selDistricts = {};
  final Set<String> _selRivers    = {};

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final mgr   = FcmTopicManager.instance;
    setState(() {
      for (final sev in _sevEnabled.keys) {
        _sevEnabled[sev] = prefs.getBool('notif_sev_$sev') ?? true;
      }
      _quietEnabled = prefs.getBool('quiet_hours_enabled') ?? false;
      _quietStart   = TimeOfDay(
        hour:   prefs.getInt('quiet_start_hour') ?? 22,
        minute: prefs.getInt('quiet_start_min')  ?? 0,
      );
      _quietEnd = TimeOfDay(
        hour:   prefs.getInt('quiet_end_hour') ?? 7,
        minute: prefs.getInt('quiet_end_min')  ?? 0,
      );
      _selDistricts
        ..clear()
        ..addAll(mgr.subscribedDistricts);
      _selRivers
        ..clear()
        ..addAll(mgr.subscribedRivers);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    if (_loading) {
      return Scaffold(
        backgroundColor: t.bgBase,
        body: Center(
            child: CircularProgressIndicator(color: t.accent)),
      );
    }
    return Scaffold(
      backgroundColor: t.bgBase,
      appBar: AppBar(
        backgroundColor: t.navBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: t.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Notification Settings',
          style: TextStyle(
            color: t.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ─ Severity toggles
          _header(t, Icons.notifications_active_rounded,
              'Alert Severity'),
          const SizedBox(height: 8),
          ..._sevEnabled.entries.map((e) => _SeverityRow(
                t:       t,
                sev:     e.key,
                enabled: e.value,
                onChanged: (v) async {
                  setState(() => _sevEnabled[e.key] = v);
                  final prefs =
                      await SharedPreferences.getInstance();
                  await prefs.setBool('notif_sev_${e.key}', v);
                  // Auto-subscribe / unsubscribe FCM topic
                  final topic = 'flood_${e.key}';
                  if (v) {
                    await FcmTopicManager.instance.subscribeTo(topic);
                  } else {
                    await FcmTopicManager.instance
                        .unsubscribeFrom(topic);
                  }
                },
              )),
          const SizedBox(height: 20),

          // ─ Quiet hours
          _header(t, Icons.bedtime_rounded, 'Quiet Hours'),
          const SizedBox(height: 8),
          _card(t, [
            SwitchListTile(
              activeColor: t.accent,
              value: _quietEnabled,
              title: Text('Enable quiet hours',
                  style: TextStyle(
                      color: t.textPrimary, fontSize: 14)),
              subtitle: Text(
                'No push during quiet window even for warnings',
                style: TextStyle(
                    color: t.textSecondary, fontSize: 11),
              ),
              onChanged: (v) async {
                setState(() => _quietEnabled = v);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('quiet_hours_enabled', v);
              },
            ),
            if (_quietEnabled) ...
              [
                _TimeTile(
                  t:       t,
                  label:   'Quiet from',
                  time:    _quietStart,
                  onPick: (picked) async {
                    setState(() => _quietStart = picked);
                    final prefs =
                        await SharedPreferences.getInstance();
                    await prefs.setInt(
                        'quiet_start_hour', picked.hour);
                    await prefs.setInt(
                        'quiet_start_min', picked.minute);
                  },
                ),
                _TimeTile(
                  t:       t,
                  label:   'Quiet until',
                  time:    _quietEnd,
                  onPick: (picked) async {
                    setState(() => _quietEnd = picked);
                    final prefs =
                        await SharedPreferences.getInstance();
                    await prefs.setInt(
                        'quiet_end_hour', picked.hour);
                    await prefs.setInt(
                        'quiet_end_min', picked.minute);
                  },
                ),
              ],
          ]),
          const SizedBox(height: 20),

          // ─ District subscriptions
          _header(t, Icons.map_rounded, 'District Alerts'),
          const SizedBox(height: 4),
          Text(
            'Receive alerts for specific Bihar districts.',
            style: TextStyle(
                color: t.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 8),
          _ChipGrid(
            t:        t,
            items:    FcmTopics.biharDistricts,
            selected: _selDistricts,
            format:   (s) => s
                .replaceAll('_', ' ')
                .split(' ')
                .map((w) => w.isEmpty
                    ? ''
                    : w[0].toUpperCase() + w.substring(1))
                .join(' '),
            onToggle: (slug, selected) async {
              setState(() {
                if (selected) {
                  _selDistricts.add(slug);
                } else {
                  _selDistricts.remove(slug);
                }
              });
              await FcmTopicManager.instance
                  .setDistrictSubscriptions(
                      _selDistricts.toList());
            },
          ),
          const SizedBox(height: 20),

          // ─ River subscriptions
          _header(t, Icons.water_rounded, 'River Alerts'),
          const SizedBox(height: 8),
          _ChipGrid(
            t:        t,
            items:    FcmTopics.biharRivers,
            selected: _selRivers,
            format:   (s) => s
                .replaceAll('_', ' ')
                .split(' ')
                .map((w) => w.isEmpty
                    ? ''
                    : w[0].toUpperCase() + w.substring(1))
                .join(' '),
            onToggle: (slug, selected) async {
              setState(() {
                if (selected) {
                  _selRivers.add(slug);
                } else {
                  _selRivers.remove(slug);
                }
              });
              await FcmTopicManager.instance
                  .setRiverSubscriptions(_selRivers.toList());
            },
          ),
          const SizedBox(height: 20),

          // ─ Test notifications
          _header(t, Icons.science_rounded, 'Test Notifications'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TestButton(
                  t: t,
                  label: '🚨 Emergency',
                  color: const Color(0xFFFF1744),
                  channelId: 'flood_emergency',
                  title: '🚨 EMERGENCY TEST',
                  body: 'Simulated HFL breach at Birpur, Kosi river'),
              _TestButton(
                  t: t,
                  label: '🔴 Critical',
                  color: const Color(0xFFFF6D00),
                  channelId: 'flood_critical',
                  title: '🔴 CRITICAL TEST',
                  body: 'Level above danger at Baltara, Gandak'),
              _TestButton(
                  t: t,
                  label: '⚠️ Warning',
                  color: const Color(0xFFFFD600),
                  channelId: 'flood_warning',
                  title: '⚠️ Warning TEST',
                  body: 'Rapid rise detected at Rosera, Bagmati'),
              _TestButton(
                  t: t,
                  label: 'ℹ️ Info',
                  color: const Color(0xFF00E5FF),
                  channelId: 'flood_info',
                  title: 'ℹ️ Advisory TEST',
                  body: 'Heavy rainfall (78 mm) near Darbhanga'),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── Helpers

  Widget _header(RiverColors t, IconData icon, String label) =>
      Row(
        children: [
          Icon(icon, color: t.accent, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: t.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ],
      );

  Widget _card(RiverColors t, List<Widget> children) =>
      Container(
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.stroke),
        ),
        child: Column(children: children),
      );
}

// ── Severity row ───────────────────────────────────────────────────────────

const _sevMeta = {
  'emergency': ('🚨', 'Emergency', Color(0xFFFF1744)),
  'critical':  ('🔴', 'Critical',  Color(0xFFFF6D00)),
  'warning':   ('⚠️', 'Warning',   Color(0xFFFFD600)),
  'info':      ('ℹ️', 'Advisory',  Color(0xFF00E5FF)),
};

class _SeverityRow extends StatelessWidget {
  final RiverColors t;
  final String  sev;
  final bool    enabled;
  final ValueChanged<bool> onChanged;
  const _SeverityRow({
    required this.t,
    required this.sev,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final meta = _sevMeta[sev]!;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.stroke),
      ),
      child: SwitchListTile(
        activeColor: meta.$3,
        value: enabled,
        leading: Text(meta.$1,
            style: const TextStyle(fontSize: 20)),
        title: Text(
          meta.$2,
          style: TextStyle(
            color: t.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        subtitle: Text(
          _subtitle(sev),
          style: TextStyle(
              color: t.textSecondary, fontSize: 10),
        ),
        onChanged: onChanged,
      ),
    );
  }

  static String _subtitle(String sev) {
    switch (sev) {
      case 'emergency': return 'HFL breach, embankment collapse';
      case 'critical':  return 'Above danger level';
      case 'warning':   return 'Above warning level, rapid rise';
      case 'info':      return 'Heavy rainfall, advisories';
      default:          return '';
    }
  }
}

// ── Time picker tile ───────────────────────────────────────────────────────

class _TimeTile extends StatelessWidget {
  final RiverColors t;
  final String     label;
  final TimeOfDay  time;
  final ValueChanged<TimeOfDay> onPick;
  const _TimeTile({
    required this.t,
    required this.label,
    required this.time,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(label,
            style: TextStyle(
                color: t.textPrimary, fontSize: 13)),
        trailing: GestureDetector(
          onTap: () async {
            HapticFeedback.lightImpact();
            final picked = await showTimePicker(
              context: context,
              initialTime: time,
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                  colorScheme: ColorScheme.dark(
                    primary: t.accent,
                    onPrimary: Colors.black,
                    surface: t.cardBg,
                  ),
                ),
                child: child!,
              ),
            );
            if (picked != null) onPick(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: t.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: t.accent.withValues(alpha: 0.4)),
            ),
            child: Text(
              time.format(context),
              style: TextStyle(
                color: t.accent,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      );
}

// ── Chip grid ──────────────────────────────────────────────────────────────

class _ChipGrid extends StatelessWidget {
  final RiverColors       t;
  final List<String>      items;
  final Set<String>       selected;
  final String Function(String) format;
  final void Function(String slug, bool selected) onToggle;
  const _ChipGrid({
    required this.t,
    required this.items,
    required this.selected,
    required this.format,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: items.map((slug) {
          final active = selected.contains(slug);
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onToggle(slug, !active);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: active
                    ? t.accent.withValues(alpha: 0.18)
                    : t.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: active
                      ? t.accent.withValues(alpha: 0.7)
                      : t.stroke,
                ),
              ),
              child: Text(
                format(slug),
                style: TextStyle(
                  color: active ? t.accent : t.textSecondary,
                  fontWeight: active
                      ? FontWeight.w700
                      : FontWeight.w500,
                  fontSize: 10,
                ),
              ),
            ),
          );
        }).toList(),
      );
}

// ── Test notification button ──────────────────────────────────────────────

class _TestButton extends StatelessWidget {
  final RiverColors t;
  final String      label;
  final Color       color;
  final String      channelId;
  final String      title;
  final String      body;
  const _TestButton({
    required this.t,
    required this.label,
    required this.color,
    required this.channelId,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) => ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.15),
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () async {
          HapticFeedback.mediumImpact();
          await NotificationService.instance.showFloodAlert(
            id:        DateTime.now().millisecondsSinceEpoch & 0xFFFF,
            title:     title,
            body:      body,
            channelId: channelId,
            payload:   'test_$channelId',
          );
        },
        child: Text(
          label,
          style: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 12),
        ),
      );
}
