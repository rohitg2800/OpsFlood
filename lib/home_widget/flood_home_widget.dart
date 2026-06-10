// lib/home_widget/flood_home_widget.dart
// OpsFlood — Module 12: Android & iOS Home-screen Widget
//
// Uses the `home_widget` package (pub.dev/packages/home_widget).
// Add to pubspec.yaml:
//   home_widget: ^0.7.0
//
// Android setup:
//   1. Create res/layout/flood_widget.xml (see below)
//   2. Create res/xml/flood_widget_info.xml (AppWidgetProviderInfo)
//   3. Register FloodWidgetProvider in AndroidManifest.xml
//
// iOS setup:
//   1. Add a Widget Extension target in Xcode
//   2. Use SwiftUI TimelineProvider; read shared UserDefaults via app group
//
// This Dart file handles:
//   - Pushing data to the widget (HomeWidget.saveWidgetData)
//   - Triggering a widget repaint (HomeWidget.updateWidget)
//   - Handling widget tap → deep-link back into the app

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

// ---------------------------------------------------------------------------
// Constants — must match Android res/xml and iOS Widget keys
// ---------------------------------------------------------------------------

const _kAppGroupId       = 'group.in.opsflood.app';  // iOS App Group
const _kAndroidWidget    = 'FloodWidgetProvider';     // AndroidManifest name
const _kIosWidget        = 'FloodWidget';             // iOS Widget kind

const _kKeyAlertTitle    = 'alert_title';
const _kKeyAlertLevel    = 'alert_level';
const _kKeyAlertSeverity = 'alert_severity';
const _kKeyStationName   = 'station_name';
const _kKeyLevelStr      = 'level_str';
const _kKeyUpdatedAt     = 'updated_at';

// ---------------------------------------------------------------------------
// FloodHomeWidget — service class (call statically)
// ---------------------------------------------------------------------------

class FloodHomeWidget {
  FloodHomeWidget._();

  // Call once from main() or after Firebase init
  static Future<void> init() async {
    await HomeWidget.setAppGroupId(_kAppGroupId);

    // Handle widget tap → navigate user to alerts screen
    HomeWidget.widgetClicked.listen((uri) {
      if (uri != null) {
        debugPrint('[HomeWidget] tapped: $uri');
        // In production: use your router to navigate
        // e.g. AppRouter.navigateTo(uri.path);
      }
    });
  }

  /// Push latest top-alert data to the widget and repaint.
  static Future<void> updateWithAlert({
    required String stationName,
    required double currentLevel,
    required double dangerLevel,
    required String severity,    // 'Emergency' | 'Danger' | 'Warning' | 'Normal'
    required String updatedAt,
  }) async {
    final pct   = (currentLevel / dangerLevel * 100).round();
    final title = '$severity at $stationName';

    await Future.wait([
      HomeWidget.saveWidgetData<String>(_kKeyAlertTitle,    title),
      HomeWidget.saveWidgetData<String>(_kKeyAlertLevel,    pct.toString()),
      HomeWidget.saveWidgetData<String>(_kKeyAlertSeverity, severity),
      HomeWidget.saveWidgetData<String>(_kKeyStationName,   stationName),
      HomeWidget.saveWidgetData<String>(_kKeyLevelStr,
          '${currentLevel.toStringAsFixed(2)} m'),
      HomeWidget.saveWidgetData<String>(_kKeyUpdatedAt,     updatedAt),
    ]);

    await HomeWidget.updateWidget(
      androidName: _kAndroidWidget,
      iOSName:     _kIosWidget,
    );

    debugPrint('[HomeWidget] Updated: $title @ $pct% of danger');
  }

  /// Push a “All Clear” / no-alert state.
  static Future<void> updateClear({
    required String stationName,
    required double currentLevel,
    required String updatedAt,
  }) async {
    await Future.wait([
      HomeWidget.saveWidgetData<String>(_kKeyAlertTitle,    'All Clear'),
      HomeWidget.saveWidgetData<String>(_kKeyAlertLevel,    '—'),
      HomeWidget.saveWidgetData<String>(_kKeyAlertSeverity, 'Normal'),
      HomeWidget.saveWidgetData<String>(_kKeyStationName,   stationName),
      HomeWidget.saveWidgetData<String>(_kKeyLevelStr,
          '${currentLevel.toStringAsFixed(2)} m'),
      HomeWidget.saveWidgetData<String>(_kKeyUpdatedAt,     updatedAt),
    ]);

    await HomeWidget.updateWidget(
      androidName: _kAndroidWidget,
      iOSName:     _kIosWidget,
    );
  }
}

// ---------------------------------------------------------------------------
// Android Widget XML stubs (place in android/app/src/main/res/)
// ---------------------------------------------------------------------------
//
// res/layout/flood_widget.xml:
// <LinearLayout xmlns:android="..."
//   android:orientation="vertical"
//   android:padding="8dp">
//   <TextView android:id="@+id/alert_title"
//     android:textSize="14sp" android:textStyle="bold" />
//   <TextView android:id="@+id/station_name"
//     android:textSize="11sp" />
//   <TextView android:id="@+id/level_str"
//     android:textSize="18sp" android:textStyle="bold" />
//   <TextView android:id="@+id/alert_level"
//     android:textSize="11sp" />
//   <TextView android:id="@+id/updated_at"
//     android:textSize="10sp" android:textColor="#888" />
// </LinearLayout>
//
// res/xml/flood_widget_info.xml:
// <appwidget-provider xmlns:android="..."
//   android:minWidth="250dp"
//   android:minHeight="110dp"
//   android:updatePeriodMillis="1800000"
//   android:initialLayout="@layout/flood_widget"
//   android:resizeMode="horizontal|vertical" />
//
// AndroidManifest.xml (inside <application>):
// <receiver android:name=".FloodWidgetProvider"
//           android:exported="true">
//   <intent-filter>
//     <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
//   </intent-filter>
//   <meta-data android:name="android.appwidget.provider"
//              android:resource="@xml/flood_widget_info" />
// </receiver>

// ---------------------------------------------------------------------------
// Widget Preview (Flutter-side debug preview card)
// ---------------------------------------------------------------------------

class FloodWidgetPreviewCard extends StatelessWidget {
  final String stationName;
  final String levelStr;
  final String alertTitle;
  final String severity;
  final String updatedAt;

  const FloodWidgetPreviewCard({
    super.key,
    required this.stationName,
    required this.levelStr,
    required this.alertTitle,
    required this.severity,
    required this.updatedAt,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (severity.toLowerCase()) {
      'emergency' => const Color(0xFFFF1744),
      'danger'    => const Color(0xFFFF6D00),
      'warning'   => const Color(0xFFFFB300),
      _           => const Color(0xFF4CAF50),
    };

    return Container(
      width:  250,
      height: 110,
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 1.5),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(.3),
              blurRadius: 12),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.water_drop, size: 14, color: color),
              const SizedBox(width: 4),
              Text('OpsFlood',
                  style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: color.withOpacity(.15),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(severity,
                    style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(alertTitle,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
          Text(stationName,
              style: const TextStyle(
                  color: Colors.white60, fontSize: 11)),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(levelStr,
                  style: TextStyle(
                      color: color,
                      fontSize: 20,
                      fontWeight: FontWeight.w900)),
              Text(updatedAt,
                  style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}
