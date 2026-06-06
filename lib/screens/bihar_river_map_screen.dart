// lib/screens/bihar_river_map_screen.dart
// BiharRiverMapScreen v3 — RiverColors token migration
// All AppPalette.abyss*/text*/gold/abyssStroke replaced with RiverColors.of(context).
// Semantic severity colors (critical/danger/warning/safe/amber) kept as-is.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flood_data.dart';
import '../providers/flood_providers.dart';
import '../theme/river_theme.dart';
import '../utils/flood_severity_helper.dart';
import '../screens/city_detail_screen.dart';

class BiharRiverMapScreen extends ConsumerStatefulWidget {
  const BiharRiverMapScreen({super.key});
  static const String route = '/bihar_river_map';

  @override
  ConsumerState<BiharRiverMapScreen> createState() =>
      _BiharRiverMapScreenState();
}

class _BiharRiverMapScreenState
    extends ConsumerState<BiharRiverMapScreen> {
  String? _selectedDistrict;

  static const _grid = {
    'Pashchim Champaran': (0, 0),
    'Purba Champaran':    (1, 0),
    'Sitamarhi':          (2, 0),
    'Madhubani':          (3, 0),
    'Supaul':             (4, 0),
    'Araria':             (5, 0),
    'Kishanganj':         (6, 0),
    'Gopalganj':          (0, 1),
    'Muzaffarpur':        (1, 1),
    'Darbhanga':          (2, 1),
    'Samastipur':         (3, 1),
    'Madhepura':          (4, 1),
    'Saharsa':            (5, 1),
    'Purnia':             (6, 1),
    'Katihar':            (7, 1),
    'Siwan':              (0, 2),
    'Saran':              (1, 2),
    'Vaishali':           (2, 2),
    'Begusarai':          (3, 2),
    'Khagaria':           (4, 2),
    'Bhagalpur':          (6, 2),
    'Banka':              (7, 2),
    'Siwanagar':          (0, 3),
    'Patna':              (2, 3),
    'Sheikhpura':         (4, 3),
    'Munger':             (5, 3),
    'Lakhisarai':         (4, 3),
    'Jamui':              (6, 3),
    'Bhojpur':            (1, 3),
    'Buxar':              (0, 4),
    'Rohtas':             (1, 4),
    'Kaimur':             (0, 5),
    'Arwal':              (2, 4),
    'Jehanabad':          (2, 4),
    'Nalanda':            (3, 3),
    'Nawada':             (4, 4),
    'Gaya':               (3, 4),
    'Aurangabad':         (2, 5),
  };

  @override
  Widget build(BuildContext context) {
    final t        = RiverColors.of(context);
    final stations = ref.watch(liveLevelsProvider);

    final Map<String, FloodData> districtData = {};
    for (final fd in stations) {
      final key = fd.district.isNotEmpty ? fd.district : fd.city;
      final existing = districtData[key];
      if (existing == null ||
          FloodSeverityHelper.fromString(fd.status).index >
              FloodSeverityHelper.fromString(existing.status).index) {
        districtData[key] = fd;
      }
    }

    final biharStations = stations
        .where((fd) => fd.state.toUpperCase().contains('BIHAR'))
        .toList()
      ..sort((a, b) =>
          FloodSeverityHelper.fromString(b.status).index -
          FloodSeverityHelper.fromString(a.status).index);

    final selected = _selectedDistrict != null
        ? districtData[_selectedDistrict]
        : null;

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── App Bar ─────────────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: t.scaffoldBg,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.map_rounded, color: t.accent, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Bihar River Map',
                  style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            actions: [
              if (_selectedDistrict != null)
                TextButton(
                  onPressed: () =>
                      setState(() => _selectedDistrict = null),
                  child: Text('Clear',
                      style: TextStyle(
                          color: t.accent, fontSize: 12)),
                ),
            ],
          ),

          // ── Legend strip ───────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: _LegendStrip(),
            ),
          ),

          // ── District grid map ─────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _DistrictGrid(
                districtData: districtData,
                selected: _selectedDistrict,
                onSelect: (d) =>
                    setState(() => _selectedDistrict = d),
              ),
            ),
          ),

          // ── Selected district detail card ─────────────────────────────────────────
          if (selected != null)
            SliverToBoxAdapter(
              child: _DistrictDetailCard(
                data: selected,
                districtName: _selectedDistrict!,
                onOpenDetail: () => Navigator.pushNamed(
                  context,
                  CityDetailScreen.route,
                  arguments: selected.city,
                ),
              ),
            ),

          // ── Section header ───────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Row(
                children: [
                  Icon(Icons.sensors_rounded,
                      color: t.accent, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    biharStations.isEmpty
                        ? 'Bihar Stations'
                        : '${biharStations.length} Bihar Stations',
                    style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Station list ─────────────────────────────────────────────────────────────
          biharStations.isEmpty
              ? SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'No Bihar stations in live data',
                      style: TextStyle(
                          color: t.textSecondary, fontSize: 13),
                    ),
                  ),
                )
              : SliverPadding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _BiharStationTile(
                        data: biharStations[i],
                        onTap: () => Navigator.pushNamed(
                          ctx,
                          CityDetailScreen.route,
                          arguments: biharStations[i].city,
                        ),
                      ),
                      childCount: biharStations.length,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// District Grid (9 × 7 cells)
// ─────────────────────────────────────────────────────────────────────────────

class _DistrictGrid extends StatelessWidget {
  final Map<String, FloodData> districtData;
  final String? selected;
  final ValueChanged<String> onSelect;

  static const _cols = 9;
  static const _rows = 7;
  static const _grid = _BiharRiverMapScreenState._grid;

  const _DistrictGrid({
    required this.districtData,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return AspectRatio(
      aspectRatio: _cols / _rows,
      child: LayoutBuilder(builder: (_, box) {
        final cw = box.maxWidth / _cols;
        final ch = box.maxHeight / _rows;
        return Stack(
          children: [
            CustomPaint(
              size: Size(box.maxWidth, box.maxHeight),
              painter: _GridLinePainter(
                  cols: _cols, rows: _rows, strokeColor: t.stroke),
            ),
            ..._grid.entries.map((e) {
              final name = e.key;
              final (col, row) = e.value;
              final fd = districtData[name];
              final sev = fd != null
                  ? FloodSeverityHelper.fromString(fd.status)
                  : null;
              final cellColor = sev != null
                  ? FloodSeverityHelper.color(sev)
                  : t.cardBgElevated;
              final isSelected = selected == name;

              return Positioned(
                left: col * cw + 2,
                top: row * ch + 2,
                width: cw - 4,
                height: ch - 4,
                child: GestureDetector(
                  onTap: () => onSelect(name),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: sev != null
                          ? cellColor.withValues(alpha: 0.22)
                          : t.cardBg,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: isSelected
                            ? t.accent
                            : cellColor.withValues(alpha: 0.45),
                        width: isSelected ? 2 : 0.8,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: t.accent.withValues(alpha: 0.40),
                                blurRadius: 8,
                              )
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        name.split(' ').last,
                        style: TextStyle(
                          color: sev != null
                              ? cellColor
                              : t.stroke,
                          fontSize: 7,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      }),
    );
  }
}

class _GridLinePainter extends CustomPainter {
  final int   cols, rows;
  final Color strokeColor;
  const _GridLinePainter({
      required this.cols,
      required this.rows,
      required this.strokeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = strokeColor
      ..strokeWidth = 0.4;
    final cw = size.width / cols;
    final ch = size.height / rows;
    for (var c = 0; c <= cols; c++) {
      canvas.drawLine(
          Offset(c * cw, 0), Offset(c * cw, size.height), p);
    }
    for (var r = 0; r <= rows; r++) {
      canvas.drawLine(
          Offset(0, r * ch), Offset(size.width, r * ch), p);
    }
  }

  @override
  bool shouldRepaint(_GridLinePainter o) => o.strokeColor != strokeColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// District Detail Card
// ─────────────────────────────────────────────────────────────────────────────

class _DistrictDetailCard extends StatelessWidget {
  final FloodData    data;
  final String       districtName;
  final VoidCallback onOpenDetail;

  const _DistrictDetailCard({
    required this.data,
    required this.districtName,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final t     = RiverColors.of(context);
    final sev   = FloodSeverityHelper.fromString(data.status);
    final color = FloodSeverityHelper.color(sev);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: FloodSeverityHelper.cardBorder(sev), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: FloodSeverityHelper.glowColor(sev),
              blurRadius: 16,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(FloodSeverityHelper.icon(sev),
                    color: color, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$districtName  ·  ${data.city}',
                    style: TextStyle(
                      color: t.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _Chip(label: FloodSeverityHelper.label(sev), color: color),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _InfoTile('River',
                    data.riverName ?? 'N/A', t.accent),
                const SizedBox(width: 8),
                _InfoTile('Level',
                    '${data.currentLevel.toStringAsFixed(2)} m', color),
                const SizedBox(width: 8),
                _InfoTile('Danger',
                    '${data.dangerLevel.toStringAsFixed(1)} m',
                    AppPalette.danger),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _InfoTile('Warning',
                    '${data.warningLevel.toStringAsFixed(1)} m',
                    AppPalette.warning),
                const SizedBox(width: 8),
                _InfoTile('Rain 24h',
                    '${data.effectiveRainfallMm.toStringAsFixed(1)} mm',
                    t.accent),
                const SizedBox(width: 8),
                _InfoTile('IMD',
                    data.imdSeverity ?? '—', t.textSecondary),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: color.withValues(alpha: 0.12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: onOpenDetail,
                child: Text('View ${data.city} Detail →',
                    style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label, value;
  final Color  color;
  const _InfoTile(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
            Text(label,
                style: TextStyle(
                    color: t.textSecondary, fontSize: 9)),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color  color;
  const _Chip({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w800)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Legend Strip
// ─────────────────────────────────────────────────────────────────────────────

class _LegendStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final sev in FloodSeverity.values) ...[
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
              color: FloodSeverityHelper.color(sev),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 3),
          Text(
            FloodSeverityHelper.label(sev),
            style: TextStyle(
              color:
                  FloodSeverityHelper.color(sev).withValues(alpha: 0.85),
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bihar Station Tile
// ─────────────────────────────────────────────────────────────────────────────

class _BiharStationTile extends StatelessWidget {
  final FloodData    data;
  final VoidCallback onTap;
  const _BiharStationTile({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t     = RiverColors.of(context);
    final sev   = FloodSeverityHelper.fromString(data.status);
    final color = FloodSeverityHelper.color(sev);
    final fill  = (data.capacityPercent / 100).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: FloodSeverityHelper.cardBorder(sev), width: 0.8),
        ),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.10),
                border:
                    Border.all(color: color.withValues(alpha: 0.30)),
              ),
              child: Icon(FloodSeverityHelper.icon(sev),
                  color: color, size: 17),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data.city,
                      style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if ((data.riverName ?? '').isNotEmpty)
                        data.riverName!,
                      if (data.district.isNotEmpty) data.district,
                    ].join(' · '),
                    style: TextStyle(
                        color: t.textSecondary, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  // Mini level bar
                  Stack(
                    children: [
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: t.cardBgElevated,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: fill,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              color.withValues(alpha: 0.4),
                              color,
                            ]),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${data.currentLevel.toStringAsFixed(2)} m',
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: color.withValues(alpha: 0.28)),
                  ),
                  child: Text(
                    FloodSeverityHelper.label(sev),
                    style: TextStyle(
                        color: color,
                        fontSize: 8,
                        fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
