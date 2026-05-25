/// Option A helper — wrap any live-telemetry widget tree with this.
/// Shows PolicyLockedScreen when allow_live_cwc_in_app = false,
/// shows [child] when live CWC is permitted.
///
/// Usage:
///   CwcGatedWrapper(
///     child: MyLiveTelemetryWidget(),
///   )
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/source_policy_provider.dart';
import 'policy_locked_screen.dart';
import 'source_policy_banner.dart';

class CwcGatedWrapper extends StatelessWidget {
  final Widget child;

  const CwcGatedWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<SourcePolicyProvider>(
      builder: (context, prov, _) {
        // Still loading — show spinner with banner
        if (prov.status == PolicyStatus.loading) {
          return Scaffold(
            backgroundColor: const Color(0xFF060a0e),
            body: SafeArea(
              child: Column(
                children: [
                  const SourcePolicyBanner(),
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF22c55e),
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Option A gate: not allowed → lock screen
        if (!prov.allowLiveCwc) {
          return const PolicyLockedScreen();
        }

        // Live CWC enabled — render the real widget tree
        return child;
      },
    );
  }
}
