// lib/widgets/alert_badge.dart
//
// Reusable badge widget — shows unread alert count on nav bar icons.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/alerts_provider.dart';

class AlertBadge extends StatelessWidget {
  final Widget child;
  const AlertBadge({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final count = context.watch<AlertsProvider>().badgeCount;
    if (count == 0) return child;
    return Badge(
      label: Text(count > 99 ? '99+' : '$count'),
      backgroundColor: Colors.red,
      child: child,
    );
  }
}
