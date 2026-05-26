/// Option A — shown when allow_live_cwc_in_app = false.
/// Uses Riverpod ConsumerWidget to match the app's existing pattern.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/source_policy_provider.dart';
import 'source_policy_banner.dart';

class PolicyLockedScreen extends ConsumerWidget {
  const PolicyLockedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prov = ref.watch(sourcePolicyProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF080c10),
      body: SafeArea(
        child: Column(
          children: [
            const SourcePolicyBanner(),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1a0a00),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0x40f59e0b), width: 1),
                        ),
                        child: const Center(
                          child: Text('\uD83D\uDD12',
                              style: TextStyle(fontSize: 32)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Live CWC Telemetry Locked',
                        style: TextStyle(
                          color: Color(0xFFfcd34d),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        prov.policy.label,
                        style: const TextStyle(
                          color: Color(0xFFf59e0b),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (prov.policy.description.isNotEmpty)
                        Text(
                          prov.policy.description,
                          style: const TextStyle(
                            color: Color(0xFF7090a0),
                            fontSize: 13,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      const SizedBox(height: 12),
                      const Text(
                        'The current source policy does not permit\nlive in-app CWC scraping.\nTap below once the server policy changes.',
                        style: TextStyle(
                          color: Color(0xFF4a6070),
                          fontSize: 12,
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      GestureDetector(
                        onTap: () => prov.refresh(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1e2a1a),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: const Color(0x4022c55e), width: 1),
                          ),
                          child: const Text(
                            'Re-check Policy',
                            style: TextStyle(
                              color: Color(0xFF86efac),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
