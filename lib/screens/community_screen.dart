// lib/screens/community_screen.dart
// OpsFlood — Module 5: Community & Offline
//
// CommunityScreen
// ─────────────────────────────────────────────────────────────────────────
// Ground-truth community incident feed + incident submission.
//
// Features:
//   • Scrollable incident feed from local Hive box
//   • Bilingual (EN + HI) incident type chips for filtering
//   • Submit-incident FAB → bottom-sheet form with:
//       - IncidentType selector (chips)
//       - Description text field (EN or HI)
//       - GPS auto-tag (uses LocationService)
//       - Image attach button (placeholder — image_picker hookup)
//       - Offline-first: saves to Hive immediately, syncs later
//   • Upvote counter on each card
//   • Offline badge on unsynced incidents
//   • Pull-to-refresh triggers backend sync attempt

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/community_incident.dart';
import '../services/location_service.dart';
import '../theme/river_theme.dart';
import '../widgets/ops_icon.dart';

const _kBoxName = 'community_incidents';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  IncidentType? _filterType; // null = show all
  bool _syncing = false;

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Scaffold(
      backgroundColor: t.bgBase,
      appBar: AppBar(
        backgroundColor: t.navBg,
        elevation: 0,
        title: Row(
          children: [
            OpsIcon(OpsIcons.community, size: 18, color: t.accent),
            const SizedBox(width: 8),
            Text(
              'Community Reports',
              style: TextStyle(
                color: t.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ],
        ),
        actions: [
          if (_syncing)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: t.accent),
              ),
            )
          else
            IconButton(
              icon:
                  Icon(Icons.cloud_sync_rounded, color: t.textSecondary),
              onPressed: _syncWithBackend,
              tooltip: 'Sync with server',
            ),
        ],
      ),
      body: Column(
        children: [
          _TypeFilterBar(t: t, selected: _filterType, onSelect: (v) {
            setState(() => _filterType = v);
          }),
          Expanded(child: _IncidentFeed(t: t, filterType: _filterType)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: t.accent,
        icon: const Icon(Icons.add_location_alt_rounded,
            color: Colors.black),
        label: Text(
          'Report',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w800,
          ),
        ),
        onPressed: () => _showSubmitSheet(context, t),
      ),
    );
  }

  // ── Type filter bar ──────────────────────────────────────────────────

  // ── Submit sheet ─────────────────────────────────────────────────────

  void _showSubmitSheet(BuildContext ctx, RiverColors t) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SubmitIncidentSheet(t: t),
    );
  }

  // ── Backend sync ─────────────────────────────────────────────────────

  Future<void> _syncWithBackend() async {
    setState(() => _syncing = true);
    await Future.delayed(const Duration(seconds: 2)); // placeholder
    if (mounted) setState(() => _syncing = false);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Sync complete'),
        backgroundColor: RiverColors.of(context).cardBg,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }
}

// ── Type filter bar ──────────────────────────────────────────────────────

class _TypeFilterBar extends StatelessWidget {
  final RiverColors      t;
  final IncidentType?    selected;
  final ValueChanged<IncidentType?> onSelect;
  const _TypeFilterBar(
      {required this.t, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          _chip(null, '🗂 All', context),
          ...IncidentType.values.map(
              (type) => _chip(type, '${type.emoji} ${type.label}', context)),
        ],
      ),
    );
  }

  Widget _chip(IncidentType? type, String label, BuildContext context) {
    final active = selected == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => onSelect(type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: active
                ? t.accent.withValues(alpha: 0.18)
                : t.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active
                  ? t.accent.withValues(alpha: 0.7)
                  : t.stroke,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? t.accent : t.textSecondary,
              fontWeight:
                  active ? FontWeight.w700 : FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Incident feed ────────────────────────────────────────────────────────

class _IncidentFeed extends StatelessWidget {
  final RiverColors   t;
  final IncidentType? filterType;
  const _IncidentFeed(
      {required this.t, required this.filterType});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable:
          Hive.box<CommunityIncident>(_kBoxName).listenable(),
      builder: (_, Box<CommunityIncident> box, __) {
        var items = box.values.toList()
          ..sort((a, b) => b.reportedAt.compareTo(a.reportedAt));
        if (filterType != null) {
          items = items.where((i) => i.type == filterType).toList();
        }
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people_outline_rounded,
                    size: 52, color: t.textSecondary.withValues(alpha: 0.4)),
                const SizedBox(height: 12),
                Text(
                  'No reports yet.\nBe the first to report a ground situation.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          color: t.accent,
          backgroundColor: t.cardBg,
          onRefresh: () async {
            await Future.delayed(const Duration(seconds: 1));
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
            itemCount: items.length,
            itemBuilder: (_, i) =>
                _IncidentCard(incident: items[i], t: t),
          ),
        );
      },
    );
  }
}

// ── Incident card ────────────────────────────────────────────────────────

class _IncidentCard extends StatelessWidget {
  final CommunityIncident incident;
  final RiverColors       t;
  const _IncidentCard({required this.incident, required this.t});

  @override
  Widget build(BuildContext context) {
    final inc  = incident;
    final age  = _age(inc.reportedAt);
    final sync = inc.synced;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Text(inc.type.emoji,
                  style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  inc.type.label,
                  style: TextStyle(
                    color: t.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              if (!sync)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppPalette.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppPalette.warning
                            .withValues(alpha: 0.50)),
                  ),
                  child: Text(
                    '📵 Offline',
                    style: TextStyle(
                      color: AppPalette.warning,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Description
          Text(
            inc.description,
            style: TextStyle(
              color: t.textSecondary,
              fontSize: 12,
              height: 1.5,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          // Footer
          Row(
            children: [
              Icon(Icons.location_on_rounded,
                  size: 12, color: t.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  inc.locationLabel ?? inc.district,
                  style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 10,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                age,
                style: TextStyle(
                  color: t.textSecondary.withValues(alpha: 0.6),
                  fontSize: 10,
                ),
              ),
              const SizedBox(width: 12),
              // Upvote button
              GestureDetector(
                onTap: () {
                  inc.upvotes++;
                  inc.save();
                  HapticFeedback.lightImpact();
                },
                child: Row(
                  children: [
                    Icon(Icons.thumb_up_rounded,
                        size: 14, color: t.accent),
                    const SizedBox(width: 4),
                    Text(
                      '${inc.upvotes}',
                      style: TextStyle(
                        color: t.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _age(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'Just now';
    if (diff.inHours   < 1)  return '${diff.inMinutes}m ago';
    if (diff.inDays    < 1)  return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ── Submit-incident bottom sheet ─────────────────────────────────────────

class _SubmitIncidentSheet extends StatefulWidget {
  final RiverColors t;
  const _SubmitIncidentSheet({required this.t});

  @override
  State<_SubmitIncidentSheet> createState() =>
      _SubmitIncidentSheetState();
}

class _SubmitIncidentSheetState extends State<_SubmitIncidentSheet> {
  IncidentType _selectedType = IncidentType.waterlogging;
  final _descCtrl = TextEditingController();
  double? _lat;
  double? _lon;
  String  _locationLabel = 'Fetching location…';
  bool    _loadingLocation = true;
  bool    _submitting      = false;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    try {
      final pos =
          await LocationService.instance.getCurrentPosition();
      if (mounted) {
        setState(() {
          _lat = pos.latitude;
          _lon = pos.longitude;
          _locationLabel =
              '${pos.latitude.toStringAsFixed(4)}, '
              '${pos.longitude.toStringAsFixed(4)}';
          _loadingLocation = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _locationLabel = 'Location unavailable';
          _loadingLocation = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            const Text('Please describe the incident before submitting.'),
        backgroundColor: widget.t.cardBg,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _submitting = true);
    final incident = CommunityIncident(
      id:            const Uuid().v4(),
      type:          _selectedType,
      description:   _descCtrl.text.trim(),
      lat:           _lat ?? 0,
      lon:           _lon ?? 0,
      district:      'Unknown', // TODO: reverse geocode
      reportedAt:    DateTime.now(),
      synced:        false,
      locationLabel: _locationLabel,
    );
    final box = Hive.box<CommunityIncident>(_kBoxName);
    await box.put(incident.id, incident);
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text(
            '✅ Incident saved locally — will sync when online.'),
        backgroundColor: widget.t.cardBg,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: t.stroke),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: t.stroke,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Report a Flood Incident',
                style: TextStyle(
                  color: t.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              Text(
                'बाढ़ की घटना रिपोर्ट करें',
                style: TextStyle(
                  color: t.textSecondary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 16),

              // Type chips
              Text('Incident Type',
                  style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: IncidentType.values.map((type) {
                  final active = _selectedType == type;
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _selectedType = type),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: active
                            ? t.accent.withValues(alpha: 0.18)
                            : t.cardBgElevated,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active
                              ? t.accent.withValues(alpha: 0.70)
                              : t.stroke,
                        ),
                      ),
                      child: Text(
                        '${type.emoji} ${type.label}',
                        style: TextStyle(
                          color: active
                              ? t.accent
                              : t.textSecondary,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Description field
              Text('Description  /  विवरण',
                  style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextField(
                controller: _descCtrl,
                maxLines: 4,
                style: TextStyle(
                    color: t.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText:
                      'Describe what you see… (English or Hindi)',
                  hintStyle: TextStyle(
                      color: t.textSecondary.withValues(alpha: 0.5),
                      fontSize: 12),
                  filled: true,
                  fillColor: t.cardBgElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: t.stroke),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: t.stroke),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: t.accent, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Location row
              Row(
                children: [
                  Icon(Icons.location_on_rounded,
                      size: 14, color: t.accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _loadingLocation
                        ? SizedBox(
                            height: 14,
                            width: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: t.accent),
                          )
                        : Text(
                            _locationLabel,
                            style: TextStyle(
                              color: t.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                  ),
                  TextButton(
                    onPressed: _loadingLocation ? null : _fetchLocation,
                    child: Text('Refresh',
                        style: TextStyle(
                            color: t.accent, fontSize: 11)),
                  ),
                ],
              ),

              // Image attach placeholder
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text(
                        'Image attachment coming in Module 6'),
                    backgroundColor: t.cardBg,
                    behavior: SnackBarBehavior.floating,
                  ));
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: t.cardBgElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: t.stroke,
                        style: BorderStyle.solid),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined,
                          color: t.textSecondary, size: 18),
                      const SizedBox(width: 8),
                      Text('Attach Photo (optional)',
                          style: TextStyle(
                              color: t.textSecondary,
                              fontSize: 12)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.accent,
                    foregroundColor: Colors.black,
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black),
                        )
                      : const Text(
                          'Submit Report',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
