import 'dart:io';
import 'dart:ui';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidviz/core/config.dart';

class AdService {
  static const String _backInterstitialLastShownKey = 'ad_back_interstitial_last_shown_ms';
  static const String _exportInterstitialMonthKey = 'ad_export_interstitial_month_key';
  static const String _exportInterstitialCountKey = 'ad_export_interstitial_count';

  static const int _backInterstitialCooldownMs = 10 * 60 * 1000;
  static const int _exportInterstitialEveryN = 3;

  int _exportProgressSessionCounter = 0;
  int _activeExportProgressSession = 0;

  bool get adsEnabled => enableAds;
  bool get bannerEnabled => enableAds && enableBannerAds && homeBannerAdUnitId.isNotEmpty;
  bool get interstitialEnabled => enableAds && enableInterstitialAds && exportInterstitialAdUnitId.isNotEmpty;

  String get homeBannerAdUnitId {
    if (!enableAds || !enableBannerAds) return '';
    if (Platform.isAndroid) return bannerHomeAndroid;
    if (Platform.isIOS) return bannerHomeIos;
    return '';
  }

  String get exportInterstitialAdUnitId {
    if (!enableAds || !enableInterstitialAds) return '';
    if (Platform.isAndroid) return interstitialExportAndroid;
    if (Platform.isIOS) return interstitialExportIos;
    return '';
  }

  BannerAd? createHomeBanner({
    required void Function(Ad ad) onAdLoaded,
    required void Function(Ad ad, LoadAdError error) onAdFailedToLoad,
  }) {
    final unitId = homeBannerAdUnitId;
    if (unitId.isEmpty) return null;
    return BannerAd(
      adUnitId: unitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: onAdLoaded,
        onAdFailedToLoad: onAdFailedToLoad,
      ),
    );
  }

  Future<void> showExportInterstitial() async {
    await _showInterstitial();
  }

  int beginExportProgressSession() {
    _exportProgressSessionCounter += 1;
    _activeExportProgressSession = _exportProgressSessionCounter;
    return _activeExportProgressSession;
  }

  void endExportProgressSession(int sessionId) {
    if (_activeExportProgressSession == sessionId) {
      _activeExportProgressSession = 0;
    }
  }

  bool isExportProgressSessionActive(int sessionId) {
    return sessionId != 0 && _activeExportProgressSession == sessionId;
  }

  Future<void> showExportInterstitialThrottled({int? exportProgressSessionId}) async {
    if (!interstitialEnabled) return;
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final storedMonth = prefs.getString(_exportInterstitialMonthKey);
    int count = prefs.getInt(_exportInterstitialCountKey) ?? 0;

    if (storedMonth != monthKey) {
      count = 0;
      await prefs.setString(_exportInterstitialMonthKey, monthKey);
      await prefs.setInt(_exportInterstitialCountKey, count);
    }

    count += 1;
    await prefs.setInt(_exportInterstitialCountKey, count);
    if (count % _exportInterstitialEveryN != 0) return;
    await _showInterstitial(exportProgressSessionId: exportProgressSessionId);
  }

  Future<void> showBackInterstitial() async {
    if (!interstitialEnabled) return;
    final prefs = await SharedPreferences.getInstance();
    final lastShown = prefs.getInt(_backInterstitialLastShownKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - lastShown < _backInterstitialCooldownMs) return;
    await _showInterstitial(onShown: () {
      prefs.setInt(_backInterstitialLastShownKey, now);
    });
  }

  Future<void> _showInterstitial({VoidCallback? onShown, int? exportProgressSessionId}) async {
    if (!interstitialEnabled) return;
    final unitId = exportInterstitialAdUnitId;
    if (unitId.isEmpty) return;
    InterstitialAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          if (exportProgressSessionId != null && !isExportProgressSessionActive(exportProgressSessionId)) {
            ad.dispose();
            return;
          }
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
            },
          );
          onShown?.call();
          ad.show();
        },
        onAdFailedToLoad: (error) {},
      ),
    );
  }
}
