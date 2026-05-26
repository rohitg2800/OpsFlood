import 'package:flutter/material.dart';

class ModelInfoScreen extends StatelessWidget {
  const ModelInfoScreen({super.key});

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
                  colors: [Color(0xFF00B4D8), Color(0xFF0077B6)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.psychology, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('Model Info',
                style: TextStyle(color: Colors.white, fontSize: 18,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader('Ensemble Architecture'),
          const SizedBox(height: 8),
          _architectureCard(),
          const SizedBox(height: 16),
          _sectionHeader('Feature Importances'),
          const SizedBox(height: 8),
          _featureImportancesCard(),
          const SizedBox(height: 16),
          _sectionHeader('Model Performance'),
          const SizedBox(height: 8),
          _metricsCard(),
          const SizedBox(height: 16),
          _sectionHeader('CWC Option-A Guard'),
          const SizedBox(height: 8),
          _cwcGuardCard(),
          const SizedBox(height: 16),
          _sectionHeader('Class Labels'),
          const SizedBox(height: 8),
          _classLabelsCard(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Text(
    title,
    style: const TextStyle(
      color: Color(0xFF00B4D8),
      fontSize: 13,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.2,
    ),
  );

  Widget _architectureCard() {
    return _card([
      _modelRow('Primary', 'RandomForest', '75% weight', const Color(0xFF00B4D8)),
      const Divider(color: Color(0xFF1A2035), height: 24),
      _modelRow('Secondary', 'XGBoost Heuristic', '25% weight', const Color(0xFF48CAE4)),
      const Divider(color: Color(0xFF1A2035), height: 24),
      _infoRow(Icons.shield_outlined, 'Guard', 'CWC Option-A severity cap'),
      const SizedBox(height: 8),
      _infoRow(Icons.layers_outlined, 'Blend', 'ML 75% + Rule Engine 25%'),
      const SizedBox(height: 8),
      _infoRow(Icons.tune_outlined, 'Features', '11 hydrological inputs'),
      const SizedBox(height: 8),
      _infoRow(Icons.category_outlined, 'Classes', '4 severity levels'),
    ]);
  }

  Widget _modelRow(String role, String name, String weight, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Text(role,
              style: TextStyle(color: color, fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(name,
              style: const TextStyle(color: Colors.white,
                  fontSize: 14, fontWeight: FontWeight.w500)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2035),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(weight,
              style: const TextStyle(color: Color(0xFF90E0EF),
                  fontSize: 12, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF48CAE4), size: 16),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(label,
              style: const TextStyle(color: Color(0xFF7B8FA6), fontSize: 13)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(color: Colors.white, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _featureImportancesCard() {
    final features = [
      ('Peak Flood Level (m)', 0.28, const Color(0xFF0077B6)),
      ('7-day Rainfall (mm)', 0.22, const Color(0xFF0096C7)),
      ('T-1d Rainfall', 0.14, const Color(0xFF00B4D8)),
      ('Duration (days)', 0.10, const Color(0xFF48CAE4)),
      ('T-2d Rainfall', 0.08, const Color(0xFF90E0EF)),
      ('T-3d Rainfall', 0.06, const Color(0xFF90E0EF)),
      ('Time to Peak', 0.05, const Color(0xFFADE8F4)),
      ('T-4d Rainfall', 0.04, const Color(0xFFADE8F4)),
      ('Recession Time', 0.02, const Color(0xFFCAF0F8)),
      ('T-5d Rainfall', 0.01, const Color(0xFFCAF0F8)),
    ];
    return _card([
      for (final f in features) ...
        [
          Row(
            children: [
              SizedBox(
                width: 150,
                child: Text(f.$1,
                    style: const TextStyle(color: Color(0xFFB0C4D8),
                        fontSize: 12)),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (ctx, c) => Stack(
                    children: [
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A2035),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: f.$2,
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: f.$3,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${(f.$2 * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(color: Color(0xFF90E0EF),
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
        ],
    ]);
  }

  Widget _metricsCard() {
    return _card([
      Row(
        children: [
          _metricChip('Accuracy', '87.4%', const Color(0xFF2ECC71)),
          const SizedBox(width: 8),
          _metricChip('F1 Score', '0.86', const Color(0xFF00B4D8)),
          const SizedBox(width: 8),
          _metricChip('Precision', '0.88', const Color(0xFFE67E22)),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          _metricChip('Recall', '0.85', const Color(0xFF9B59B6)),
          const SizedBox(width: 8),
          _metricChip('States', '36', const Color(0xFF48CAE4)),
          const SizedBox(width: 8),
          _metricChip('Classes', '4', const Color(0xFFE74C3C)),
        ],
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2035),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Model trained on 15+ years of CWC river gauge data across India. '
          'Ensemble blends RF decision boundaries with heuristic XGBoost probabilities.',
          style: TextStyle(color: Color(0xFF7B8FA6), fontSize: 12,
              height: 1.5),
        ),
      ),
    ]);
  }

  Widget _metricChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(color: color, fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: Color(0xFF7B8FA6),
                    fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _cwcGuardCard() {
    return _card([
      _guardRow('Below Warning', 'Cap SEVERE/CRITICAL → MODERATE unless 7d rainfall >= severe threshold',
          const Color(0xFF2ECC71)),
      const SizedBox(height: 10),
      _guardRow('At Warning Level', 'Model probabilities trusted as-is',
          const Color(0xFFE67E22)),
      const SizedBox(height: 10),
      _guardRow('At Danger Level', 'Cap CRITICAL → SEVERE',
          const Color(0xFFE74C3C)),
      const SizedBox(height: 10),
      _guardRow('Above HFL', 'All severity levels allowed — no cap',
          const Color(0xFF9B59B6)),
    ]);
  }

  Widget _guardRow(String cond, String action, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4, height: 44,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(cond,
                  style: TextStyle(color: color, fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(action,
                  style: const TextStyle(color: Color(0xFF7B8FA6),
                      fontSize: 12, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _classLabelsCard() {
    const labels = [
      ('LOW', Color(0xFF2ECC71), 'Normal river conditions. Standard monitoring.'),
      ('MODERATE', Color(0xFFF39C12), 'Watch issued. Pre-position rescue teams.'),
      ('SEVERE', Color(0xFFE67E22), 'High alert. Alert district administration.'),
      ('CRITICAL', Color(0xFFE74C3C), 'Emergency. Immediate NDRF activation.'),
    ];
    return _card([
      for (final l in labels) ...
        [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 80,
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                decoration: BoxDecoration(
                  color: l.$2.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: l.$2.withValues(alpha: 0.4)),
                ),
                child: Text(l.$1,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: l.$2, fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(l.$3,
                    style: const TextStyle(color: Color(0xFFB0C4D8),
                        fontSize: 13, height: 1.4)),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
    ]);
  }

  Widget _card(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1321),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1A2A40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
