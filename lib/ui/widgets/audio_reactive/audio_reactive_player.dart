import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/director_service.dart';
import 'package:vidviz/service/audio_reactive_service.dart';
import 'package:vidviz/service/audio_analysis_service.dart';
import 'package:vidviz/model/layer.dart';
import 'package:vidviz/model/audio_reactive.dart';
import 'package:vidviz/model/text_asset.dart';
import 'package:vidviz/model/visualizer.dart';


/// Audio Reactive Player - Overlay'leri müziğe göre hareket ettirme (PREVIEW)
/// Export'ta gerçek ses analizi yapılacak, burada basit simülasyon
class AudioReactivePlayer extends StatefulWidget {
  @override
  _AudioReactivePlayerState createState() => _AudioReactivePlayerState();
}

class _AudioReactivePlayerState extends State<AudioReactivePlayer> {
  final directorService = locator.get<DirectorService>();
  final audioReactiveService = locator.get<AudioReactiveService>();
  final audioAnalysis = locator.get<AudioAnalysisService>();
  final logger = locator.get<Logger>();
  StreamSubscription? _positionSubscription;

  // Audio source paths to process
  Set<String> _processedAudioPaths = {};

  // Per-audio reactive last output level for temporal smoothing
  final Map<String, double> _lastLevels = {};
  // Per-target base font size for text overlays so scaling is relative
  final Map<String, double> _baseFontSizes = {};

  // Log throttle (ms)
  final Map<String, int> _lastLogMs = {};
  
  // Batch setState flag to prevent multiple rebuilds per frame
  bool _needsRebuild = false;

  double _clamp01(double v, double fallback) {
    final x = v.isFinite ? v : fallback;
    return x.clamp(0.0, 1.0);
  }

  double _clamp(double v, double min, double max, double fallback) {
    final x = v.isFinite ? v : fallback;
    return x.clamp(min, max);
  }

  double _clampReactiveValue(String reactiveType, double value) {
    switch (reactiveType) {
      case 'opacity':
      case 'x':
      case 'y':
        return _clamp01(value, 0.0);
      case 'rotation':
        // Rotation is normalized 0..1 in audio reactive UI.
        return _clamp01(value, 0.0);
      case 'scale':
      default:
        return _clamp(value, 0.1, 4.0, 1.0);
    }
  }

  List<double> _boundsForTarget({
    required String overlayType,
    required String reactiveType,
  }) {
    switch (reactiveType) {
      case 'opacity':
      case 'x':
      case 'y':
        return const [0.0, 1.0];
      case 'rotation':
        // normalized 0..1 (later multiplied by 360 for overlays that support rotation)
        return const [0.0, 1.0];
      case 'scale':
      default:
        if (overlayType == 'visualizer') return const [0.5, 2.0];
        return const [0.1, 4.0];
    }
  }

  double _clampOverlayValue({
    required String overlayType,
    required String reactiveType,
    required double value,
  }) {
    // Overlay-specific safety layer.
    // Keep these aligned with form slider bounds to avoid UI asserts.
    switch (reactiveType) {
      case 'opacity':
        return _clamp01(value, 1.0);
      case 'x':
      case 'y':
        return _clamp01(value, 0.5);
      case 'rotation':
        // Still normalized 0..1 here.
        return _clamp01(value, 0.0);
      case 'scale':
      default:
        if (overlayType == 'media') return _clamp(value, 0.1, 4.0, 1.0);
        if (overlayType == 'visualizer') return _clamp(value, 0.5, 2.0, 1.0);
        if (overlayType == 'shader') return _clamp(value, 0.1, 4.0, 1.0);
        // Text uses its own mapping.
        return _clamp(value, 0.1, 4.0, 1.0);
    }
  }

  @override
  void initState() {
    super.initState();

    // Listen to position changes (preview + export + scrubbing)
    _positionSubscription = directorService.position$.listen((position) {
      if (!mounted) return;
      _updateAudioReactiveOverlays(position);
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  /// Update overlays based on audio level (REAL FFT or SIMULATED)
  void _updateAudioReactiveOverlays(int position) {
    if (directorService.layers == null) return;
    
    // Reset batch rebuild flag
    _needsRebuild = false;

    // Find all active audio reactive assets
    for (final layer in directorService.layers!) {
      if (layer.type == 'audio_reactive') {
        for (final asset in layer.assets) {
          if (!asset.deleted &&
              position >= asset.begin &&
              position < asset.begin + asset.duration) {
            final reactive = AudioReactiveAsset.fromAsset(asset);

            // Resolve audio source and local time within that source
            final sourceInfo = _getAudioSourceInfo(reactive, position);

            if (sourceInfo != null && sourceInfo.path.isNotEmpty) {
              final canonPath = audioAnalysis.canonicalizeAudioPath(sourceInfo.path);
              // Process audio for FFT if not already done
              if (!_processedAudioPaths.contains(canonPath)) {
                _processedAudioPaths.add(canonPath);
                audioReactiveService.processAudioForFFT(canonPath);
              }

              // Try to get REAL audio level from FFT at the correct local time
              final realAudioLevel = audioReactiveService.getAudioLevelAtTime(
                canonPath,
                sourceInfo.localMs,
                reactive.frequencyRange,
              );

              if (realAudioLevel != null) {
                // ✅ GERÇEK SES ANALİZİ
                _logReactiveInput(
                  reactive: reactive,
                  sourceInfo: sourceInfo,
                  level: realAudioLevel,
                  isRealAudio: true,
                  positionMs: position,
                );
                _applyAudioReactiveEffect(
                  reactive,
                  realAudioLevel,
                  isRealAudio: true,
                  positionMs: position,
                );
              } else {
                // ⏳ FFT henüz hazır değil - simülasyon kullan
                final simulatedLevel = _getSimulatedAudioLevel(position);
                _logReactiveInput(
                  reactive: reactive,
                  sourceInfo: sourceInfo,
                  level: simulatedLevel,
                  isRealAudio: false,
                  positionMs: position,
                );
                _applyAudioReactiveEffect(
                  reactive,
                  simulatedLevel,
                  isRealAudio: false,
                  positionMs: position,
                );
              }
            } else {
              // Audio source yok veya çözülemedi - simülasyon kullan
              _logMissingAudioSource(reactive, position);
              final simulatedLevel = _getSimulatedAudioLevel(position);
              _logReactiveInput(
                reactive: reactive,
                sourceInfo: sourceInfo,
                level: simulatedLevel,
                isRealAudio: false,
                positionMs: position,
              );
              _applyAudioReactiveEffect(
                reactive,
                simulatedLevel,
                isRealAudio: false,
                positionMs: position,
              );
            }
          }
        }
      }
    }
  }

  bool _shouldLog(String key, int positionMs, {int intervalMs = 1000}) {
    final last = _lastLogMs[key];
    if (last != null && (positionMs - last) < intervalMs) return false;
    _lastLogMs[key] = positionMs;
    return true;
  }

  void _logMissingAudioSource(AudioReactiveAsset reactive, int positionMs) {
    final key = reactive.id.isNotEmpty ? reactive.id : reactive.targetOverlayId;
    if (!_shouldLog('missing:$key', positionMs, intervalMs: 1500)) return;
    try {
      logger.w(
        '[AR] missing audio source id=$key target=${reactive.targetOverlayId} '
        'audioSourceId=${reactive.audioSourceId ?? ''} posMs=$positionMs',
      );
    } catch (_) {}
  }

  void _logReactiveInput({
    required AudioReactiveAsset reactive,
    required _AudioSourceInfo? sourceInfo,
    required double level,
    required bool isRealAudio,
    required int positionMs,
  }) {
    final key = reactive.id.isNotEmpty ? reactive.id : reactive.targetOverlayId;
    if (!_shouldLog('input:$key', positionMs)) return;
    final audioPath = sourceInfo?.path ?? '';
    final localMs = sourceInfo?.localMs ?? -1;
    try {
      logger.i(
        '[AR] input id=$key target=${reactive.targetOverlayId} '
        'audioPath=$audioPath localMs=$localMs posMs=$positionMs '
        'level=${level.toStringAsFixed(3)} '
        'freq=${reactive.frequencyRange} sens=${reactive.sensitivity} '
        'smooth=${reactive.smoothing} min=${reactive.minValue} '
        'max=${reactive.maxValue} invert=${reactive.invertReaction} '
        'mode=${isRealAudio ? 'real' : 'sim'}',
      );
    } catch (_) {}
  }

  void _logReactiveApply({
    required AudioReactiveAsset reactive,
    required double audioLevel,
    required double filteredLevel,
    required double targetLevel,
    required double value,
    required int? positionMs,
  }) {
    if (positionMs == null) return;
    final key = reactive.id.isNotEmpty ? reactive.id : reactive.targetOverlayId;
    if (!_shouldLog('apply:$key', positionMs)) return;
    try {
      logger.i(
        '[AR_APPLY] id=$key target=${reactive.targetOverlayId} '
        'type=${reactive.reactiveType} audio=${audioLevel.toStringAsFixed(3)} '
        'filtered=${filteredLevel.toStringAsFixed(3)} '
        'level=${targetLevel.toStringAsFixed(3)} '
        'value=${value.toStringAsFixed(3)} posMs=$positionMs',
      );
    } catch (_) {}
  }

  /// Audio kaynağını ve o kaynak içindeki yerel zamanı (ms) çöz
  /// Sadece gerçekten ses taşıyan kaynaklar (audio track veya raster video + useVideoAudio) dikkate alınır.
  _AudioSourceInfo? _getAudioSourceInfo(
    AudioReactiveAsset reactive,
    int position,
  ) {
    if (directorService.layers == null) return null;

    // Helper: Bir asset'in gerçekten ses kaynağı olup olmadığını kontrol et
    bool _isAudioCapableAsset(Layer layer, Asset asset) {
      if (asset.deleted || asset.srcPath.isEmpty) return false;
      if (asset.type == AssetType.audio) return true;
      if (asset.type == AssetType.video &&
          layer.type == 'raster' &&
          layer.useVideoAudio) {
        return true;
      }
      return false;
    }

    Asset? sourceAsset;

    // 1) audioSourceId tanımlıysa, önce o asset'i bul ve ses taşıyıp taşımadığını kontrol et
    if (reactive.audioSourceId != null) {
      for (final layer in directorService.layers!) {
        for (final asset in layer.assets) {
          if (asset.id == reactive.audioSourceId &&
              _isAudioCapableAsset(layer, asset)) {
            sourceAsset = asset;
            break;
          }
        }
        if (sourceAsset != null) break;
      }
    }

    // 2) ID'den geçerli bir kaynak bulunamadıysa veya ID yoksa: mevcut pozisyonda aktif ses kaynağını ara
    if (sourceAsset == null) {
      for (final layer in directorService.layers!) {
        if (layer.type == 'audio' ||
            (layer.type == 'raster' && layer.useVideoAudio)) {
          for (final asset in layer.assets) {
            if (_isAudioCapableAsset(layer, asset) &&
                position >= asset.begin &&
                position < asset.begin + asset.duration) {
              sourceAsset = asset;
              break;
            }
          }
        }
        if (sourceAsset != null) break;
      }
    }

    // 3) Aktif ses kaynağı yoksa, projedeki ilk uygun ses kaynağını fallback olarak kullan
    if (sourceAsset == null) {
      for (final layer in directorService.layers!) {
        if (layer.type == 'audio' ||
            (layer.type == 'raster' && layer.useVideoAudio)) {
          for (final asset in layer.assets) {
            if (_isAudioCapableAsset(layer, asset)) {
              sourceAsset = asset;
              break;
            }
          }
        }
        if (sourceAsset != null) break;
      }
    }

    if (sourceAsset == null) return null;

    // Kaynak içi yerel zaman: timeline pozisyonu - layer'daki begin + cutFrom offset
    // + audio reactive offset (ileri/geri kaydırma)
    int localMs =
        position - sourceAsset.begin + sourceAsset.cutFrom + reactive.offsetMs;
    if (localMs < 0) localMs = 0;

    return _AudioSourceInfo(sourceAsset.srcPath, localMs);
  }

  /// Simulated audio level (fallback)
  double _getSimulatedAudioLevel(int position) {
    final timeInSeconds = position / 1000.0;
    final beatInterval = 1.0; // 60 BPM
    final timeSinceLastBeat = timeInSeconds % beatInterval;

    if (timeSinceLastBeat < 0.1) {
      return timeSinceLastBeat / 0.1;
    } else {
      final decayTime = (timeSinceLastBeat - 0.1) / (beatInterval - 0.1);
      return math.exp(-decayTime * 3.0).clamp(0.0, 1.0);
    }
  }

  /// Apply audio reactive effect to target overlay
  void _applyAudioReactiveEffect(
    AudioReactiveAsset reactive,
    double audioLevel, {
    bool isRealAudio = false,
    int? positionMs,
  }) {
    if (directorService.layers == null) return;

    // Find target overlay
    Asset? targetAsset;
    int targetLayerIndex = -1;
    int targetAssetIndex = -1;

    for (int i = 0; i < directorService.layers!.length; i++) {
      final layer = directorService.layers![i];
      for (int j = 0; j < layer.assets.length; j++) {
        final asset = layer.assets[j];
        if (asset.id == reactive.targetOverlayId) {
          targetAsset = asset;
          targetLayerIndex = i;
          targetAssetIndex = j;
          break;
        }
      }
      if (targetAsset != null) break;
    }

    if (targetAsset == null) return;

    // Normalize overlayType label
    final String targetOverlayType =
        (targetAsset.data?['overlayType'] as String?) ??
        (targetAsset.type == AssetType.text
            ? 'text'
            : targetAsset.type == AssetType.visualizer
                ? 'visualizer'
                : targetAsset.type == AssetType.shader
                    ? 'shader'
                    : 'unknown');

    // Start from normalized audio level
    final double safeAudio = audioLevel.isFinite ? audioLevel : 0.0;
    double filteredLevel = safeAudio.clamp(0.0, 1.0);

    // For simulated audio (no real FFT), apply simple fake frequency behavior.
    // For real FFT levels, frequencyRange is already handled in AudioAnalysisService.
    if (!isRealAudio) {
      filteredLevel = _applyFrequencyFilter(
        filteredLevel,
        reactive.frequencyRange,
      );
    }

    // Apply sensitivity
    final double safeSensitivity =
        (reactive.sensitivity.isFinite ? reactive.sensitivity : 1.0)
            .clamp(0.0, 10.0);
    double targetLevel = (filteredLevel * safeSensitivity).clamp(0.0, 1.0);

    // Temporal smoothing based on previous output level for this reactive asset
    final smoothing =
        (reactive.smoothing.isFinite ? reactive.smoothing : 0.0).clamp(0.0, 0.95);
    if (smoothing > 0.0) {
      final prevLevel = _lastLevels[reactive.id] ?? targetLevel;
      final alpha = 1.0 - smoothing; // lower alpha => stronger smoothing
      targetLevel = prevLevel * (1.0 - alpha) + targetLevel * alpha;
    }
    _lastLevels[reactive.id] = targetLevel;

    // Invert if needed
    if (reactive.invertReaction) {
      targetLevel = 1.0 - targetLevel;
    }

    // Map to min/max range (ensure non-zero range)
    final bounds = _boundsForTarget(
      overlayType: targetOverlayType,
      reactiveType: reactive.reactiveType,
    );
    final double minB = bounds[0];
    final double maxB = bounds[1];

    double minValue = reactive.minValue.isFinite ? reactive.minValue : minB;
    double maxValue = reactive.maxValue.isFinite ? reactive.maxValue : maxB;

    // Backward compatibility: some projects stored rotation bounds in degrees.
    if (reactive.reactiveType == 'rotation' && (minValue > 1.0 || maxValue > 1.0)) {
      minValue = minValue / 360.0;
      maxValue = maxValue / 360.0;
    }

    minValue = minValue.clamp(minB, maxB);
    maxValue = maxValue.clamp(minB, maxB);
    if (maxValue < minValue) {
      final t = minValue;
      minValue = maxValue;
      maxValue = t;
    }
    if ((maxValue - minValue).abs() < 0.0001) {
      maxValue = (minValue + 0.05).clamp(minB, maxB);
    }
    var value = minValue + (maxValue - minValue) * targetLevel;
    value = _clampReactiveValue(reactive.reactiveType, value);

    _logReactiveApply(
      reactive: reactive,
      audioLevel: audioLevel,
      filteredLevel: filteredLevel,
      targetLevel: targetLevel,
      value: value,
      positionMs: positionMs,
    );

    // Apply to target overlay based on reactive type
    _applyValueToOverlay(
      targetAsset,
      reactive.reactiveType,
      value,
      targetLayerIndex,
      targetAssetIndex,
      positionMs: positionMs,
    );
  }

  /// Apply frequency filter (simplified for preview)
  double _applyFrequencyFilter(double audioLevel, String frequencyRange) {
    // TODO: Real frequency analysis in export
    // For preview, just simulate different ranges
    switch (frequencyRange) {
      case 'bass':
        return audioLevel * 0.8; // Bass is usually lower amplitude
      case 'mid':
        return audioLevel;
      case 'treble':
        return audioLevel * 0.6; // Treble is usually lower amplitude
      case 'all':
      default:
        return audioLevel;
    }
  }

  /// Apply value to target overlay property
  void _applyValueToOverlay(
    Asset targetAsset,
    String reactiveType,
    double value,
    int layerIndex,
    int assetIndex, {
    int? positionMs,
  }
  ) {
    final overlayType = targetAsset.data?['overlayType'];

    if (overlayType == 'text' || targetAsset.type == AssetType.text) {
      // Text overlay - TextAsset has different properties
      try {
        final textAsset = TextAsset.fromAsset(targetAsset);

        final double safe = _clampOverlayValue(
          overlayType: 'text',
          reactiveType: reactiveType,
          value: value,
        );

        switch (reactiveType) {
          case 'scale':
            // Text uses fontSize, not scale; treat value as a multiplier
            final String key = targetAsset.id;
            final double baseFontSize =
                _baseFontSizes[key] ?? textAsset.fontSize;
            _baseFontSizes[key] = baseFontSize;
            final double scaled = (baseFontSize * safe).clamp(0.03, 1.0);
            textAsset.fontSize = scaled;
            break;
          case 'rotation':
            // Text doesn't support rotation in current model
            // TODO: Add rotation support to TextAsset
            break;
          case 'opacity':
            // Text uses alpha property
            textAsset.alpha = safe;
            break;
          case 'x':
            textAsset.x = safe;
            break;
          case 'y':
            textAsset.y = safe;
            break;
        }

        // Convert back to Asset, but preserve original id so audio reactive
        // targetOverlayId continues to match this text overlay.
        final updatedAsset = textAsset.toAsset();
        updatedAsset.id = targetAsset.id;
        directorService.layers![layerIndex].assets[assetIndex] = updatedAsset;
        _needsRebuild = true;
      } catch (e) {
        // If TextAsset parsing fails, skip
        print('AudioReactive: Failed to update text asset: $e');
      }
    } else if (overlayType == 'media') {
      // Media overlay - update data
      final data = Map<String, dynamic>.from(targetAsset.data ?? {});

      final double safe = _clampOverlayValue(
        overlayType: 'media',
        reactiveType: reactiveType,
        value: value,
      );

      switch (reactiveType) {
        case 'scale':
          final String key = targetAsset.id;
          if (positionMs != null && _shouldLog('mediaScale:$key', positionMs)) {
            try {
              logger.i(
                '[AR_APPLY] media scale id=$key value=${safe.toStringAsFixed(3)}',
              );
            } catch (_) {}
          }
          data['scale'] = safe;
          break;
        case 'rotation':
          data['rotation'] = safe * 360.0;
          break;
        case 'opacity':
          data['opacity'] = safe;
          break;
        case 'x':
          data['x'] = safe;
          break;
        case 'y':
          data['y'] = safe;
          break;
      }

      targetAsset.data = data;
      directorService.layers![layerIndex].assets[assetIndex] = targetAsset;
      _needsRebuild = true;
    } else if (overlayType == 'visualizer' ||
        targetAsset.type == AssetType.visualizer) {
      // Visualizer overlay - VisualizerAsset has scale and alpha, no rotation
      try {
        final visualizerAsset = VisualizerAsset.fromAsset(targetAsset);

        final double safe = _clampOverlayValue(
          overlayType: 'visualizer',
          reactiveType: reactiveType,
          value: value,
        );

        switch (reactiveType) {
          case 'scale':
            visualizerAsset.scale = safe;
            break;
          case 'rotation':
            // Visualizer stores rotation in degrees.
            visualizerAsset.rotation = (safe * 360.0).clamp(0.0, 360.0);
            break;
          case 'opacity':
            visualizerAsset.alpha = safe;
            break;
          case 'x':
            visualizerAsset.x = safe;
            break;
          case 'y':
            visualizerAsset.y = safe;
            break;
        }

        // Convert back to Asset and preserve original id so audio reactive
        // targetOverlayId keeps pointing to this visualizer overlay.
        final updatedAsset = visualizerAsset.toAsset();
        updatedAsset.id = targetAsset.id;
        directorService.layers![layerIndex].assets[assetIndex] = updatedAsset;
        _needsRebuild = true;
      } catch (e) {
        print('AudioReactive: Failed to update visualizer asset: $e');
      }
    } else if (overlayType == 'shader' ||
        targetAsset.type == AssetType.shader) {
      // Shader overlay - update data directly (no fromAsset/toAsset methods)
      final data = Map<String, dynamic>.from(targetAsset.data ?? {});

      final rawShader = data['shader'];
      final Map<String, dynamic>? shaderMap =
          (rawShader is Map) ? Map<String, dynamic>.from(rawShader) : null;

      final double safe = _clampOverlayValue(
        overlayType: 'shader',
        reactiveType: reactiveType,
        value: value,
      );

      switch (reactiveType) {
        case 'scale':
          if (shaderMap != null) {
            shaderMap['scale'] = safe;
          } else {
            data['scale'] = safe;
          }
          break;
        case 'rotation':
          // Shader doesn't support rotation in current model
          // TODO: Add rotation support to ShaderEffectAsset
          break;
        case 'opacity':
          if (shaderMap != null) {
            shaderMap['alpha'] = safe;
          } else {
            data['alpha'] = safe;
          }
          break;
        case 'x':
          if (shaderMap != null) {
            shaderMap['x'] = safe;
          } else {
            data['x'] = safe;
          }
          break;
        case 'y':
          if (shaderMap != null) {
            shaderMap['y'] = safe;
          } else {
            data['y'] = safe;
          }
          break;
      }

      if (shaderMap != null) {
        data['shader'] = shaderMap;
      }

      targetAsset.data = data;
      directorService.layers![layerIndex].assets[assetIndex] = targetAsset;
      _needsRebuild = true;
    }
    
    // Batch setState: only rebuild once after all overlays updated
    if (_needsRebuild && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // Audio reactive player is invisible - it just updates overlay properties
    return Container();
  }
}

/// Audio kaynağı çözüm bilgisi: path + kaynak içi zaman
class _AudioSourceInfo {
  final String path;
  final int localMs;

  _AudioSourceInfo(this.path, this.localMs);
}
