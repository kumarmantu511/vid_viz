import 'dart:ui'; // Asenkron hata yakalama için
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vidviz/service_locator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidviz/l10n/generated/app_localizations.dart';
import 'package:vidviz/ui/screens/project_list.dart';
import 'package:vidviz/service/settings_service.dart';
import 'package:vidviz/model/app_settings.dart';
import 'package:vidviz/core/theme.dart' as app_theme;


import 'core/config.dart';
import 'firebase_options.dart';

void main() async {
  // 1. Flutter motorunu başlat
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Cihaz ayarlarını yap (Yatay mod vs.) devredışı teste kullanılabilir dikey kualnıyoruz var sayılan
  /// setupDevice();

  // 3. Firebase'i başlat ve BEKLE (Güvenlik için şart, yarım saniye sürer)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 4. Hata yakalamayı aktif et
  setupAnalyticsAndCrashlytics();

  // 5. Yerel ayarları yükle
  final prefs = await SharedPreferences.getInstance();
  setupLocator(prefs);

  // 6. KRİTİK NOKTA: Reklamları başlat ama BEKLEME (Hız kazandıran yer burası)
  if (enableAds) {
    MobileAds.instance.initialize();
  }

  // 7. Uygulamayı ekrana çiz
  runApp(const MyApp());

  /// test ler için kullanacağız widget sıkışması wb
  // runApp(
  //   TestWrapper(
  //     testSize: Size(360, 640), // Test için aç
  //     // testSize: null, // Normal kullanım için kapat
  //     child: MyApp(),
  //   ),
  // );
}

void setupDevice() {
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  // Tam ekran modu
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
}

void setupAnalyticsAndCrashlytics() {
  // Flutter arayüz hatalarını yakala
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // Arka plan ve asenkron hataları yakala (Çok önemli)
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final AppSettingsService settingsService = locator.get<AppSettingsService>();
    // Analytics instance'ını al
    FirebaseAnalytics analytics = FirebaseAnalytics.instance;

    return StreamBuilder<AppSettings>(
      stream: settingsService.settings$,
      initialData: settingsService.settings,
      builder: (context, snapshot) {
        final settings = snapshot.data ?? settingsService.settings;

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: appName,
          theme: app_theme.buildLightTheme(),
          darkTheme: app_theme.buildDarkTheme(),
          themeMode: settings.materialThemeMode,
          locale: Locale(settings.localeCode),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: ProjectList(),
          navigatorObservers: [
            FirebaseAnalyticsObserver(analytics: analytics)
          ],
        );
      },
    );
  }
}