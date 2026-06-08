// lib/screens/alerts_screen.dart
// Bihar Flood Command — Alerts HUD v3
// Robotic HUD aesthetic, Bihar-only districts/rivers, live CWC+IMD+NDMA data.
//
// P1 fixes applied (2026-06-08):
//   1. All fontSize values floored at 10px minimum (was: 7, 7.5, 8, 8.5, 9)
//   2. _clock Timer isolated into _HudClockWidget — only the time Text
//      rebuilds every second instead of the entire screen tree.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/context_l10n.dart';
import '../providers/flood_providers.dart';
import '../theme/river_theme.dart';

// ─── Bihar districts constant ──────────────────────────────────────────────
const _biharDistricts = [
  'Patna','Muzaffarpur','Darbhanga','Bhagalpur','Gaya','Purnia',
  'Saran','Begusarai','Samastipur','Vaishali','East Champaran',
  'West Champaran','Sitamarhi','Madhubani','Supaul','Araria',
  'Kishanganj','Katihar','Madhepura','Saharsa','Khagaria',
  'Sheikhpura','Lakhisarai','Munger','Jamui','Banka','Nawada',
  'Nalanda','Sheohar','Gopalganj','Siwan','Bhojpur','Buxar',
  'Rohtas','Kaimur','Aurangabad','Jehanabad','Arwal',
];

// ─────────────────────────────────────────────────────────────────────────────
// P1 FIX: Isolated clock widget — only this rebuilds every second.
// Previously the Timer called setState on _AlertsScreenState which caused
// the entire NestedScrollView + ListView tree to rebuild on every tick.
// ─────────────────────────────────────────────────────────────────────────────
class _HudClockWidget extends StatefulWidget {
  const _HudClockWidget();
  @override
  State<_HudClockWidget> createState() => _HudClockWidgetState();
}

class _HudClockWidgetState extends State<_HudClockWidget> {
  late final Timer _clock;
  String _timeStr = '';

  @override
  void initState() {
    super.initState();
    _tick();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    setState(() {
      _timeStr = DateFormat('HH:mm:ss').format(DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      'SYS CLOCK $_timeStr · BSDMA FEED',
      style: const TextStyle(
        color: AppPalette.textDim,
        fontSize: 10, // P1 FIX: was 9
        letterSpacing: 1,
      ),
    );
  }
}

class AlertsScreen extends ConsumerStatefulWidget {
  static const route = '/alerts';
  const AlertsScreen({super.key});
  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  // P1 FIX: _clock Timer and _timeStr removed from this class.
  // The clock now lives entirely inside _HudClockWidget.
  String _filter = 'ALL';
  final _filters = ['ALL', 'CRITICAL', 'SEVERE', 'MODERATE', 'SAFE'];

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this, duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imdAlerts  = ref.watch(imdAlertsProvider);
    final ndmaAlerts = ref.watch(ndmaAdvisoriesProvider);
    final allAlerts  = [...imdAlerts, ...ndmaAlerts];

    final filtered = _filter == 'ALL'
        ? allAlerts
        : allAlerts.where((a) {
            final sev = _severity(a).toUpperCase();
            return sev.contains(_filter);
          }).toList();

    return Scaffold(
      backgroundColor: AppPalette.abyss0,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverToBoxAdapter(child: _buildHUDHeader()),
          SliverToBoxAdapter(child: _buildCommandStrip(allAlerts)),
          SliverToBoxAdapter(child: _buildFilterBar()),
        ],
        body: filtered.isEmpty
            ? _NoSignal(label: 'NO ALERTS · BIHAR CLEAR')
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                itemCount: filtered.length,
                itemBuilder: (_, i) => _AlertTile(raw: filtered[i]),
              ),
      ),
    );
  }

  Widget _buildHUDHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 12),
      decoration: BoxDecoration(
        color: AppPalette.abyss0,
        border: Border(
            bottom: BorderSide(color: AppPalette.cyan.withValues(alpha: 0.15))),
      ),
      child: Row(
        children: [
          // back
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppPalette.cyan.withValues(alpha: 0.30)),
                color: AppPalette.abyss2,
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppPalette.cyan, size: 14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ALERT COMMAND · BIHAR',
                    style: TextStyle(
                      color: AppPalette.cyan,
                      fontSize: 13, fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    )),
                // P1 FIX: Replaced inline Text + Timer.setState with isolated widget
                const _HudClockWidget(),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppPalette.critical
                    .withValues(alpha: 0.08 + 0.08 * _pulse.value),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color: AppPalette.critical.withValues(alpha: 0.40)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppPalette.critical
                          .withValues(alpha: 0.5 + 0.5 * _pulse.value),
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text('LIVE',
                      style: TextStyle(
                        color: AppPalette.critical,
                        fontSize: 10, // P1 FIX: was 9
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommandStrip(List allAlerts) {
    final counts = <String, int>{
      'CRITICAL': 0, 'SEVERE': 0, 'MODERATE': 0, 'SAFE': 0,
    };
    for (final a in allAlerts) {
      final s = _severity(a).toUpperCase();
      if (s.contains('CRITICAL') || s.contains('EXTREME') || s.contains('RED')) {
        counts['CRITICAL'] = counts['CRITICAL']! + 1;
      } else if (s.contains('SEVERE') || s.contains('ORANGE') || s.contains('HIGH')) {
        counts['SEVERE'] = counts['SEVERE']! + 1;
      } else if (s.contains('MODERATE') || s.contains('YELLOW') || s.contains('MEDIUM')) {
        counts['MODERATE'] = counts['MODERATE']! + 1;
      } else {
        counts['SAFE'] = counts['SAFE']! + 1;
      }
    }
    final tiles = [
      ('CRITICAL', counts['CRITICAL']!, AppPalette.critical),
      ('SEVERE',   counts['SEVERE']!,   AppPalette.danger),
      ('MODERATE', counts['MODERATE']!, AppPalette.amber),
      ('SAFE',     counts['SAFE']!,     AppPalette.safe),
      ('TOTAL',    allAlerts.length,    AppPalette.cyan),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: tiles.map((t) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: t.$3.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: t.$3.withValues(alpha: 0.25)),
            ),
            child: Column(
              children: [
                Text('${t.$2}',
                    style: TextStyle(
                      color: t.$3, fontSize: 18,
                      fontWeight: FontWeight.w900,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    )),
                const SizedBox(height: 2),
                Text(t.$1,
                    style: const TextStyle(
                      color: AppPalette.textDim,
                      fontSize: 10, // P1 FIX: was 7
                      fontWeight: FontWeight.w700, letterSpacing: 0.8,
                    )),
              ],
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildFilterBar() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: _filters.map((f) {
          final active = _filter == f;
          final col = _colorForFilter(f);
          return GestureDetector(
            onTap: () => setState(() => _filter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: active ? col.withValues(alpha: 0.15) : AppPalette.abyss2,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color: active ? col : AppPalette.abyssStroke),
              ),
              child: Center(
                child: Text(f,
                    style: TextStyle(
                      color: active ? col : AppPalette.textDim,
                      fontSize: 10, // P1 FIX: was 9
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    )),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _severity(dynamic raw) {
    try {
      return (raw as dynamic)['severity']?.toString() ??
          (raw as dynamic)['alert_level']?.toString() ?? 'safe';
    } catch (_) { return 'safe'; }
  }

  Color _colorForFilter(String f) {
    switch (f) {
      case 'CRITICAL': return AppPalette.critical;
      case 'SEVERE':   return AppPalette.danger;
      case 'MODERATE': return AppPalette.amber;
      case 'SAFE':     return AppPalette.safe;
      default:         return AppPalette.cyan;
    }
  }
}

// ─── Alert Tile ──────────────────────────────────────────────────────────────
class _AlertTile extends StatelessWidget {
  final dynamic raw;
  const _AlertTile({required this.raw});

  String _f(String key, [String fb = '—']) {
    try {
      final v = (raw as dynamic)[key];
      return v?.toString().isNotEmpty == true ? v.toString() : fb;
    } catch (_) { return fb; }
  }

  Color get _col {
    final s = _f('severity', _f('alert_level', 'low')).toLowerCase();
    if (s.contains('extreme') || s.contains('critical') || s.contains('red'))
      return AppPalette.critical;
    if (s.contains('severe') || s.contains('orange') || s.contains('high'))
      return AppPalette.danger;
    if (s.contains('moderate') || s.contains('yellow') || s.contains('medium'))
      return AppPalette.amber;
    return AppPalette.safe;
  }

  @override
  Widget build(BuildContext context) {
    final col    = _col;
    final title  = _f('title', _f('headline', 'Alert'));
    final desc   = _f('description', _f('message', ''));
    final source = _f('source', _f('agency', ''));
    final area   = _f('area', _f('district', ''));
    final rawDate= _f('issued_at', _f('date', ''));
    String dateStr = '';
    if (rawDate.isNotEmpty) {
      final dt = DateTime.tryParse(rawDate);
      dateStr = dt != null
          ? DateFormat('dd MMM · HH:mm').format(dt.toLocal())
          : rawDate;
    }

    // District badge — highlight if it's a Bihar district
    final isBihar = _biharDistricts.any(
        (d) => area.toLowerCase().contains(d.toLowerCase()));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppPalette.abyss2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: col.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
              color: col.withValues(alpha: 0.07),
              blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          // top accent bar
          Container(
            height: 2,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              gradient: LinearGradient(colors: [
                col.withValues(alpha: 0.8), col.withValues(alpha: 0),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: col.withValues(alpha: 0.10),
                        border: Border.all(color: col.withValues(alpha: 0.28)),
                      ),
                      child: Icon(_iconFor(col), color: col, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: const TextStyle(
                                color: AppPalette.textWhite,
                                fontSize: 12, fontWeight: FontWeight.w800,
                                height: 1.3,
                              )),
                          if (area.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.location_on_rounded,
                                    color: AppPalette.textDim, size: 10),
                                const SizedBox(width: 3),
                                Text(area,
                                    style: TextStyle(
                                      color: isBihar
                                          ? AppPalette.cyan
                                          : AppPalette.textGrey,
                                      fontSize: 10,
                                      fontWeight: isBihar
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                    )),
                                if (isBihar) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppPalette.cyan.withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(
                                          color: AppPalette.cyan.withValues(alpha: 0.25)),
                                    ),
                                    child: const Text('BIHAR',
                                        style: TextStyle(
                                          color: AppPalette.cyan,
                                          fontSize: 10, // P1 FIX: was 7
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.8,
                                        )),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: col.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: col.withValues(alpha: 0.30)),
                          ),
                          child: Text(
                            _f('severity', _f('alert_level', 'INFO'))
                                .toUpperCase()
                                .replaceAll('_', ' '),
                            style: TextStyle(
                              color: col,
                              fontSize: 10, // P1 FIX: was 7.5
                              fontWeight: FontWeight.w900, letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        if (dateStr.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(dateStr,
                              style: const TextStyle(
                                color: AppPalette.textDim,
                                fontSize: 10, // P1 FIX: was 8.5
                              )),
                        ],
                      ],
                    ),
                  ],
                ),
                if (desc.isNotEmpty && desc != '—') ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppPalette.abyss4,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppPalette.abyssStroke),
                    ),
                    child: Text(desc,
                        style: const TextStyle(
                          color: AppPalette.textGrey,
                          fontSize: 10.5, height: 1.55)),
                  ),
                ],
                if (source.isNotEmpty && source != '—') ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.sensors_rounded,
                        color: AppPalette.textDim, size: 10),
                    const SizedBox(width: 4),
                    Text(source,
                        style: const TextStyle(
                          color: AppPalette.textDim,
                          fontSize: 10, // P1 FIX: was 9
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        )),
                  ]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(Color c) {
    if (c == AppPalette.critical) return Icons.crisis_alert_rounded;
    if (c == AppPalette.danger)   return Icons.warning_rounded;
    if (c == AppPalette.amber)    return Icons.warning_amber_rounded;
    return Icons.check_circle_outline_rounded;
  }
}

// ─── No Signal ────────────────────────────────────────────────────────────────
class _NoSignal extends StatelessWidget {
  final String label;
  const _NoSignal({required this.label});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppPalette.safe.withValues(alpha: 0.12),
                  AppPalette.abyss2,
                ]),
                border: Border.all(
                    color: AppPalette.safe.withValues(alpha: 0.25)),
              ),
              child: const Icon(Icons.sensors_off_rounded,
                  color: AppPalette.safe, size: 30),
            ),
            const SizedBox(height: 14),
            Text(label,
                style: const TextStyle(
                  color: AppPalette.textGrey, fontSize: 11,
                  fontWeight: FontWeight.w700, letterSpacing: 1.5,
                )),
            const SizedBox(height: 6),
            const Text('38 BIHAR DISTRICTS MONITORED',
                style: TextStyle(
                  color: AppPalette.textDim,
                  fontSize: 10, // P1 FIX: was 9
                  letterSpacing: 1,
                )),
          ],
        ),
      );
}
