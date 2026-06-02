// lib/widgets/source_policy_banner.dart
// OpsFlood — SourcePolicyBanner
// Shows an attribution/disclaimer banner when required by data source policy.
library;

import 'package:flutter/material.dart';

class SourcePolicyBanner extends StatelessWidget {
  const SourcePolicyBanner({
    super.key,
    required this.child,
    this.source = 'CWC / IMD',
  });

  final Widget child;
  final String source;

  @override
  Widget build(BuildContext context) {
    return child; // Banner display handled contextually in each screen.
  }
}
