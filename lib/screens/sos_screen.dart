// lib/screens/sos_screen.dart  — 3-D UI rebuild
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen>
    with SingleTickerProviderStateMixin {
  bool _sent     = false;
  bool _sending  = false;

  late AnimationController _pulse;
  late Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.97, end: 1.03)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _triggerSOS() async {
    HapticFeedback.heavyImpact();
    setState(() => _sending = true);
    await Future.delayed(const Duration(seconds: 2));
    HapticFeedback.heavyImpact();
    setState(() { _sending = false; _sent = true; });
  }

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          Td3AppBar(
            title: 'Emergency SOS',
            subtitle: 'Flood emergency response',
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: t.textPrimary, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          SliverFillRemaining(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Pulsing SOS button
                  if (!_sent) ...[
                    ScaleTransition(
                      scale: _scale,
                      child: GestureDetector(
                        onTap: _sending ? null : _triggerSOS,
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                t.danger.withValues(alpha: 0.30),
                                t.danger.withValues(alpha: 0.08),
                              ],
                            ),
                            border: Border.all(
                                color: t.danger.withValues(alpha: 0.55),
                                width: 2),
                            boxShadow: [
                              BoxShadow(
                                  color: t.danger.withValues(alpha: 0.45),
                                  blurRadius: 40,
                                  spreadRadius: 4),
                              BoxShadow(
                                  color: t.danger.withValues(alpha: 0.25),
                                  blurRadius: 80,
                                  spreadRadius: 10),
                            ],
                          ),
                          child: Center(
                            child: _sending
                                ? CircularProgressIndicator(
                                    color: t.danger, strokeWidth: 3)
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.sos_rounded,
                                          color: t.danger, size: 52),
                                      Text(
                                        'HOLD TO SEND',
                                        style: TextStyle(
                                            color: t.danger,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.2),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Td3Card(
                      accentColor: t.danger,
                      elevation: Td3.elevMid,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Tap the SOS button to alert flood rescue teams and share your location.',
                          style: TextStyle(
                              color: t.textPrimary,
                              fontSize: 13,
                              height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ] else ...[
                    Td3Card(
                      accentColor: t.safe,
                      elevation: Td3.elevHigh,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(Icons.check_circle_rounded,
                                color: t.safe, size: 64),
                            const SizedBox(height: 16),
                            Text(
                              'SOS Sent!',
                              style: TextStyle(
                                  color: t.safe,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Rescue teams have been alerted. Stay calm and stay in place.',
                              style: TextStyle(
                                  color: t.textPrimary,
                                  fontSize: 13,
                                  height: 1.5),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            Td3Button(
                              label: 'Send Another SOS',
                              icon: Icons.sos_rounded,
                              color: t.danger,
                              onTap: () => setState(() => _sent = false),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Emergency contacts
                  const Td3SectionHeader('Emergency Contacts'),
                  const SizedBox(height: 10),
                  _ContactTile(
                      label: 'NDRF Bihar',
                      number: '0612-2506070',
                      color: RiverColors.of(context).danger),
                  const SizedBox(height: 8),
                  _ContactTile(
                      label: 'SDRF Control Room',
                      number: '0612-2217305',
                      color: RiverColors.of(context).warning),
                  const SizedBox(height: 8),
                  _ContactTile(
                      label: 'National Helpline',
                      number: '1078',
                      color: RiverColors.of(context).info),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final String label;
  final String number;
  final Color  color;
  const _ContactTile({
    required this.label,
    required this.number,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Td3Card(
      accentColor: color,
      elevation: Td3.elevLow,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  Icon(Icons.phone_rounded, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: RiverColors.of(context).textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                  Text(number,
                      style: TextStyle(
                          color: color,
                          fontSize: 14,
                          fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            Td3Badge(
                label: 'CALL',
                color: color,
                icon: Icons.call_rounded,
                fontSize: 8),
          ],
        ),
      ),
    );
  }
}
