import 'package:flutter/material.dart';
import 'package:vidviz/model/app_settings.dart';
import 'package:vidviz/service/settings_service.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/core/theme.dart' as app_theme;
import 'package:vidviz/l10n/generated/app_localizations.dart';

/// Application settings screen.
/// Theme and language toggles will be added later; for now we expose
/// important maintenance actions like cache clearing.
class SettingsScreen extends StatelessWidget {
  SettingsScreen({Key? key}) : super(key: key);

  final AppSettingsService _settingsService = locator.get<AppSettingsService>();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    
    return Scaffold(
      backgroundColor: isDark ? app_theme.projectListBg : app_theme.background,
      appBar: AppBar(
        backgroundColor: isDark ? app_theme.projectListBg : app_theme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          loc.settingsTitle,
          style: TextStyle(
            color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<AppSettings>(
        stream: _settingsService.settings$,
        initialData: _settingsService.settings,
        builder: (context, snapshot) {
          final settings = snapshot.data ?? _settingsService.settings;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildAppearanceSection(context, settings),
              const SizedBox(height: 20),
              _buildPerformanceSection(context),
              const SizedBox(height: 20),
              _buildAdvancedSection(context),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }


  Widget _buildAppearanceSection(BuildContext context, AppSettings settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            loc.appearanceSectionTitle,
            style: TextStyle(
              color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        
        // Theme Card
        Container(
          decoration: BoxDecoration(
            color: isDark ? app_theme.projectListCardBg : app_theme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? app_theme.projectListCardBorder : app_theme.border,
            ),
          ),
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  Icons.color_lens_outlined,
                  color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
                ),
                title: Text(
                  loc.themeLabel,
                  style: TextStyle(
                    color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  settings.themeMode == 'system'
                      ? loc.themeSubtitleSystem
                      : (settings.themeMode == 'light'
                          ? loc.themeOptionLight
                          : loc.themeOptionDark),
                  style: TextStyle(
                    color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                trailing: DropdownButton<String>(
                  value: settings.themeMode,
                  dropdownColor: isDark ? app_theme.projectListCardBg : app_theme.surface,
                  style: TextStyle(
                    color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
                    fontSize: 14,
                  ),
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'system', child: Text('System')),
                    DropdownMenuItem(value: 'light', child: Text('Light')),
                    DropdownMenuItem(value: 'dark', child: Text('Dark')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      _settingsService.setThemeMode(value);
                    }
                  },
                ),
              ),
              Divider(
                height: 1,
                color: isDark ? app_theme.projectListCardBorder : app_theme.border,
              ),
              Builder(
                builder: (context) {
                  String languageLabel;
                  switch (settings.localeCode) {
                    case 'tr':
                      languageLabel = loc.languageOptionTurkish;
                      break;
                    case 'es':
                      languageLabel = loc.languageOptionSpanish;
                      break;
                    case 'pt':
                      languageLabel = loc.languageOptionPortuguese;
                      break;
                    case 'hi':
                      languageLabel = loc.languageOptionHindi;
                      break;
                    case 'zh':
                      languageLabel = loc.languageOptionChinese;
                      break;
                    case 'ar':
                      languageLabel = loc.languageOptionArabic;
                      break;
                    case 'fr':
                      languageLabel = loc.languageOptionFrench;
                      break;
                    case 'de':
                      languageLabel = loc.languageOptionGerman;
                      break;
                    case 'ru':
                      languageLabel = loc.languageOptionRussian;
                      break;
                    case 'ja':
                      languageLabel = loc.languageOptionJapanese;
                      break;
                    case 'ko':
                      languageLabel = loc.languageOptionKorean;
                      break;
                    case 'en':
                    default:
                      languageLabel = loc.languageOptionEnglish;
                      break;
                  }
                  return ListTile(
                    leading: Icon(
                      Icons.language_outlined,
                      color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
                    ),
                    title: Text(
                      loc.languageLabel,
                      style: TextStyle(
                        color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      languageLabel,
                      style: TextStyle(
                        color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    trailing: DropdownButton<String>(
                      value: settings.localeCode,
                      dropdownColor: isDark
                          ? app_theme.projectListCardBg
                          : app_theme.surface,
                      style: TextStyle(
                        color: isDark
                            ? app_theme.darkTextPrimary
                            : app_theme.textPrimary,
                        fontSize: 14,
                      ),
                      underline: const SizedBox(),
                      items: [
                        DropdownMenuItem(
                          value: 'en',
                          child: Text(loc.languageOptionEnglish),
                        ),
                        DropdownMenuItem(
                          value: 'tr',
                          child: Text(loc.languageOptionTurkish),
                        ),
                        DropdownMenuItem(
                          value: 'es',
                          child: Text(loc.languageOptionSpanish),
                        ),
                        DropdownMenuItem(
                          value: 'pt',
                          child: Text(loc.languageOptionPortuguese),
                        ),
                        DropdownMenuItem(
                          value: 'hi',
                          child: Text(loc.languageOptionHindi),
                        ),
                        DropdownMenuItem(
                          value: 'zh',
                          child: Text(loc.languageOptionChinese),
                        ),
                        DropdownMenuItem(
                          value: 'ar',
                          child: Text(loc.languageOptionArabic),
                        ),
                        DropdownMenuItem(
                          value: 'fr',
                          child: Text(loc.languageOptionFrench),
                        ),
                        DropdownMenuItem(
                          value: 'de',
                          child: Text(loc.languageOptionGerman),
                        ),
                        DropdownMenuItem(
                          value: 'ru',
                          child: Text(loc.languageOptionRussian),
                        ),
                        DropdownMenuItem(
                          value: 'ja',
                          child: Text(loc.languageOptionJapanese),
                        ),
                        DropdownMenuItem(
                          value: 'ko',
                          child: Text(loc.languageOptionKorean),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          _settingsService.setLocaleCode(value);
                        }
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            loc.performanceSectionTitle,
            style: TextStyle(
              color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        
        // Cache Cards
        Container(
          decoration: BoxDecoration(
            color: isDark ? app_theme.projectListCardBg : app_theme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? app_theme.projectListCardBorder : app_theme.border,
            ),
          ),
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  Icons.graphic_eq,
                  color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
                ),
                title: Text(
                  loc.clearVisualizerCacheTitle,
                  style: TextStyle(
                    color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  loc.clearVisualizerCacheSubtitle,
                  style: TextStyle(
                    color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                ),
                onTap: () {
                  _settingsService.clearVisualizerCache();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        loc.clearVisualizerCacheSnack,
                        style: TextStyle(
                          color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
                        ),
                      ),
                      backgroundColor: isDark ? app_theme.projectListCardBg : app_theme.surface,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              Divider(
                height: 1,
                color: isDark ? app_theme.projectListCardBorder : app_theme.border,
              ),
              ListTile(
                leading: Icon(
                  Icons.multitrack_audio,
                  color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
                ),
                title: Text(
                  loc.clearAudioReactiveCacheTitle,
                  style: TextStyle(
                    color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  loc.clearAudioReactiveCacheSubtitle,
                  style: TextStyle(
                    color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                ),
                onTap: () {
                  _settingsService.clearAudioReactiveCache();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        loc.clearAudioReactiveCacheSnack,
                        style: TextStyle(
                          color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
                        ),
                      ),
                      backgroundColor: isDark ? app_theme.projectListCardBg : app_theme.surface,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            loc.advancedSectionTitle,
            style: TextStyle(
              color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        
        // Reset Card
        Container(
          decoration: BoxDecoration(
            color: isDark ? app_theme.projectListCardBg : app_theme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? app_theme.projectListCardBorder : app_theme.border,
            ),
          ),
          child: ListTile(
            leading: Icon(
              Icons.restore,
              color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
            ),
            title: Text(
              loc.resetSettingsTitle,
              style: TextStyle(
                color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              loc.resetSettingsSubtitle,
              style: TextStyle(
                color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                fontSize: 13,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
            ),
            onTap: () {
              _settingsService.resetToDefaults();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    loc.resetSettingsSnack,
                    style: TextStyle(
                      color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
                    ),
                  ),
                  backgroundColor: isDark ? app_theme.projectListCardBg : app_theme.surface,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
