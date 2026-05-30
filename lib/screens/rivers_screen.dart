import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/station_provider.dart';
import '../models/station.dart';
import '../widgets/station_card.dart';
import 'station_detail_screen.dart';

// River info for display
const _riverInfo = {
  'Ganga':        {'icon': '🌊', 'stations': 7, 'desc': 'Main river, 7 gauges'},
  'Kosi':         {'icon': '💧', 'stations': 4, 'desc': 'Sorrow of Bihar'},
  'Gandak':       {'icon': '🏞', 'stations': 4, 'desc': 'West-central Bihar'},
  'Bagmati':      {'icon': '💙', 'stations': 3, 'desc': 'North Bihar plains'},
  'Burhi Gandak': {'icon': '🔵', 'stations': 4, 'desc': 'Muzaffarpur corridor'},
  'Ghaghra':      {'icon': '🌀', 'stations': 2, 'desc': 'Siwan district'},
  'Mahananda':    {'icon': '🟣', 'stations': 2, 'desc': 'Purnea / Kishanganj'},
  'Kamla':        {'icon': '🩵', 'stations': 1, 'desc': 'Madhubani entry'},
  'Kamla Balan':  {'icon': '🔷', 'stations': 1, 'desc': 'Madhubani Jhanjharpur'},
  'Adhwara':      {'icon': '⚪', 'stations': 3, 'desc': 'Sitamarhi / Darbhanga'},
  'Punpun':       {'icon': '🟤', 'stations': 1, 'desc': 'Patna southern drain'},
};

class RiversScreen extends StatelessWidget {
  const RiversScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<StationProvider>(
        builder: (ctx, prov, _) {
          final grouped = prov.byRiver;
          return RefreshIndicator(
            color: const Color(0xFF00D4FF),
            backgroundColor: const Color(0xFF141928),
            onRefresh: () => prov.loadAll(),
            child: CustomScrollView(
              slivers: [
                _appBar(grouped.length),
                SliverToBoxAdapter(child: _riverSummaryRow(grouped)),
                for (final entry in grouped.entries) ...
                  [
                    _riverHeader(entry.key, entry.value),
                    _stationList(ctx, entry.value),
                  ],
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
          );
        },
      ),
    );
  }

  SliverAppBar _appBar(int riverCount) => SliverAppBar(
    pinned: true,
    backgroundColor: const Color(0xFF0A0E1A),
    automaticallyImplyLeading: false,
    title: Row(
      children: [
        const Text('Bihar Rivers', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF00D4FF).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('$riverCount rivers', style: const TextStyle(color: Color(0xFF00D4FF), fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );

  Widget _riverSummaryRow(Map<String, List<Station>> grouped) {
    final totalStations  = grouped.values.fold(0, (s, l) => s + l.length);
    final atRisk = grouped.values.expand((l) => l).where((s) => !s.isNormal).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          _miniStat('$totalStations', 'Total Gauges', const Color(0xFF00D4FF)),
          const SizedBox(width: 10),
          _miniStat('$atRisk', 'At Risk', const Color(0xFFFFA502)),
          const SizedBox(width: 10),
          _miniStat('${grouped.length}', 'Rivers', const Color(0xFF00FF88)),
        ],
      ),
    );
  }

  Widget _miniStat(String val, String label, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(val, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(color: Color(0xFF4A5568), fontSize: 10)),
        ],
      ),
    ),
  );

  SliverToBoxAdapter _riverHeader(String river, List<Station> stations) {
    final info = _riverInfo[river];
    final danger  = stations.where((s) => s.isDanger).length;
    final warning = stations.where((s) => s.isWarning).length;
    final worstColor = danger > 0 ? const Color(0xFFFF4757) : (warning > 0 ? const Color(0xFFFFA502) : const Color(0xFF00FF88));
    final maxPct = stations.fold(0.0, (m, s) => s.pctToDanger > m ? s.pctToDanger : m);

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF141928),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          border: Border.all(color: worstColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Text(info?['icon'] as String? ?? '🌀', style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(river, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  Text(info?['desc'] as String? ?? '${stations.length} stations',
                    style: const TextStyle(color: Color(0xFF8B9CC8), fontSize: 11)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${stations.length} gauges', style: const TextStyle(color: Color(0xFF4A5568), fontSize: 11)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (danger > 0) ...
                      [_dot(const Color(0xFFFF4757)), Text(' $danger', style: const TextStyle(color: Color(0xFFFF4757), fontSize: 12, fontWeight: FontWeight.w600))],
                    if (warning > 0) ...
                      [const SizedBox(width: 6), _dot(const Color(0xFFFFA502)), Text(' $warning', style: const TextStyle(color: Color(0xFFFFA502), fontSize: 12, fontWeight: FontWeight.w600))],
                    if (danger == 0 && warning == 0)
                      const Text('All normal', style: TextStyle(color: Color(0xFF00FF88), fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 2),
                Text('Max ${maxPct.toStringAsFixed(0)}% to danger', style: TextStyle(color: worstColor, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(Color c) => Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle));

  SliverList _stationList(BuildContext ctx, List<Station> stations) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (_, i) {
          final s = stations[i];
          final isLast = i == stations.length - 1;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1520),
              borderRadius: isLast ? const BorderRadius.vertical(bottom: Radius.circular(16)) : BorderRadius.zero,
              border: const Border(left: BorderSide(color: Color(0xFF1E2840)), right: BorderSide(color: Color(0xFF1E2840)), bottom: BorderSide(color: Color(0xFF1E2840))),
            ),
            child: StationCard(station: s, onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => StationDetailScreen(station: s))), compact: true),
          );
        },
        childCount: stations.length,
      ),
    );
  }
}
