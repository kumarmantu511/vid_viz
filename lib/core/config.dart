
const String appName = 'VidViz';

const bool enableAds = true;
const bool enableBannerAds = true;
const bool enableInterstitialAds = true;

const String admobAppIdAndroid = 'ca-app-pub-3634953280076466~1258974216';
const String admobAppIdIos = '';

const String bannerHomeAndroid = 'ca-app-pub-3634953280076466/1562226546';
const String bannerHomeIos = '';

const String interstitialExportAndroid = 'ca-app-pub-3634953280076466/9085299821';
const String interstitialExportIos = '';

const bool enableProFeatures = false;  // açık kalsın
const bool proUser = false;          // zorla PRO kapat

class ProPlanConfig {
  final String id;
  final String title;
  final String subtitle;
  final String priceText;

  const ProPlanConfig({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.priceText,
  });
}

const List<ProPlanConfig> proPlansConfig = [
  ProPlanConfig(
    id: 'pro_monthly',
    title: 'Aylık PRO',
    subtitle: 'Tüm PRO özelliklere aylık erişim.',
    priceText: '₺49,99 / ay',
  ),
  ProPlanConfig(
    id: 'pro_yearly',
    title: 'Yıllık PRO',
    subtitle: 'Tüm PRO özelliklere yıllık erişim.',
    priceText: '₺299,99 / yıl',
  ),
  ProPlanConfig(
    id: 'pro_lifetime',
    title: 'Ömür Boyu PRO',
    subtitle: 'Tek sefer ödeme ile tüm PRO özellikler.',
    priceText: '₺599,99 tek sefer',
  ),
];

/// FİREBASE SETTİNGS
/// şuanlık gereksiz demolar
// const String fireapiKey = 'AIzaSyAnGHpQx6GRdiz8WjRjmsGUWsvk0gtTMPw';
// const String fireappId = '787780064793';
// const String firemessagingSenderId = '9828252526296';
// const String fireprojectId = 'vidviz-22037';
// const String firestorageBucket = 'sayhi-7baeb.appspot.com';

