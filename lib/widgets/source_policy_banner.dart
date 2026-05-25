/// Option B — always-visible source policy status strip.
/// Uses Riverpod ConsumerWidget — matches the app's existing pattern.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/source_policy_provider.dart';

class SourcePolicyBanner extends ConsumerWidget {
  const SourcePolicyBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prov = ref.watch(sourcePolicyProvider);

    final Color dotColor;
    final Color labelColor;
    final Color bgColor;
    final String labelText;
    final String? subText;

    switch (prov.status) {
      case PolicyStatus.loading:
        dotColor = const Color(0xFF4a6080);
        labelColor = const Color(0xFF7090a0);
        bgColor = const Color(0xFF1e2a3a);
        labelText = 'Connecting to server\u2026';
        subText = null;
      case PolicyStatus.offline:
        dotColor = const Color(0xFFff4455);
        labelColor = const Color(0xFFff8090);
        bgColor = const Color(0xFF2a1a1a);
        labelText = 'Server unreachable \u2014 offline mode';
        subText = prov.error;
      case PolicyStatus.locked:
        dotColor = const Color(0xFFf59e0b);
        labelColor = const Color(0xFFfcd34d);
        bgColor = const Color(0xFF2a200a);
        labelText = prov.policy.label;
        subText = '${prov.policy.mode}  \u00b7  '
            '${prov.policy.telemetryMode}  \u00b7  CWC Locked';
      case PolicyStatus.live:
        dotColor = const Color(0xFF22c55e);
        labelColor = const Color(0xFF86efac);
        bgColor = const Color(0xFF0d2318);
        labelText = prov.policy.label;
        subText = '${prov.policy.mode}  \u00b7  '
            '${prov.policy.telemetryMode}  \u00b7  CWC Live \u2713';
    }

    return GestureDetector(
      onTap: () => prov.refresh(),
      child: Container(
        color: bgColor,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    labelText,
                    style: TextStyle(
                      color: labelColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subText != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subText,
                      style: const TextStyle(
                        color: Color(0xFF4a6070),
                        fontSize: 10,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const Text('\u21ba',
                style: TextStyle(color: Color(0xFF4a6070), fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
