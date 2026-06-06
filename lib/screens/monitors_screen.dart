// lib/screens/monitors_screen.dart
// OpsFlood — MonitorsScreen v5.3  "Live data wired"
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/context_l10n.dart';
import '../models/flood_data.dart';
import '../providers/flood_providers.dart';
import '../providers/weather_provider.dart';
import '../theme/river_theme.dart';

class MonitorsScreen extends ConsumerStatefulWidget {
  const MonitorsScreen({super.key});
  @override
  ConsumerState<MonitorsScreen> createState() => _MonitorsScreenState();
}

class _MonitorsScreenState extends ConsumerState<MonitorsScreen>
    with SingleTickerProviderStateMixin {
  String? _expanded;
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;
  String _sort = 'risk';

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  List<FloodData> _sorted(List<FloodData> raw) {
    final list = List<FloodData>.from(raw);
    switch (_sort) {
      case 'level':
        list.sort((a, b) => b.currentLevel.compareTo(a.currentLevel));
      case 'rain':
        list.sort((a, b) =>
            b.effectiveRainfallMm.compareTo(a.effectiveRainfallMm));
      default:
        list.sort((a, b) {
          final c = b.priorityOrder.compareTo(a.priorityOrder);
          return c != 0 ? c : b.capacityPercent.compareTo(a.capacityPercent);
        });
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final s  = context.l10n;
    // ── Wire directly to liveLevelsProvider so rebuilds happen on every tick ──
    final rt     = ref.watch(realTimeProvider);
    final items  = ref.watch(liveLevelsProvider);   // <── THE FIX
    final wx     = ref.watch(weatherProvider);

    final sorted    = _sorted(items);
    final critCount = sorted.where((d) => d.riskLevel == 'CRITICAL').length;
    final sevCount  = sorted.where((d) => d.riskLevel == 'SEVERE').length;
    final modCount  = sorted.where((d) => d.riskLevel == 'MODERATE').length;
    final safeCount = sorted.where((d) => d.riskLevel == 'LOW').length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppPalette.abyss0,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _Header(
                total:         sorted.length,
                critical:      critCount,
                pulseAnim:     _pulseAnim,
                lastFetch:     rt.lastFetchTime,
                wxCity:        wx.cityName,
                wxLoaded:      wx.status == WeatherStatus.loaded,
                liveLabel:     s.live,
                stationsLabel: s.stations,
                onRefresh: () {
                  HapticFeedback.mediumImpact();
                  rt.refreshData();
                },
              ),
              if (sorted.isNotEmpty)
                _StatsBar(
                  critical: critCount, severe:   sevCount,
                  moderate: modCount,  safe:     safeCount,
                  total:    sorted.length,
                  criticalLabel: s.critical,
                  safeLabel:     s.safe,
                ),
              if (wx.status == WeatherStatus.loaded)
                _WxFeedBanner(wx: wx),
              if (sorted.isNotEmpty)
                _SortChips(
                  current:    _sort,
                  sortLabel:  s.sortBy,
                  riskLabel:  s.floodRisk,
                  levelLabel: s.riverLevel,
                  rainLabel:  s.rainfall,
                  onChange: (v) => setState(() => _sort = v),
                ),
              Expanded(
                child: sorted.isEmpty
                    ? _EmptyState(
                        isLoading:    rt.isLoading,
                        loadingLabel: s.loading,
                        noDataLabel:  s.noData,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        physics: const BouncingScrollPhysics(),
                        itemCount: sorted.length,
                        itemBuilder: (_, i) => _MonitorCard(
                          data:          sorted[i],
                          wx:            wx,
                          isExpanded:    _expanded == sorted[i].city,
                          pulseAnim:     _pulseAnim,
                          safeLabel:     s.safe,
                          warningLabel:  s.warning,
                          dangerLabel:   s.danger,
                          capacityLabel: s.capacity,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _expanded =
                                _expanded == sorted[i].city
                                    ? null
                                    : sorted[i].city);
                          },
                          onLongPress: () {
                            HapticFeedback.mediumImpact();
                            Navigator.pushNamed(
                              context,
                              '/city_detail',
                              arguments: sorted[i].city,
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// HEADER
// ══════════════════════════════════════════════════════════════════════════════
class _Header extends StatelessWidget {
  final int               total, critical;
  final Animation<double> pulseAnim;
  final DateTime?         lastFetch;
  final String            wxCity;
  final bool              wxLoaded;
  final String            liveLabel;
  final String            stationsLabel;
  final VoidCallback      onRefresh;
  const _Header({
    required this.total,          required this.critical,
    required this.pulseAnim,      required this.lastFetch,
    required this.wxCity,         required this.wxLoaded,
    required this.liveLabel,      required this.stationsLabel,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [
                  AppPalette.cyan.withValues(alpha: 0.20),
                  AppPalette.cyan.withValues(alpha: 0.05),
                ],
              ),
              border: Border.all(
                  color: AppPalette.cyan.withValues(alpha: 0.28), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppPalette.cyan.withValues(alpha: 0.14),
                  blurRadius: 14,
                ),
              ],
            ),
            child: const Icon(Icons.monitor_heart_rounded,
                color: AppPalette.cyan, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [Color(0xFF00E5FF), Color(0xFF0072FF)],
                  ).createShader(b),
                  child: Text(
                    context.l10n.tabMonitors,
                    style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900,
                      color: Colors.white, letterSpacing: -0.8, height: 1.1,
                    ),
                  ),
                ),
                Row(children: [
                  Flexible(
                    child: Text(
                      lastFetch != null
                          ? '${context.l10n.lastUpdated} ${_fmt(lastFetch!)}'
                          : '$total $stationsLabel',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: AppPalette.textGrey.withValues(alpha: 0.65),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (wxLoaded) ...[
                    Flexible(
                      child: Text(
                        '  ·  wx: $wxCity',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: AppPalette.cyan.withValues(alpha: 0.55),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ]),
              ],
            ),
          ),
          if (critical > 0)
            AnimatedBuilder(
              animation: pulseAnim,
              builder: (_, __) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppPalette.critical.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppPalette.critical.withValues(
                        alpha: 0.25 + 0.20 * pulseAnim.value)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppPalette.critical.withValues(
                          alpha: 0.5 + 0.5 * pulseAnim.value),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text('$critical ${context.l10n.critical}',
                      style: const TextStyle(
                        color: AppPalette.critical,
                        fontSize: 9, fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      )),
                ]),
              ),
            )
          else
            AnimatedBuilder(
              animation: pulseAnim,
              builder: (_, __) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppPalette.safe.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppPalette.safe.withValues(
                        alpha: 0.20 + 0.15 * pulseAnim.value)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppPalette.safe.withValues(
                          alpha: 0.5 + 0.5 * pulseAnim.value),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(liveLabel,
                      style: const TextStyle(
                        color: AppPalette.safe,
                        fontSize: 9, fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      )),
                ]),
              ),
            ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRefresh,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppPalette.abyss2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppPalette.abyssStroke),
              ),
              child: const Icon(Icons.refresh_rounded,
                  color: AppPalette.textGrey, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inSeconds < 60) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    return DateFormat('HH:mm').format(dt.toLocal());
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// STATS BAR
// ══════════════════════════════════════════════════════════════════════════════
class _StatsBar extends StatelessWidget {
  final int    critical, severe, moderate, safe, total;
  final String criticalLabel, safeLabel;
  const _StatsBar({
    required this.critical,      required this.severe,
    required this.moderate,      required this.safe,
    required this.total,
    required this.criticalLabel, required this.safeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: AppPalette.abyss2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.abyssStroke),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatPill(value: critical, label: criticalLabel.toUpperCase(),
              color: AppPalette.critical, glow: critical > 0),
          _vDivider(),
          _StatPill(value: severe,   label: s.danger.toUpperCase(),
              color: AppPalette.danger,   glow: severe > 0),
          _vDivider(),
          _StatPill(value: moderate, label: s.warning.toUpperCase(),
              color: AppPalette.warning),
          _vDivider(),
          _StatPill(value: safe,     label: safeLabel.toUpperCase(),
              color: AppPalette.safe),
          _vDivider(),
          _StatPill(value: total,    label: 'TOTAL',
              color: AppPalette.cyan),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(
        width: 1, height: 28, color: AppPalette.abyssStroke);
}

class _StatPill extends StatelessWidget {
  final int value; final String label; final Color color; final bool glow;
  const _StatPill({required this.value, required this.label,
      required this.color, this.glow = false});
  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$value', style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -1,
            color: glow ? color : (value > 0 ? color : AppPalette.textDim),
            shadows: glow ? [Shadow(color: color.withValues(alpha: 0.6),
                blurRadius: 8)] : null,
          )),
          const SizedBox(height: 1),
          Text(label, style: TextStyle(
            fontSize: 7.5, fontWeight: FontWeight.w700, letterSpacing: 0.6,
            color: glow ? color.withValues(alpha: 0.75) : AppPalette.textDim,
          )),
        ],
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// WEATHER FEED BANNER
// ══════════════════════════════════════════════════════════════════════════════
class _WxFeedBanner extends StatelessWidget {
  final WeatherState wx;
  const _WxFeedBanner({required this.wx});

  @override
  Widget build(BuildContext context) {
    final indexColor = wx.rainfallIndex > 70
        ? AppPalette.critical
        : wx.rainfallIndex > 45
            ? AppPalette.danger
            : wx.rainfallIndex > 25
                ? AppPalette.amber
                : AppPalette.safe;
    final city = wx.cityName.split(',').first;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppPalette.abyss2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppPalette.cyan.withValues(alpha: 0.20), width: 1.2),
      ),
      child: Wrap(
        spacing: 0,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _BannerLabel(city: city),
          _BannerDivider(),
          _WxBannerItem(Icons.thermostat_rounded,
              '${wx.tempC.toStringAsFixed(1)}°', AppPalette.amber),
          _BannerDivider(),
          _WxBannerItem(Icons.grain_rounded,
              '${wx.rainfall7dMm.toStringAsFixed(0)} mm 7d', AppPalette.cyan),
          _BannerDivider(),
          _WxBannerItem(Icons.analytics_rounded,
              'RI ${wx.rainfallIndex.toStringAsFixed(0)}', indexColor),
          _BannerDivider(),
          _WxBannerItem(Icons.umbrella_rounded,
              '${wx.maxPrecipProb.toStringAsFixed(0)}%', AppPalette.amber),
          _BannerDivider(),
          _WxBannerItem(Icons.water_drop_rounded,
              '${wx.humidity}% RH', const Color(0xFF64B5F6)),
        ],
      ),
    );
  }
}

class _BannerLabel extends StatelessWidget {
  final String city;
  const _BannerLabel({required this.city});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_rounded, color: AppPalette.cyan, size: 12),
          const SizedBox(width: 4),
          Text('WX·$city',
              style: const TextStyle(
                color: AppPalette.cyan, fontSize: 9,
                fontWeight: FontWeight.w800, letterSpacing: 0.3)),
        ],
      );
}

class _BannerDivider extends StatelessWidget {
  const _BannerDivider();
  @override
  Widget build(BuildContext context) => Container(
        width: 1, height: 11,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: AppPalette.abyssStroke);
}

class _WxBannerItem extends StatelessWidget {
  final IconData icon; final String val; final Color col;
  const _WxBannerItem(this.icon, this.val, this.col);
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: col, size: 10),
          const SizedBox(width: 3),
          Text(val, style: TextStyle(
              color: col, fontSize: 9, fontWeight: FontWeight.w700)),
        ],
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// SORT CHIPS
// ══════════════════════════════════════════════════════════════════════════════
class _SortChips extends StatelessWidget {
  final String current;
  final String sortLabel, riskLabel, levelLabel, rainLabel;
  final ValueChanged<String> onChange;
  const _SortChips({
    required this.current,    required this.sortLabel,
    required this.riskLabel,  required this.levelLabel,
    required this.rainLabel,  required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final opts = [
      ('risk',  Icons.crisis_alert_rounded, riskLabel),
      ('level', Icons.water_rounded,        levelLabel),
      ('rain',  Icons.grain_rounded,        rainLabel),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Text(sortLabel,
              style: TextStyle(
                fontSize: 10,
                color: AppPalette.textGrey.withValues(alpha: 0.60),
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(width: 8),
          ...opts.map((o) {
            final active = current == o.$1;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onChange(o.$1);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: active
                      ? AppPalette.cyan.withValues(alpha: 0.12)
                      : AppPalette.abyss2,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: active
                        ? AppPalette.cyan.withValues(alpha: 0.40)
                        : AppPalette.abyssStroke,
                    width: active ? 1.5 : 1,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(o.$2,
                      size: 11,
                      color: active ? AppPalette.cyan : AppPalette.textGrey),
                  const SizedBox(width: 4),
                  Text(o.$3,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                        color: active ? AppPalette.cyan : AppPalette.textGrey,
                      )),
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MONITOR CARD
// ══════════════════════════════════════════════════════════════════════════════
class _MonitorCard extends StatelessWidget {
  final FloodData         data;
  final WeatherState      wx;
  final bool              isExpanded;
  final Animation<double> pulseAnim;
  final String            safeLabel, warningLabel, dangerLabel, capacityLabel;
  final VoidCallback      onTap;
  final VoidCallback      onLongPress;
  const _MonitorCard({
    required this.data,          required this.wx,
    required this.isExpanded,    required this.pulseAnim,
    required this.safeLabel,     required this.warningLabel,
    required this.dangerLabel,   required this.capacityLabel,
    required this.onTap,         required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final col    = data.priorityColor;
    final fill   = (data.capacityPercent / 100).clamp(0.0, 1.0);
    final isCrit = data.riskLevel == 'CRITICAL' || data.riskLevel == 'SEVERE';
    final hasWx  = wx.status == WeatherStatus.loaded;

    return GestureDetector(
      onTap:       onTap,
      onLongPress: onLongPress,
      child: AnimatedBuilder(
        animation: pulseAnim,
        builder: (_, __) => AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isExpanded ? col.withValues(alpha: 0.06) : AppPalette.abyss2,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isExpanded || isCrit
                  ? col.withValues(alpha:
                      isExpanded ? 0.40 : 0.14 + 0.12 * pulseAnim.value)
                  : AppPalette.abyssStroke,
              width: isExpanded ? 1.5 : 1,
            ),
            boxShadow: (isExpanded || isCrit)
                ? [
                    BoxShadow(
                      color: col.withValues(
                          alpha: isExpanded ? 0.14 : 0.05 * pulseAnim.value),
                      blurRadius: 20, offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: col.withValues(alpha: 0.10),
                      border: Border.all(
                        color: col.withValues(
                          alpha: isCrit
                              ? 0.22 + 0.18 * pulseAnim.value
                              : 0.25,
                        ),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(_iconFor(data.riskLevel), color: col, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                data.city,
                                style: const TextStyle(
                                  color: AppPalette.textWhite,
                                  fontSize: 15, fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            _RiskChip(label: data.riskLevel, color: col),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _subLine,
                          style: const TextStyle(
                              color: AppPalette.textGrey, fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Tap arrow → city detail
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.pushNamed(
                        context, '/city_detail',
                        arguments: data.city,
                      );
                    },
                    child: Container(
                      width: 32, height: 32,
                      margin: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        color: col.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: col.withValues(alpha: 0.22)),
                      ),
                      child: Icon(Icons.chevron_right_rounded,
                          color: col, size: 18),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${data.currentLevel.toStringAsFixed(2)} m',
                        style: TextStyle(
                          color: col, fontSize: 20,
                          fontWeight: FontWeight.w900, letterSpacing: -0.8,
                        ),
                      ),
                      Text('${data.capacityPercent.toStringAsFixed(0)}% $capacityLabel',
                          style: const TextStyle(
                              color: AppPalette.textGrey, fontSize: 9.5)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Stack(
                children: [
                  Container(
                    height: 7,
                    decoration: BoxDecoration(
                        color: AppPalette.abyss4,
                        borderRadius: BorderRadius.circular(4)),
                  ),
                  FractionallySizedBox(
                    widthFactor: fill,
                    child: Container(
                      height: 7,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: [col.withValues(alpha: 0.45), col]),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                              color: col.withValues(alpha: 0.45),
                              blurRadius: 6),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (hasWx && !isExpanded)
                _WxCollapsedStrip(wx: wx, floodRain: data.effectiveRainfallMm),
              if (!hasWx && !isExpanded)
                _SubLine(
                  warning: data.warningLevel,
                  danger:  data.dangerLevel,
                  rain:    data.effectiveRainfallMm,
                  river:   data.riverName,
                ),
              AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                child: isExpanded
                    ? _ExpandPanel(
                        data:         data,
                        wx:           wx,
                        safeLabel:    safeLabel,
                        warningLabel: warningLabel,
                        dangerLabel:  dangerLabel,
                      )
                    : const SizedBox.shrink(),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Center(
                  child: AnimatedRotation(
                    turns:    isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 260),
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: AppPalette.textDim.withValues(alpha: 0.6),
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _subLine {
    final p = <String>[];
    if ((data.riverName ?? '').isNotEmpty) p.add(data.riverName!);
    if (data.district.isNotEmpty)          p.add(data.district);
    if (data.state.isNotEmpty)             p.add(data.state);
    return p.join('  ·  ');
  }

  IconData _iconFor(String r) => switch (r) {
    'CRITICAL' => Icons.crisis_alert_rounded,
    'SEVERE'   => Icons.error_outline_rounded,
    'MODERATE' => Icons.warning_amber_rounded,
    _          => Icons.check_circle_outline_rounded,
  };
}

// ──────────────────────────────────────────────────────────────────────────────
// COLLAPSED WEATHER STRIP
// ──────────────────────────────────────────────────────────────────────────────
class _WxCollapsedStrip extends StatelessWidget {
  final WeatherState wx;
  final double       floodRain;
  const _WxCollapsedStrip({required this.wx, required this.floodRain});

  @override
  Widget build(BuildContext context) {
    final indexColor = wx.rainfallIndex > 70
        ? AppPalette.critical
        : wx.rainfallIndex > 45
            ? AppPalette.danger
            : wx.rainfallIndex > 25
                ? AppPalette.amber
                : AppPalette.safe;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: AppPalette.abyss4,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppPalette.cyan.withValues(alpha: 0.10)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(child: _WxCol(
              icon:  Icons.thermostat_rounded,
              value: '${wx.tempC.toStringAsFixed(1)}°',
              label: 'Temp', color: AppPalette.amber,
            )),
            _vBar(),
            Expanded(child: _WxCol(
              icon:  Icons.grain_rounded,
              value: '${wx.rainfall7dMm.toStringAsFixed(0)}mm',
              label: '7d Rain', color: AppPalette.cyan,
            )),
            _vBar(),
            Expanded(child: _WxCol(
              icon:  Icons.analytics_rounded,
              value: '${wx.rainfallIndex.toStringAsFixed(0)}/100',
              label: 'Rain Idx', color: indexColor,
            )),
            _vBar(),
            Expanded(child: _WxCol(
              icon:  Icons.umbrella_rounded,
              value: '${wx.maxPrecipProb.toStringAsFixed(0)}%',
              label: 'Rain Prob', color: AppPalette.amber,
            )),
            _vBar(),
            Expanded(child: _WxCol(
              icon:  Icons.water_drop_rounded,
              value: '${wx.humidity}%',
              label: 'Humidity', color: const Color(0xFF64B5F6),
            )),
          ],
        ),
      ),
    );
  }

  Widget _vBar() => const VerticalDivider(
        width: 16, thickness: 1, color: AppPalette.abyssStroke);
}

class _WxCol extends StatelessWidget {
  final IconData icon; final String value, label; final Color color;
  const _WxCol({
    required this.icon, required this.value,
    required this.label, required this.color,
  });
  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 10),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                color: color, fontSize: 9, fontWeight: FontWeight.w800),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center),
          const SizedBox(height: 1),
          Text(label,
              style: const TextStyle(
                color: AppPalette.textDim, fontSize: 7,
                fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
        ],
      );
}

class _RiskChip extends StatelessWidget {
  final String label; final Color color;
  const _RiskChip({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color:        color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(6),
          border:       Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Text(label, style: TextStyle(
          color: color, fontSize: 8, fontWeight: FontWeight.w900)),
      );
}

class _SubLine extends StatelessWidget {
  final double warning, danger, rain; final String? river;
  const _SubLine({
    required this.warning, required this.danger,
    required this.rain,    this.river,
  });
  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _mini('W ${warning.toStringAsFixed(1)} m', AppPalette.amber),
          if (river != null && river!.isNotEmpty)
            Flexible(child: _mini(river!, AppPalette.textDim)),
          _mini('D ${danger.toStringAsFixed(1)} m', AppPalette.danger),
          _mini('${rain.toStringAsFixed(1)} mm', AppPalette.cyan),
        ],
      );
  Widget _mini(String t, Color c) => Text(t,
      style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.w600),
      overflow: TextOverflow.ellipsis);
}

// ══════════════════════════════════════════════════════════════════════════════
// EXPAND PANEL
// ══════════════════════════════════════════════════════════════════════════════
class _ExpandPanel extends StatelessWidget {
  final FloodData    data;
  final WeatherState wx;
  final String       safeLabel, warningLabel, dangerLabel;
  const _ExpandPanel({
    required this.data, required this.wx,
    required this.safeLabel, required this.warningLabel,
    required this.dangerLabel,
  });

  @override
  Widget build(BuildContext context) {
    final col    = data.priorityColor;
    final hasWx  = wx.status == WeatherStatus.loaded;
    final indexColor = hasWx
        ? (wx.rainfallIndex > 70
            ? AppPalette.critical
            : wx.rainfallIndex > 45
                ? AppPalette.danger
                : wx.rainfallIndex > 25
                    ? AppPalette.amber
                    : AppPalette.safe)
        : AppPalette.textDim;

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        children: [
          _gradientDivider(col.withValues(alpha: 0.30)),
          const SizedBox(height: 14),
          if (hasWx) ...[
            _sectionLabel('WEATHER FEED', AppPalette.cyan,
                sub: wx.cityName.split(',').first),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _WxDetailTile(
                icon: Icons.thermostat_rounded, label: 'Temperature',
                value: '${wx.tempC.toStringAsFixed(1)}°C',
                color: AppPalette.amber,
              )),
              const SizedBox(width: 8),
              Expanded(child: _WxDetailTile(
                icon: Icons.device_thermostat_rounded, label: 'Feels Like',
                value: '${wx.current!.feelsLikeC.toStringAsFixed(1)}°C',
                color: AppPalette.amber,
              )),
              const SizedBox(width: 8),
              Expanded(child: _WxDetailTile(
                icon: Icons.water_drop_rounded, label: 'Humidity',
                value: '${wx.humidity}%',
                color: const Color(0xFF64B5F6),
              )),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _WxDetailTile(
                icon: Icons.grain_rounded, label: '7-Day Rain',
                value: '${wx.rainfall7dMm.toStringAsFixed(1)} mm',
                color: AppPalette.cyan,
              )),
              const SizedBox(width: 8),
              Expanded(child: _WxDetailTile(
                icon: Icons.analytics_rounded, label: 'Rain Index',
                value: '${wx.rainfallIndex.toStringAsFixed(0)}/100',
                color: indexColor,
                isHighlight: wx.rainfallIndex > 45,
              )),
              const SizedBox(width: 8),
              Expanded(child: _WxDetailTile(
                icon: Icons.umbrella_rounded, label: 'Precip Prob',
                value: '${wx.maxPrecipProb.toStringAsFixed(0)}%',
                color: AppPalette.amber,
              )),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _WxDetailTile(
                icon: Icons.air_rounded, label: 'Wind',
                value: '${wx.windKph.toStringAsFixed(0)} km/h',
                color: const Color(0xFF64B5F6),
              )),
              const SizedBox(width: 8),
              Expanded(child: _WxDetailTile(
                icon: Icons.wb_sunny_rounded, label: 'UV Index',
                value: wx.current!.uvIndex.toStringAsFixed(1),
                color: AppPalette.amber,
              )),
              const SizedBox(width: 8),
              Expanded(child: _WxDetailTile(
                icon: Icons.water_rounded, label: 'Now Precip',
                value: '${wx.precipMm.toStringAsFixed(1)} mm',
                color: AppPalette.cyan,
              )),
            ]),
            const SizedBox(height: 14),
            _gradientDivider(AppPalette.abyssStroke),
            const SizedBox(height: 14),
          ],
          _sectionLabel('RIVER DATA', AppPalette.textGrey, accentColor: col),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _ThresholdPill(
                label: safeLabel,
                value: '${data.safeLevel.toStringAsFixed(1)} m',
                color: AppPalette.safe)),
            const SizedBox(width: 8),
            Expanded(child: _ThresholdPill(
                label: warningLabel,
                value: '${data.warningLevel.toStringAsFixed(1)} m',
                color: AppPalette.amber)),
            const SizedBox(width: 8),
            Expanded(child: _ThresholdPill(
                label: dangerLabel,
                value: '${data.dangerLevel.toStringAsFixed(1)} m',
                color: AppPalette.critical)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _InfoTile(
              icon: Icons.grain_rounded, label: 'Station Rain',
              value: '${data.effectiveRainfallMm.toStringAsFixed(1)} mm',
              color: AppPalette.cyan,
            )),
            const SizedBox(width: 8),
            Expanded(child: _InfoTile(
              icon: Icons.speed_rounded, label: 'Flow Rate',
              value: data.flowRate != null
                  ? '${data.flowRate!.toStringAsFixed(0)} m³/s' : '—',
              color: AppPalette.cyan,
            )),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _InfoTile(
              icon: Icons.thermostat_rounded, label: 'IMD Severity',
              value: data.imdSeverity ?? '—',
              color: AppPalette.amber,
            )),
            const SizedBox(width: 8),
            Expanded(child: _InfoTile(
              icon: Icons.cloud_rounded, label: 'IMD Rain',
              value: data.imdRainfallMm != null
                  ? '${data.imdRainfallMm!.toStringAsFixed(1)} mm' : '—',
              color: AppPalette.amber,
            )),
          ]),
          const SizedBox(height: 8),
          _GapBar(
            current: data.currentLevel,
            danger:  data.dangerLevel,
            color:   col,
          ),
          const SizedBox(height: 8),
          Row(children: [
            _StatusBadge(status: data.status),
            const Spacer(),
            Text(
              DateFormat('dd MMM HH:mm').format(data.lastUpdated.toLocal()),
              style: const TextStyle(color: AppPalette.textDim, fontSize: 9.5),
            ),
          ]),
          const SizedBox(height: 12),
          // ── Detail button ──
          GestureDetector(
            onTap: () => Navigator.pushNamed(
              context, '/city_detail', arguments: data.city),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: col.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: col.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.open_in_new_rounded, color: col, size: 13),
                  const SizedBox(width: 6),
                  Text('View Full Detail for ${data.city}',
                      style: TextStyle(
                        color: col, fontSize: 11,
                        fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gradientDivider(Color mid) => Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [Colors.transparent, mid, Colors.transparent]),
        ),
      );

  Widget _sectionLabel(String label, Color color,
      {String? sub, Color? accentColor}) {
    return Row(children: [
      Container(
        width: 3, height: 12,
        decoration: BoxDecoration(
          color: accentColor ?? color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(
        color: color, fontSize: 9,
        fontWeight: FontWeight.w900, letterSpacing: 1.0)),
      if (sub != null) ...[
        const SizedBox(width: 4),
        Text('· $sub',
            style: const TextStyle(color: AppPalette.textDim, fontSize: 9)),
      ],
    ]);
  }
}

class _WxDetailTile extends StatelessWidget {
  final IconData icon; final String label, value; final Color color;
  final bool isHighlight;
  const _WxDetailTile({
    required this.icon, required this.label,
    required this.value, required this.color,
    this.isHighlight = false,
  });
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        decoration: BoxDecoration(
          color: isHighlight
              ? color.withValues(alpha: 0.08)
              : AppPalette.abyss4,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isHighlight
                ? color.withValues(alpha: 0.25)
                : AppPalette.abyssStroke,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w900),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    color: AppPalette.textDim, fontSize: 7.5),
                textAlign: TextAlign.center),
          ],
        ),
      );
}

class _ThresholdPill extends StatelessWidget {
  final String label, value; final Color color;
  const _ThresholdPill({
    required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color:        color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w800),
              overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(
              color: AppPalette.textDim, fontSize: 8)),
          ],
        ),
      );
}

class _InfoTile extends StatelessWidget {
  final IconData icon; final String label, value; final Color color;
  const _InfoTile({
    required this.icon, required this.label,
    required this.value, required this.color,
  });
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color:        AppPalette.abyss4,
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: AppPalette.abyssStroke),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(
                color: AppPalette.textWhite, fontSize: 11,
                fontWeight: FontWeight.w800),
                overflow: TextOverflow.ellipsis),
              Text(label, style: const TextStyle(
                color: AppPalette.textDim, fontSize: 8.5)),
            ],
          )),
        ]),
      );
}

class _GapBar extends StatelessWidget {
  final double current, danger; final Color color;
  const _GapBar({
    required this.current, required this.danger, required this.color});
  @override
  Widget build(BuildContext context) {
    final gap     = (danger - current).clamp(0.0, danger);
    final isAbove = current >= danger;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color:        AppPalette.abyss4,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: AppPalette.abyssStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  isAbove
                      ? '⚠ ${(current - danger).abs().toStringAsFixed(2)} m above danger'
                      : '${gap.toStringAsFixed(2)} m to danger level',
                  style: TextStyle(
                    fontSize: 10,
                    color: isAbove ? AppPalette.critical : AppPalette.textGrey,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text('D: ${danger.toStringAsFixed(1)} m',
                  style: const TextStyle(
                      color: AppPalette.textDim, fontSize: 9.5)),
            ],
          ),
          const SizedBox(height: 6),
          Stack(
            children: [
              Container(
                height: 5,
                decoration: BoxDecoration(
                  color: AppPalette.abyssStroke,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              FractionallySizedBox(
                widthFactor: (current / math.max(danger, 1)).clamp(0.0, 1.0),
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [color.withValues(alpha: 0.4), color]),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                          color: color.withValues(alpha: 0.4), blurRadius: 4),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    final isLive = status.toUpperCase() == 'LIVE' ||
        status.toUpperCase() == 'REAL';
    final c = isLive ? AppPalette.safe : AppPalette.textDim;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 5, height: 5,
          decoration: BoxDecoration(shape: BoxShape.circle, color: c),
        ),
        const SizedBox(width: 4),
        Text(status.toUpperCase(),
            style: TextStyle(
              color: c, fontSize: 8, fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            )),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// EMPTY STATE
// ══════════════════════════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  final bool   isLoading;
  final String loadingLabel, noDataLabel;
  const _EmptyState({
    required this.isLoading,
    required this.loadingLabel,
    required this.noDataLabel,
  });
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    AppPalette.cyan.withValues(alpha: 0.12),
                    AppPalette.abyss2,
                  ]),
                  border: Border.all(
                      color: AppPalette.cyan.withValues(alpha: 0.20)),
                ),
                child: Icon(
                  isLoading
                      ? Icons.hourglass_top_rounded
                      : Icons.sensors_off_rounded,
                  color: AppPalette.cyan, size: 36,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                isLoading ? loadingLabel : noDataLabel,
                style: const TextStyle(
                  color: AppPalette.textGrey,
                  fontSize: 14, fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              if (isLoading) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: 24, height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppPalette.cyan.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
}
