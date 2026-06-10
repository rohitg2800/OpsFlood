// lib/screens/admin_dashboard_screen.dart
// OpsFlood — Module 11: Admin Dashboard
//
// Gated behind role check: only shown when
// FirebaseAuth.currentUser?.email ends with @opsflood.gov.in
// (replace with your real admin check)
//
// Sections:
//  1. Overview cards  — total stations, active alerts, pending incidents
//  2. Incident moderation queue  — approve / reject community reports
//  3. Station health monitor  — stale / offline stations
//  4. FCM broadcast  — send manual push to all subscribers
//  5. System health  — last CWC fetch time, cache size

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// Stub data models
// ---------------------------------------------------------------------------

class _PendingIncident {
  final String id;
  final String category;
  final String description;
  final String reporter;
  final String submittedAt;
  final int    severity;
  bool approved = false;
  bool rejected = false;
  _PendingIncident({
    required this.id,
    required this.category,
    required this.description,
    required this.reporter,
    required this.submittedAt,
    required this.severity,
  });
}

class _StaleStation {
  final String id;
  final String name;
  final String river;
  final int    minutesSinceUpdate;
  const _StaleStation({
    required this.id,
    required this.name,
    required this.river,
    required this.minutesSinceUpdate,
  });
}

final _pendingIncidents = [
  _PendingIncident(
    id: 'INC001', category: '🌊 Flood',
    description: 'Water entered 15 homes in ward 7, Muzaffarpur.',
    reporter: 'ravi.kumar', submittedAt: '10 Jun 17:42',
    severity: 4,
  ),
  _PendingIncident(
    id: 'INC002', category: '🚨 Embankment Breach',
    description: 'Small breach visible near Kosi embankment km 42.',
    reporter: 'sita.devi', submittedAt: '10 Jun 18:01',
    severity: 5,
  ),
  _PendingIncident(
    id: 'INC003', category: '🚧 Road Blocked',
    description: 'NH-77 submerged near Darbhanga, 30 cm water.',
    reporter: 'mohan.lal', submittedAt: '10 Jun 18:15',
    severity: 3,
  ),
];

const _staleStations = [
  _StaleStation(id: 'ST023', name: 'Dharhara', river: 'Kosi',       minutesSinceUpdate: 92),
  _StaleStation(id: 'ST041', name: 'Rosera',   river: 'Bagmati',    minutesSinceUpdate: 45),
  _StaleStation(id: 'ST057', name: 'Sitamarhi', river: 'Lalbakaiya', minutesSinceUpdate: 130),
];

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState
    extends ConsumerState<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _broadcastCtrl = TextEditingController();
  bool  _broadcasting  = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _broadcastCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('🛡️ Admin Dashboard'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor:   Colors.white,
          indicatorColor: Colors.amberAccent,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Incidents'),
            Tab(text: 'Stations'),
            Tab(text: 'Broadcast'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildOverview(theme),
          _buildIncidents(theme),
          _buildStations(theme),
          _buildBroadcast(theme),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 1: Overview
  // ---------------------------------------------------------------------------

  Widget _buildOverview(ThemeData theme) {
    const cards = [
      _StatCard(label: 'Total Stations', value: '124',  icon: Icons.sensors,              color: Color(0xFF1565C0)),
      _StatCard(label: 'Active Alerts',  value: '17',   icon: Icons.warning_amber_rounded, color: Color(0xFFE65100)),
      _StatCard(label: 'Pending Reports',value: '3',    icon: Icons.pending_actions,        color: Color(0xFF6A1B9A)),
      _StatCard(label: 'Stale Stations', value: '3',    icon: Icons.signal_wifi_off,        color: Color(0xFFB71C1C)),
      _StatCard(label: 'FCM Subscribers',value: '8,241',icon: Icons.notifications_active,  color: Color(0xFF00695C)),
      _StatCard(label: 'Last CWC Fetch', value: '2 min',icon: Icons.cloud_sync,             color: Color(0xFF37474F)),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('System Overview',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap:     true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing:  12,
            childAspectRatio: 1.6,
            children: cards,
          ),
          const SizedBox(height: 24),
          // Recent activity log (stub)
          Text('Recent Activity',
              style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final log in [
            '18:15  INC003 submitted by mohan.lal',
            '18:01  INC002 submitted by sita.devi',
            '17:55  CWC fetch completed (124 stations)',
            '17:42  INC001 submitted by ravi.kumar',
            '17:30  FCM broadcast sent to floods-all',
          ])
            ListTile(
              dense: true,
              leading: const Icon(Icons.circle, size: 8,
                  color: Color(0xFF4CAF50)),
              title: Text(log,
                  style: const TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 2: Incident moderation
  // ---------------------------------------------------------------------------

  Widget _buildIncidents(ThemeData theme) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _pendingIncidents.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final inc = _pendingIncidents[i];
        return Card(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Chip(
                      label:     Text(inc.category,
                          style: const TextStyle(fontSize: 11)),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ),
                    const Spacer(),
                    Text('Severity ${inc.severity}/5',
                        style: TextStyle(
                            fontSize: 11,
                            color: inc.severity >= 4
                                ? const Color(0xFFFF1744)
                                : const Color(0xFFFFB300))),
                    const SizedBox(width: 8),
                    Text(inc.submittedAt,
                        style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(inc.description,
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 4),
                Text('Reporter: ${inc.reporter}',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon:  const Icon(Icons.close,
                            color: Color(0xFFFF1744)),
                        label: const Text('Reject',
                            style: TextStyle(
                                color: Color(0xFFFF1744))),
                        onPressed: inc.rejected
                            ? null
                            : () => setState(
                                () => inc.rejected = true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        icon:  const Icon(Icons.check),
                        label: const Text('Approve'),
                        style: FilledButton.styleFrom(
                            backgroundColor:
                                const Color(0xFF4CAF50)),
                        onPressed: inc.approved
                            ? null
                            : () => setState(
                                () => inc.approved = true),
                      ),
                    ),
                  ],
                ),
                if (inc.approved)
                  const Text('✅ Approved',
                      style: TextStyle(
                          color: Color(0xFF4CAF50),
                          fontSize: 12)),
                if (inc.rejected)
                  const Text('❌ Rejected',
                      style: TextStyle(
                          color: Color(0xFFFF1744),
                          fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 3: Stale stations
  // ---------------------------------------------------------------------------

  Widget _buildStations(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('Stale / Offline Stations',
            style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        ..._staleStations.map((s) => ListTile(
              tileColor: const Color(0xFFFFF8E1),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              leading: const Icon(Icons.signal_wifi_off,
                  color: Color(0xFFFF6D00)),
              title: Text('${s.name} (${s.river})'),
              subtitle: Text(
                  'No update for ${s.minutesSinceUpdate} min'),
              trailing: TextButton(
                child: const Text('Ping'),
                onPressed: () =>
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(
                      content: Text('Ping sent to ${s.id}'),
                    )),
              ),
            )),
        const Divider(height: 32),
        Text('All Stations Health (124)',
            style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        const LinearProgressIndicator(
          value: 0.976, // 121/124 online
          minHeight: 8,
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
        const SizedBox(height: 4),
        const Text('121 online  •  3 stale  •  0 offline',
            style: TextStyle(fontSize: 12)),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 4: FCM Broadcast
  // ---------------------------------------------------------------------------

  Widget _buildBroadcast(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Send Broadcast Notification',
              style: theme.textTheme.titleSmall),
          const SizedBox(height: 12),
          TextField(
            controller: _broadcastCtrl,
            maxLines:   4,
            maxLength:  200,
            decoration: const InputDecoration(
              labelText: 'Message',
              hintText:  'e.g. NDRF teams deployed in Darbhanga…',
              border:    OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          const Text('Target topic:  floods-all',
              style: TextStyle(fontSize: 12,
                  color: Colors.grey)),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: _broadcasting
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white))
                : const Icon(Icons.send),
            label: Text(_broadcasting
                ? 'Sending…'
                : 'Broadcast to All Users'),
            style: FilledButton.styleFrom(
                backgroundColor:
                    const Color(0xFFB71C1C)),
            onPressed: _broadcasting
                ? null
                : () async {
                    if (_broadcastCtrl.text.trim().isEmpty) {
                      return;
                    }
                    setState(() => _broadcasting = true);
                    // In production:
                    // await ref.read(fcmBroadcastServiceProvider)
                    //   .broadcast(_broadcastCtrl.text);
                    await Future.delayed(
                        const Duration(seconds: 2));
                    setState(() {
                      _broadcasting = false;
                      _broadcastCtrl.clear();
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(
                        content: Text(
                            '📣 Broadcast sent to floods-all'),
                        backgroundColor: Color(0xFF4CAF50),
                      ));
                    }
                  },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stat Card helper widget
// ---------------------------------------------------------------------------

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color  color;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Card(
        color: color.withOpacity(.12),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(value,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color)),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: color.withOpacity(.8))),
            ],
          ),
        ),
      );
}
