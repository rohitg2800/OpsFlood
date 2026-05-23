// lib/constants.dart  — DEPRECATED: kept for backward-compat during migration
// TODO: Replace all imports of this file with:
//   import 'package:equinox_flood/constants/constants.dart';
// then delete this file.

// ignore_for_file: deprecated_member_use_from_same_package

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'constants/constants.dart';

@Deprecated('Use AppConfig, FloodThresholds, AlertChannels, IndiaGeodata from constants/constants.dart')
class AppConstants {
  static String get baseUrl            => AppConfig.baseUrl;
  static String get backupBaseUrl      => AppConfig.backupBaseUrl;

  static const String healthEndpoint          = AppConfig.healthEndpoint;
  static const String liveTelemetryEndpoint   = AppConfig.liveTelemetryEndpoint;
  static const String liveLevelsEndpoint      = AppConfig.liveLevelsEndpoint;
  static const String criticalAlertsEndpoint  = AppConfig.criticalAlertsEndpoint;
  static const String predictLegacyEndpoint   = AppConfig.predictLegacyEndpoint;
  static const String weatherCurrentEndpoint  = AppConfig.weatherCurrentEndpoint;
  static const String weatherForecastEndpoint = AppConfig.weatherForecastEndpoint;

  static const double criticalThreshold  = FloodThresholds.critical;
  static const double highThreshold      = FloodThresholds.high;
  static const double moderateThreshold  = FloodThresholds.moderate;

  static const double defaultDangerLevel  = FloodThresholds.defaultDangerLevel;
  static const double defaultWarningLevel = FloodThresholds.defaultWarningLevel;
  static const double defaultSafeLevel    = FloodThresholds.defaultSafeLevel;

  static const String criticalAlertChannelId   = AlertChannels.criticalId;
  static const String criticalAlertChannelName = AlertChannels.criticalName;
  static const String warningAlertChannelId    = AlertChannels.warningId;
  static const String warningAlertChannelName  = AlertChannels.warningName;

  static const Duration pollingInterval    = AppConfig.pollingInterval;
  static const int      maxRetries         = AppConfig.maxRetries;
  static const Duration shortAnimDuration  = AppConfig.shortAnimDuration;
  static const Duration longAnimDuration   = AppConfig.longAnimDuration;

  static const Map<String, int>    riskColors = FloodThresholds.riskColors;
  static const Map<String, String> riskIcons  = FloodThresholds.riskIcons;

  static const List<String> indianStates = IndiaGeodata.states;
  static const List<Map<String, dynamic>> monitoredCities = IndiaGeodata.monitoredCities;
}
