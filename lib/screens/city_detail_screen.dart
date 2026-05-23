// lib/screens/city_detail_screen.dart
//
// Full city detail screen — opened by tapping any city on the India Map
// or in the Stations list.  Shows:
//  - Real gauge level + CWC source badge
//  - 24-hr trend sparkline (from RealTimeService._historyByCity)
//  - IMD colour alert badge + rainfall
//  - NDMA advisories for the state
//  - Emergency contacts for the state
//  - "Run Prediction" CTA → PredictScreen with city pre-filled

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/flood_data.dart';
import '../models/river_monitoring.dart';
import '../providers/flood_providers.dart';
import '../services/ndma_service.dart';

const _kBg     = Color(0xFF060D14);
const _kCard   = Color(0xFF0D1B26);
const _kCyan   = Color(0xFF00C2DE);
const _kGreen  = Color(0xFF22C55E);
const _kYellow = Color(0xFFF59E0B);
const _kOrange = Color(0xFFEA580C);
const _kRed    = Color(0xFFEF4444);
const _kText   = Color(0xFFE2EAF0);
const _kSub    = Color(0xFF6B8699);

Color _riskColor(String r) {
  switch (r.toUpperCase()) {
    case 'CRITICAL': return _kRed;
    case 'HIGH':     return _kOrange;
    case 'MODERATE': return _kYellow;
    default:         return _kGreen;
  }
}

Color _imdColor(String s) {
  switch (s.toUpperCase()) {
    case 'RED':    return _kRed;
    case 'ORANGE': return _kOrange;
    case 'YELLOW': return _kYellow;
    default:       return _kGreen;
  }
}

/// Push this screen via:
///   Navigator.push(context,
///     MaterialPageRoute(builder: (_) => CityDetailScreen(cityName: 'Patna')));
class CityDetailScreen extends ConsumerWidget {
  final String cityName;
  const CityDetailScreen({super.key, required this.cityName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data         = ref.watch(cityDataProvider(cityName));
    final trend        = ref.watch(cityTrendProvider(cityName)).cast<RiverLevelSnapshot>();
    final imdAlerts    = ref.watch(stateImdAlertsProvider(data?.state ?? ''));
    final advisories   = ref.watch(stateNdmaAdvisoriesProvider(data?.state ?? ''));
    final contacts     = ref.watch(stateEmergencyContactsProvider(data?.state ?? ''));

    return Scaffold(
      backgroundColor: _kBg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A1E2C), _kBg],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── App bar ──────────────────────────────────────────────────
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                pinned: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded,
                      color: _kText, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  cityName,
                  style: const TextStyle(
                      color: _kText,
                      fontWeight: FontWeight.w800,
                      fontSize: 18),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded,
                        color: _kSub, size: 20),
                    onPressed: () =>
                        ref.read(realTimeProvider).refreshData(),
                  ),
                ],
              ),

              if (data == null)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_off_rounded,
                            color: _kSub, size: 40),
                        const SizedBox(height: 12),
                        Text('No data for $cityName',
                            style: const TextStyle(
                                color: _kSub, fontSize: 14)),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // ── Gauge hero card ─────────────────────────────────
                      _GaugeHeroCard(data: data),
                      const SizedBox(height: 14),

                      // ── 24-hr trend ──────────────────────────────────────
                      if (trend.isNotEmpty) ...[
                        _TrendCard(trend: trend),
                        const SizedBox(height: 14),
                      ],

                      // ── IMD alerts ───────────────────────────────────────
                      if (imdAlerts.isNotEmpty) ...[
                        _SectionLabel('\uD83C\uDF27  IMD Weather Alerts'),
                        ...imdAlerts.take(3).map((a) => _ImdAlertTile(alert: a)),
                        const SizedBox(height: 14),
                      ],

                      // ── NDMA advisories ──────────────────────────────────
                      if (advisories.isNotEmpty) ...[
                        _SectionLabel('\uD83D\uDEA8  NDMA Advisories'),
                        ...advisories.take(2).map((a) => _NdmaAdvisoryTile(adv: a)),
                        const SizedBox(height: 14),
                      ],

                      // ── Emergency contacts ───────────────────────────────
                      _SectionLabel('\uD83D\uDCDE  Emergency Contacts'),
                      _EmergencyContactsCard(contacts: contacts, state: data.state),
                      const SizedBox(height: 20),

                      // ── Predict CTA ──────────────────────────────────────
                      _PredictCta(cityName: cityName, currentLevel: data.currentLevel),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Gauge Hero Card ──────────────────────────────────────────────────────────
class _GaugeHeroCard extends StatelessWidget {
  final FloodData data;
  const _GaugeHeroCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final rc  = _riskColor(data.riskLevel);
    final pct = data.capacityPercent.clamp(0.0, 100.0);

    final s      = data.status.toUpperCase();
    final isLive = s != 'ESTIMATED';
    final badgeLabel = isLive ? 'LIVE · CWC' : 'ESTIMATED';
    final badgeColor = isLive ? _kCyan : _kSub;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: rc.withValues(alpha: 0.4)),
        boxShadow: [BoxShadow(color: rc.withValues(alpha: 0.08), blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.riverName ?? 'River',
                        style: const TextStyle(color: _kSub, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(data.state,
                        style: const TextStyle(
                            color: _kText,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: rc.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: rc.withValues(alpha: 0.5)),
                ),
                child: Text(data.riskLevel,
                    style: TextStyle(
                        color: rc, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${data.currentLevel.toStringAsFixed(2)} m',
                  style: TextStyle(
                      color: rc,
                      fontWeight: FontWeight.w900,
                      fontSize: 38,
                      letterSpacing: -1)),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(badgeLabel,
                      style: TextStyle(
                          color: badgeColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w700)),
                ),
              ),
              if (data.imdSeverity != null) ...[
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _imdColor(data.imdSeverity!).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: _imdColor(data.imdSeverity!).withValues(alpha: 0.5)),
                    ),
                    child: Text('IMD ${data.imdSeverity}',
                        style: TextStyle(
                            color: _imdColor(data.imdSeverity!),
                            fontSize: 9,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Container(
                    height: 8, color: Colors.white.withValues(alpha: 0.06)),
                FractionallySizedBox(
                  widthFactor: pct / 100,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [rc.withValues(alpha: 0.6), rc]),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${pct.toStringAsFixed(0)}% capacity',
                  style: TextStyle(
                      color: rc, fontWeight: FontWeight.w700, fontSize: 12)),
              Text(
                'W ${data.warningLevel.toStringAsFixed(1)}  '
                'D ${data.dangerLevel.toStringAsFixed(1)} m',
                style:
                    const TextStyle(color: _kSub, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (data.flowRate != null)
                _StatChip(
                    Icons.waves_rounded,
                    '${data.flowRate!.toStringAsFixed(0)} m³/s',
                    'Flow'),
              if (data.effectiveRainfallMm > 0)
                _StatChip(
                    Icons.water_drop_outlined,
                    '${data.effectiveRainfallMm.toStringAsFixed(1)} mm',
                    data.imdRainfallMm != null ? 'IMD rain' : 'Rain 24h'),
              _StatChip(
                  Icons.schedule_rounded,
                  DateFormat('HH:mm').format(data.lastUpdated.toLocal()),
                  'Updated'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value, label;
  const _StatChip(this.icon, this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: _kSub),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                      color: _kText,
                      fontWeight: FontWeight.w700,
                      fontSize: 11)),
              Text(label,
                  style: const TextStyle(color: _kSub, fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── 24-hr Trend Sparkline ────────────────────────────────────────────────────
class _TrendCard extends StatelessWidget {
  final List<RiverLevelSnapshot> trend;
  const _TrendCard({required this.trend});

  @override
  Widget build(BuildContext context) {
    final levels = trend.map((s) => s.level).toList();
    final minL   = levels.reduce((a, b) => a < b ? a : b);
    final maxL   = levels.reduce((a, b) => a > b ? a : b);
    final range  = (maxL - minL).abs();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('24-hr River Level Trend',
              style: TextStyle(
                  color: _kText,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
          const SizedBox(height: 12),
          SizedBox(
            height: 60,
            child: CustomPaint(
              painter: _SparklinePainter(
                  levels: levels, minL: minL, range: range),
              size: Size.infinite,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('HH:mm').format(
                    trend.first.timestamp.toLocal()),
                style:
                    const TextStyle(color: _kSub, fontSize: 9)),
              Text(
                '${trend.length} readings  '
                '${minL.toStringAsFixed(2)}–${maxL.toStringAsFixed(2)} m',
                style:
                    const TextStyle(color: _kSub, fontSize: 9)),
              Text(
                DateFormat('HH:mm').format(
                    trend.last.timestamp.toLocal()),
                style:
                    const TextStyle(color: _kSub, fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> levels;
  final double minL, range;
  const _SparklinePainter(
      {required this.levels, required this.minL, required this.range});

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.length < 2) return;
    final paint = Paint()
      ..color = const Color(0xFF00C2DE)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (var i = 0; i < levels.length; i++) {
      final x = i / (levels.length - 1) * size.width;
      final y = range < 0.01
          ? size.height / 2
          : size.height - ((levels[i] - minL) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.levels != levels || old.minL != minL || old.range != range;
}

// ─── IMD Alert Tile ───────────────────────────────────────────────────────────
class _ImdAlertTile extends StatelessWidget {
  final dynamic alert;
  const _ImdAlertTile({required this.alert});

  @override
  Widget build(BuildContext context) {
    final c = _imdColor(alert.severity as String? ?? '');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: c.withValues(alpha: 0.5), blurRadius: 5)
                ]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    (alert.title as String?) ??
                        (alert.severity as String? ?? 'IMD Alert'),
                    style: const TextStyle(
                        color: _kText,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                if ((alert.description as String?)?.isNotEmpty == true)
                  Text(alert.description as String,
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c.withValues(alpha: 0.5)),
            ),
            child: Text(
                (alert.severity as String? ?? '').toUpperCase(),
                style: TextStyle(
                    color: c,
                    fontWeight: FontWeight.w800,
                    fontSize: 10)),
          ),
        ],
      ),
    );
  }
}

// ─── NDMA Advisory Tile ───────────────────────────────────────────────────────
class _NdmaAdvisoryTile extends StatelessWidget {
  final dynamic adv;
  const _NdmaAdvisoryTile({required this.adv});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: _kOrange.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kOrange.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: _kOrange, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((adv.title as String? ?? 'NDMA Advisory'),
                    style: const TextStyle(
                        color: _kText,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                if ((adv.advisory as String?)?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(adv.advisory as String,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 11),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Emergency Contacts ───────────────────────────────────────────────────────
class _EmergencyContactsCard extends StatelessWidget {
  final List<EmergencyContact> contacts;
  final String state;
  const _EmergencyContactsCard(
      {required this.contacts, required this.state});

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          _buildRow('NDMA Helpline', '1078'),
          _buildRow('NDRF', '011-24363260'),
          _buildRow('Police', '100'),
          _buildRow('Ambulance', '108'),
          if (contacts.isNotEmpty) ...[
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.07)),
            ...contacts.take(4).map(
                (c) => _buildRow(c.role.isNotEmpty ? c.role : c.name, c.phone)),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(String label, String phone) {
    return InkWell(
      onTap: () => _call(phone),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.phone_rounded, color: _kGreen, size: 14),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: const TextStyle(color: _kText, fontSize: 13)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _kGreen.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kGreen.withValues(alpha: 0.4)),
              ),
              child: Text(phone,
                  style: const TextStyle(
                      color: _kGreen,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Predict CTA ──────────────────────────────────────────────────────────────
class _PredictCta extends StatelessWidget {
  final String cityName;
  final double currentLevel;
  const _PredictCta(
      {required this.cityName, required this.currentLevel});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/predict',
          arguments: {
            'city':          cityName,
            'river_level':   currentLevel,
          },
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF005C6E), Color(0xFF00C2DE)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: _kCyan.withValues(alpha: 0.2),
                blurRadius: 16,
                spreadRadius: 1)
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.psychology_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text(
              'Run Flood Prediction',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Section label helper ─────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
            color: _kText, fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }
}
