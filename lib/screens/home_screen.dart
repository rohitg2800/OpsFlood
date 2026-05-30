import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/station_provider.dart';
import '../models/station.dart';
import '../widgets/station_card.dart';
import 'station_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _filter = 'all'; // all | danger | warning | normal
  String _sortBy = 'risk'; // risk | name | river

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<StationProvider>(
        builder: (ctx, prov, _) {
          if (prov.state == LoadState.loading && prov.stations.isEmpty) {
            return _buildLoading();
          }
          if (prov.state == LoadState.error && prov.stations.isEmpty) {
            return _buildError(prov);
          }
          final stations = _applyFilter(prov.stations);
          return RefreshIndicator(
            color: const Color(0xFF00D4FF),
            backgroundColor: const Color(0xFF141928),
            onRefresh: () => prov.loadAll(),
            child: CustomScrollView(
              slivers: [
                _buildAppBar(prov),
                SliverToBoxAdapter(child: _buildSummaryCards(prov)),
                SliverToBoxAdapter(child: _buildFilterBar()),
                _buildStationList(stations, prov),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoading() => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(color: Color(0xFF00D4FF)),
        SizedBox(height: 16),
        Text('Loading Bihar stations...', style: TextStyle(color: Color(0xFF8B9CC8))),
      ],
    ),
  );

  Widget _buildError(StationProvider prov) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.wifi_off, color: Color(0xFFFF4757), size: 48),
        const SizedBox(height: 16),
        const Text('Cannot reach server', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('Make sure backend is running\non localhost:8000', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF8B9CC8), fontSize: 13)),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: prov.loadAll,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D4FF), foregroundColor: Colors.black),
        ),
      ],
    ),
  );

  SliverAppBar _buildAppBar(StationProvider prov) {
    final lastFetch = prov.lastFetch;
    final timeStr = lastFetch != null
      ? '${lastFetch.hour.toString().padLeft(2,'0')}:${lastFetch.minute.toString().padLeft(2,'0')}'
      : '--:--';
    return SliverAppBar(
      expandedHeight: 110,
      floating: true,
      pinned: true,
      backgroundColor: const Color(0xFF0A0E1A),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A0E1A), Color(0xFF0D1B2A)],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 50, 20, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF00D4FF).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.water, color: Color(0xFF00D4FF), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text('WRD Bihar Monitor', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                    Text('Updated $timeStr · Pull to refresh', style: const TextStyle(color: Color(0xFF4A5568), fontSize: 11)),
                  ],
                ),
              ),
              // Live badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF88).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF00FF88), shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    const Text('LIVE', style: TextStyle(color: Color(0xFF00FF88), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      // Refresh icon in actions
      actions: [
        IconButton(
          icon: prov.state == LoadState.loading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00D4FF)))
            : const Icon(Icons.refresh, color: Color(0xFF00D4FF)),
          onPressed: prov.state == LoadState.loading ? null : prov.loadAll,
        ),
      ],
    );
  }

  Widget _buildSummaryCards(StationProvider prov) {
    final s = prov.summary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          _sumCard('${s?.biharTotal ?? prov.stations.length}', 'Stations', const Color(0xFF00D4FF), Icons.radio_button_checked),
          const SizedBox(width: 10),
          _sumCard('${s?.warning ?? prov.warningStations.length}', 'Warning', const Color(0xFFFFA502), Icons.warning_amber),
          const SizedBox(width: 10),
          _sumCard('${s?.danger ?? prov.dangerStations.length}', 'Danger', const Color(0xFFFF4757), Icons.dangerous),
          const SizedBox(width: 10),
          _sumCard('${s?.normal ?? prov.normalStations.length}', 'Normal', const Color(0xFF00FF88), Icons.check_circle_outline),
        ],
      ),
    );
  }

  Widget _sumCard(String value, String label, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800)),
            Text(label, style: const TextStyle(color: Color(0xFF8B9CC8), fontSize: 9, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('all', 'All'),
                  const SizedBox(width: 8),
                  _filterChip('danger', 'Danger', color: const Color(0xFFFF4757)),
                  const SizedBox(width: 8),
                  _filterChip('warning', 'Warning', color: const Color(0xFFFFA502)),
                  const SizedBox(width: 8),
                  _filterChip('normal', 'Normal', color: const Color(0xFF00FF88)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _sortButton(),
        ],
      ),
    );
  }

  Widget _filterChip(String val, String label, {Color? color}) {
    final active = _filter == val;
    final c = color ?? const Color(0xFF00D4FF);
    return GestureDetector(
      onTap: () => setState(() => _filter = val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? c.withOpacity(0.2) : const Color(0xFF141928),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? c : const Color(0xFF1E2840)),
        ),
        child: Text(label, style: TextStyle(color: active ? c : const Color(0xFF4A5568), fontSize: 12, fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
      ),
    );
  }

  Widget _sortButton() {
    return GestureDetector(
      onTap: () {
        final opts = ['risk', 'name', 'river'];
        final next = opts[(opts.indexOf(_sortBy) + 1) % opts.length];
        setState(() => _sortBy = next);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF141928),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF1E2840)),
        ),
        child: Row(
          children: [
            const Icon(Icons.sort, size: 14, color: Color(0xFF8B9CC8)),
            const SizedBox(width: 4),
            Text(_sortBy.toUpperCase(), style: const TextStyle(color: Color(0xFF8B9CC8), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  List<Station> _applyFilter(List<Station> all) {
    List<Station> list = switch (_filter) {
      'danger'  => all.where((s) => s.isDanger).toList(),
      'warning' => all.where((s) => s.isWarning).toList(),
      'normal'  => all.where((s) => s.isNormal).toList(),
      _         => List.of(all),
    };
    list.sort((a, b) => switch (_sortBy) {
      'name'  => a.name.compareTo(b.name),
      'river' => a.river.compareTo(b.river),
      _       => _statusOrder(a).compareTo(_statusOrder(b)), // risk
    });
    return list;
  }

  int _statusOrder(Station s) => s.isDanger ? 0 : (s.isWarning ? 1 : 2);

  SliverList _buildStationList(List<Station> stations, StationProvider prov) {
    if (stations.isEmpty) {
      return SliverList(
        delegate: SliverChildListDelegate([
          const SizedBox(height: 80),
          const Center(child: Text('No stations match filter', style: TextStyle(color: Color(0xFF4A5568), fontSize: 15))),
        ]),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (ctx, i) {
          if (i == stations.length) return const SizedBox(height: 80);
          return StationCard(
            station: stations[i],
            onTap: () => Navigator.push(
              ctx,
              MaterialPageRoute(builder: (_) => StationDetailScreen(station: stations[i])),
            ),
          );
        },
        childCount: stations.length + 1,
      ),
    );
  }
}
