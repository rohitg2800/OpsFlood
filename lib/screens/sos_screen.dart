// lib/screens/sos_screen.dart
// Bihar Flood Command — SOS / Emergency HUD v3
// Bihar emergency contacts, SDRF, NDRF, BSDMA helplines.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/river_theme.dart';

const _biharEmergency = [
  (
    name: 'BSDMA HELPLINE',
    number: '0612-2215518',
    desc: 'Bihar State Disaster Mgmt Authority',
    type: 'STATE',
    color: 0xFF00E5FF,
  ),
  (
    name: 'SDRF BIHAR',
    number: '0612-2217305',
    desc: 'State Disaster Response Force',
    type: 'SDRF',
    color: 0xFF00E5FF,
  ),
  (
    name: 'NDRF 12th BN PATNA',
    number: '9430060606',
    desc: 'National Disaster Response Force, Bihar',
    type: 'NDRF',
    color: 0xFFFF3B5C,
  ),
  (
    name: 'NDMA HELPLINE',
    number: '1078',
    desc: 'National Disaster Mgmt Authority',
    type: 'NATIONAL',
    color: 0xFFFF8C00,
  ),
  (
    name: 'PATNA DM OFFICE',
    number: '0612-2219081',
    desc: 'District Magistrate, Patna',
    type: 'DISTRICT',
    color: 0xFFFFD200,
  ),
  (
    name: 'MUZAFFARPUR DM',
    number: '0621-2213700',
    desc: 'District Magistrate, Muzaffarpur',
    type: 'DISTRICT',
    color: 0xFFFFD200,
  ),
  (
    name: 'DARBHANGA DM',
    number: '06272-242400',
    desc: 'District Magistrate, Darbhanga',
    type: 'DISTRICT',
    color: 0xFFFFD200,
  ),
  (
    name: 'SUPAUL DM (KOSI BELT)',
    number: '06473-222201',
    desc: 'District Magistrate, Supaul — Kosi Flood Zone',
    type: 'DISTRICT',
    color: 0xFFFF8C00,
  ),
  (
    name: 'POLICE CONTROL ROOM',
    number: '100',
    desc: 'Bihar Police Emergency',
    type: 'POLICE',
    color: 0xFFFF3B5C,
  ),
  (
    name: 'AMBULANCE / MEDICAL',
    number: '108',
    desc: 'Emergency Medical Services',
    type: 'MEDICAL',
    color: 0xFFFF3B5C,
  ),
  (
    name: 'FIRE BRIGADE',
    number: '101',
    desc: 'Fire & Rescue Services',
    type: 'FIRE',
    color: 0xFFFF8C00,
  ),
  (
    name: 'FLOOD RELIEF CONTROL',
    number: '1800-345-6182',
    desc: 'Toll-Free Flood Relief Bihar',
    type: 'RELIEF',
    color: 0xFF00C853,
  ),
];

class SosScreen extends StatefulWidget {
  static const route = '/sos';
  const SosScreen({super.key});
  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Timer _clock;
  String _timeStr = '';
  bool _calling = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
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
    _pulse.dispose();
    _clock.cancel();
    super.dispose();
  }

  Future<void> _call(String number) async {
    setState(() => _calling = true);
    HapticFeedback.heavyImpact();
    final uri = Uri.parse('tel:$number');
    try {
      await launchUrl(uri);
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _calling = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.abyss0,
      body: Column(
        children: [
          _buildHeader(),
          _buildSOSButton(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Text('BIHAR EMERGENCY CONTACTS',
                    style: TextStyle(
                      color: AppPalette.textDim, fontSize: 9,
                      fontWeight: FontWeight.w700, letterSpacing: 2,
                    )),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              itemCount: _biharEmergency.length,
              itemBuilder: (_, i) {
                final e = _biharEmergency[i];
                final col = Color(e.color);
                return _ContactTile(
                  name: e.name,
                  number: e.number,
                  desc: e.desc,
                  type: e.type,
                  color: col,
                  onCall: () => _call(e.number),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() => Container(
    padding: const EdgeInsets.fromLTRB(16, 48, 16, 12),
    decoration: BoxDecoration(
      color: AppPalette.abyss0,
      border: Border(bottom:
          BorderSide(color: AppPalette.critical.withValues(alpha: 0.20))),
    ),
    child: Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border:
                  Border.all(color: AppPalette.critical.withValues(alpha: 0.35)),
              color: AppPalette.abyss2,
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppPalette.critical, size: 14),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('EMERGENCY · BIHAR',
                  style: TextStyle(
                    color: AppPalette.critical, fontSize: 13,
                    fontWeight: FontWeight.w800, letterSpacing: 2,
                  )),
              Text('SYS $_timeStr · BSDMA / SDRF / NDRF',
                  style: const TextStyle(
                    color: AppPalette.textDim, fontSize: 9,
                    letterSpacing: 1,
                  )),
            ],
          ),
        ),
        AnimatedBuilder(
          animation: _pulse,
          builder: (_, __) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppPalette.critical
                  .withValues(alpha: 0.10 + 0.10 * _pulse.value),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                  color: AppPalette.critical.withValues(alpha: 0.40)),
            ),
            child: const Text('EMERGENCY',
                style: TextStyle(
                  color: AppPalette.critical, fontSize: 8.5,
                  fontWeight: FontWeight.w900, letterSpacing: 1.2,
                )),
          ),
        ),
      ],
    ),
  );

  Widget _buildSOSButton() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: GestureDetector(
      onTap: () => _call('112'),
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) => Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: AppPalette.critical
                .withValues(alpha: 0.12 + 0.08 * _pulse.value),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppPalette.critical.withValues(alpha: 0.60),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppPalette.critical
                    .withValues(alpha: 0.15 + 0.15 * _pulse.value),
                blurRadius: 20, spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              const Icon(Icons.sos_rounded,
                  color: AppPalette.critical, size: 40),
              const SizedBox(height: 6),
              const Text('TAP TO CALL 112',
                  style: TextStyle(
                    color: AppPalette.critical,
                    fontSize: 16, fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  )),
              const SizedBox(height: 4),
              const Text('NATIONAL EMERGENCY · BIHAR',
                  style: TextStyle(
                    color: AppPalette.textGrey,
                    fontSize: 9, letterSpacing: 2,
                  )),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ContactTile extends StatelessWidget {
  final String name, number, desc, type;
  final Color color;
  final VoidCallback onCall;

  const _ContactTile({
    required this.name, required this.number,
    required this.desc, required this.type,
    required this.color, required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppPalette.abyss2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
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
                Text(name,
                    style: const TextStyle(
                      color: AppPalette.textWhite,
                      fontSize: 11.5, fontWeight: FontWeight.w800,
                    )),
                const SizedBox(height: 2),
                Text(desc,
                    style: const TextStyle(
                      color: AppPalette.textGrey, fontSize: 9.5)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: color.withValues(alpha: 0.22)),
                      ),
                      child: Text(type,
                          style: TextStyle(
                            color: color, fontSize: 7,
                            fontWeight: FontWeight.w800, letterSpacing: 0.8,
                          )),
                    ),
                    const SizedBox(width: 6),
                    Text(number,
                        style: TextStyle(
                          color: color, fontSize: 11,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        )),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onCall,
            child: Container(
              width: 40, height: 40,
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
      case 'NDRF':     return Icons.local_fire_department_rounded;
      case 'SDRF':     return Icons.shield_rounded;
      case 'STATE':    return Icons.account_balance_rounded;
      case 'NATIONAL': return Icons.flag_rounded;
      case 'DISTRICT': return Icons.location_city_rounded;
      case 'POLICE':   return Icons.local_police_rounded;
      case 'MEDICAL':  return Icons.medical_services_rounded;
      case 'FIRE':     return Icons.fireplace_rounded;
      case 'RELIEF':   return Icons.volunteer_activism_rounded;
      default:         return Icons.phone_rounded;
    }
  }
}
