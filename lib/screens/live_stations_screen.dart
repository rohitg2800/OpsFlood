// lib/screens/live_stations_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/context_l10n.dart';
import '../providers/flood_providers.dart';
import '../widgets/station_tile.dart';

class LiveStationsScreen extends ConsumerWidget {
  const LiveStationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s        = context.l10n;
    final stations = ref.watch(liveStationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.liveData),
        centerTitle: true,
      ),
      body: stations.when(
        loading: () => Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('${s.noData}: $e')),
        data: (list) => list.isEmpty
            ? Center(child: Text(s.noStationsFound))
            : ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) => StationTile(station: list[i]),
              ),
      ),
    );
  }
}
