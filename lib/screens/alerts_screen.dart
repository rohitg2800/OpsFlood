import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants.dart';
import '../models/flood_data.dart';
import '../providers/flood_providers.dart';
import '../services/ndma_service.dart';
import '../widgets/animated_alert_badge.dart';

const _kBg     = Color(0xFF060D14);
const _kCard   = Color(0xFF0D1B26);
const _kCyan   = Color(0xFF00C2DE);
const _kGreen  = Color(0xFF22C55E);
const _kYellow = Color(0xFFF59E0B);
const _kOrange = Color(0xFFEA580C);
const _kRed    = Color(0xFFEF4444);
const _kText   = Color(0xFFE2EAF0);
const _kSub    = Color(0xFF6B8699);

Color _sevColor(String sev) {
  switch (sev.toUpperCase()) {
    case 'ALL':      return _kCyan;
    case 'CRITICAL': return _kRed;
    case 'HIGH':     return _kOrange;
    case 'MODERATE': return _kYellow;
    default:         return _kGreen;
  }
}

String _sevIcon(String sev) {
  switch (sev.toUpperCase()) {
    case 'CRITICAL': return '\uD83D\uDD34';
    case 'HIGH':     return '\uD83D\uDFE0';
    case 'MODERATE': return '\uD83D\uDFE1';
    case 'LOW':      return '\uD83D\uDFE2';
    default:         return '\u26AA';
  }
}

// IMD colour → Flutter Color
Color _imdColor(String sev) {
  switch (sev.toUpperCase()) {
    case 'RED':    return _kRed;
    case 'ORANGE': return _kOrange;
    case 'YELLOW': return _kYellow;
    case 'GREEN':  return _kGreen;
    default:       return _kSub;
  }
}

// Source badge label + colour for _GaugeCard
_SourceBadge _sourceBadge(String status) {
  final s = status.toUpperCase();
  if (s == 'ESTIMATED') return _SourceBadge('ESTIMATED', _kSub);
  if (s.contains('CWC') || s == 'BULK' || s == 'TELEMETRY' || s == 'CWC_FFS' ||
      s == 'RESERVOIR' || s == 'LIVE_LEVELS') {
    return _SourceBadge('LIVE · CWC', _kCyan);
  }
  if (s == 'LIVE') return _SourceBadge('LIVE', _kGreen);
  return _SourceBadge(status, _kSub);
}

class _SourceBadge {
  final String label;
  final Color  color;
  const _SourceBadge(this.label, this.color);
}

class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});
  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen>
    with SingleTickerProviderStateMixin {
  final Set<String> _dismissed = {};
  String _filter = 'ALL';
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final liveLevels    = ref.watch(liveLevelsProvider);
    final isOffline     = ref.watch(isOfflineProvider);
    final isOnline      = !isOffline;
    final isUsingCache  = ref.watch(realTimeProvider).isUsingCache;
    final critAlerts    = ref.watch(criticalAlertsProvider);
    final activeCrit    = ref.watch(activeCriticalAlertsProvider);
    final imdAlerts     = ref.watch(imdAlertsProvider);
    final ndmaAdvisories= ref.watch(ndmaAdvisoriesProvider);
    final emergContacts = ref.watch(emergencyContactsProvider);

    return Scaffold(
      backgroundColor: _kBg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A1E2C), _kBg, Color(0xFF030608)],
          ),
        ),
        child: SafeArea(
          child: Builder(builder: (context) {
            final levels = List<FloodData>.from(liveLevels)
              ..sort((a, b) => b.capacityPercent.compareTo(a.capacityPercent));

            final baseAlerts = critAlerts.isNotEmpty ? critAlerts : activeCrit;

            final timelineAlerts = baseAlerts
                .where((a) => !_dismissed.contains(a.id))
                .where((a) => _filter == 'ALL' || a.severity == _filter)
                .toList()
              ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

            final counts = <String, int>{
              'CRITICAL': baseAlerts.where((a) => a.severity == 'CRITICAL').length,
              'HIGH':     baseAlerts.where((a) => a.severity == 'HIGH').length,
              'MODERATE': baseAlerts.where((a) => a.severity == 'MODERATE').length,
              'LOW':      baseAlerts.where((a) => a.severity == 'LOW').length,
            };

            return RefreshIndicator(
              onRefresh: () => ref.read(realTimeProvider).refreshData(),
              color: _kCyan,
              backgroundColor: _kCard,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // ── Header ───────────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Live Alerts',
                                  style: TextStyle(
                                      color: _kText,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5)),
                              const Spacer(),
                              IconButton(
                                onPressed: () => ref.read(realTimeProvider).refreshData(),
                                icon: const Icon(Icons.refresh_rounded, color: _kSub, size: 20),
                                style: IconButton.styleFrom(
                                    backgroundColor: Colors.white.withOpacity(0.06),
                                    padding: const EdgeInsets.all(8)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          AnimatedAlertBadge(
                            count: timelineAlerts.length,
                            isCritical: timelineAlerts.any((e) => e.severity == 'CRITICAL'),
                            label: 'Active Timeline Alerts',
                          ),
                          const SizedBox(height: 14),
                          // ── Severity count row ────────────────────────────
                          Row(
                            children: ['CRITICAL', 'HIGH', 'MODERATE', 'LOW'].map((s) {
                              final c = _sevColor(s);
                              return Expanded(
                                child: Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: c.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: c.withOpacity(0.22)),
                                  ),
                                  child: Column(
                                    children: [
                                      Text('${counts[s] ?? 0}',
                                          style: TextStyle(
                                              color: c,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 18)),
                                      Text(s[0] + s.substring(1).toLowerCase(),
                                          style: const TextStyle(
                                              color: _kSub, fontSize: 9)),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                          // ── Offline banner ────────────────────────────────
                          if (!isOnline || isUsingCache)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _kOrange.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _kOrange.withOpacity(0.4)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.wifi_off_rounded, color: _kOrange, size: 14),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Offline \u2014 showing cached alerts.',
                                      style: TextStyle(color: _kOrange, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // ── IMD Colour Alerts section ─────────────────────────────
                  if (imdAlerts.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
                        child: _ImdAlertsSection(alerts: imdAlerts),
                      ),
                    ),

                  // ── NDMA Advisories section ───────────────────────────────
                  if (ndmaAdvisories.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                        child: _NdmaAdvisoriesSection(advisories: ndmaAdvisories),
                      ),
                    ),

                  // ── Live River Gauges ─────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                      child: Row(
                        children: const [
                          Icon(Icons.water_drop, color: _kCyan, size: 13),
                          SizedBox(width: 5),
                          Text('Live River Gauges',
                              style: TextStyle(
                                  color: _kText,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                        ],
                      ),
                    ),
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _GaugeCard(item: levels[i]),
                        ),
                        childCount: levels.take(6).length,
                      ),
                    ),
                  ),

                  // ── Alert Timeline filter ─────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ['ALL', 'CRITICAL', 'HIGH', 'MODERATE', 'LOW'].map((s) {
                            final selected = s == _filter;
                            final c = _sevColor(s);
                            return GestureDetector(
                              onTap: () => setState(() => _filter = s),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: selected ? c.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: selected ? c : Colors.white.withOpacity(0.15),
                                    width: selected ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (s != 'ALL') ...[
                                      Text(_sevIcon(s), style: const TextStyle(fontSize: 12)),
                                      const SizedBox(width: 5),
                                    ],
                                    Text(s,
                                        style: TextStyle(
                                          color: selected ? c : Colors.white70,
                                          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                                          fontSize: 12,
                                        )),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),

                  // ── Timeline alerts list ──────────────────────────────────
                  if (timelineAlerts.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.check_circle_outline, color: _kGreen, size: 36),
                              SizedBox(height: 10),
                              Text('No alerts for this severity',
                                  style: TextStyle(color: _kSub, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) {
                            final alert = timelineAlerts[i];
                            return _AlertCard(
                              key: ValueKey(alert.id),
                              alert: alert,
                              pulseCtrl: _pulseCtrl,
                              onDismiss: () => setState(() => _dismissed.add(alert.id)),
                              onUndo: () => setState(() => _dismissed.remove(alert.id)),
                            );
                          },
                          childCount: timelineAlerts.length,
                        ),
                      ),
                    ),

                  // ── Emergency Contacts card ───────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 30),
                      child: _NdmaContactsCard(contacts: emergContacts),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ─── IMD Colour Alerts Section ────────────────────────────────────────────────
class _ImdAlertsSection extends StatelessWidget {
  final List<dynamic> alerts; // List<ImdAlert>
  const _ImdAlertsSection({required this.alerts});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _kYellow.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kYellow.withOpacity(0.5)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('\uD83C\uDF27', style: TextStyle(fontSize: 11)),
                  SizedBox(width: 5),
                  Text('IMD Weather Alerts',
                      style: TextStyle(
                          color: _kYellow,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 0.5)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...alerts.take(5).map((a) {
          final c = _imdColor(a.severity as String? ?? '');
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: c.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.withOpacity(0.35)),
            ),
            child: Row(
              children: [
                Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: c.withOpacity(0.5), blurRadius: 6)]),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((a.title as String? ?? a.severity as String? ?? 'IMD Alert'),
                          style: const TextStyle(
                              color: _kText, fontWeight: FontWeight.w700, fontSize: 13)),
                      if ((a.description as String?)?.isNotEmpty == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(a.description as String,
                              style: const TextStyle(color: Colors.white60, fontSize: 11),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: c.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: c.withOpacity(0.5)),
                      ),
                      child: Text((a.severity as String? ?? '').toUpperCase(),
                          style: TextStyle(
                              color: c, fontWeight: FontWeight.w800, fontSize: 10)),
                    ),
                    const SizedBox(height: 3),
                    Text((a.state as String? ?? ''),
                        style: const TextStyle(color: _kSub, fontSize: 10)),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ─── NDMA Advisories Section ──────────────────────────────────────────────────
class _NdmaAdvisoriesSection extends StatelessWidget {
  final List<dynamic> advisories; // List<NdmaAdvisory>
  const _NdmaAdvisoriesSection({required this.advisories});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _kOrange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kOrange.withOpacity(0.5)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('\uD83D\uDEA8', style: TextStyle(fontSize: 11)),
                  SizedBox(width: 5),
                  Text('NDMA Advisories',
                      style: TextStyle(
                          color: _kOrange,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 0.5)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...advisories.take(4).map((adv) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: _kOrange.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kOrange.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: _kOrange, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((adv.title as String? ?? 'NDMA Advisory'),
                          style: const TextStyle(
                              color: _kText, fontWeight: FontWeight.w700, fontSize: 13)),
                      if ((adv.advisory as String?)?.isNotEmpty == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(adv.advisory as String,
                              style: const TextStyle(color: Colors.white60, fontSize: 11),
                              maxLines: 3, overflow: TextOverflow.ellipsis),
                        ),
                      const SizedBox(height: 4),
                      Text((adv.state as String? ?? ''),
                          style: const TextStyle(color: _kSub, fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ─── NDMA Emergency Contacts Card ─────────────────────────────────────────────
class _NdmaContactsCard extends StatelessWidget {
  final List<EmergencyContact> contacts;
  const _NdmaContactsCard({required this.contacts});

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                const Text('\uD83D\uDEA8', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Emergency Contacts',
                      style: TextStyle(
                          color: _kText, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: _kOrange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kOrange.withOpacity(0.5)),
                  ),
                  child: const Text('NDMA',
                      style: TextStyle(
                          color: _kOrange,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1)),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.white.withOpacity(0.07)),
          _ContactRow(role: 'National Disaster Helpline', name: 'NDMA 24x7', phone: '1078', onCall: _call),
          _ContactRow(role: 'NDRF Emergency', name: 'National Disaster Response Force', phone: '011-24363260', onCall: _call),
          _ContactRow(role: 'Police Emergency', name: 'National Helpline', phone: '100', onCall: _call),
          _ContactRow(role: 'Ambulance', name: 'National Helpline', phone: '108', onCall: _call),
          if (contacts.isNotEmpty) ...[
            Divider(height: 1, color: Colors.white.withOpacity(0.07)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
              child: Text('State-specific contacts',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
            ),
            ...contacts.map((c) =>
                _ContactRow(role: c.role, name: c.name, phone: c.phone, onCall: _call)),
          ] else ...[
            Divider(height: 1, color: Colors.white.withOpacity(0.07)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Text(
                '\u2139\uFE0F  State-specific contacts load when /api/ndrf/contacts is live.',
                style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
            child: Text(
              'Source: National Disaster Management Authority (NDMA)',
              style: TextStyle(color: Colors.white.withOpacity(0.22), fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final String role, name, phone;
  final Future<void> Function(String) onCall;
  const _ContactRow({required this.role, required this.name, required this.phone, required this.onCall});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onCall(phone),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _kGreen.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: _kGreen.withOpacity(0.35)),
              ),
              child: const Icon(Icons.phone_rounded, color: _kGreen, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(role, style: const TextStyle(color: _kSub, fontSize: 10)),
                  Text(name, style: const TextStyle(color: _kText, fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _kGreen.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kGreen.withOpacity(0.4)),
              ),
              child: Text(phone,
                  style: const TextStyle(
                      color: _kGreen, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Gauge Card with real source badge ────────────────────────────────────────
class _GaugeCard extends StatelessWidget {
  final FloodData item;
  const _GaugeCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final riskC = _getRiskColor(item.riskLevel);
    final pct   = item.capacityPercent.clamp(0.0, 100.0);
    final badge = _sourceBadge(item.status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: riskC.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 4, height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [riskC.withOpacity(0.3), riskC],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(item.city,
                          style: const TextStyle(
                              color: _kText, fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                    Text(item.riverName ?? '',
                        style: const TextStyle(color: _kSub, fontSize: 11)),
                    const SizedBox(width: 8),
                    Text('D ${item.dangerLevel.toStringAsFixed(1)}',
                        style: const TextStyle(color: _kSub, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('${item.currentLevel.toStringAsFixed(2)} m',
                        style: TextStyle(
                            color: riskC, fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(width: 6),
                    // Real source badge (LIVE · CWC / LIVE / ESTIMATED)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: badge.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: badge.color.withOpacity(0.5))),
                      child: Text(badge.label,
                          style: TextStyle(
                              color: badge.color,
                              fontSize: 9,
                              fontWeight: FontWeight.w700)),
                    ),
                    // IMD severity dot if present
                    if (item.imdSeverity != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          color: _imdColor(item.imdSeverity!),
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(
                              color: _imdColor(item.imdSeverity!).withOpacity(0.6),
                              blurRadius: 5)],
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text('IMD ${item.imdSeverity}',
                          style: TextStyle(
                              color: _imdColor(item.imdSeverity!),
                              fontSize: 9,
                              fontWeight: FontWeight.w700)),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    children: [
                      Container(height: 4, color: Colors.white.withOpacity(0.06)),
                      FractionallySizedBox(
                        widthFactor: pct / 100,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                                colors: [riskC.withOpacity(0.6), riskC]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getRiskColor(String risk) {
    switch (risk) {
      case 'CRITICAL': return _kRed;
      case 'HIGH':     return _kOrange;
      case 'MODERATE': return _kYellow;
      default:         return _kGreen;
    }
  }
}

// ─── Alert Timeline Card ──────────────────────────────────────────────────────
class _AlertCard extends StatelessWidget {
  final FloodAlert alert;
  final AnimationController pulseCtrl;
  final VoidCallback onDismiss, onUndo;
  const _AlertCard({
    super.key,
    required this.alert,
    required this.pulseCtrl,
    required this.onDismiss,
    required this.onUndo,
  });

  @override
  Widget build(BuildContext context) {
    final color  = _sevColor(alert.severity);
    final isCrit = alert.severity == 'CRITICAL';
    final date   = DateFormat('dd MMM | HH:mm').format(alert.timestamp.toLocal());

    return Dismissible(
      key: ValueKey(alert.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
            color: _kRed.withOpacity(0.2),
            borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white60),
      ),
      onDismissed: (_) {
        onDismiss();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _kCard,
            content: Text('${alert.city} alert dismissed',
                style: const TextStyle(color: _kText)),
            action: SnackBarAction(
                label: 'UNDO', textColor: _kCyan, onPressed: onUndo),
          ),
        );
      },
      child: AnimatedBuilder(
        animation: pulseCtrl,
        builder: (_, child) {
          final glow = isCrit
              ? color.withOpacity(0.04 + pulseCtrl.value * 0.06)
              : Colors.transparent;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isCrit
                    ? color.withOpacity(0.5 + pulseCtrl.value * 0.3)
                    : color.withOpacity(0.35),
                width: isCrit ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(color: glow, blurRadius: 16, spreadRadius: 1)
              ],
            ),
            child: child,
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 3,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18)),
                gradient: LinearGradient(
                    colors: [color.withOpacity(0.6), color]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 12, height: 12,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: color.withOpacity(0.5),
                                blurRadius: 6)
                          ],
                        ),
                      ),
                      Container(
                          width: 1.5, height: 70,
                          color: color.withOpacity(0.2)),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(alert.title,
                                  style: const TextStyle(
                                      color: _kText,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14)),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border:
                                    Border.all(color: color.withOpacity(0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_sevIcon(alert.severity),
                                      style:
                                          const TextStyle(fontSize: 10)),
                                  const SizedBox(width: 4),
                                  Text(alert.severity,
                                      style: TextStyle(
                                          color: color,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(alert.message,
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 12)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8, runSpacing: 6,
                          children: [
                            _Chip(Icons.location_on_outlined, alert.city),
                            _Chip(Icons.map_outlined, alert.state),
                            _Chip(Icons.schedule_rounded, date),
                            if (alert.currentLevel != null)
                              _Chip(Icons.straighten,
                                  '${alert.currentLevel!.toStringAsFixed(2)} m'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Chip(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: _kSub),
          const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(color: Colors.white60, fontSize: 10.5)),
        ],
      ),
    );
  }
}
