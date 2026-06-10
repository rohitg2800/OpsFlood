// lib/screens/onboarding_screen.dart
// OpsFlood — Module 8: Onboarding Walkthrough
//
// 5-page PageView first-launch walkthrough:
//   Page 0 — Welcome        : App name, tagline, hero icon
//   Page 1 — District pick  : Chip grid of 38 Bihar districts
//                              (subscribes FCM district topics on confirm)
//   Page 2 — River pick     : 7 Bihar river chips
//   Page 3 — Notification   : Request OS permission; severity toggle preview
//   Page 4 — Theme pick     : Live theme swatch grid
//   Page 5 — Done           : CTA — Enter OpsFlood
//
// On completion writes 'onboarding_done = true' to SharedPreferences.
// SplashScreen checks this flag and routes to /onboarding if false.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/theme_provider.dart';
import '../services/fcm_topic_manager.dart';
import '../theme/river_theme.dart';
import 'main_shell.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  static const String route = '/onboarding';

  @override
  ConsumerState<OnboardingScreen> createState() =>
      _OnboardingState();
}

class _OnboardingState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  final _ctrl = PageController();
  int _page = 0;
  static const _total = 6;

  // District & river selection
  final Set<String> _districts = {};
  final Set<String> _rivers    = {};

  // ── Navigation helpers

  void _next() {
    if (_page < _total - 1) {
      _ctrl.nextPage(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    // Subscribe district + river topics
    await FcmTopicManager.instance
        .setDistrictSubscriptions(_districts.toList());
    await FcmTopicManager.instance
        .setRiverSubscriptions(_rivers.toList());
    // Mark done
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (mounted) {
      Navigator.of(context)
          .pushReplacementNamed(MainShell.route);
    }
  }

  Future<void> _requestNotifPermission() async {
    await FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
            alert: true, badge: true, sound: true);
    // Android 13+ permission is handled by the OS prompt
    // triggered automatically on first notification fire.
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final t = RiverColors.of(context);
    return Scaffold(
      backgroundColor: t.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button (top-right)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: Text('Skip',
                    style: TextStyle(
                        color: t.textSecondary, fontSize: 12)),
              ),
            ),

            // Page content
            Expanded(
              child: PageView(
                controller: _ctrl,
                onPageChanged: (p) =>
                    setState(() => _page = p),
                children: [
                  _PageWelcome(t: t),
                  _PageDistricts(
                      t: t,
                      selected: _districts,
                      onToggle: (s, v) => setState(() {
                            if (v) {
                              _districts.add(s);
                            } else {
                              _districts.remove(s);
                            }
                          })),
                  _PageRivers(
                      t: t,
                      selected: _rivers,
                      onToggle: (s, v) => setState(() {
                            if (v) {
                              _rivers.add(s);
                            } else {
                              _rivers.remove(s);
                            }
                          })),
                  _PageNotifications(
                      t: t,
                      onRequest: _requestNotifPermission),
                  _PageTheme(
                      t: t,
                      onPick: (m) => ref
                          .read(themeModeProvider.notifier)
                          .setMode(m)),
                  _PageDone(t: t),
                ],
              ),
            ),

            // Dot indicator + button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  // Dots
                  Row(
                    children: List.generate(
                        _total,
                        (i) => AnimatedContainer(
                              duration: const Duration(
                                  milliseconds: 250),
                              margin: const EdgeInsets.only(
                                  right: 5),
                              width: i == _page ? 18 : 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: i == _page
                                    ? t.accent
                                    : t.stroke,
                                borderRadius:
                                    BorderRadius.circular(4),
                              ),
                            )),
                  ),
                  // Next / Done button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: t.accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _next();
                    },
                    child: Text(
                      _page == _total - 1
                          ? 'Enter OpsFlood '➜'
                          : 'Next →',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13),
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

// ────────────────────────────────────────────────────────────────────────────────
// Individual page widgets
// ────────────────────────────────────────────────────────────────────────────────

class _PageWelcome extends StatelessWidget {
  final RiverColors t;
  const _PageWelcome({required this.t});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 32, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🌊',
                style: const TextStyle(fontSize: 72)),
            const SizedBox(height: 24),
            Text('OpsFlood',
                style: TextStyle(
                    color: t.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 34,
                    letterSpacing: -0.5)),
            const SizedBox(height: 12),
            Text(
              'Real-time flood monitoring for Bihar — '  
              'live river levels, CWC alerts, AI prediction '  
              'and community incident reporting.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: t.textSecondary,
                  fontSize: 13,
                  height: 1.55),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Pill(t: t, icon: '📍', label: 'Live CWC'),
                const SizedBox(width: 8),
                _Pill(t: t, icon: '🤖', label: 'AI predict'),
                const SizedBox(width: 8),
                _Pill(t: t, icon: '📣', label: 'Alerts'),
              ],
            ),
          ],
        ),
      );
}

class _Pill extends StatelessWidget {
  final RiverColors t;
  final String icon, label;
  const _Pill({required this.t, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: t.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: t.accent.withValues(alpha: 0.35)),
        ),
        child: Text('$icon $label',
            style: TextStyle(
                color: t.accent,
                fontWeight: FontWeight.w700,
                fontSize: 11)),
      );
}

// ── Page 1: District selection

class _PageDistricts extends StatelessWidget {
  final RiverColors t;
  final Set<String> selected;
  final void Function(String, bool) onToggle;
  const _PageDistricts({
      required this.t,
      required this.selected,
      required this.onToggle});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🗺️ Select your districts',
                style: TextStyle(
                    color: t.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 20)),
            const SizedBox(height: 6),
            Text(
              'Get alerts for specific Bihar districts. '  
              'You can change this in Settings anytime.',
              style: TextStyle(
                  color: t.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 6, runSpacing: 6,
                  children:
                      FcmTopics.biharDistricts.map((slug) {
                    final active = selected.contains(slug);
                    final label = slug
                        .replaceAll('_', ' ')
                        .split(' ')
                        .map((w) => w.isEmpty
                            ? ''
                            : w[0].toUpperCase() +
                                w.substring(1))
                        .join(' ');
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onToggle(slug, !active);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(
                            milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: active
                              ? t.accent.withValues(alpha: 0.18)
                              : t.cardBg,
                          borderRadius:
                              BorderRadius.circular(16),
                          border: Border.all(
                            color: active
                                ? t.accent
                                : t.stroke,
                          ),
                        ),
                        child: Text(label,
                            style: TextStyle(
                              color: active
                                  ? t.accent
                                  : t.textSecondary,
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 11,
                            )),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      );
}

// ── Page 2: River selection

class _PageRivers extends StatelessWidget {
  final RiverColors t;
  final Set<String> selected;
  final void Function(String, bool) onToggle;
  const _PageRivers({
      required this.t,
      required this.selected,
      required this.onToggle});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🌊 Select rivers to watch',
                style: TextStyle(
                    color: t.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 20)),
            const SizedBox(height: 6),
            Text(
              'Receive push alerts when a river you follow '  
              'crosses danger or warning thresholds.',
              style: TextStyle(
                  color: t.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: FcmTopics.biharRivers.map((slug) {
                final active = selected.contains(slug);
                final label = slug
                    .replaceAll('_', ' ')
                    .split(' ')
                    .map((w) => w.isEmpty
                        ? ''
                        : w[0].toUpperCase() + w.substring(1))
                    .join(' ');
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onToggle(slug, !active);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: active
                          ? t.accent.withValues(alpha: 0.18)
                          : t.cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: active ? t.accent : t.stroke,
                          width: active ? 2 : 1),
                    ),
                    child: Text('🌊 $label',
                        style: TextStyle(
                          color: active
                              ? t.accent
                              : t.textSecondary,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 13,
                        )),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );
}

// ── Page 3: Notification permission

class _PageNotifications extends StatelessWidget {
  final RiverColors t;
  final VoidCallback onRequest;
  const _PageNotifications({
      required this.t, required this.onRequest});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 32, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🔔',
                style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 24),
            Text('Enable Alerts',
                style: TextStyle(
                    color: t.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 26)),
            const SizedBox(height: 12),
            Text(
              'OpsFlood sends real-time flood push notifications '  
              'when river levels hit danger or warning thresholds. '  
              'Emergency alerts use heads-up style for visibility.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: t.textSecondary,
                  fontSize: 12,
                  height: 1.55),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: t.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.notifications_active_rounded),
              label: const Text('Allow Notifications',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13)),
              onPressed: onRequest,
            ),
          ],
        ),
      );
}

// ── Page 4: Theme pick

const _onboardThemes = [
  (AppThemeMode.dark,        '🎨', 'Dark'),
  (AppThemeMode.ocean,       '🌊', 'Ocean'),
  (AppThemeMode.sunset,      '🌅', 'Sunset'),
  (AppThemeMode.roboticDark, '🤖', 'Robotic'),
  (AppThemeMode.light,       '☀️', 'Light'),
  (AppThemeMode.system,      '📱', 'System'),
];

class _PageTheme extends ConsumerWidget {
  final RiverColors t;
  final ValueChanged<AppThemeMode> onPick;
  const _PageTheme({required this.t, required this.onPick});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeModeProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🎨 Choose a theme',
              style: TextStyle(
                  color: t.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 22)),
          const SizedBox(height: 6),
          Text('You can change this anytime in Settings.',
              style: TextStyle(
                  color: t.textSecondary, fontSize: 12)),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _onboardThemes.map((th) {
              final active = current == th.$1;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onPick(th.$1);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: active
                        ? t.accent.withValues(alpha: 0.18)
                        : t.cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color:
                          active ? t.accent : t.stroke,
                      width: active ? 2 : 1,
                    ),
                  ),
                  child: Text('${th.$2}  ${th.$3}',
                      style: TextStyle(
                        color: active
                            ? t.accent
                            : t.textSecondary,
                        fontWeight: active
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontSize: 13,
                      )),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Page 5: Done

class _PageDone extends StatelessWidget {
  final RiverColors t;
  const _PageDone({required this.t});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 32, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('✅',
                style: const TextStyle(fontSize: 72)),
            const SizedBox(height: 24),
            Text('You\'re all set!',
                style: TextStyle(
                    color: t.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 28)),
            const SizedBox(height: 12),
            Text(
              'OpsFlood is ready. Tap "Enter OpsFlood" to '  
              'start monitoring Bihar rivers in real time.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: t.textSecondary,
                  fontSize: 13,
                  height: 1.55),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Pill2(t: t, icon: '📊', label: 'Live data'),
                const SizedBox(width: 8),
                _Pill2(t: t, icon: '🚨', label: 'Push alerts'),
                const SizedBox(width: 8),
                _Pill2(t: t, icon: '📄', label: 'PDF/CSV export'),
              ],
            ),
          ],
        ),
      );
}

class _Pill2 extends StatelessWidget {
  final RiverColors t;
  final String icon, label;
  const _Pill2(
      {required this.t, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: t.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: t.accent.withValues(alpha: 0.35)),
        ),
        child: Text('$icon $label',
            style: TextStyle(
                color: t.accent,
                fontWeight: FontWeight.w700,
                fontSize: 10)),
      );
}
