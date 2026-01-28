import 'package:flutter/material.dart';
import 'package:vidviz/l10n/generated/app_localizations.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/director_service.dart';
import 'package:vidviz/service/visualizer_service.dart';
import 'package:vidviz/model/visualizer.dart';
import 'package:vidviz/core/theme.dart' as app_theme;

class ProgressForm extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset asset;

  ProgressForm(this.asset, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    if (asset.strokeWidth < 6.0) {
      Future.microtask(() {
        if (asset.strokeWidth < 6.0) {
          final updated = VisualizerAsset.clone(asset)
            ..renderMode = 'progress'
            ..strokeWidth = 6.0;
          visualizerService.editingVisualizerAsset = updated;
        }
      });
    }
    final children = <Widget>[
      _PresetSelector(asset),
      _ProgressStyleSelector(asset),
      _ThemeSelector(asset),
      _HeadAnimSelector(asset),

      _EffectAmountSlider(asset),
      _HeadEffectSlider(asset),
      _HeadSizeSlider(asset),

      _CornerRadiusSlider(asset),
      _SegmentGapSlider(asset),
      _ScaleSlider(asset),
      _ThicknessSlider(asset),
      _GlowSlider(asset),
      _SpeedSlider(asset),
      _TrackOpacitySlider(asset),
      const SizedBox(height: 8),
      Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          _ColorField(asset: asset, label: loc.visualizerColorLabel, size: 110),
          _TrackColorField(asset: asset),
          _ProgressGradientColorField(asset: asset),
        ],
      ),
      const SizedBox(height: 16),
    ];

    return SingleChildScrollView(
      child: Wrap(spacing: 0, runSpacing: 0, children: children),
    );
  }
}

class _HeadSizeSlider extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset asset;

  _HeadSizeSlider(this.asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    double current = 0.5;
    if (asset.shaderParams != null &&
        asset.shaderParams!['progressHeadSize'] is num) {
      current = (asset.shaderParams!['progressHeadSize'] as num).toDouble();
    }
    final value = current.clamp(0.0, 1.0);

    return Container(
      width: 290,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              loc.visualizerHeadSizeLabel,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
              ),
            ),
          ),
          Expanded(
            child: Slider(
              min: 0.0,
              max: 1.0,
              value: value,
              activeColor: app_theme.accent,
              inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
              onChanged: (v) {
                final updated = VisualizerAsset.clone(asset)
                  ..renderMode = 'progress';
                final params = Map<String, dynamic>.from(
                  updated.shaderParams ?? {},
                );
                params['progressHeadSize'] = v;
                updated.shaderParams = params;
                visualizerService.editingVisualizerAsset = updated;
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeadAnimSelector extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset asset;

  _HeadAnimSelector(this.asset);

  static const _options = [
    {'id': 'none'},
    {'id': 'static'},
    {'id': 'pulse'},
    {'id': 'spark'},
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final String current =
        (asset.shaderParams != null &&
            asset.shaderParams!['progressHeadStyle'] is String)
        ? (asset.shaderParams!['progressHeadStyle'] as String)
        : 'pulse';

    return Container(
      width: 290,
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              loc.visualizerHeadAnimLabel,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _options.map((opt) {
                final id = opt['id'] as String;
                final label = id == 'none'
                    ? loc.visualizerHeadAnimNone
                    : id == 'static'
                        ? loc.visualizerHeadAnimStatic
                        : id == 'pulse'
                            ? loc.visualizerHeadAnimPulse
                            : loc.visualizerHeadAnimSpark;
                final bool selected = id == current;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      if (!selected) {
                        final updated = VisualizerAsset.clone(asset)
                          ..renderMode = 'progress';
                        final params = Map<String, dynamic>.from(
                          updated.shaderParams ?? {},
                        );
                        params['progressHeadStyle'] = id;
                        if (id == 'none') {
                          params['progressHeadAmount'] = 0.0;
                        }
                        updated.shaderParams = params;
                        visualizerService.editingVisualizerAsset = updated;
                      }
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? app_theme.accent.withOpacity(0.2)
                            : (isDark ? app_theme.projectListCardBg : app_theme.surface),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: selected ? app_theme.accent : (isDark ? app_theme.projectListCardBorder : app_theme.border),
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          color: selected ? app_theme.accent : (isDark ? app_theme.darkTextSecondary : app_theme.textSecondary),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeadEffectSlider extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset asset;

  _HeadEffectSlider(this.asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    double current = 0.0;
    if (asset.shaderParams != null &&
        asset.shaderParams!['progressHeadAmount'] is num) {
      current = (asset.shaderParams!['progressHeadAmount'] as num).toDouble();
    }
    final value = current.clamp(0.0, 1.0);

    return Container(
      width: 290,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              loc.visualizerHeadEffectLabel,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
              ),
            ),
          ),
          Expanded(
            child: Slider(
              min: 0.0,
              max: 1.0,
              value: value,
              activeColor: app_theme.accent,
              inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
              onChanged: (v) {
                final updated = VisualizerAsset.clone(asset)
                  ..renderMode = 'progress';
                final params = Map<String, dynamic>.from(
                  updated.shaderParams ?? {},
                );
                params['progressHeadAmount'] = v;
                updated.shaderParams = params;
                visualizerService.editingVisualizerAsset = updated;
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetSelector extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset asset;

  _PresetSelector(this.asset);

  static const _presets = [
    {'id': 'clean'},
    {'id': 'neon'},
    {'id': 'cinematic'},
    {'id': 'glitch'},
    {'id': 'fire'},
    {'id': 'electric'},
    {'id': 'rainbow'},
    {'id': 'soft'},
    {'id': 'ice'},
    {'id': 'matrix'},
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    String current = '';
    if (asset.shaderParams != null &&
        asset.shaderParams!['progressPreset'] is String) {
      current = asset.shaderParams!['progressPreset'] as String;
    }

    return Container(
      width: 290,
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              loc.visualizerPresetsLabel,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _presets.map((opt) {
                final id = opt['id'] as String;
                final label = () {
                  switch (id) {
                    case 'clean':
                      return loc.visualizerPresetClean;
                    case 'neon':
                      return loc.visualizerPresetNeonClub;
                    case 'cinematic':
                      return loc.visualizerPresetCinematic;
                    case 'glitch':
                      return loc.visualizerPresetGlitchy;
                    case 'fire':
                      return loc.visualizerPresetFireBlast;
                    case 'electric':
                      return loc.visualizerPresetElectricBlue;
                    case 'rainbow':
                      return loc.visualizerPresetRainbowRoad;
                    case 'soft':
                      return loc.visualizerPresetSoftPastel;
                    case 'ice':
                      return loc.visualizerPresetIceCold;
                    case 'matrix':
                      return loc.visualizerPresetMatrixCode;
                    default:
                      return id;
                  }
                }();
                final bool selected = id == current;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      if (!selected) {
                        final updated = VisualizerAsset.clone(asset)
                          ..renderMode = 'progress';
                        final params = Map<String, dynamic>.from(
                          updated.shaderParams ?? {},
                        );

                        if (id == 'clean') {
                          updated.effectStyle = 'capsule';
                          updated.glowIntensity = 0.25;
                          updated.speed = 1.0;
                          updated.strokeWidth = 6.0;
                          params['progressTheme'] = 'classic';
                          params['progressCorner'] = 0.9;
                          params['progressGap'] = 0.0;
                          params['progressTrackAlpha'] = 0.35;
                          params['progressEffectAmount'] = 0.25;
                          params['progressTrackColor'] = 0xFF333333;
                        } else if (id == 'neon') {
                          updated.effectStyle = 'capsule';
                          updated.glowIntensity = 0.20;
                          updated.speed = 1.5;
                          updated.strokeWidth = 8.0;
                          updated.color = 0xFF00FFFF;
                          updated.gradientColor = 0xFFFF00FF;
                          params['progressTheme'] = 'neon';
                          params['progressCorner'] = 1.0;
                          params['progressGap'] = 0.0;
                          params['progressTrackAlpha'] = 0.5;
                          params['progressEffectAmount'] = 0.5;
                          params['progressTrackColor'] = 0xFF141428;
                        } else if (id == 'cinematic') {
                          updated.effectStyle = 'outline';
                          updated.glowIntensity = 0.4;
                          updated.speed = 0.9;
                          updated.strokeWidth = 7.0;
                          updated.color = 0xFFFFE0A0;
                          updated.gradientColor = 0xFFFFA040;
                          params['progressTheme'] = 'classic';
                          params['progressCorner'] = 0.8;
                          params['progressGap'] = 0.0;
                          params['progressTrackAlpha'] = 0.5;
                          params['progressEffectAmount'] = 0.3;
                          params['progressTrackColor'] = 0xFF201810;
                        } else if (id == 'glitch') {
                          updated.effectStyle = 'segments';
                          updated.glowIntensity = 0.3;
                          updated.speed = 1.8;
                          updated.strokeWidth = 6.0;
                          updated.color = 0xFF00E0FF;
                          updated.gradientColor = 0xFFFF00E0;
                          params['progressTheme'] = 'glitch';
                          params['progressCorner'] = 0.6;
                          params['progressGap'] = 0.5;
                          params['progressTrackAlpha'] = 0.4;
                          params['progressEffectAmount'] = 0.5;
                          params['progressTrackColor'] = 0xFF050914;
                        } else if (id == 'fire') {
                          updated.effectStyle = 'capsule';
                          updated.glowIntensity = 0.3;
                          updated.speed = 1.3;
                          updated.strokeWidth = 7.0;
                          updated.color = 0xFFFF5500;
                          updated.gradientColor = 0xFFFFD080;
                          params['progressTheme'] = 'fire';
                          params['progressCorner'] = 1.0;
                          params['progressGap'] = 0.0;
                          params['progressTrackAlpha'] = 0.5;
                          params['progressEffectAmount'] = 0.5;
                          params['progressTrackColor'] = 0xFF230704;
                        } else if (id == 'electric') {
                          updated.effectStyle = 'capsule';
                          updated.glowIntensity = 0.3;
                          updated.speed = 1.7;
                          updated.strokeWidth = 7.0;
                          updated.color = 0xFF00B7FF;
                          updated.gradientColor = 0xFFC0FFFF;
                          params['progressTheme'] = 'electric';
                          params['progressCorner'] = 0.9;
                          params['progressGap'] = 0.0;
                          params['progressTrackAlpha'] = 0.45;
                          params['progressEffectAmount'] = 0.5;
                          params['progressTrackColor'] = 0xFF020821;
                        } else if (id == 'rainbow') {
                          updated.effectStyle = 'capsule';
                          updated.glowIntensity = 0.3;
                          updated.speed = 1.4;
                          updated.strokeWidth = 7.0;
                          updated.color = 0xFFFF00E0;
                          updated.gradientColor = 0xFF00FF7F;
                          params['progressTheme'] = 'rainbow';
                          params['progressCorner'] = 1.0;
                          params['progressGap'] = 0.0;
                          params['progressTrackAlpha'] = 0.5;
                          params['progressEffectAmount'] = 0.5;
                          params['progressTrackColor'] = 0xFF101010;
                        } else if (id == 'soft') {
                          updated.effectStyle = 'capsule';
                          updated.glowIntensity = 0.4;
                          updated.speed = 0.9;
                          updated.strokeWidth = 6.0;
                          updated.color = 0xFFFFB4C8;
                          updated.gradientColor = 0xFFB4C8FF;
                          params['progressTheme'] = 'soft';
                          params['progressCorner'] = 0.8;
                          params['progressGap'] = 0.0;
                          params['progressTrackAlpha'] = 0.4;
                          params['progressEffectAmount'] = 0.5;
                          params['progressTrackColor'] = 0xFF202030;
                        } else if (id == 'ice') {
                          updated.effectStyle = 'thin';
                          updated.glowIntensity = 0.3;
                          updated.speed = 1.1;
                          updated.strokeWidth = 6.0;
                          updated.color = 0xFF7FE5FF;
                          updated.gradientColor = 0xFFFFFFFF;
                          params['progressTheme'] = 'ice';
                          params['progressCorner'] = 0.7;
                          params['progressGap'] = 0.0;
                          params['progressTrackAlpha'] = 0.4;
                          params['progressEffectAmount'] = 0.5;
                          params['progressTrackColor'] = 0xFF020718;
                        } else if (id == 'matrix') {
                          updated.effectStyle = 'thin';
                          updated.glowIntensity = 0.3;
                          updated.speed = 1.6;
                          updated.strokeWidth = 6.0;
                          updated.color = 0xFF00FF66;
                          updated.gradientColor = 0xFF00AA33;
                          params['progressTheme'] = 'matrix';
                          params['progressCorner'] = 0.4;
                          params['progressGap'] = 0.0;
                          params['progressTrackAlpha'] = 0.35;
                          params['progressEffectAmount'] = 0.5;
                          params['progressTrackColor'] = 0xFF020503;
                        }

                        params['progressPreset'] = id;
                        updated.shaderParams = params;
                        visualizerService.editingVisualizerAsset = updated;
                      }
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? app_theme.accent.withOpacity(0.2)
                            : (isDark ? app_theme.projectListCardBg : app_theme.surface),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: selected ? app_theme.accent : (isDark ? app_theme.projectListCardBorder : app_theme.border),
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          color: selected ? app_theme.accent : (isDark ? app_theme.darkTextSecondary : app_theme.textSecondary),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedSlider extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset asset;

  _SpeedSlider(this.asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final value = asset.speed.clamp(0.5, 2.0);
    return Container(
      width: 290,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              loc.visualizerSpeedLabel,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
              ),
            ),
          ),
          Expanded(
            child: Slider(
              min: 0.5,
              max: 2.0,
              divisions: 30,
              label: value.toStringAsFixed(2),
              value: value,
              activeColor: app_theme.accent,
              inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
              onChanged: (v) {
                final updated = VisualizerAsset.clone(asset)
                  ..renderMode = 'progress'
                  ..speed = v;
                visualizerService.editingVisualizerAsset = updated;
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EffectAmountSlider extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset asset;

  _EffectAmountSlider(this.asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    double current = 1.0;
    if (asset.shaderParams != null &&
        asset.shaderParams!['progressEffectAmount'] is num) {
      current = (asset.shaderParams!['progressEffectAmount'] as num).toDouble();
    }
    final value = current.clamp(0.0, 1.0);

    return Container(
      width: 290,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              loc.visualizerIntensityLabel,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
              ),
            ),
          ),
          Expanded(
            child: Slider(
              min: 0.0,
              max: 1.0,
              value: value,
              activeColor: app_theme.accent,
              inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
              onChanged: (v) {
                final updated = VisualizerAsset.clone(asset)
                  ..renderMode = 'progress';
                final params = Map<String, dynamic>.from(
                  updated.shaderParams ?? {},
                );
                params['progressEffectAmount'] = v;
                updated.shaderParams = params;
                visualizerService.editingVisualizerAsset = updated;
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset asset;

  _ThemeSelector(this.asset);

  static const _themes = [
    {'id': 'classic'},
    {'id': 'fire'},
    {'id': 'electric'},
    {'id': 'neon'},
    {'id': 'rainbow'},
    {'id': 'glitch'},
    {'id': 'soft'},
    {'id': 'sunset'},
    {'id': 'ice'},
    {'id': 'matrix'},
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final String current =
        (asset.shaderParams != null &&
            asset.shaderParams!['progressTheme'] is String)
        ? (asset.shaderParams!['progressTheme'] as String)
        : 'classic';

    return Container(
      width: 290,
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              loc.visualizerThemeLabel,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _themes.map((opt) {
                final id = opt['id'] as String;
                final label = () {
                  switch (id) {
                    case 'classic':
                      return loc.visualizerThemeClassic;
                    case 'fire':
                      return loc.visualizerThemeFire;
                    case 'electric':
                      return loc.visualizerThemeElectric;
                    case 'neon':
                      return loc.visualizerThemeNeon;
                    case 'rainbow':
                      return loc.visualizerThemeRainbow;
                    case 'glitch':
                      return loc.visualizerThemeGlitch;
                    case 'soft':
                      return loc.visualizerThemeSoft;
                    case 'sunset':
                      return loc.visualizerThemeSunset;
                    case 'ice':
                      return loc.visualizerThemeIce;
                    case 'matrix':
                      return loc.visualizerThemeMatrix;
                    default:
                      return id;
                  }
                }();
                final bool selected = id == current;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      if (!selected) {
                        final updated = VisualizerAsset.clone(asset)
                          ..renderMode = 'progress';
                        final params = Map<String, dynamic>.from(
                          updated.shaderParams ?? {},
                        );
                        params['progressTheme'] = id;
                        updated.shaderParams = params;
                        visualizerService.editingVisualizerAsset = updated;
                      }
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? app_theme.accent.withOpacity(0.2)
                            : (isDark ? app_theme.projectListCardBg : app_theme.surface),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: selected ? app_theme.accent : (isDark ? app_theme.projectListCardBorder : app_theme.border),
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          color: selected ? app_theme.accent : (isDark ? app_theme.darkTextSecondary : app_theme.textSecondary),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CornerRadiusSlider extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset asset;

  _CornerRadiusSlider(this.asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    double current = 0.2;
    if (asset.shaderParams != null &&
        asset.shaderParams!['progressCorner'] is num) {
      current = (asset.shaderParams!['progressCorner'] as num).toDouble();
    }
    final value = current.clamp(0.0, 1.0);

    return Container(
      width: 290,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              loc.visualizerCornerLabel,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
              ),
            ),
          ),
          Expanded(
            child: Slider(
              min: 0.0,
              max: 1.0,
              value: value,
              activeColor: app_theme.accent,
              inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
              onChanged: (v) {
                final updated = VisualizerAsset.clone(asset)
                  ..renderMode = 'progress';
                final params = Map<String, dynamic>.from(
                  updated.shaderParams ?? {},
                );
                params['progressCorner'] = v;
                updated.shaderParams = params;
                visualizerService.editingVisualizerAsset = updated;
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentGapSlider extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset asset;

  _SegmentGapSlider(this.asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    double current = 0.3;
    if (asset.shaderParams != null &&
        asset.shaderParams!['progressGap'] is num) {
      current = (asset.shaderParams!['progressGap'] as num).toDouble();
    }
    final value = current.clamp(0.0, 1.0);

    return Container(
      width: 290,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              loc.visualizerGapLabel,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
              ),
            ),
          ),
          Expanded(
            child: Slider(
              min: 0.0,
              max: 1.0,
              value: value,
              activeColor: app_theme.accent,
              inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
              onChanged: (v) {
                final updated = VisualizerAsset.clone(asset)
                  ..renderMode = 'progress';
                final params = Map<String, dynamic>.from(
                  updated.shaderParams ?? {},
                );
                params['progressGap'] = v;
                updated.shaderParams = params;
                visualizerService.editingVisualizerAsset = updated;
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackOpacitySlider extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset asset;

  _TrackOpacitySlider(this.asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    double current = 0.35;
    if (asset.shaderParams != null &&
        asset.shaderParams!['progressTrackAlpha'] is num) {
      current = (asset.shaderParams!['progressTrackAlpha'] as num).toDouble();
    }
    final value = current.clamp(0.0, 1.0);

    return Container(
      width: 290,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              loc.visualizerTrackOpacityLabel,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
              ),
            ),
          ),
          Expanded(
            child: Slider(
              min: 0.0,
              max: 1.0,
              value: value,
              activeColor: app_theme.accent,
              inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
              onChanged: (v) {
                final updated = VisualizerAsset.clone(asset)
                  ..renderMode = 'progress';
                final params = Map<String, dynamic>.from(
                  updated.shaderParams ?? {},
                );
                params['progressTrackAlpha'] = v;
                updated.shaderParams = params;
                visualizerService.editingVisualizerAsset = updated;
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowSlider extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset asset;

  _GlowSlider(this.asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final value = asset.glowIntensity.clamp(0.0, 1.0);
    return Container(
      width: 290,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              loc.visualizerGlowLabel,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
              ),
            ),
          ),
          Expanded(
            child: Slider(
              min: 0.0,
              max: 1.0,
              value: value,
              activeColor: app_theme.accent,
              inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
              onChanged: (v) {
                final updated = VisualizerAsset.clone(asset)
                  ..renderMode = 'progress'
                  ..glowIntensity = v;
                visualizerService.editingVisualizerAsset = updated;
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressStyleSelector extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset asset;

  _ProgressStyleSelector(this.asset);

  static const _styles = [
    {'id': 'capsule'},
    {'id': 'segments'},
    {'id': 'steps'},
    {'id': 'centered'},
    {'id': 'outline'},
    {'id': 'thin'},
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final current = asset.effectStyle.isEmpty ? 'capsule' : asset.effectStyle;

    return Container(
      width: 290,
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              loc.visualizerStyleLabel,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _styles.map((opt) {
                final id = opt['id'] as String;
                final label = () {
                  switch (id) {
                    case 'capsule':
                      return loc.visualizerProgressStyleCapsule;
                    case 'segments':
                      return loc.visualizerProgressStyleSegments;
                    case 'steps':
                      return loc.visualizerProgressStyleSteps;
                    case 'centered':
                      return loc.visualizerProgressStyleCentered;
                    case 'outline':
                      return loc.visualizerProgressStyleOutline;
                    case 'thin':
                      return loc.visualizerProgressStyleThin;
                    default:
                      return id;
                  }
                }();
                final bool selected = id == current;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      if (!selected) {
                        final updated = VisualizerAsset.clone(asset)
                          ..renderMode = 'progress'
                          ..effectStyle = id;
                        visualizerService.editingVisualizerAsset = updated;
                      }
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? app_theme.accent.withOpacity(0.2)
                            : (isDark ? app_theme.projectListCardBg : app_theme.surface),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: selected ? app_theme.accent : (isDark ? app_theme.projectListCardBorder : app_theme.border),
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          color: selected ? app_theme.accent : (isDark ? app_theme.darkTextSecondary : app_theme.textSecondary),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScaleSlider extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset asset;

  _ScaleSlider(this.asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    return Container(
      width: 290,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              loc.visualizerScaleLabel,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
              ),
            ),
          ),
          Expanded(
            child: Slider(
              min: 0.5,
              max: 2.0,
              value: asset.scale.clamp(0.5, 2.0),
              activeColor: app_theme.accent,
              inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
              onChanged: (scale) {
                final updated = VisualizerAsset.clone(asset)
                  ..renderMode = 'progress'
                  ..scale = scale;
                visualizerService.editingVisualizerAsset = updated;
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ThicknessSlider extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset asset;

  _ThicknessSlider(this.asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    final value = asset.strokeWidth.clamp(6.0, 24.0);
    return Container(
      width: 290,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              loc.visualizerThicknessLabel,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
              ),
            ),
          ),
          Expanded(
            child: Slider(
              min: 6.0,
              max: 24.0,
              divisions: 44,
              label: value.toStringAsFixed(1),
              value: value,
              activeColor: app_theme.accent,
              inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
              onChanged: (v) {
                final updated = VisualizerAsset.clone(asset)
                  ..renderMode = 'progress'
                  ..strokeWidth = v;
                visualizerService.editingVisualizerAsset = updated;
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorField extends StatelessWidget {
  final directorService = locator.get<DirectorService>();
  final VisualizerAsset asset;
  final String label;
  final double size;

  _ColorField({required this.asset, this.label = 'Color', this.size = 110});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 14, 
            color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            directorService.editingColor = 'visualizerColor';
          },
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Color(asset.color),
              border: Border.all(
                color: isDark ? app_theme.projectListCardBorder : app_theme.border,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 2)
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressGradientColorField extends StatelessWidget {
  final directorService = locator.get<DirectorService>();
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset asset;

  _ProgressGradientColorField({required this.asset});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const int fallbackColor = 0xFFFFFFFF;
    final int effectiveColor = asset.gradientColor ?? fallbackColor;

    if (asset.gradientColor == null) {
      // Avoid modifying state during build if possible, but here it's initializing default
      // Ideally this should be done in asset creation/logic, but keeping existing logic
      Future.microtask(() {
        if (asset.gradientColor == null) {
           final updated = VisualizerAsset.clone(asset)
            ..renderMode = 'progress'
            ..gradientColor = fallbackColor;
           visualizerService.editingVisualizerAsset = updated;
        }
      });
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          AppLocalizations.of(context).visualizerGradientLabel,
          style: TextStyle(
            fontSize: 14, 
            color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            directorService.editingColor = 'visualizerGradient';
          },
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Color(effectiveColor),
              border: Border.all(
                color: isDark ? app_theme.projectListCardBorder : app_theme.border,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 2)
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TrackColorField extends StatelessWidget {
  final directorService = locator.get<DirectorService>();
  final VisualizerAsset asset;

  _TrackColorField({required this.asset});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    int effectiveColor = 0xFF444444;
    if (asset.shaderParams != null &&
        asset.shaderParams!['progressTrackColor'] is int) {
      effectiveColor = asset.shaderParams!['progressTrackColor'] as int;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          AppLocalizations.of(context).visualizerTrackLabel,
          style: TextStyle(
            fontSize: 14, 
            color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            directorService.editingColor = 'progressTrackColor';
          },
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Color(effectiveColor),
              border: Border.all(
                color: isDark ? app_theme.projectListCardBorder : app_theme.border,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 2)
              ],
            ),
          ),
        ),
      ],
    );
  }
}
