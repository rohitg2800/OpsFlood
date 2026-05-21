import 'package:flutter/material.dart';
import '../models/river_station.dart';
import '../widgets/station_card.dart';

class RiverMonitorScreen extends StatefulWidget {
  const RiverMonitorScreen({super.key});

  @override
  State<RiverMonitorScreen> createState() => _RiverMonitorScreenState();
}

class _RiverMonitorScreenState extends State<RiverMonitorScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final List<RiverStation> _stations = [
    const RiverStation(
      city: 'Delhi',       state: 'Delhi',         river: 'Yamuna',
      station: 'Old Delhi Railway Bridge',
      current: 204.18, warning: 204.0, danger: 204.83, hfl: 207.49,
    ),
    const RiverStation(
      city: 'Patna',       state: 'Bihar',         river: 'Ganga',
      station: 'Gandhighat',
      current: 47.82, warning: 48.60, danger: 50.45, hfl: 50.27,
    ),
    const RiverStation(
      city: 'Guwahati',    state: 'Assam',         river: 'Brahmaputra',
      station: 'Pandu',
      current: 48.92, warning: 48.68, danger: 49.68, hfl: 50.18,
    ),
    const RiverStation(
      city: 'Prayagraj',   state: 'Uttar Pradesh', river: 'Ganga',
      station: 'Phaphamau',
      current: 83.44, warning: 84.73, danger: 84.73, hfl: 87.50,
    ),
    const RiverStation(
      city: 'Bhagalpur',   state: 'Bihar',         river: 'Ganga',
      station: 'Bhagalpur Gauge',
      current: 32.16, warning: 32.00, danger: 33.68, hfl: 34.41,
    ),
    const RiverStation(
      city: 'Cuttack',     state: 'Odisha',        river: 'Mahanadi',
      station: 'Naraj',
      current: 25.44, warning: 24.90, danger: 26.41, hfl: 27.55,
    ),
  ];

  bool _sortedByRisk = false;

  // add-city form
  final _formKey = GlobalKey<FormState>();
  final _cityCtrl    = TextEditingController();
  final _stateCtrl   = TextEditingController();
  final _riverCtrl   = TextEditingController();
  final _stationCtrl = TextEditingController();
  final _curCtrl     = TextEditingController();
  final _warnCtrl    = TextEditingController();
  final _dangerCtrl  = TextEditingController();
  final _hflCtrl     = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final c in [_cityCtrl, _stateCtrl, _riverCtrl, _stationCtrl, _curCtrl, _warnCtrl, _dangerCtrl, _hflCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  List<RiverStation> get _displayList {
    final list = List<RiverStation>.from(_stations);
    if (_sortedByRisk) list.sort((a, b) => b.riskScore.compareTo(a.riskScore));
    return list;
  }

  void _addStation() {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _stations.insert(0, RiverStation(
        city:    _cityCtrl.text.trim(),
        state:   _stateCtrl.text.trim(),
        river:   _riverCtrl.text.trim(),
        station: _stationCtrl.text.trim(),
        current: double.parse(_curCtrl.text),
        warning: double.parse(_warnCtrl.text),
        danger:  double.parse(_dangerCtrl.text),
        hfl:     double.parse(_hflCtrl.text),
      ));
    });
    for (final c in [_cityCtrl, _stateCtrl, _riverCtrl, _stationCtrl, _curCtrl, _warnCtrl, _dangerCtrl, _hflCtrl]) {
      c.clear();
    }
    _tabController.animateTo(0);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('City added to monitoring list'), backgroundColor: Color(0xFF437A22)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final at    = _stations.where((s) => s.dangerClass != DangerClass.normal).length;
    final total = _stations.length;

    return Scaffold(
      backgroundColor: const Color(0xFF06101A),
      body: SafeArea(
        child: Column(
          children: [
            // ── header ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('River Monitor',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                        Text('CWC danger-level tracking',
                          style: TextStyle(fontSize: 13, color: Color(0xFF7B8A99))),
                      ],
                    ),
                  ),
                  // stat chips
                  _StatChip(label: '$total Cities',     color: const Color(0xFF4F98A3)),
                  const SizedBox(width: 8),
                  _StatChip(label: '$at At risk',       color: const Color(0xFFDA7101)),
                ],
              ),
            ),

            // ── tabs ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1B2A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: const Color(0xFF006C77),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: const Color(0xFF7B8A99),
                  labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(text: 'Stations'),
                    Tab(text: 'Add City'),
                  ],
                ),
              ),
            ),

            // ── body ─────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _StationsTab(
                    stations: _displayList,
                    sorted: _sortedByRisk,
                    onToggleSort: () => setState(() => _sortedByRisk = !_sortedByRisk),
                    onDelete: (s) => setState(() => _stations.remove(s)),
                  ),
                  _AddCityTab(
                    formKey: _formKey,
                    cityCtrl: _cityCtrl,    stateCtrl: _stateCtrl,
                    riverCtrl: _riverCtrl,  stationCtrl: _stationCtrl,
                    curCtrl: _curCtrl,      warnCtrl: _warnCtrl,
                    dangerCtrl: _dangerCtrl, hflCtrl: _hflCtrl,
                    onSubmit: _addStation,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stations tab ──────────────────────────────────────────────────────────

class _StationsTab extends StatelessWidget {
  final List<RiverStation> stations;
  final bool sorted;
  final VoidCallback onToggleSort;
  final ValueChanged<RiverStation> onDelete;

  const _StationsTab({
    required this.stations,
    required this.sorted,
    required this.onToggleSort,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // sort bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${stations.length} stations',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF7B8A99))),
              TextButton.icon(
                onPressed: onToggleSort,
                icon: Icon(
                  sorted ? Icons.sort_rounded : Icons.sort_rounded,
                  size: 16,
                  color: sorted ? const Color(0xFF4F98A3) : const Color(0xFF7B8A99),
                ),
                label: Text(
                  sorted ? 'Sorted by risk' : 'Sort by risk',
                  style: TextStyle(
                    fontSize: 12,
                    color: sorted ? const Color(0xFF4F98A3) : const Color(0xFF7B8A99),
                  ),
                ),
              ),
            ],
          ),
        ),
        // CWC category legend
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              _LegendDot(color: const Color(0xFF437A22), label: 'Normal'),
              const SizedBox(width: 10),
              _LegendDot(color: const Color(0xFFD19900), label: 'Above Normal'),
              const SizedBox(width: 10),
              _LegendDot(color: const Color(0xFFDA7101), label: 'Severe'),
              const SizedBox(width: 10),
              _LegendDot(color: const Color(0xFFA13544), label: 'Extreme'),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: stations.length,
            itemBuilder: (_, i) => StationCard(
              station: stations[i],
              onDelete: () => onDelete(stations[i]),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Add city tab ──────────────────────────────────────────────────────────

class _AddCityTab extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController cityCtrl, stateCtrl, riverCtrl, stationCtrl;
  final TextEditingController curCtrl, warnCtrl, dangerCtrl, hflCtrl;
  final VoidCallback onSubmit;

  const _AddCityTab({
    required this.formKey,
    required this.cityCtrl, required this.stateCtrl,
    required this.riverCtrl, required this.stationCtrl,
    required this.curCtrl, required this.warnCtrl,
    required this.dangerCtrl, required this.hflCtrl,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('City & River details',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 4),
            const Text('Enter the CWC station thresholds for the new city.',
              style: TextStyle(fontSize: 12, color: Color(0xFF7B8A99))),
            const SizedBox(height: 16),
            _Field(ctrl: cityCtrl,    label: 'City',                hint: 'e.g. Nashik'),
            _Field(ctrl: stateCtrl,   label: 'State',               hint: 'e.g. Maharashtra'),
            _Field(ctrl: riverCtrl,   label: 'River',               hint: 'e.g. Godavari'),
            _Field(ctrl: stationCtrl, label: 'CWC Station name',    hint: 'e.g. Ramkund Gauge'),
            const SizedBox(height: 12),
            const Text('Water level readings (metres)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF7B8A99))),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _Field(ctrl: curCtrl,    label: 'Current reading', hint: '0.00', isNum: true)),
                const SizedBox(width: 10),
                Expanded(child: _Field(ctrl: warnCtrl,   label: 'Warning level',   hint: '0.00', isNum: true)),
              ],
            ),
            Row(
              children: [
                Expanded(child: _Field(ctrl: dangerCtrl, label: 'Danger level',    hint: '0.00', isNum: true)),
                const SizedBox(width: 10),
                Expanded(child: _Field(ctrl: hflCtrl,    label: 'HFL',             hint: '0.00', isNum: true)),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF006C77), padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: onSubmit,
                icon: const Icon(Icons.add_location_alt_rounded),
                label: const Text('Add monitoring city', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1B2A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF4F98A3).withOpacity(0.25)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF4F98A3)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Get real readings from ffs.india-water.gov.in (CWC Flood Forecast Portal)',
                      style: TextStyle(fontSize: 11, color: Color(0xFF7B8A99)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Small reusable pieces ─────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final bool isNum;
  const _Field({required this.ctrl, required this.label, required this.hint, this.isNum = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: ctrl,
        keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: Color(0xFF7B8A99), fontSize: 12),
          hintStyle: const TextStyle(color: Color(0xFF3A4A58), fontSize: 13),
          filled: true,
          fillColor: const Color(0xFF0D1B2A),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF006C77), width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Required';
          if (isNum && double.tryParse(v) == null) return 'Enter a number';
          return null;
        },
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF7B8A99))),
      ],
    );
  }
}
