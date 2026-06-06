// lib/screens/sos_screen.dart
// OpsFlood — SOS Emergency Screen
// One-tap calling for NDRF, Bihar Flood Control, district DMs, hospitals.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/river_theme.dart';
import '../data/emergency_contacts.dart';

class SosScreen extends StatelessWidget {
  const SosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppPalette.abyss0,
        body: SafeArea(
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                decoration: BoxDecoration(
                  color: AppPalette.abyss0,
                  border: Border(
                    bottom: BorderSide(
                        color: AppPalette.critical.withValues(alpha: 0.25),
                        width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: AppPalette.critical.withValues(alpha: 0.12),
                        border: Border.all(
                            color: AppPalette.critical.withValues(alpha: 0.35),
                            width: 1.5),
                      ),
                      child: const Icon(Icons.sos_rounded,
                          color: AppPalette.critical, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (b) => const LinearGradient(
                            colors: [Color(0xFFFF5252), Color(0xFFFF1744)],
                          ).createShader(b),
                          child: const Text('EMERGENCY SOS',
                              style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w900,
                                color: Colors.white, letterSpacing: -0.5,
                              )),
                        ),
                        Text('Bihar Flood Emergency Contacts',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppPalette.textGrey.withValues(alpha: 0.65),
                            )),
                      ],
                    ),
                  ],
                ),
              ),

              // ── EMERGENCY BANNER ─────────────────────────────────────
              Container(
                margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppPalette.critical.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppPalette.critical.withValues(alpha: 0.30)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: AppPalette.critical, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'During a flood emergency, move to higher ground '  
                        'immediately. Call NDRF or State Helpline first.',
                        style: TextStyle(
                          color: AppPalette.critical.withValues(alpha: 0.90),
                          fontSize: 11, fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Contact List ─────────────────────────────────────────
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _SectionHeader(
                        label: 'NATIONAL EMERGENCY', icon: Icons.flag_rounded),
                    const SizedBox(height: 8),
                    ...kNationalContacts.map((c) => _ContactCard(contact: c)),

                    const SizedBox(height: 18),
                    _SectionHeader(
                        label: 'BIHAR STATE', icon: Icons.location_city_rounded),
                    const SizedBox(height: 8),
                    ...kStateContacts.map((c) => _ContactCard(contact: c)),

                    const SizedBox(height: 18),
                    _SectionHeader(
                        label: 'DISTRICT CONTROL ROOMS',
                        icon: Icons.apartment_rounded),
                    const SizedBox(height: 8),
                    ...kDistrictContacts.map(
                        (c) => _ContactCard(contact: c, compact: true)),

                    const SizedBox(height: 18),
                    _SectionHeader(
                        label: 'MEDICAL & NGO',
                        icon: Icons.local_hospital_rounded),
                    const SizedBox(height: 8),
                    ...kMedicalContacts.map((c) => _ContactCard(contact: c)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionHeader({required this.label, required this.icon});
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 13, color: AppPalette.textDim),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                color: AppPalette.textDim, fontSize: 9,
                fontWeight: FontWeight.w800, letterSpacing: 1.0,
              )),
        ],
      );
}

class _ContactCard extends StatelessWidget {
  final EmergencyContact contact;
  final bool compact;
  const _ContactCard({required this.contact, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final col = _colorFor(contact.type);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.symmetric(
          horizontal: 14, vertical: compact ? 10 : 14),
      decoration: BoxDecoration(
        color: AppPalette.abyss2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: col.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 36 : 44, height: compact ? 36 : 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: col.withValues(alpha: 0.10),
              border: Border.all(color: col.withValues(alpha: 0.25)),
            ),
            child: Icon(_iconFor(contact.type), color: col,
                size: compact ? 16 : 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contact.name,
                    style: const TextStyle(
                      color: AppPalette.textWhite, fontSize: 13,
                      fontWeight: FontWeight.w800,
                    )),
                if (contact.subtitle != null)
                  Text(contact.subtitle!,
                      style: const TextStyle(
                        color: AppPalette.textGrey, fontSize: 10)),
                const SizedBox(height: 2),
                Text(contact.number,
                    style: TextStyle(
                      color: col, fontSize: 11,
                      fontWeight: FontWeight.w700, letterSpacing: 0.3,
                    )),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              HapticFeedback.mediumImpact();
              final uri = Uri.parse('tel:${contact.number}');
              if (await canLaunchUrl(uri)) launchUrl(uri);
            },
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: col.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: col.withValues(alpha: 0.30)),
              ),
              child: Icon(Icons.call_rounded, color: col, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Color _colorFor(ContactType t) => switch (t) {
    ContactType.national  => AppPalette.critical,
    ContactType.state     => AppPalette.danger,
    ContactType.district  => AppPalette.amber,
    ContactType.medical   => const Color(0xFF4CAF50),
    ContactType.ngo       => AppPalette.cyan,
  };

  IconData _iconFor(ContactType t) => switch (t) {
    ContactType.national  => Icons.security_rounded,
    ContactType.state     => Icons.account_balance_rounded,
    ContactType.district  => Icons.location_city_rounded,
    ContactType.medical   => Icons.local_hospital_rounded,
    ContactType.ngo       => Icons.volunteer_activism_rounded,
  };
}
