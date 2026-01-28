import 'package:flutter/material.dart';
import 'package:vidviz/l10n/generated/app_localizations.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/director_service.dart';
import 'package:vidviz/service/visualizer_service.dart';
import 'package:vidviz/model/layer.dart';
import 'package:vidviz/model/visualizer.dart';
import 'package:vidviz/core/theme.dart' as app_theme;
import 'package:vidviz/ui/widgets/visualizer/visualizer_shader_registry.dart';

String _normalizeVisualizerShaderIdForUi(String shaderType) {
  return normalizeVisualizerShaderId(shaderType);
}

class _StrokeWidthSlider extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset _asset;

  _StrokeWidthSlider(this._asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double w = _asset.strokeWidth.clamp(0.5, 8.0);
    return Container(
      width: 290,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              AppLocalizations.of(context).visualizerThicknessLabel,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Slider(
              min: 0.5,
              max: 8.0,
              divisions: 75,
              value: w,
              activeColor: app_theme.accent,
              inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
              onChanged: (value) {
                final updated = VisualizerAsset.clone(_asset)
                  ..renderMode = 'shader'
                  ..strokeWidth = value;
                visualizerService.editingVisualizerAsset = updated;
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DynamicsSliders extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset _asset;

  _DynamicsSliders(this._asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    double smooth = _asset.smoothness;
    if ((smooth - 0.6).abs() < 0.001) smooth = 0.0;
    double reactivity = _asset.reactivity.clamp(0.5, 2.0);
    final loc = AppLocalizations.of(context);

    return Column(
      children: [
        Container(
          width: 290,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  loc.visualizerSettingsAnimSmoothnessLabel,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: Slider(
                  value: smooth.clamp(0.0, 1.0),
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  activeColor: app_theme.accent,
                  inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
                  onChanged: (value) {
                    final updated = VisualizerAsset.clone(_asset)..smoothness = value;
                    visualizerService.editingVisualizerAsset = updated;
                  },
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 290,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  loc.visualizerSettingsReactivityLabel,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: Slider(
                  value: reactivity,
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  activeColor: app_theme.accent,
                  inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
                  onChanged: (value) {
                    final updated = VisualizerAsset.clone(_asset)..reactivity = value;
                    visualizerService.editingVisualizerAsset = updated;
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BarFillSlider extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset _asset;

  _BarFillSlider(this._asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const double minFill = 0.35;
    const double maxFill = 0.92;
    final double fill = _asset.barSpacing.clamp(minFill, maxFill);
    final double spacing = ((maxFill - fill) / (maxFill - minFill)).clamp(0.0, 1.0);
    return Container(
      width: 290,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              AppLocalizations.of(context).visualizerSpacingLabel,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Slider(
              min: 0.0,
              max: 1.0,
              divisions: 50,
              value: spacing,
              activeColor: app_theme.accent,
              inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
              onChanged: (value) {

                final double newFill = (maxFill - value * (maxFill - minFill)).clamp(minFill, maxFill);
                final updated = VisualizerAsset.clone(_asset)
                  ..renderMode = 'shader'
                  ..barSpacing = newFill;
                visualizerService.editingVisualizerAsset = updated;
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// ShaderForm - Shader mode ayarları
class ShaderForm extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset _asset;

  ShaderForm(VisualizerAsset asset) : _asset = asset, super();

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final st = _normalizeVisualizerShaderIdForUi(_asset.shaderType ?? 'bar');
    final children = <Widget>[
      _AudioSourceSelector(_asset),
      _ShaderTypeSelector(_asset),
     // _FullScreenToggle(_asset),
      _ScaleSlider(_asset),
      if (st != 'particle')
      _AmplitudeSlider(_asset),
      _OpacitySlider(_asset),
      _RotationSlider(_asset),
    ];

    final showSpeed = st == 'wav' ||
        st == 'smooth' ||
        st == 'sinus' ||
        st == 'circle' ||
        st == 'wave' ||
        st == 'particle' ||
        st == 'nation' ||
        st == 'claude' ||
        st == 'bar_colors';
    if (showSpeed) {
      children.add(_SpeedSlider(_asset));
    }

    final showStroke = st == 'line' || st == 'wave' || st == 'curves' || st == 'wav' || st == 'smooth' || st == 'sinus';
    if (showStroke) {
      children.add(_StrokeWidthSlider(_asset));
    }

    children.add(_DynamicsSliders(_asset));
    if (st == 'bar' ||
        st == 'bar_normal' ||
        st == 'bar_colors' ||
        st == 'bar_circle' ||
        st == 'circle' ||
        st == 'claude' ) {
      children.add(_BarCountSlider(_asset));
    }

    if (st == 'bar' ||
        st == 'bar_normal' ||
        st == 'bar_colors' ||
        st == 'bar_circle' ||
        st == 'circle' ||
        st == 'claude' ) {
      children.add(_BarFillSlider(_asset));
    }

    children.add(_SoftnessSlider(_asset));

    children.add(_MirrorToggle(_asset));

    // Color settings
    children.add(const SizedBox(height: 8));
    children.add(Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _ColorField(asset: _asset, label: loc.visualizerColorLabel, size: 110),
        // Gradient kontrolü: gradient destekleyen tüm shader'lar
        if (st == 'bar' ||
            st == 'bar_normal' ||
            st == 'bar_colors' ||
            st == 'bar_circle' ||
            st == 'circle' ||
            st == 'wav' ||
            st == 'wave' ||
            st == 'smooth' ||
            st == 'sinus' ||
            st == 'curves' ||
            st == 'particle' ||
            st == 'claude' ||
            st == 'nation')
          _GradientColorField(asset: _asset),
      ],
    ));
    children.add(const SizedBox(height: 16));

    return SingleChildScrollView(
      child: Wrap(spacing: 0.0, runSpacing: 0.0, children: children),
    );
  }
}

// Background (Full Screen) Toggle
class FullScreenToggle extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset _asset;

  FullScreenToggle(this._asset);

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
              loc.visualizerBackgroundLabel,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
              ),
            ),
          ),
          Switch(
            value: _asset.fullScreen,
            activeColor: app_theme.accent,
            onChanged: (enabled) {
              final updated = VisualizerAsset.clone(_asset)
                ..renderMode = 'shader'
                ..fullScreen = enabled;
              visualizerService.editingVisualizerAsset = updated;
            },
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: loc.visualizerShaderFullscreenTooltip,
            child: Icon(
              Icons.fullscreen,
              size: 16,
              color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// Rotation Slider (Shader mode)
class _RotationSlider extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset _asset;
  _RotationSlider(this._asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    double rotation = _asset.rotation.clamp(0.0, 360.0);
    return Container(
      width: 290,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              AppLocalizations.of(context).visualizerRotationLabel,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
              ),
            ),
          ),
          Expanded(
            child: Slider(
              min: 0.0,
              max: 360.0,
              divisions: 72,
              label: '${rotation.toInt()}°',
              value: rotation,
              activeColor: app_theme.accent,
              inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
              onChanged: (value) {
                final updated = VisualizerAsset.clone(_asset)
                  ..renderMode = 'shader'
                  ..rotation = value;
                visualizerService.editingVisualizerAsset = updated;
              },
            ),
          ),
          SizedBox(
            width: 35,
            child: Text(
              '${rotation.toInt()}°',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

// Glow Slider (Shader mode)
class _SoftnessSlider extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset _asset;

  _SoftnessSlider(this._asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    double glow = _asset.glowIntensity.clamp(0.0, 1.0);
    return Container(
      width: 290,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              AppLocalizations.of(context).visualizerGlowLabel,
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
              divisions: 100,
              label: '${(glow * 100).toInt()}%',
              value: glow,
              activeColor: app_theme.accent,
              inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
              onChanged: (value) {
                final updated = VisualizerAsset.clone(_asset)
                  ..renderMode = 'shader'
                  ..glowIntensity = value;
                visualizerService.editingVisualizerAsset = updated;
              },
            ),
          ),
          SizedBox(
            width: 35,
            child: Text(
              '${(glow * 100).toInt()}%',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

// Audio Source Selector (canvas_form ile aynı)
class _AudioSourceSelector extends StatelessWidget {
  final directorService = locator.get<DirectorService>();
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset _asset;

  _AudioSourceSelector(this._asset);

  List<Asset> _getAvailableAudioSources() {
    List<Asset> sources = [];
    if (directorService.layers == null) return sources;
    // Tüm layer'ları tara ve hem video hem audio asset'leri ekle (dinamik mimari)
    final Set<String> seen = {};
    for (final layer in directorService.layers!) {
      for (final asset in layer.assets) {
        if ((asset.type == AssetType.audio || asset.type == AssetType.video) &&
            !asset.deleted) {
          final key = asset.srcPath;
          if (key.isEmpty) continue;
          if (!seen.contains(key)) {
            sources.add(asset);
            seen.add(key);
          }
        }
      }
    }
    return sources;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    List<Asset> audioSources = _getAvailableAudioSources();

    if (audioSources.isEmpty) {
      return Container(
        width: 290,
        padding: const EdgeInsets.all(8),
        child: Text(
          loc.visualizerAudioEmptyTimeline,
          style: TextStyle(fontSize: 14, color: app_theme.error),
        ),
      );
    }

    return Container(
      width: 290,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              loc.visualizerAudioLabel,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? app_theme.projectListCardBg : app_theme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? app_theme.projectListCardBorder : app_theme.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: (() {
                    if (_asset.srcPath.isEmpty) return null;
                    final values = audioSources.map((s) => s.srcPath).toList();
                    final matches = values.where((v) => v == _asset.srcPath).length;
                    if (matches != 1) return null;
                    return _asset.srcPath;
                  })(),
                  hint: Text(
                    loc.visualizerAudioSelectHint,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
                    )
                  ),
                  isExpanded: true,
                  dropdownColor: isDark ? app_theme.projectListCardBg : app_theme.surface,
                  items: audioSources.map((Asset source) => DropdownMenuItem(
                    value: source.srcPath,
                    child: Text(
                      source.title.length > 20
                          ? source.title.substring(0, 20) + '...'
                          : source.title,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )).toList(),
                  onChanged: (audioPath) {
                    if (audioPath != null) {
                      Asset selectedSource = audioSources.firstWhere(
                        (s) => s.srcPath == audioPath,
                      );
                      visualizerService.changeAudioSource(
                        audioPath,
                        selectedSource.duration,
                      );
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Shader Type Selector
class _ShaderTypeSelector extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset _asset;

  _ShaderTypeSelector(this._asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    String currentShader = _normalizeVisualizerShaderIdForUi(_asset.shaderType ?? 'bar');

    final shaderOptions = [
      {'id': 'bar', 'label': loc.visualizerShaderOptionBars},
      {'id': 'bar_normal', 'label': 'Bar Normal'},
      {'id': 'bar_colors', 'label': 'Bar Colors'},
      {'id': 'bar_circle', 'label': loc.visualizerShaderOptionCircleBars},
      {'id': 'circle', 'label': 'Circle'},
      {'id': 'claude', 'label': loc.visualizerShaderOptionClaudeSpectrum},
      {'id': 'wav', 'label': loc.visualizerShaderOptionWaveform},
      {'id': 'wave', 'label': 'Wave'},
      {'id': 'smooth', 'label': loc.visualizerShaderOptionSmoothCurves},
      {'id': 'line', 'label': 'Line'},
      {'id': 'sinus', 'label': loc.visualizerShaderOptionSinusWaves},
      {'id': 'curves', 'label': 'Curves'},
      {'id': 'particle', 'label': 'Particle'},
      {'id': 'nation', 'label': loc.visualizerShaderOptionNationCircle},
    ];

    final optionIds = shaderOptions.map((e) => e['id']).whereType<String>().toSet();
    if (!optionIds.contains(currentShader)) {
      currentShader = 'bar';
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
              loc.visualizerShaderLabel,
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
              children: shaderOptions.map((opt) {
                final String id = opt['id'] as String;
                final String label = opt['label'] as String;
                final bool isSelected = id == currentShader;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      if (!isSelected) {
                        print('Shader değiştirildi: $id');
                        final updated = VisualizerAsset.clone(_asset)
                          ..renderMode = 'shader'
                          ..shaderType = id;
                        print(
                          'Stream\'e gönderiliyor: shaderType: ${updated.shaderType}',
                        );
                        visualizerService.editingVisualizerAsset = updated;
                      }
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? app_theme.accent.withOpacity(0.2)
                            : (isDark ? app_theme.projectListCardBg : app_theme.surface),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected ? app_theme.accent : (isDark ? app_theme.projectListCardBorder : app_theme.border),
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? app_theme.accent : (isDark ? app_theme.darkTextSecondary : app_theme.textSecondary),
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

// Intensity Slider (VisualizerAsset.sensitivity)
class _AmplitudeSlider extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset _asset;

  _AmplitudeSlider(this._asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 290,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              AppLocalizations.of(context).visualizerHeightLabel,
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
              value: _asset.amplitude.clamp(0.5, 2.0),
              activeColor: app_theme.accent,
              inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
              onChanged: (value) {
                final updated = VisualizerAsset.clone(_asset)
                  ..renderMode = 'shader'
                  ..amplitude = value;
                visualizerService.editingVisualizerAsset = updated;
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OpacitySlider extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset _asset;

  _OpacitySlider(this._asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 290,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              AppLocalizations.of(context).mediaOverlayOpacityLabel,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Slider(
              min: 0.0,
              max: 1.0,
              value: _asset.alpha.clamp(0.0, 1.0),
              activeColor: app_theme.accent,
              inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
              onChanged: (value) {
                final updated = VisualizerAsset.clone(_asset)
                  ..renderMode = 'shader'
                  ..alpha = value;
                visualizerService.editingVisualizerAsset = updated;
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Speed Slider (VisualizerAsset.speed)
class _SpeedSlider extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset _asset;

  _SpeedSlider(this._asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 290,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              AppLocalizations.of(context).visualizerSpeedLabel,
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
              value: _asset.speed.clamp(0.5, 2.0),
              activeColor: app_theme.accent,
              inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
              onChanged: (speed) {
                final updated = VisualizerAsset.clone(_asset)
                  ..renderMode = 'shader'
                  ..speed = speed;
                visualizerService.editingVisualizerAsset = updated;
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Scale Slider (Shader için)
class _ScaleSlider extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset _asset;

  _ScaleSlider(this._asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 290,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              AppLocalizations.of(context).visualizerScaleLabel,
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
              value: _asset.scale.clamp(0.5, 2.0),
              activeColor: app_theme.accent,
              inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
              onChanged: (scale) {
                final updated = VisualizerAsset.clone(_asset)
                  ..renderMode = 'shader'
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

// Bar Count Slider (Shader için de kullanılabilir)
class _BarCountSlider extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset _asset;

  _BarCountSlider(this._asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    int barCount = _asset.barCount.clamp(8, 150);

    return Container(
      width: 290,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              AppLocalizations.of(context).visualizerBarsLabel,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
              ),
            ),
          ),
          Expanded(
            child: Slider(
              min: 8,
              max: 150,
              divisions: 142,
              label: barCount.toString(),
              value: barCount.toDouble(),
              activeColor: app_theme.accent,
              inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
              onChanged: (count) {
                final updated = VisualizerAsset.clone(_asset)
                  ..renderMode = 'shader'
                  ..barCount = count.toInt();
                visualizerService.editingVisualizerAsset = updated;
              },
            ),
          ),
          SizedBox(
            width: 30,
            child: Text(
              barCount.toString(),
              style: TextStyle(
                fontSize: 12,
                color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

// Mirror Toggle (Shader için)
class _MirrorToggle extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset _asset;

  _MirrorToggle(this._asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 290,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              AppLocalizations.of(context).visualizerMirrorLabel,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
              ),
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: _asset.mirror,
              activeColor: app_theme.accent,
              onChanged: (mirror) {
                final updated = VisualizerAsset.clone(_asset)
                  ..renderMode = 'shader'
                  ..mirror = mirror;
                visualizerService.editingVisualizerAsset = updated;
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Color Field
class _ColorField extends StatelessWidget {
  final directorService = locator.get<DirectorService>();
  final VisualizerAsset asset;
  final String? label;
  final double? size;

  _ColorField({required this.asset, this.label = 'Color', this.size = 110});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
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
            height: 32,
            width: 32,
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

// Gradient Color Field (optional second color)
class _GradientColorField extends StatelessWidget {
  final directorService = locator.get<DirectorService>();
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset asset;

  _GradientColorField({required this.asset});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const int fallbackColor = 0xFFFFFFFF;
    final int effectiveColor = asset.gradientColor ?? fallbackColor;

    if (asset.gradientColor == null) {
      final updated = VisualizerAsset.clone(asset)
        ..renderMode = 'shader'
        ..gradientColor = fallbackColor;
      visualizerService.editingVisualizerAsset = updated;
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
        SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            directorService.editingColor = 'visualizerGradient';
          },
          child: Container(
            height: 32,
            width: 32,
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
