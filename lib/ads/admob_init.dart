// lib/ads/admob_init.dart
// Call AdmobInit.initialize() once in main() before runApp()

import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdmobInit {
  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }
}
