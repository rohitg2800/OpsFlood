// lib/screens/sos_screen.dart
// Bihar Flood Command — SOS / Emergency HUD v6
// WIRED: can show all Bihar contacts or station-scoped contacts.
library;

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/emergency_contact_service.dart';
import '../theme/river_theme.dart';

String _typeLabel(String category) {
  final c = category.toLowerCase();
  if (c.contains('ndrf')) return 'NDRF';
  if (c.contains('sdrf')) return 'SDRF';
  if (c.contains('ndma')) return 'NATIONAL';
  if (c.contains('cwc')) return 'CWC';
  if (c.contains('district') || c.contains('dm')) return 'DISTRICT';
  if (c.contains('barrage')) return 'BARRAGE';
  if (c.contains('police')) return 'POLICE';
  if (c.contains('medic')) return 'MEDICAL';
  if (c.contains('fire')) return 'FIRE';
  if (c.contains('relief')) return 'RELIEF';
  if (c.contains('state')) return 'STATE';
  return 'SOS';
}

Color _accentColor(String category) {
  final c = category.toLowerCase();
  if (c.contains('ndrf')) return const Color(0xFFFF3B5C);
  if (c.contains('ndma')) return const Color(0xFFFF8C00);
  if (c.contains('sdrf')) return const Color(0xFF00E5FF);
  if (c.contains('cwc')) return const Color(0xFF00C853);
  if (c.contains('district') || c.contains('dm')) return const Color(0xFFFFD200);
  if (c.contains('barrage')) return const Color(0xFFFF8C00);
  if (c.contains('police')) return const Color(0xFFFF3B5C);
  if (c.contains('medic')) return const Color(0xFFFF3B5C);
  if (c.contains('fire')) return const Color(0xFFFF8C00);
  return const Color(0xFF00C853);
}

class _SosClockWidget extends StatefulWidget {
  const _SosClockWidget();
  @override
  State<_SosClockWidget> createState() => _SosClockWidgetState();
}

class _SosClockWidgetState extends State<_SosClockWidget> {
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
      final now = DateTime.now();
      _timeStr =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Text(
      'SYS $_timeStr · BSDMA / SDRF / NDRF',
      style: TextStyle(
        color: t.textSecondary.withValues(alpha: 0.6),
        fontSize: 10,
        letterSpacing: 1,
      ),
    );
  }
}

class SosScreen extends StatefulWidget {
  static const route = '/sos';
  const SosScreen({super.key});
  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  final _svc = EmergencyContactService();

  Future<List<EmergencyContact>>? _contactsFuture;
  String? _activeFilter;
  String? _stationName;
  String? _districtName;
  bool _initializedArgs = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initializedArgs) return;
    _initializedArgs = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    String? stationName;
    if (args is Map) {
      final raw = args['stationName'];
      if (raw is String && raw.trim().isNotEmpty) {
        stationName = raw.trim();
      }
    }

    _stationName = stationName;
    _districtName = stationName == null ? null : _svc.districtForStation(stationName);
    _contactsFuture = stationName == null
        ? _svc.getAllContacts()
        : _svc.getContactsForStation(stationName);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _callDirect(String number) async {
    HapticFeedback.heavyImpact();
    final uri = Uri.parse('tel:$number');
    try {
      await launchUrl(uri);
    } catch (_) {}
  }

  Future<void> _callWithConfirm({
    required String name,
    required String number,
    required Color accentColor,
  }) async {
    final t = RiverColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.70),
      builder: (ctx) => AlertDialog(
        backgroundColor: t.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: accentColor.withValues(alpha: 0.30)),
        ),
        title: Row(
          children: [
            Icon(Icons.call_rounded, color: accentColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: TextStyle(
              color: t.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
            children: [
              const TextSpan(text: 'Call '),
              TextSpan(
                text: number,
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const TextSpan(text: '?'),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: t.textSecondary,
              minimumSize: const Size(72, 40),
            ),
            child: const Text('Cancel', style: TextStyle(fontSize: 13)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor.withValues(alpha: 0.15),
              foregroundColor: accentColor,
              side: BorderSide(color: accentColor.withValues(alpha: 0.45)),
              elevation: 0,
              minimumSize: const Size(88, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.call_rounded, size: 15),
            label: const Text(
              'CALL',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await _callDirect(number);
  }

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    final future = _contactsFuture;

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: Column(
        children: [
          _buildHeader(t),
          _buildSOSButton(t),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: Row(
              children: [
                Text(
                  _districtName != null
                      ? 'EMERGENCY CONTACTS · ${_districtName!.toUpperCase()}'
                      : 'BIHAR EMERGENCY CONTACTS',
                  style: TextStyle(
                    color: t.textSecondary.withValues(alpha: 0.6),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: future == null
                ? const SizedBox.shrink()
                : FutureBuilder<List<EmergencyContact>>(
                    future: future,
                    builder: (ctx, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppPalette.critical,
                          ),
                        );
                      }

                      final all = snap.data ?? [];
                      if (all.isEmpty) {
                        return Center(
                          child: Text(
                            'No contacts available',
                            style: TextStyle(color: t.textSecondary, fontSize: 12),
                          ),
                        );
                      }

                      final categories = all
                          .map((c) => _typeLabel(c.category))
                          .toSet()
                          .toList()
                        ..sort();

                      final sorted = [...all]..sort((a, b) {
                          if (a.isSOS && !b.isSOS) return -1;
                          if (!a.isSOS && b.isSOS) return 1;
                          final aNull = a.district == null ? 0 : 1;
                          final bNull = b.district == null ? 0 : 1;
                          if (aNull != bNull) return aNull - bNull;
                          return a.category.compareTo(b.category);
                        });

                      final filtered = _activeFilter == null
                          ? sorted
                          : sorted
                              .where((c) => _typeLabel(c.category) == _activeFilter)
                              .toList();

                      return Column(
                        children: [
                          SizedBox(
                            height: 34,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              children: [
                                _FilterChip(
                                  label: 'ALL',
                                  active: _activeFilter == null,
                                  color: AppPalette.critical,
                                  t: t,
                                  onTap: () => setState(() => _activeFilter = null),
                                ),
                                ...categories.map(
                                  (cat) => _FilterChip(
                                    label: cat,
                                    active: _activeFilter == cat,
                                    color: _accentColor(cat),
                                    t: t,
                                    onTap: () => setState(() => _activeFilter = cat),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_stationName != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _districtName != null
                                      ? 'Scoped from station: $_stationName → $_districtName'
                                      : 'Scoped from station: $_stationName',
                                  style: TextStyle(
                                    color: t.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                              itemCount: filtered.length,
                              itemBuilder: (_, i) {
                                final c = filtered[i];
                                final col = _accentColor(c.category);
                                final type = _typeLabel(c.category);
                                return _ContactTile(
                                  name: c.name,
                                  number: c.phone,
                                  desc: c.description ?? c.category,
                                  type: type,
                                  color: col,
                                  isSOS: c.isSOS,
                                  district: c.district,
                                  t: t,
                                  onCall: c.phone == '112'
                                      ? () => _callDirect(c.phone)
                                      : () => _callWithConfirm(
                                            name: c.name,
                                            number: c.phone,
                                            accentColor: col,
                                          ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(RiverColors t) => Container(
        padding: const EdgeInsets.fromLTRB(16, 48, 16, 12),
        decoration: BoxDecoration(
          color: t.scaffoldBg,
          border: Border(
            bottom: BorderSide(color: AppPalette.critical.withValues(alpha: 0.20)),
          ),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.maybePop(context),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppPalette.critical.withValues(alpha: 0.35)),
                  color: t.cardBg,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppPalette.critical,
                  size: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _districtName != null ? 'EMERGENCY · $_districtName' : 'EMERGENCY · BIHAR',
                    style: const TextStyle(
                      color: AppPalette.critical,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  const _SosClockWidget(),
                ],
              ),
            ),
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppPalette.critical.withValues(alpha: 0.10 + 0.10 * _pulse.value),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppPalette.critical.withValues(alpha: 0.40)),
                ),
                child: const Text(
                  'EMERGENCY',
                  style: TextStyle(
                    color: AppPalette.critical,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildSOSButton(RiverColors t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: GestureDetector(
          onTap: () => _callDirect('112'),
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: AppPalette.critical.withValues(alpha: 0.12 + 0.08 * _pulse.value),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppPalette.critical.withValues(alpha: 0.60),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppPalette.critical.withValues(alpha: 0.15 + 0.15 * _pulse.value),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.sos_rounded, color: AppPalette.critical, size: 40),
                  const SizedBox(height: 6),
                  const Text(
                    'TAP TO CALL 112',
                    style: TextStyle(
                      color: AppPalette.critical,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _districtName != null
                        ? 'NATIONAL EMERGENCY · $_districtName'
                        : 'NATIONAL EMERGENCY · BIHAR',
                    style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 10,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final RiverColors t;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.active,
    required this.color,
    required this.t,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.18) : t.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? color.withValues(alpha: 0.55) : color.withValues(alpha: 0.20),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? color : t.textSecondary,
              fontSize: 10,
              fontWeight: active ? FontWeight.w800 : FontWeight.w500,
              letterSpacing: 0.8,
            ),
          ),
        ),
      );
}

class _ContactTile extends StatelessWidget {
  final String name, number, desc, type;
  final Color color;
  final bool isSOS;
  final String? district;
  final RiverColors t;
  final VoidCallback onCall;

  const _ContactTile({
    required this.name,
    required this.number,
    required this.desc,
    required this.type,
    required this.color,
    required this.isSOS,
    this.district,
    required this.t,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.10),
              border: Border.all(color: color.withValues(alpha: 0.28)),
            ),
            child: Icon(_iconFor(type), color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: TextStyle(
                          color: t.textPrimary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSOS) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppPalette.critical.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                            color: AppPalette.critical.withValues(alpha: 0.30),
                          ),
                        ),
                        child: const Text(
                          'SOS',
                          style: TextStyle(
                            color: AppPalette.critical,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(color: t.textSecondary, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: color.withValues(alpha: 0.22)),
                      ),
                      child: Text(
                        type,
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    if (district != null) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          district!,
                          style: TextStyle(
                            color: color.withValues(alpha: 0.75),
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        number,
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onCall,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.12),
                border: Border.all(color: color.withValues(alpha: 0.35)),
              ),
              child: Icon(Icons.call_rounded, color: color, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String t) {
    switch (t) {
      case 'NDRF':
        return Icons.local_fire_department_rounded;
      case 'SDRF':
        return Icons.shield_rounded;
      case 'STATE':
        return Icons.account_balance_rounded;
      case 'NATIONAL':
        return Icons.flag_rounded;
      case 'DISTRICT':
        return Icons.location_city_rounded;
      case 'BARRAGE':
        return Icons.water_damage_rounded;
      case 'CWC':
        return Icons.water_rounded;
      case 'POLICE':
        return Icons.local_police_rounded;
      case 'MEDICAL':
        return Icons.medical_services_rounded;
      case 'FIRE':
        return Icons.fireplace_rounded;
      case 'RELIEF':
        return Icons.volunteer_activism_rounded;
      default:
        return Icons.phone_rounded;
    }
  }
}
