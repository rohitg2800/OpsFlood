// lib/screens/live_stations_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/flood_providers.dart';
import '../theme/river_theme.dart';

class LiveStationsScreen extends ConsumerWidget {
  static const String route = '/live-stations';
  const LiveStationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(realTimeProvider);
    final t = RiverColors.of(context);
    final stations = service.cwcStations;

    return Scaffold(
      backgroundColor: AppPalette.abyss0,
      appBar: AppBar(
        backgroundColor: AppPalette.abyss0,
        title: Text(
          'Live CWC Stations',
          style: TextStyle(
            color: AppPalette.cyan,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: AppPalette.gold),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppPalette.cyan),
            tooltip: 'Refresh',
            onPressed: () => service.refreshData(),
          ),
        ],
      ),
      body: service.isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppPalette.cyan))
          : service.error != null
              ? Center(
                  child: Text(
                    service.error!,
                    style: TextStyle(color: AppPalette.danger),
                  ))
              : stations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.water_outlined,
                              size: 56, color: AppPalette.cyan),
                          const SizedBox(height: 12),
                          Text(
                            'No live station data yet',
                            style: TextStyle(color: AppPalette.textGrey),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Pull to refresh or wait for next fetch',
                            style: TextStyle(
                                color: AppPalette.textDim, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: AppPalette.cyan,
                      onRefresh: () => service.refreshData(),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: stations.length,
                        itemBuilder: (ctx, i) {
                          final s = stations[i];
                          final level = s is Map ? s['level'] ?? s['current_level'] ?? 0.0 : 0.0;
                          final name  = s is Map ? s['station_name'] ?? s['name'] ?? 'Station' : s.toString();
                          final river = s is Map ? s['river_name'] ?? s['river'] ?? '' : '';
                          final status = s is Map ? (s['status'] ?? s['risk_level'] ?? 'normal').toString().toUpperCase() : 'NORMAL';
                          final color = status == 'DANGER' || status == 'CRITICAL'
                              ? AppPalette.danger
                              : status == 'WARNING'
                                  ? AppPalette.warning
                                  : AppPalette.cyan;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: t.cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: color.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: color,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name.toString(),
                                        style: TextStyle(
                                          color: AppPalette.textWhite,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (river.toString().isNotEmpty)
                                        Text(
                                          river.toString(),
                                          style: TextStyle(
                                            color: AppPalette.textGrey,
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${(level is num ? level.toStringAsFixed(2) : level)} m',
                                  style: TextStyle(
                                    color: AppPalette.textGrey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
