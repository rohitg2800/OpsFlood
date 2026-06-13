// lib/screens/monitors_screen.dart  — 3-D UI rebuild
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/river_theme.dart';
import '../theme/theme_3d.dart';
import '../providers/flood_provider.dart';
import 'cwc_station_detail_screen.dart';

class MonitorsScreen extends StatefulWidget {
  const MonitorsScreen({super.key});

  @override
  State<MonitorsScreen> createState() => _MonitorsScreenState();
}

class _MonitorsScreenState extends State<MonitorsScreen> {
  String _search = '';
  String _filter = 'All';

  static const _filters = ['All', 'Danger', 'Warning', 'Normal'];

  @override
  Widget build(BuildContext context) {
    final t  = RiverColors.of(context);
    final fp = context.watch<FloodProvider>();

    final stations = fp.liveStations.where((s) {
      final matchSearch = _search.isEmpty ||
          s.site.toLowerCase().contains(_search.toLowerCase()) ||
          s.river.toLowerCase().contains(_search.toLowerCase());
      final matchFilter = _filter == 'All' ||
          s.statusLabel.toLowerCase() == _filter.toLowerCase();
      return matchSearch && matchFilter;
    }).toList();

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          Td3AppBar(
            title: 'River Monitors',
            subtitle: '${fp.stationCount} stations tracked',
            leading: Navigator.canPop(context)
                ? IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        color: t.textPrimary, size: 18),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: [
                  // Search
                  Td3InputField(
                    controller: TextEditingController(text: _search),
                    label: 'Search stations',
                    hint: 'River, site name…',
                    icon: Icons.search_rounded,
                    required: false,
                    validator: (_) => null,
                  ),
                  const SizedBox(height: 10),
                  // Filter chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _filters.map((f) {
                        final sel = f == _filter;
                        final color = f == 'Danger'
                            ? t.danger
                            : f == 'Warning'
                                ? t.warning
                                : f == 'Normal'
                                    ? t.safe
                                    : t.accent;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _filter = f),
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 180),
                              opacity: sel ? 1.0 : 0.55,
                              child: Td3Chip(
                                  label: f,
                                  color: color,
                                  icon: sel ? Icons.check_rounded : null),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Td3Divider(),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final s     = stations[i];
                  final color = s.statusColor(t);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Td3Card(
                      accentColor: color,
                      elevation: Td3.elevMid,
                      onTap: () => Navigator.push(
                        ctx,
                        MaterialPageRoute(
                            builder: (_) =>
                                CwcStationDetailScreen(station: s)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(s.site,
                                          style: TextStyle(
                                              color: t.textPrimary,
                                              fontSize: 13,
                                              fontWeight:
                                                  FontWeight.w700)),
                                      Text(s.river,
                                          style: TextStyle(
                                              color: t.textSecondary,
                                              fontSize: 10)),
                                    ],
                                  ),
                                ),
                                Td3Chip(
                                    label: s.statusLabel.toUpperCase(),
                                    color: color,
                                    fontSize: 9),
                                const SizedBox(width: 10),
                                Text(
                                  '${s.level.toStringAsFixed(2)} m',
                                  style: TextStyle(
                                      color: color,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      shadows: [
                                        Shadow(
                                            color: color.withValues(
                                                alpha: 0.30),
                                            blurRadius: 6)
                                      ]),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Td3ProgressBar(
                                value: s.levelPercent,
                                fillColor: color,
                                height: 7),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: stations.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
