import 'package:flutter/material.dart';
import 'package:vidviz/l10n/generated/app_localizations.dart';
import 'package:vidviz/core/theme.dart' as app_theme;
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/director_service.dart';
import 'package:vidviz/model/video_settings.dart';

class VideoSettingsForm extends StatelessWidget {
  final VideoSettings _settings;
  final directorService = locator.get<DirectorService>();

  VideoSettingsForm(this._settings);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<VideoSettings?>(
      stream: directorService.editingVideoSettings$,
      initialData: _settings,
      builder: (context, snapshot) {
        VideoSettings currentSettings = snapshot.data ?? _settings;

        // Text editor gibi tasarım: Sol SubMenu + Sağ Kontroller
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SubMenu(),

            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  padding: EdgeInsets.only(left: 16.0,top: 8.0),
                  color: isDark ? app_theme.projectListBg : app_theme.background,
                  width: MediaQuery.of(context).size.width - 120,
                  child: Wrap(
                    spacing: 0.0,
                    runSpacing: 0.0,
                    children: [
                      _AspectRatio(currentSettings),
                      _CropMode(currentSettings),
                      _Rotation(currentSettings),
                      _FlipOptions(currentSettings),
                      _BackgroundColor(currentSettings),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SubMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? app_theme.projectListCardBg : app_theme.surface, // Daha belirgin arka plan
      //margin: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          IconButton(
            icon: Icon(Icons.settings, color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

class _AspectRatio extends StatelessWidget {
  final directorService = locator.get<DirectorService>();
  final VideoSettings _settings;

  _AspectRatio(this._settings);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final ratios = ['16:9', '9:16', '1:1', '4:3', '21:9'];

    return Container(
      /// iki defa verilince kesiyo width: MediaQuery.of(context).size.width - 120,
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.videoSettingsAspectRatioLabel,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary
            ),
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ratios.map((ratio) {
              final isSelected = _settings.aspectRatio == ratio;
              return InkWell(
                onTap: () {
                  final updated = VideoSettings.clone(_settings)
                    ..aspectRatio = ratio;
                  directorService.editingVideoSettings = updated;
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? app_theme.accent.withOpacity(0.2) : (isDark ? app_theme.projectListCardBg : app_theme.surface), // Pasif butonlar kart renginde
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? app_theme.accent : (isDark ? app_theme.projectListCardBorder : app_theme.border),
                    ),
                    boxShadow: isSelected ? [] : [ // Hafif gölge ekleyerek kart hissini güçlendir
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      )
                    ],
                  ),
                  child: Text(
                    ratio,
                    style: TextStyle(
                      color: isSelected ? app_theme.accent : (isDark ? app_theme.darkTextSecondary : app_theme.textSecondary),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _CropMode extends StatelessWidget {
  final directorService = locator.get<DirectorService>();
  final VideoSettings _settings;

  _CropMode(this._settings);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final modes = {
      'fit': loc.videoSettingsCropModeFit,
      'fill': loc.videoSettingsCropModeFill,
      'stretch': loc.videoSettingsCropModeStretch,
    };

    return Container(
      /// iki defa verilince kesiyo width: MediaQuery.of(context).size.width - 120,
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.videoSettingsCropModeLabel,
            style: TextStyle(
              fontSize: 16, 
              fontWeight: FontWeight.w600,
              color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary
            ),
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: modes.entries.map((entry) {
              final isSelected = _settings.cropMode == entry.key;
              return InkWell(
                onTap: () {
                  final updated = VideoSettings.clone(_settings)..cropMode = entry.key;
                  directorService.editingVideoSettings = updated;
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? app_theme.accent.withOpacity(0.2) : (isDark ? app_theme.projectListCardBg : app_theme.surface),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? app_theme.accent : (isDark ? app_theme.projectListCardBorder : app_theme.border),
                    ),
                    boxShadow: isSelected ? [] : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      )
                    ],
                  ),
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      color: isSelected ? app_theme.accent : (isDark ? app_theme.darkTextSecondary : app_theme.textSecondary),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _Rotation extends StatelessWidget {
  final directorService = locator.get<DirectorService>();
  final VideoSettings _settings;

  _Rotation(this._settings);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final rotations = [0, 90, 180, 270];

    return Container(
      /// iki defa verilince kesiyo  width: MediaQuery.of(context).size.width - 120,
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).videoSettingsRotationLabel,
            style: TextStyle(
              fontSize: 16, 
              fontWeight: FontWeight.w600,
              color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary
            ),
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: rotations.map((rotation) {
              final isSelected = _settings.rotation == rotation;
              return InkWell(
                onTap: () {
                  final updated = VideoSettings.clone(_settings)
                    ..rotation = rotation;
                  directorService.editingVideoSettings = updated;
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? app_theme.accent.withOpacity(0.2)
                        : (isDark ? app_theme.projectListCardBg : app_theme.surface),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? app_theme.accent : (isDark ? app_theme.projectListCardBorder : app_theme.border),
                    ),
                    boxShadow: isSelected ? [] : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      )
                    ],
                  ),
                  child: Text(
                    '$rotation°',
                    style: TextStyle(
                      color: isSelected
                          ? app_theme.accent
                          : (isDark ? app_theme.darkTextSecondary : app_theme.textSecondary),
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _FlipOptions extends StatelessWidget {
  final directorService = locator.get<DirectorService>();
  final VideoSettings _settings;

  _FlipOptions(this._settings);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    return Container(
      /// iki defa verilince kesiyo width: MediaQuery.of(context).size.width - 120,
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.videoSettingsFlipLabel,
            style: TextStyle(
              fontSize: 16, 
              fontWeight: FontWeight.w600,
              color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              InkWell(
                onTap: () {
                  final updated = VideoSettings.clone(_settings)
                    ..flipHorizontal = !_settings.flipHorizontal;
                  directorService.editingVideoSettings = updated;
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _settings.flipHorizontal
                        ? app_theme.accent.withOpacity(0.2)
                        : (isDark ? app_theme.projectListCardBg : app_theme.surface),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _settings.flipHorizontal ? app_theme.accent : (isDark ? app_theme.projectListCardBorder : app_theme.border),
                    ),
                    boxShadow: _settings.flipHorizontal ? [] : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.flip,
                        color: _settings.flipHorizontal
                            ? app_theme.accent
                            : (isDark ? app_theme.darkTextSecondary : app_theme.textSecondary),
                        size: 16,
                      ),
                      SizedBox(width: 4),
                      Text(
                        loc.videoSettingsFlipHorizontal,
                        style: TextStyle(
                          color: _settings.flipHorizontal
                              ? app_theme.accent
                              : (isDark ? app_theme.darkTextSecondary : app_theme.textSecondary),
                          fontWeight: _settings.flipHorizontal
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 8),
              InkWell(
                onTap: () {
                  final updated = VideoSettings.clone(_settings)
                    ..flipVertical = !_settings.flipVertical;
                  directorService.editingVideoSettings = updated;
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _settings.flipVertical
                        ? app_theme.accent.withOpacity(0.2)
                        : (isDark ? app_theme.projectListCardBg : app_theme.surface),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _settings.flipVertical ? app_theme.accent : (isDark ? app_theme.projectListCardBorder : app_theme.border),
                    ),
                    boxShadow: _settings.flipVertical ? [] : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.flip,
                        color: _settings.flipVertical
                            ? app_theme.accent
                            : (isDark ? app_theme.darkTextSecondary : app_theme.textSecondary),
                        size: 16,
                      ),
                      SizedBox(width: 4),
                      Text(
                        loc.videoSettingsFlipVertical,
                        style: TextStyle(
                          color: _settings.flipVertical
                              ? app_theme.accent
                              : (isDark ? app_theme.darkTextSecondary : app_theme.textSecondary),
                          fontWeight: _settings.flipVertical
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BackgroundColor extends StatelessWidget {
  final directorService = locator.get<DirectorService>();
  final VideoSettings _settings;

  _BackgroundColor(this._settings);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final colors = {
      0xFF000000: loc.videoSettingsBackgroundBlack,
      0xFFFFFFFF: loc.videoSettingsBackgroundWhite,
      0xFF424242: loc.videoSettingsBackgroundGray,
      0xFF1976D2: loc.videoSettingsBackgroundBlue,
      0xFF388E3C: loc.videoSettingsBackgroundGreen,
      0xFFD63031: loc.videoSettingsBackgroundRed,
    };

    return Container(
      /// iki defa verilince kesiyo width: MediaQuery.of(context).size.width - 120,
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.videoSettingsBackgroundLabel,
            style: TextStyle(
              fontSize: 16, 
              fontWeight: FontWeight.w600,
              color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary
            ),
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: colors.entries.map((entry) {
              final isSelected = _settings.backgroundColor == entry.key;
              return InkWell(
                onTap: () {
                  final updated = VideoSettings.clone(_settings)
                    ..backgroundColor = entry.key;
                  directorService.editingVideoSettings = updated;
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Color(entry.key),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? app_theme.accent : (isDark ? app_theme.projectListCardBorder : app_theme.border),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      color: entry.key == 0xFFFFFFFF
                          ? Colors.black
                          : Colors.white,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
