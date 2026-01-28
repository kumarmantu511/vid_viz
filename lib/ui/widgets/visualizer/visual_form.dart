import 'dart:io';
import 'package:flutter/material.dart';
import 'package:vidviz/l10n/generated/app_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/director_service.dart';
import 'package:vidviz/service/visualizer_service.dart';
import 'package:vidviz/model/layer.dart';
import 'package:vidviz/model/visualizer.dart';
import 'package:vidviz/core/theme.dart' as app_theme;
import 'package:vidviz/ui/widgets/visualizer/visualizer_shader_registry.dart';

/// VisualForm - Visual (stage sampling) shader mode editor
/// Lists shaders under assets/shaders/visual/ and exposes minimal controls.
class VisualForm extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset _asset;

  VisualForm(VisualizerAsset asset) : _asset = asset, super();

  @override
  Widget build(BuildContext context) {
    final currentShader = normalizeVisualShaderIdForUi(_asset.shaderType ?? 'pro_nation');
    final isNationShader = currentShader == 'pro_nation';
    final loc = AppLocalizations.of(context);
    
    final children = <Widget>[
      _AudioSourceSelector(_asset),
      _VisualShaderTypeSelector(_asset),
      //_FullScreenToggle(_asset),
      _ScaleSlider(_asset),
      _IntensitySlider(_asset),
      _SpeedSlider(_asset),
      _RotationSlider(_asset),
      _MirrorToggle(_asset),
    ];
    
    // Nation shader icin resim seciciler
    if (isNationShader) {
      children.add(const SizedBox(height: 12));
      children.add(const Divider(height: 1));
      children.add(const SizedBox(height: 8));
      children.add(_ImagePickerSection(_asset));
    }

    // Color settings
    children.add(const SizedBox(height: 8));
    children.add(Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _ColorField(asset: _asset, label: loc.visualizerColorLabel, size: 110),
        _GradientColorField(asset: _asset),
      ],
    ));
    children.add(const SizedBox(height: 16));

    return SingleChildScrollView(
      child: Wrap(spacing: 0.0, runSpacing: 0.0, children: children),
    );
  }
}

// Scale Slider (Visual mode)
class _ScaleSlider extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset _asset;

  _ScaleSlider(this._asset);

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
              value: _asset.scale.clamp(0.5, 2.0),
              activeColor: app_theme.accent,
              inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
              onChanged: (scale) {
                final updated = VisualizerAsset.clone(_asset)
                  ..renderMode = 'visual'
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
        ..renderMode = 'visual'
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
        const SizedBox(width: 8),
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

// Audio Source Selector (same behavior as ShaderForm)
class _AudioSourceSelector extends StatelessWidget {
  final directorService = locator.get<DirectorService>();
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset _asset;

  _AudioSourceSelector(this._asset);

  List<Asset> _getAvailableAudioSources() {
    List<Asset> sources = [];
    if (directorService.layers == null) return sources;
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
                          ? '${source.title.substring(0, 20)}...'
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

class _VisualShaderTypeSelector extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset _asset;
  _VisualShaderTypeSelector(this._asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    String current = normalizeVisualShaderIdForUi(_asset.shaderType ?? 'pro_nation');

    return Container(
      width: 290,
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              loc.visualizerVisualLabel,
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
              children: kAllowedVisualShaderUiIds.map((id) {
                final bool isSelected = id == current;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      if (!isSelected) {
                        final updated = VisualizerAsset.clone(_asset)
                          ..renderMode = 'visual'
                          ..shaderType = id;
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
                        id,
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
                ..renderMode = 'visual'
                ..fullScreen = enabled;
              visualizerService.editingVisualizerAsset = updated;
            },
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: loc.visualizerVisualFullscreenTooltip,
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

class _IntensitySlider extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final VisualizerAsset _asset;
  _IntensitySlider(this._asset);
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
              AppLocalizations.of(context).visualizerIntensityLabel,
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
              onChanged: (intensity) {
                final updated = VisualizerAsset.clone(_asset)
                  ..renderMode = 'visual'
                  ..amplitude = intensity;
                visualizerService.editingVisualizerAsset = updated;
              },
            ),
          ),
        ],
      ),
    );
  }
}

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
                  ..renderMode = 'visual'
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
                  ..renderMode = 'visual'
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
                  ..renderMode = 'visual'
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

/// Nation shader icin overlay ayarlari bolumu
class _ImagePickerSection extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();
  final directorService = locator.get<DirectorService>();
  final VisualizerAsset _asset;
  
  _ImagePickerSection(this._asset);
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    return Container(
      width: 290,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.visualizerOverlaySettingsTitle,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          // Orta resim
          _ImagePickerRow(
            label: loc.visualizerOverlayCenterImageLabel,
            imagePath: _asset.centerImagePath,
            onPick: () => _pickImage('center'),
            onClear: () => _clearImage('center'),
          ),
          const SizedBox(height: 6),
          // Cember rengi
          _RingColorRow(
            label: loc.visualizerOverlayRingColorLabel,
            color: _asset.ringColor != null ? Color(_asset.ringColor!) : null,
            onTap: () {
              directorService.editingColor = 'visualizerRingColor';
            },
            onClear: () {
              final updated = VisualizerAsset.clone(_asset)..renderMode = 'visual';
              updated.ringColor = null;
              visualizerService.editingVisualizerAsset = updated;
            },
          ),
          const SizedBox(height: 6),
          // Arkaplan resmi
          _ImagePickerRow(
            label: loc.visualizerOverlayBackgroundLabel,
            imagePath: _asset.backgroundImagePath,
            onPick: () => _pickImage('background'),
            onClear: () => _clearImage('background'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _pickImage(String type) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    
    if (result != null && result.files.isNotEmpty) {
      final path = result.files.first.path;
      if (path != null) {
        final updated = VisualizerAsset.clone(_asset)..renderMode = 'visual';
        switch (type) {
          case 'center':
            updated.centerImagePath = path;
            break;
          case 'background':
            updated.backgroundImagePath = path;
            break;
        }
        visualizerService.editingVisualizerAsset = updated;
      }
    }
  }
  
  void _clearImage(String type) {
    final updated = VisualizerAsset.clone(_asset)..renderMode = 'visual';
    switch (type) {
      case 'center':
        updated.centerImagePath = null;
        break;
      case 'background':
        updated.backgroundImagePath = null;
        break;
    }
    visualizerService.editingVisualizerAsset = updated;
  }
}

/// Cember rengi secici satiri
class _RingColorRow extends StatelessWidget {
  final String label;
  final Color? color;
  final VoidCallback onTap;
  final VoidCallback onClear;
  
  const _RingColorRow({
    required this.label,
    required this.color,
    required this.onTap,
    required this.onClear,
  });
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasColor = color != null;
    
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            '$label:',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
            ),
          ),
        ),
        // Renk kutusu
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: hasColor ? color : (isDark ? app_theme.projectListCardBg : app_theme.surface),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: hasColor 
                    ? app_theme.accent 
                    : (isDark ? app_theme.projectListCardBorder : app_theme.border),
              ),
              // Gokkusagi efekti (varsayilan)
              gradient: !hasColor ? LinearGradient(
                colors: [
                  Colors.red,
                  Colors.orange,
                  Colors.yellow,
                  Colors.green,
                  Colors.blue,
                  Colors.purple,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ) : null,
            ),
            child: !hasColor
                ? null
                : null,
          ),
        ),
        const SizedBox(width: 8),
        // Sec butonu
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: app_theme.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              AppLocalizations.of(context).colorEditorSelect,
              style: TextStyle(
                fontSize: 12,
                color: app_theme.accent,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        // Temizle butonu (varsayilana don)
        if (hasColor) ...[
          const SizedBox(width: 4),
          InkWell(
            onTap: onClear,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close,
                size: 16,
                color: app_theme.error,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Tek bir resim secici satiri
class _ImagePickerRow extends StatelessWidget {
  final String label;
  final String? imagePath;
  final VoidCallback onPick;
  final VoidCallback onClear;
  
  const _ImagePickerRow({
    required this.label,
    required this.imagePath,
    required this.onPick,
    required this.onClear,
  });
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasImage = imagePath != null && imagePath!.isNotEmpty;
    
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            '$label:',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
            ),
          ),
        ),
        // Thumbnail veya placeholder
        GestureDetector(
          onTap: onPick,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? app_theme.projectListCardBg : app_theme.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: hasImage 
                    ? app_theme.accent 
                    : (isDark ? app_theme.projectListCardBorder : app_theme.border),
              ),
            ),
            child: hasImage
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: Image.file(
                      File(imagePath!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.broken_image,
                        size: 20,
                        color: app_theme.error,
                      ),
                    ),
                  )
                : Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 20,
                    color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                  ),
          ),
        ),
        const SizedBox(width: 8),
        // Sec butonu
        InkWell(
          onTap: onPick,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: app_theme.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              AppLocalizations.of(context).colorEditorSelect,
              style: TextStyle(
                fontSize: 12,
                color: app_theme.accent,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        // Temizle butonu
        if (hasImage) ...[
          const SizedBox(width: 4),
          InkWell(
            onTap: onClear,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close,
                size: 16,
                color: app_theme.error,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
