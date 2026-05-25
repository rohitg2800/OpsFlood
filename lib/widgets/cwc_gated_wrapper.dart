/// Option A — wrap any live-CWC widget with this.
/// Uses Riverpod ConsumerWidget to match the app's existing pattern.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/source_policy_provider.dart';
import 'policy_locked_screen.dart';
import 'source_policy_banner.dart';

class CwcGatedWrapper extends ConsumerWidget {
  final Widget child;
  const CwcGatedWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(policyStatusProvider);
    final allowed = ref.watch(allowLiveCwcProvider);

    if (status == PolicyStatus.loading) {
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

    if (!allowed) return const PolicyLockedScreen();

    return child;
  }
}
