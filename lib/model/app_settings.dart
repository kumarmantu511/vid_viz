import 'package:flutter/material.dart';

/// Global application settings model
/// Prepared for theme/locale, but can be extended with more options.
class AppSettings {
  /// 'system', 'light', 'dark'
  final String themeMode;

  /// Locale code, e.g. 'en', 'es', 'tr'
  final String localeCode;

  const AppSettings({this.themeMode = 'system', this.localeCode = 'en'});

  AppSettings copyWith({String? themeMode, String? localeCode}) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      localeCode: localeCode ?? this.localeCode,
    );
  }

  ThemeMode get materialThemeMode {
    switch (themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}
