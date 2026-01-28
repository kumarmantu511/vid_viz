import 'dart:ui' as ui;
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidviz/model/app_settings.dart';
import 'package:vidviz/service/visualizer_service.dart';
import 'package:vidviz/service/audio_reactive_service.dart';

/// Central service for global application settings.
/// Currently keeps settings in memory; persistence can be added later.
class AppSettingsService {
  final VisualizerService _visualizerService;
  final AudioReactiveService _audioReactiveService;
  final SharedPreferences _prefs;

  static const String _localeKey = 'app_locale_code';

  late final BehaviorSubject<AppSettings> _settingsSubject;

  AppSettingsService(
    this._visualizerService,
    this._audioReactiveService,
    this._prefs,
  ) {
    // 1) Daha önce kayıtlı bir dil varsa onu kullan
    final storedCode = _prefs.getString(_localeKey);

    // 2) Yoksa, sadece ilk sefer için cihaz diline bak ve kaydet
    String initialLocale;
    if (storedCode != null && storedCode.isNotEmpty) {
      initialLocale = storedCode;
    } else {
      final systemCode = ui.PlatformDispatcher.instance.locale.languageCode;
      initialLocale = (systemCode == 'tr' || systemCode == 'en') ? systemCode : 'en';
      _prefs.setString(_localeKey, initialLocale);
    }

    _settingsSubject = BehaviorSubject<AppSettings>.seeded(
      AppSettings(localeCode: initialLocale),
    );
  }

  Stream<AppSettings> get settings$ => _settingsSubject.stream;
  AppSettings get settings => _settingsSubject.value;

  void setThemeMode(String mode) {
    final next = settings.copyWith(themeMode: mode);
    _settingsSubject.add(next);
  }

  void setLocaleCode(String code) {
    _prefs.setString(_localeKey, code);
    final next = settings.copyWith(localeCode: code);
    _settingsSubject.add(next);
  }

  void resetToDefaults() {
    // Sistem diline göre başlangıç locale'ünü tekrar hesapla (ilk kurulumdaki gibi)
    final systemCode = ui.PlatformDispatcher.instance.locale.languageCode;
    final initialLocale = (systemCode == 'tr' || systemCode == 'en') ? systemCode : 'en';

    // Kalıcı depolamayı da bu yeni değere getir
    _prefs.setString(_localeKey, initialLocale);

    // Diğer ayarlar varsayılan, locale ise güncel initialLocale olacak şekilde güncelle
    _settingsSubject.add(
      const AppSettings().copyWith(localeCode: initialLocale),
    );
  }

  /// Clear cached FFT and visualizer data to free memory.
  void clearVisualizerCache() {
    _visualizerService.clearCache();
  }

  /// Clear cached audio-reactive FFT data.
  void clearAudioReactiveCache() {
    _audioReactiveService.clearCache();
  }

  void dispose() {
    _settingsSubject.close();
  }
}
