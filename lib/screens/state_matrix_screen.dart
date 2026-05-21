import 'package:flutter/material.dart';
import '../ml/flood_engine.dart';

class StateMatrixScreen extends StatefulWidget {
  const StateMatrixScreen({super.key});

  @override
  State<StateMatrixScreen> createState() => _StateMatrixScreenState();
}

class _StateMatrixScreenState extends State<StateMatrixScreen> {
  String _regionFilter = 'ALL';
  String _searchQuery = '';

  static const _regionColors = {
    'PLAINS': Color(0xFF2ECC71),
    'COASTAL': Color(0xFF00B4D8),
    'HIMALAYAN': Color(0xFF9B59B6),
    'NORTHEAST': Color(0xFFF39C12),
    'ARID': Color(0xFFE67E22),
    'ISLAND': Color(0xFF1ABC9C),
    'URBAN_UT': Color(0xFFE74C3C),
  };

  Color _regionColor(String r) =>
      _regionColors[r.toUpperCase()] ?? const Color(0xFF7B8FA6);

  List<MapEntry<String, StateEntry>> get _filtered {
    return stateSeverityMatrix.entries.where((e) {
      final matchRegion = _regionFilter == 'ALL' ||
          e.value.region.toUpperCase() == _regionFilter;
      final matchSearch = _searchQuery.isEmpty ||
          e.key.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchRegion && matchSearch;
    }).toList()
      ..sort((a, b) => a.key.compareTo(b.key));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1321),
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2ECC71), Color(0xFF27AE60)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.map_outlined,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('State Matrix',
                style: TextStyle(color: Colors.white, fontSize: 18,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          _buildStatsBar(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: _filtered.length,
              itemBuilder: (ctx, i) => _stateCard(_filtered[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: const Color(0xFF0D1321),
      child: Column(
        children: [
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search state...',
              hintStyle: const TextStyle(color: Color(0xFF4A5568)),
              prefixIcon: const Icon(Icons.search,
                  color: Color(0xFF4A5568), size: 20),
              filled: true,
              fillColor: const Color(0xFF1A2035),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('ALL', const Color(0xFF00B4D8)),
                ...(_regionColors.keys.map((r) =>
                    _filterChip(r, _regionColors[r]!))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, Color color) {
    final selected = _regionFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _regionFilter = label),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.2)
              : const Color(0xFF1A2035),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : const Color(0xFF2A3A50),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : const Color(0xFF7B8FA6),
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsBar() {
    final total = _filtered.length;
    final highRisk = _filtered.where((e) =>
        e.value.dangerLevelM < 10.0).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF0A0E1A),
      child: Row(
        children: [
          _statBadge('$total States', const Color(0xFF00B4D8)),
          const SizedBox(width: 8),
          _statBadge('$highRisk High Risk', const Color(0xFFE74C3C)),
          const Spacer(),
          Text(
            'Tap state for details',
            style: const TextStyle(
                color: Color(0xFF4A5568), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _statBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 12,
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _stateCard(MapEntry<String, StateEntry> entry) {
    final name = entry.key
        .split(' ')
        .map((w) => w.isNotEmpty
            ? '${w[0].toUpperCase()}${w.substring(1)}'
            : w)
        .join(' ');
    final e = entry.value;
    final color = _regionColor(e.region);

    return GestureDetector(
      onTap: () => _showStateDetail(context, name, e),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1321),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1A2A40)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color.withValues(alpha: 0.4)),
                  ),
                  child: Text(e.region,
                      style: TextStyle(color: color, fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _thresholdCell('Warning', '${e.warningLevelM}m',
                    const Color(0xFFF39C12)),
                _thresholdCell('Danger', '${e.dangerLevelM}m',
                    const Color(0xFFE67E22)),
                _thresholdCell('HFL', '${e.hflM}m',
                    const Color(0xFFE74C3C)),
              ],
            ),
            if (e.primaryRivers.isNotEmpty) ...
              [
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.water,
                        color: Color(0xFF00B4D8), size: 13),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        e.primaryRivers.take(3).join(', '),
                        style: const TextStyle(
                            color: Color(0xFF4A5568), fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
          ],
        ),
      ),
    );
  }

  Widget _thresholdCell(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(color: color, fontSize: 14,
                    fontWeight: FontWeight.w700)),
            Text(label,
                style: const TextStyle(color: Color(0xFF4A5568),
                    fontSize: 10)),
          ],
        ),
      ),
    );
  }

  void _showStateDetail(
      BuildContext context, String name, StateEntry e) {
    final color = _regionColor(e.region);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1321),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.4)),
                  ),
                  child: Text(e.region,
                      style: TextStyle(color: color, fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _detailRow('Warning Level', '${e.warningLevelM} m',
                const Color(0xFFF39C12)),
            _detailRow('Danger Level', '${e.dangerLevelM} m',
                const Color(0xFFE67E22)),
            _detailRow('HFL (Historical)', '${e.hflM} m',
                const Color(0xFFE74C3C)),
            const SizedBox(height: 8),
            const Text('Primary Rivers',
                style: TextStyle(color: Color(0xFF7B8FA6), fontSize: 12)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: e.primaryRivers
                  .map((r) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00B4D8)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: const Color(0xFF00B4D8)
                                  .withValues(alpha: 0.3)),
                        ),
                        child: Text(r,
                            style: const TextStyle(
                                color: Color(0xFF90E0EF),
                                fontSize: 12)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            const Text('Vulnerable Districts',
                style: TextStyle(color: Color(0xFF7B8FA6), fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              e.vulnerableDistricts.join(', '),
              style: const TextStyle(
                  color: Color(0xFFB0C4D8), fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: const TextStyle(
                    color: Color(0xFF7B8FA6), fontSize: 13)),
          ),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
