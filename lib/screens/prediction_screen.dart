// lib/screens/prediction_screen.dart
// OpsFlood — AI Flood Prediction Screen
// Shows LSTM-based 24h / 72h river level predictions per gauge station.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../theme/river_theme.dart';
import '../providers/prediction_provider.dart';
import '../data/bihar_rivers.dart';

class PredictionScreen extends ConsumerStatefulWidget {
  const PredictionScreen({super.key});
  static const String route = '/prediction';
  @override
  ConsumerState<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends ConsumerState<PredictionScreen> {
  String _selectedStation = 'Gandhighat';
  int    _horizon = 24;

  @override
  Widget build(BuildContext context) {
    final pred = ref.watch(predictionProvider(_selectedStation));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppPalette.abyss0,
        body: SafeArea(
          child: Column(
            children: [
              _Header(),
              _StationSelector(
                stations: kBiharGauges.map((g) => g.station).toSet().toList()
                    ..sort(),
                selected: _selectedStation,
                onChanged: (s) => setState(() => _selectedStation = s),
              ),
              _HorizonToggle(
                selected: _horizon,
                onChanged: (h) => setState(() => _horizon = h),
              ),
              Expanded(
                child: pred.when(
                  data: (p) => _PredictionBody(
                    prediction: p,
                    horizon:    _horizon,
                    station:    _selectedStation,
                  ),
                  loading: () => const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                            strokeWidth: 2.5, color: AppPalette.cyan),
                        SizedBox(height: 16),
                        Text('Running LSTM model…',
                            style: TextStyle(
                                color: AppPalette.textGrey, fontSize: 13)),
                      ],
                    ),
                  ),
                  error: (e, _) => _ErrorPanel(message: e.toString()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        decoration: BoxDecoration(
          color: AppPalette.abyss0,
          border: Border(
            bottom: BorderSide(
                color: AppPalette.cyan.withValues(alpha: 0.10), width: 1)),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: AppPalette.cyan.withValues(alpha: 0.10),
                border: Border.all(
                    color: AppPalette.cyan.withValues(alpha: 0.28), width: 1.5),
              ),
              child: const Icon(Icons.auto_graph_rounded,
                  color: AppPalette.cyan, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [Color(0xFF00E5FF), Color(0xFF0072FF)],
                  ).createShader(b),
                  child: const Text('AI PREDICTION',
                      style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w900,
                        color: Colors.white, letterSpacing: -0.5,
                      )),
                ),
                Text('LSTM · 24h / 72h flood forecast',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppPalette.textGrey.withValues(alpha: 0.65),
                    )),
              ],
            ),
          ],
        ),
      );
}

class _StationSelector extends StatelessWidget {
  final List<String> stations;
  final String selected;
  final ValueChanged<String> onChanged;
  const _StationSelector({
    required this.stations,
    required this.selected,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Container(
        height: 44,
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppPalette.abyss2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppPalette.abyssStroke),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selected,
            dropdownColor: AppPalette.abyss2,
            iconEnabledColor: AppPalette.cyan,
            isExpanded: true,
            style: const TextStyle(
                color: AppPalette.textWhite, fontSize: 13,
                fontWeight: FontWeight.w700),
            items: stations.map((s) => DropdownMenuItem(
              value: s,
              child: Text(s),
            )).toList(),
            onChanged: (v) { if (v != null) onChanged(v); },
          ),
        ),
      );
}

class _HorizonToggle extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  const _HorizonToggle({
    required this.selected, required this.onChanged});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Row(
          children: [24, 48, 72].map((h) {
            final active = selected == h;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(h);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: active
                      ? AppPalette.cyan.withValues(alpha: 0.14)
                      : AppPalette.abyss2,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: active
                        ? AppPalette.cyan.withValues(alpha: 0.45)
                        : AppPalette.abyssStroke,
                    width: active ? 1.5 : 1,
                  ),
                ),
                child: Text('${h}h',
                    style: TextStyle(
                      color: active ? AppPalette.cyan : AppPalette.textGrey,
                      fontSize: 12,
                      fontWeight: active
                          ? FontWeight.w900
                          : FontWeight.w600,
                    )),
              ),
            );
          }).toList(),
        ),
      );
}

class _PredictionBody extends StatelessWidget {
  final FloodPrediction prediction;
  final int             horizon;
  final String          station;
  const _PredictionBody({
    required this.prediction,
    required this.horizon,
    required this.station,
  });

  @override
  Widget build(BuildContext context) {
    final pts = horizon == 24
        ? prediction.next24h
        : horizon == 48
            ? prediction.next48h
            : prediction.next72h;
    final peak = pts.isEmpty ? 0.0
        : pts.map((p) => p.level).reduce((a, b) => a > b ? a : b);
    final danger = prediction.dangerLevel;
    final willBreach = peak >= danger;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      physics: const BouncingScrollPhysics(),
      children: [
        // ── Alert banner ─────────────────────────────────────────────
        if (willBreach)
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: AppPalette.critical.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppPalette.critical.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_rounded,
                    color: AppPalette.critical, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'AI model predicts river level will breach '
                    'danger level (${danger.toStringAsFixed(2)} m) '
                    'within ${horizon}h at $station.',
                    style: const TextStyle(
                      color: AppPalette.critical, fontSize: 12,
                      fontWeight: FontWeight.w700, height: 1.4),
                  ),
                ),
              ],
            ),
          ),

        // ── Stats row ────────────────────────────────────────────────
        Row(
          children: [
            Expanded(child: _StatBox(
              label: 'Current Level',
              value: '${prediction.currentLevel.toStringAsFixed(2)} m',
              color: AppPalette.cyan,
            )),
            const SizedBox(width: 8),
            Expanded(child: _StatBox(
              label: 'Predicted Peak',
              value: '${peak.toStringAsFixed(2)} m',
              color: willBreach ? AppPalette.critical : AppPalette.amber,
            )),
            const SizedBox(width: 8),
            Expanded(child: _StatBox(
              label: 'Danger Level',
              value: '${danger.toStringAsFixed(2)} m',
              color: AppPalette.danger,
            )),
          ],
        ),
        const SizedBox(height: 14),

        // ── Confidence badge ─────────────────────────────────────────
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppPalette.abyss2,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppPalette.abyssStroke),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome_rounded,
                      color: AppPalette.cyan, size: 11),
                  const SizedBox(width: 5),
                  Text(
                    'Model confidence: ${(prediction.confidencePct).toStringAsFixed(0)}%  ·  '  
                    'LSTM • ${prediction.modelVersion}',
                    style: const TextStyle(
                        color: AppPalette.textGrey, fontSize: 9,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Mini sparkline chart ─────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppPalette.abyss2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppPalette.abyssStroke),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${horizon}h LEVEL FORECAST',
                  style: const TextStyle(
                    color: AppPalette.textDim, fontSize: 9,
                    fontWeight: FontWeight.w800, letterSpacing: 0.8)),
              const SizedBox(height: 12),
              SizedBox(
                height: 120,
                child: _Sparkline(
                  points: pts,
                  dangerLevel: danger,
                  warningLevel: prediction.warningLevel,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Hourly table ─────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: AppPalette.abyss2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppPalette.abyssStroke),
          ),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text('TIME',
                        style: TextStyle(
                          color: AppPalette.textDim, fontSize: 9,
                          fontWeight: FontWeight.w800, letterSpacing: 0.8))),
                    Expanded(flex: 2, child: Text('LEVEL (m)',
                        style: TextStyle(
                          color: AppPalette.textDim, fontSize: 9,
                          fontWeight: FontWeight.w800, letterSpacing: 0.8),
                        textAlign: TextAlign.right)),
                    Expanded(flex: 2, child: Text('PRECIP',
                        style: TextStyle(
                          color: AppPalette.textDim, fontSize: 9,
                          fontWeight: FontWeight.w800, letterSpacing: 0.8),
                        textAlign: TextAlign.right)),
                    Expanded(flex: 2, child: Text('STATUS',
                        style: TextStyle(
                          color: AppPalette.textDim, fontSize: 9,
                          fontWeight: FontWeight.w800, letterSpacing: 0.8),
                        textAlign: TextAlign.right)),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppPalette.abyssStroke),
              ...pts.asMap().entries.map((e) {
                final i = e.key;
                final p = e.value;
                final col = p.level >= danger
                    ? AppPalette.critical
                    : p.level >= prediction.warningLevel
                        ? AppPalette.danger
                        : AppPalette.safe;
                final status = p.level >= danger
                    ? 'DANGER'
                    : p.level >= prediction.warningLevel
                        ? 'WARNING'
                        : 'SAFE';
                return Container(
                  color: i.isOdd
                      ? AppPalette.abyss0.withValues(alpha: 0.30)
                      : Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: Text(
                        DateFormat('dd MMM HH:mm').format(p.time.toLocal()),
                        style: const TextStyle(
                            color: AppPalette.textGrey, fontSize: 10),
                      )),
                      Expanded(flex: 2, child: Text(
                        p.level.toStringAsFixed(2),
                        style: TextStyle(
                          color: col, fontSize: 10,
                          fontWeight: FontWeight.w800),
                        textAlign: TextAlign.right,
                      )),
                      Expanded(flex: 2, child: Text(
                        p.precipMm != null
                            ? '${p.precipMm!.toStringAsFixed(1)} mm'
                            : '—',
                        style: const TextStyle(
                            color: AppPalette.cyan, fontSize: 10),
                        textAlign: TextAlign.right,
                      )),
                      Expanded(flex: 2, child: Text(
                        status,
                        style: TextStyle(
                          color: col, fontSize: 9,
                          fontWeight: FontWeight.w900),
                        textAlign: TextAlign.right,
                      )),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

// Simple canvas sparkline ─────────────────────────────────────────────────────
class _Sparkline extends StatelessWidget {
  final List<PredictionPoint> points;
  final double dangerLevel;
  final double warningLevel;
  const _Sparkline({
    required this.points,
    required this.dangerLevel,
    required this.warningLevel,
  });
  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _SparklinePainter(
            points: points,
            dangerLevel: dangerLevel,
            warningLevel: warningLevel),
        size: Size.infinite,
      );
}

class _SparklinePainter extends CustomPainter {
  final List<PredictionPoint> points;
  final double dangerLevel;
  final double warningLevel;
  _SparklinePainter({
    required this.points,
    required this.dangerLevel,
    required this.warningLevel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final levels = points.map((p) => p.level).toList();
    final minY   = (levels.reduce((a, b) => a < b ? a : b) - 0.3)
        .clamp(0.0, double.infinity);
    final maxY   = levels.reduce((a, b) => a > b ? a : b) + 0.3;
    final range  = maxY - minY;
    if (range == 0) return;

    double xOf(int i) => size.width * i / (points.length - 1);
    double yOf(double v) => size.height * (1 - (v - minY) / range);

    // Danger line
    _drawHLine(canvas, size, yOf(dangerLevel), AppPalette.critical);
    // Warning line
    _drawHLine(canvas, size, yOf(warningLevel), AppPalette.amber);

    // Fill area
    final fillPath = Path();
    fillPath.moveTo(xOf(0), yOf(levels[0]));
    for (var i = 1; i < points.length; i++) {
      fillPath.lineTo(xOf(i), yOf(levels[i]));
    }
    fillPath.lineTo(xOf(points.length - 1), size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [
          AppPalette.cyan.withValues(alpha: 0.25),
          AppPalette.cyan.withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill);

    // Line
    final linePaint = Paint()
      ..color = AppPalette.cyan
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final linePath = Path();
    linePath.moveTo(xOf(0), yOf(levels[0]));
    for (var i = 1; i < points.length; i++) {
      linePath.lineTo(xOf(i), yOf(levels[i]));
    }
    canvas.drawPath(linePath, linePaint);
  }

  void _drawHLine(Canvas canvas, Size size, double y, Color col) {
    canvas.drawLine(
        Offset(0, y), Offset(size.width, y),
        Paint()
          ..color = col.withValues(alpha: 0.55)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.points != points;
}

class _StatBox extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatBox({
    required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(
              color: color, fontSize: 15, fontWeight: FontWeight.w900,
              letterSpacing: -0.5)),
            const SizedBox(height: 3),
            Text(label, style: const TextStyle(
                color: AppPalette.textDim, fontSize: 8.5),
                textAlign: TextAlign.center),
          ],
        ),
      );
}

class _ErrorPanel extends StatelessWidget {
  final String message;
  const _ErrorPanel({required this.message});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.model_training_rounded,
                  color: AppPalette.textDim, size: 48),
              const SizedBox(height: 16),
              const Text('AI Model Unavailable',
                  style: TextStyle(
                    color: AppPalette.textGrey,
                    fontSize: 16, fontWeight: FontWeight.w800,
                  )),
              const SizedBox(height: 8),
              Text(message,
                  style: const TextStyle(
                      color: AppPalette.textDim, fontSize: 11),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}
