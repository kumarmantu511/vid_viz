import 'package:flutter/material.dart';
import 'package:vidviz/l10n/generated/app_localizations.dart';
import 'package:vidviz/core/theme.dart' as app_theme;
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/audio_reactive_service.dart';
import 'package:vidviz/model/layer.dart';
import 'package:vidviz/model/audio_reactive.dart';
import 'package:vidviz/model/text_asset.dart';

/// AudioReactiveForm - TextForm ve MediaOverlayForm pattern'ini takip eder
/// Audio reactive ayarları: target overlay, audio source, reactive type, sensitivity
class AudioReactiveForm extends StatelessWidget {
  final audioReactiveService = locator.get<AudioReactiveService>();
  final AudioReactiveAsset _asset;

  AudioReactiveForm(this._asset) : super();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<AudioReactiveAsset?>(
      stream: audioReactiveService.editingAudioReactive$,
      initialData: _asset,
      builder: (context, snapshot) {
        AudioReactiveAsset currentAsset = snapshot.data ?? _asset;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView( scrollDirection: Axis.vertical,child: _SubMenu()),
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  color: isDark ? app_theme.projectListBg : app_theme.background,
                  padding: const EdgeInsets.only(left: 16, top: 8, right: 16, bottom: 16),
                  child: Wrap(
                    spacing: 0.0,
                    runSpacing: 0.0,
                    children: [
                      _TargetOverlaySelector(currentAsset),
                      _AudioSourceSelector(currentAsset),
                      _ReactiveTypeSelector(currentAsset),
                      _PresetButtons(currentAsset),
                      _SensitivitySlider(currentAsset),
                      _FrequencyRangeSelector(currentAsset),
                      _SmoothingSlider(currentAsset),
                      _OffsetSlider(currentAsset),
                      _MinMaxSliders(currentAsset),
                      _InvertToggle(currentAsset),
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

/// Preset Buttons - hazır hassasiyet/smoothing setleri
class _PresetButtons extends StatelessWidget {
  final audioReactiveService = locator.get<AudioReactiveService>();
  final AudioReactiveAsset _asset;

  _PresetButtons(this._asset);

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final presets = [
      _PresetConfig(loc.audioReactivePresetUltraSubtle, 0.5, 0.9),
      _PresetConfig(loc.audioReactivePresetSubtle, 0.7, 0.7),
      _PresetConfig(loc.audioReactivePresetSoft, 0.9, 0.6),
      _PresetConfig(loc.audioReactivePresetNormal, 1.1, 0.4),
      _PresetConfig(loc.audioReactivePresetGroove, 1.3, 0.5),
      _PresetConfig(loc.audioReactivePresetPunchy, 1.6, 0.25),
      _PresetConfig(loc.audioReactivePresetHard, 1.9, 0.2),
      _PresetConfig(loc.audioReactivePresetExtreme, 2.2, 0.15),
      _PresetConfig(loc.audioReactivePresetInsane, 2.6, 0.1),
      _PresetConfig(loc.audioReactivePresetChill, 0.9, 0.85),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      /// iki defa verilince kesiyo width: 600,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.audioReactivePresetsTitle,
            style: TextStyle(
              fontSize: 16, 
              fontWeight: FontWeight.bold,
              color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: presets.map((preset) {
                final bool isSelected =
                    (_asset.sensitivity - preset.sensitivity).abs() < 0.01 &&
                    (_asset.smoothing - preset.smoothing).abs() < 0.01;

                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () {
                      final updated = AudioReactiveAsset.clone(_asset)
                        ..sensitivity = preset.sensitivity
                        ..smoothing = preset.smoothing;
                      audioReactiveService.editingAudioReactive = updated;
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
                        preset.name,
                        style: TextStyle(
                          fontSize: 12,
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

class _PresetConfig {
  final String name;
  final double sensitivity;
  final double smoothing;

  _PresetConfig(this.name, this.sensitivity, this.smoothing);
}

/// SubMenu - Icon ve SAVE butonu (MediaOverlay pattern'i)
class _SubMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? app_theme.projectListCardBg : app_theme.surface,
        border: Border(
          right: BorderSide(
            color: isDark ? app_theme.projectListCardBorder : app_theme.border,
            width: 1
          )
        )
      ),
      width: 50, // Sabit genişlik
      child: Column(
        children: [
          IconButton(
            icon: Icon(
              Icons.graphic_eq, 
              color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary
            ),
            tooltip: AppLocalizations.of(context).audioReactiveSidebarTooltip,
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

/// Target Overlay Selector
class _TargetOverlaySelector extends StatelessWidget {
  final audioReactiveService = locator.get<AudioReactiveService>();
  final AudioReactiveAsset _asset;

  _TargetOverlaySelector(this._asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    return StreamBuilder<List<Asset>>(
      stream: audioReactiveService.availableOverlays$,
      initialData: [],
      builder: (context, snapshot) {
        final rawOverlays = snapshot.data ?? [];

        // Aynı id'ye sahip overlay'leri tekilleştir
        final Map<String, Asset> uniqueById = <String, Asset>{};
        for (final overlay in rawOverlays) {
          uniqueById.putIfAbsent(overlay.id, () => overlay);
        }
        final overlays = uniqueById.values.toList();

        if (overlays.isEmpty) {
          return Container(
            /// iki defa verilince kesiyo width: 300,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              loc.audioReactiveNoOverlays,
              style: TextStyle(color: app_theme.error, fontSize: 14),
            ),
          );
        }

        // Ensure current targetOverlayId is valid; fallback to first overlay if not
        String? currentId = _asset.targetOverlayId;
        final hasMatch = overlays.any((o) => o.id == currentId);
        if (!hasMatch) {
          currentId = overlays.first.id;
        }

        return Container(
          /// iki defa verilince kesiyo width: 300,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).audioReactiveTargetOverlayLabel,
                style: TextStyle(
                  fontSize: 14, 
                  fontWeight: FontWeight.w500,
                  color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? app_theme.projectListCardBg : app_theme.surface,
                  border: Border.all(
                    color: isDark ? app_theme.projectListCardBorder : app_theme.border
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: currentId,
                    isExpanded: true,
                    icon: Icon(Icons.arrow_drop_down, color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary),
                    dropdownColor: isDark ? app_theme.projectListCardBg : app_theme.surface,
                    items: overlays.map((overlay) {
                      String label = overlay.title.isNotEmpty
                          ? overlay.title
                          : AppLocalizations.of(context).audioReactiveOverlayUnnamed;
                      String type = _getOverlayType(AppLocalizations.of(context), overlay);
                      return DropdownMenuItem(
                        value: overlay.id,
                        child: Text(
                          '$label ($type)',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        final updated = AudioReactiveAsset.clone(_asset)
                          ..targetOverlayId = value;

                        // Keep min/max aligned with the newly selected target.
                        // Otherwise the first overlay's defaults can be applied to
                        // the new target and cause a visible jump (scale/fontSize).
                        final helper = _ReactiveTypeSelector(updated);
                        final b = helper._boundsForType(updated.reactiveType);
                        final double minB = b[0];
                        final double maxB = b[1];
                        final target = helper._getTargetOverlay();
                        final mm = helper._defaultMinMaxForType(
                          updated.reactiveType,
                          minB,
                          maxB,
                          target,
                        );
                        updated
                          ..minValue = mm[0]
                          ..maxValue = mm[1];

                        audioReactiveService.editingAudioReactive = updated;
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getOverlayType(AppLocalizations loc, Asset asset) {
    final overlayType = asset.data?['overlayType'];

    if (overlayType == 'media') return loc.audioReactiveOverlayTypeMedia;
    if (overlayType == 'audio_reactive') return loc.audioReactiveOverlayTypeAudioReactive;

    if (asset.type == AssetType.text) return loc.audioReactiveOverlayTypeText;
    if (asset.type == AssetType.visualizer) return loc.audioReactiveOverlayTypeVisualizer;
    if (asset.type == AssetType.shader) return loc.audioReactiveOverlayTypeShader;

    return loc.audioReactiveOverlayTypeUnknown;
  }
}

/// Audio Source Selector
class _AudioSourceSelector extends StatelessWidget {
  final audioReactiveService = locator.get<AudioReactiveService>();
  final AudioReactiveAsset _asset;

  _AudioSourceSelector(this._asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<Asset>>(
      stream: audioReactiveService.availableAudioSources$,
      initialData: [],
      builder: (context, snapshot) {
        final audioSources = snapshot.data ?? [];

        String? currentSourceId = _asset.audioSourceId;
        if (currentSourceId != null) {
          final hasMatch = audioSources.any((a) => a.id == currentSourceId);
          if (!hasMatch) {
            currentSourceId = null;
          }
        }

        return Container(
          /// iki defa verilince kesiyo width: 300,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).audioReactiveAudioSourceLabel,
                style: TextStyle(
                  fontSize: 14, 
                  fontWeight: FontWeight.w500,
                  color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? app_theme.projectListCardBg : app_theme.surface,
                  border: Border.all(
                    color: isDark ? app_theme.projectListCardBorder : app_theme.border
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: currentSourceId,
                    isExpanded: true,
                    icon: Icon(Icons.arrow_drop_down, color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary),
                    dropdownColor: isDark ? app_theme.projectListCardBg : app_theme.surface,
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(
                          AppLocalizations.of(context).audioReactiveAudioSourceMixed,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary
                          ),
                        ),
                      ),
                      ...audioSources.map((audio) {
                        String label = audio.title.isNotEmpty
                            ? audio.title
                            : AppLocalizations.of(context).audioReactiveAudioSourceUnnamed;
                        return DropdownMenuItem(
                          value: audio.id,
                          child: Text(
                            label, 
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      final updated = AudioReactiveAsset.clone(_asset)
                        ..audioSourceId = value;
                      audioReactiveService.editingAudioReactive = updated;
                    },
                  ),
                ),
              ),
              if (audioSources.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    AppLocalizations.of(context).audioReactiveNoDedicatedTracks,
                    style: TextStyle(fontSize: 11, color: app_theme.warning),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Reactive Type Selector
class _ReactiveTypeSelector extends StatelessWidget {
  final audioReactiveService = locator.get<AudioReactiveService>();
  final AudioReactiveAsset _asset;

  _ReactiveTypeSelector(this._asset);

  Asset? _getTargetOverlay() {
    final overlays = audioReactiveService.availableOverlays;
    for (final o in overlays) {
      if (o.id == _asset.targetOverlayId) return o;
    }
    return null;
  }

  List<double> _defaultMinMaxForType(
    String reactiveType,
    double minB,
    double maxB,
    Asset? target,
  ) {
    final rawData = target?.data;
    final Map<dynamic, dynamic> dataMap =
        (rawData is Map)
            ? Map<dynamic, dynamic>.from(rawData as Map)
            : const <dynamic, dynamic>{};

    // Some overlays store their values in a nested map.
    Map<dynamic, dynamic> overlayMap = dataMap;
    if (target?.type == AssetType.visualizer && dataMap['visualizer'] is Map) {
      overlayMap = Map<dynamic, dynamic>.from(dataMap['visualizer'] as Map);
    } else if (target?.type == AssetType.shader && dataMap['shader'] is Map) {
      overlayMap = Map<dynamic, dynamic>.from(dataMap['shader'] as Map);
    }

    final bool isTextTarget =
        target?.type == AssetType.text || (dataMap['text'] is Map);
    TextAsset? textTarget;
    if (isTextTarget && target != null) {
      try {
        textTarget = TextAsset.fromAsset(target);
      } catch (_) {
        textTarget = null;
      }
    }

    double clamp(double v, double fallback) {
      final x = v.isFinite ? v : fallback;
      return x.clamp(minB, maxB);
    }

    double baseScale() {
      // Text has no scale field; audio reactive 'scale' is treated as a multiplier.
      if (textTarget != null) {
        return clamp(1.0, 1.0);
      }
      final v = overlayMap['scale'];
      final d = (v is num) ? v.toDouble() : 1.0;
      return clamp(d, 1.0);
    }

    double baseAlpha() {
      if (textTarget != null) {
        return clamp(textTarget.alpha, 1.0);
      }
      final v = overlayMap['opacity'] ?? overlayMap['alpha'];
      final d = (v is num) ? v.toDouble() : 1.0;
      return clamp(d, 1.0);
    }

    double basePos(String key, double fallback) {
      if (textTarget != null) {
        final double d =
            (key == 'x') ? textTarget.x : (key == 'y') ? textTarget.y : fallback;
        return clamp(d, fallback);
      }
      final v = overlayMap[key];
      final d = (v is num) ? v.toDouble() : fallback;
      return clamp(d, fallback);
    }

    double baseRotation01() {
      // Text doesn't support rotation.
      if (textTarget != null) return 0.0;
      final v = overlayMap['rotation'];
      final d = (v is num) ? v.toDouble() : 0.0;
      if (!d.isFinite) return 0.0;
      // media overlay commonly stores degrees 0..360
      if (d > 1.0) {
        final deg = d % 360.0;
        return (deg / 360.0).clamp(0.0, 1.0);
      }
      return d.clamp(0.0, 1.0);
    }

    switch (reactiveType) {
      case 'opacity':
        final b = baseAlpha();
        double minV = clamp(b * 0.8, minB);
        double maxV = clamp(b, maxB);
        if (maxV < minV) {
          final t = minV;
          minV = maxV;
          maxV = t;
        }
        if ((maxV - minV).abs() < 0.0001) {
          minV = (maxV - 0.05).clamp(minB, maxB);
        }
        return [minV, maxV];
      case 'x':
      case 'y':
        final b = basePos(reactiveType, 0.5);
        final delta = (maxB - minB) * 0.08;
        double minV = clamp(b - delta, minB);
        double maxV = clamp(b + delta, maxB);
        if (maxV < minV) {
          final t = minV;
          minV = maxV;
          maxV = t;
        }
        if ((maxV - minV).abs() < 0.0001) {
          maxV = (minV + 0.05).clamp(minB, maxB);
        }
        return [minV, maxV];
      case 'rotation':
        final b = clamp(baseRotation01(), 0.0);
        final delta = (maxB - minB) * 0.08;
        double minV = clamp(b - delta, minB);
        double maxV = clamp(b + delta, maxB);
        if (maxV < minV) {
          final t = minV;
          minV = maxV;
          maxV = t;
        }
        if ((maxV - minV).abs() < 0.0001) {
          maxV = (minV + 0.05).clamp(minB, maxB);
        }
        return [minV, maxV];
      case 'scale':
      default:
        final b = baseScale();
        double minV = clamp(b, minB);
        double maxV = clamp(b * 1.1, maxB);
        if (maxV < minV) {
          final t = minV;
          minV = maxV;
          maxV = t;
        }
        if ((maxV - minV).abs() < 0.0001) {
          maxV = (minV + 0.05).clamp(minB, maxB);
        }
        return [minV, maxV];
    }
  }

  String _getTargetOverlayType() {
    final overlays = audioReactiveService.availableOverlays;
    for (final o in overlays) {
      if (o.id == _asset.targetOverlayId) {
        final t = o.data?['overlayType'];
        if (t is String && t.isNotEmpty) return t;
        if (o.type == AssetType.text) return 'text';
        if (o.type == AssetType.visualizer) return 'visualizer';
        if (o.type == AssetType.shader) return 'shader';
        return 'unknown';
      }
    }
    return 'unknown';
  }

  List<double> _boundsForType(String type) {
    switch (type) {
      case 'opacity':
      case 'x':
      case 'y':
        return const [0.0, 1.0];
      case 'rotation':
        return const [0.0, 1.0];
      case 'scale':
      default:
        final targetType = _getTargetOverlayType();
        if (targetType == 'visualizer') return const [0.5, 2.0];
        return const [0.1, 4.0];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final reactiveTypes = <String, String>{
      'scale': loc.audioReactiveReactiveTypeScale,
      'rotation': loc.audioReactiveReactiveTypeRotation,
      'opacity': loc.audioReactiveReactiveTypeOpacity,
      'x': loc.audioReactiveReactiveTypePosX,
      'y': loc.audioReactiveReactiveTypePosY,
    };

    return Container(
      /// iki defa verilince kesiyo width: 600,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  loc.audioReactiveReactiveTypeLabel,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    overflow: TextOverflow.ellipsis,
                    color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _asset.reactiveType == 'scale' ? loc.audioReactiveReactiveTypeScale :
                _asset.reactiveType == 'rotation' ? loc.audioReactiveReactiveTypeRotation :
                _asset.reactiveType == 'opacity' ? loc.audioReactiveReactiveTypeOpacity :
                _asset.reactiveType == 'x' ? loc.audioReactiveReactiveTypePosX :
                _asset.reactiveType == 'y' ? loc.audioReactiveReactiveTypePosY :
                loc.audioReactiveReactiveTypeFallback,
                style: TextStyle(
                  fontSize: 12,
                  color: app_theme.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: reactiveTypes.entries.map((entry) {
                final isSelected = _asset.reactiveType == entry.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () {
                      final updated = AudioReactiveAsset.clone(_asset)
                        ..reactiveType = entry.key;

                      final b = _boundsForType(entry.key);
                      final double minB = b[0];
                      final double maxB = b[1];

                      final target = _getTargetOverlay();
                      final mm = _defaultMinMaxForType(
                        entry.key,
                        minB,
                        maxB,
                        target,
                      );

                      updated
                        ..minValue = mm[0]
                        ..maxValue = mm[1];
                      audioReactiveService.editingAudioReactive = updated;
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
                        entry.value,
                        style: TextStyle(
                          fontSize: 12,
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

/// Sensitivity Slider
class _SensitivitySlider extends StatelessWidget {
  final audioReactiveService = locator.get<AudioReactiveService>();
  final AudioReactiveAsset _asset;

  _SensitivitySlider(this._asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final double safeValue = (_asset.sensitivity.isFinite ? _asset.sensitivity : 1.0)
        .clamp(0.1, 3.0);
    return Container(
      /// iki defa verilince kesiyo width: 220,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context).audioReactiveSensitivityLabel,
                style: TextStyle(
                  fontSize: 14, 
                  fontWeight: FontWeight.w500,
                  color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
                ),
              ),
              Text(
                'x${_asset.sensitivity.toStringAsFixed(1)}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
                ),
              ),
            ],
          ),
          SizedBox(
            height: 36,
            child: Slider(
              value: safeValue,
              min: 0.1,
              max: 3.0,
              divisions: 29,
              activeColor: app_theme.accent,
              inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
              onChanged: (val) {
                final updated = AudioReactiveAsset.clone(_asset)
                  ..sensitivity = val;
                audioReactiveService.editingAudioReactive = updated;
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Frequency Range Selector
class _FrequencyRangeSelector extends StatelessWidget {
  final audioReactiveService = locator.get<AudioReactiveService>();
  final AudioReactiveAsset _asset;

  _FrequencyRangeSelector(this._asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    return Container(
      /// iki defa verilince kesiyo width: 350,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.audioReactiveFrequencyRangeLabel,
            style: TextStyle(
              fontSize: 14, 
              fontWeight: FontWeight.w500,
              color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['all', 'bass', 'mid', 'treble'].map((range) {
                final isSelected = _asset.frequencyRange == range;
                String label;
                switch (range) {
                  case 'bass':
                    label = loc.audioReactiveFrequencyBass;
                    break;
                  case 'mid':
                    label = loc.audioReactiveFrequencyMid;
                    break;
                  case 'treble':
                    label = loc.audioReactiveFrequencyTreble;
                    break;
                  case 'all':
                  default:
                    label = loc.audioReactiveFrequencyAll;
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () {
                      final updated = AudioReactiveAsset.clone(_asset)
                        ..frequencyRange = range;
                      audioReactiveService.editingAudioReactive = updated;
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                          fontSize: 12,
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

/// Smoothing Slider
class _SmoothingSlider extends StatelessWidget {
  final audioReactiveService = locator.get<AudioReactiveService>();
  final AudioReactiveAsset _asset;

  _SmoothingSlider(this._asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    final double safeValue = (_asset.smoothing.isFinite ? _asset.smoothing : 0.3)
        .clamp(0.0, 1.0);
    return Container(
      /// iki defa verilince kesiyo width: 220,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                loc.audioReactiveSmoothingLabel,
                style: TextStyle(
                  fontSize: 14, 
                  fontWeight: FontWeight.w500,
                  color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
                ),
              ),
              Text(
                '${(_asset.smoothing * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
                ),
              ),
            ],
          ),
          SizedBox(
            height: 36,
            child: Slider(
              value: safeValue,
              min: 0.0,
              max: 1.0,
              divisions: 10,
              activeColor: app_theme.accent,
              inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
              onChanged: (val) {
                final updated = AudioReactiveAsset.clone(_asset)
                  ..smoothing = val;
                audioReactiveService.editingAudioReactive = updated;
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Offset (Delay) Slider
class _OffsetSlider extends StatelessWidget {
  final audioReactiveService = locator.get<AudioReactiveService>();
  final AudioReactiveAsset _asset;

  _OffsetSlider(this._asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    final double safeValue = _asset.offsetMs.toDouble().clamp(-300.0, 300.0);
    return Container(
      /// iki defa verilince kesiyo width: 260,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                loc.audioReactiveDelayLabel,
                style: TextStyle(
                  fontSize: 14, 
                  fontWeight: FontWeight.w500,
                  color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
                ),
              ),
              Text(
                '${_asset.offsetMs} ms',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
                ),
              ),
            ],
          ),
          SizedBox(
            height: 36,
            child: Slider(
              value: safeValue,
              min: -300.0,
              max: 300.0,
              divisions: 24,
              activeColor: app_theme.accent,
              inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
              onChanged: (val) {
                final updated = AudioReactiveAsset.clone(_asset)
                  ..offsetMs = val.round();
                audioReactiveService.editingAudioReactive = updated;
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Min/Max Sliders
class _MinMaxSliders extends StatelessWidget {
  final audioReactiveService = locator.get<AudioReactiveService>();
  final AudioReactiveAsset _asset;

  _MinMaxSliders(this._asset);

  String _getTargetOverlayType() {
    final overlays = audioReactiveService.availableOverlays;
    for (final o in overlays) {
      if (o.id == _asset.targetOverlayId) {
        final t = o.data?['overlayType'];
        if (t is String && t.isNotEmpty) return t;
        if (o.type == AssetType.text) return 'text';
        if (o.type == AssetType.visualizer) return 'visualizer';
        if (o.type == AssetType.shader) return 'shader';
        return 'unknown';
      }
    }
    return 'unknown';
  }

  List<double> _boundsForType(String type) {
    switch (type) {
      case 'opacity':
      case 'x':
      case 'y':
        return const [0.0, 1.0];
      case 'rotation':
        return const [0.0, 1.0];
      case 'scale':
      default:
        final targetType = _getTargetOverlayType();
        if (targetType == 'visualizer') return const [0.5, 2.0];
        return const [0.1, 4.0];
    }
  }

  int _divisionsForType(String type, double minB, double maxB) {
    switch (type) {
      case 'opacity':
        return 100;
      case 'x':
      case 'y':
        return 100;
      case 'rotation':
        return 120;
      case 'scale':
      default:
        return 39;
    }
  }

  String _formatValue(String type, double v) {
    switch (type) {
      case 'rotation':
        return '${(v * 360.0).round()}°';
      case 'opacity':
        return v.toStringAsFixed(2);
      case 'x':
      case 'y':
        return v.toStringAsFixed(2);
      case 'scale':
      default:
        return v.toStringAsFixed(2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    final b = _boundsForType(_asset.reactiveType);
    final double minB = b[0];
    final double maxB = b[1];

    double minVal = _asset.minValue;
    double maxVal = _asset.maxValue;
    if (_asset.reactiveType == 'rotation' && (minVal > 1.0 || maxVal > 1.0)) {
      minVal = minVal / 360.0;
      maxVal = maxVal / 360.0;
    }
    minVal = (minVal.isFinite ? minVal : minB).clamp(minB, maxB);
    maxVal = (maxVal.isFinite ? maxVal : maxB).clamp(minB, maxB);
    if (maxVal < minVal) {
      final t = minVal;
      minVal = maxVal;
      maxVal = t;
    }
    if ((maxVal - minVal).abs() < 0.0001) {
      maxVal = (minVal + 0.05).clamp(minB, maxB);
    }

    final divisions = _divisionsForType(_asset.reactiveType, minB, maxB);
    return Container(
      /// iki defa verilince kesiyo width: 400,
      child: Row(
        children: [
          // Min Value
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        loc.audioReactiveMinLabel,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
                        ),
                      ),
                      Text(
                        _formatValue(_asset.reactiveType, minVal),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 36,
                    child: Slider(
                      value: minVal,
                      min: minB,
                      max: maxB,
                      divisions: divisions,
                      activeColor: app_theme.accent,
                      inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
                      onChanged: (val) {
                        double newMin = val;
                        double newMax = maxVal;
                        if (newMax < newMin + 0.0001) {
                          newMax = (newMin + 0.05).clamp(minB, maxB);
                        }
                        final updated = AudioReactiveAsset.clone(_asset)
                          ..minValue = newMin
                          ..maxValue = newMax;
                        audioReactiveService.editingAudioReactive = updated;
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Max Value
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        loc.audioReactiveMaxLabel,
                        style: TextStyle(
                          fontSize: 14, 
                          fontWeight: FontWeight.w500,
                          color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
                        ),
                      ),
                      Text(
                        _formatValue(_asset.reactiveType, maxVal),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 36,
                    child: Slider(
                      value: maxVal,
                      min: minB,
                      max: maxB,
                      divisions: divisions,
                      activeColor: app_theme.accent,
                      inactiveColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
                      onChanged: (val) {
                        double newMax = val;
                        double newMin = minVal;
                        if (newMax < newMin + 0.0001) {
                          newMin = (newMax - 0.05).clamp(minB, maxB);
                        }
                        final updated = AudioReactiveAsset.clone(_asset)
                          ..minValue = newMin
                          ..maxValue = newMax;
                        audioReactiveService.editingAudioReactive = updated;
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Invert Toggle
class _InvertToggle extends StatelessWidget {
  final audioReactiveService = locator.get<AudioReactiveService>();
  final AudioReactiveAsset _asset;

  _InvertToggle(this._asset);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    return Container(
      /// iki defa verilince kesiyo width: 250,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              loc.audioReactiveInvertLabel,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                overflow: TextOverflow.ellipsis,
                color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary
              ),
            ),
          ),
          const SizedBox(width: 8),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: _asset.invertReaction,
              activeColor: app_theme.accent,
              onChanged: (val) {
                final updated = AudioReactiveAsset.clone(_asset)..invertReaction = val;
                audioReactiveService.editingAudioReactive = updated;
              },
            ),
          ),
          Text(
            _asset.invertReaction ? loc.audioReactiveOn : loc.audioReactiveOff,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _asset.invertReaction ? app_theme.accent : (isDark ? app_theme.darkTextSecondary : app_theme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// (Duration slider kaldırıldı - süre davranışı overlay gibi tamamen timeline pozisyonu ve asset.duration'a bağlı)
