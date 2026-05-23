// lib/constants/constants.dart
// Barrel export — import this single file everywhere instead of individual files.
//
// MIGRATION from lib/constants.dart:
//   Old: import 'package:equinox_flood/constants.dart';
//          AppConstants.baseUrl              → AppConfig.baseUrl
//          AppConstants.criticalThreshold    → FloodThresholds.critical
//          AppConstants.criticalAlertChannelId → AlertChannels.criticalId
//          AppConstants.indianStates         → IndiaGeodata.states
//          AppConstants.monitoredCities      → IndiaGeodata.monitoredCities
//          AppConstants.riskColors           → FloodThresholds.riskColors
//
//   New: import 'package:equinox_flood/constants/constants.dart';

export 'app_config.dart';
export 'flood_thresholds.dart';
export 'alert_channels.dart';
export 'india_geodata.dart';
