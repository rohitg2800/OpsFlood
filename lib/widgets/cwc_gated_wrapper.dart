// lib/widgets/cwc_gated_wrapper.dart
// OpsFlood — CwcGatedWrapper
// Shows child only when CWC data policy allows it; otherwise shows a locked screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CwcGatedWrapper extends ConsumerWidget {
  const CwcGatedWrapper({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: wire up actual CWC policy provider when available.
    return child;
  }
}
