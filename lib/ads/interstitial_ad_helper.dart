// lib/ads/interstitial_ad_helper.dart
// Call InterstitialAdHelper.load() on app start
// Call InterstitialAdHelper.show() when navigating to a new screen

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_units.dart';

class InterstitialAdHelper {
  static InterstitialAd? _interstitialAd;
  static int _numLoadAttempts = 0;
  static const int _maxFailedLoadAttempts = 3;

  static void load() {
    InterstitialAd.load(
      adUnitId: AdUnits.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _numLoadAttempts = 0;
          _interstitialAd!.setImmersiveMode(true);
        },
        onAdFailedToLoad: (error) {
          _numLoadAttempts++;
          _interstitialAd = null;
          if (_numLoadAttempts < _maxFailedLoadAttempts) load();
        },
      ),
    );
  }

  static void show() {
    if (_interstitialAd == null) return;
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        load(); // preload next one
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        load();
      },
    );
    _interstitialAd!.show();
    _interstitialAd = null;
  }
}
