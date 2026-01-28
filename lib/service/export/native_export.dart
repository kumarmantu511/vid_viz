import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:vidviz/model/layer.dart';
import 'package:vidviz/model/video_settings.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/export/native_text_preprocess.dart';
import 'package:vidviz/service/export/native_overlay_preprocess.dart';
import 'package:vidviz/service/export/native_ui_context.dart';
import 'package:vidviz/service/export/native_visualizer_staging.dart';
import 'package:vidviz/service/export/native_fft_builder.dart';
import 'package:vidviz/service/export/native_shader_builder.dart';
import 'package:vidviz/service/export/native_shader_loader.dart';
import 'package:vidviz/service/export/native_progress.dart';
import 'package:vidviz/service/audio_analysis_service.dart';
import 'package:vidviz/service/visualizer_service.dart';
import 'package:logger/logger.dart';

// Engine paketinden import
import 'package:vidviz_engine/vidviz_engine.dart';

/// VidViz Native Export Service
/// Ana uygulamadan engine'e TEK giriș-çıkış noktası.
/// DirectorService bu dosyayı kullanır.

/// Native export availability check
bool get isNativeExportAvailable {
  return Platform.isAndroid || Platform.isIOS;
}

/// Native Export Service
/// 
/// Wrapper around vidviz_engine FFI calls.
/// Provides async API for DirectorService.
class NativeExportService {
  static final NativeExportService instance = NativeExportService._();
  NativeExportService._();

  final _logger = locator.get<Logger>();
  final _progressController = StreamController<NativeExportProgress>.broadcast();

  static const bool _audioPerfLogs = kDebugMode || kProfileMode;

  void _perf(String msg) {
    if (!_audioPerfLogs) return;
    try {
      _logger.i(msg);
    } catch (_) {}
  }

  Stream<NativeExportProgress> get progress$ => _progressController.stream;

  bool _initialized = false;
  bool _exporting = false;
  StreamSubscription? _progressSub;

  String? _lastErrorMessage;
  String? get lastErrorMessage => _lastErrorMessage;

  /// Initialize native engine
  Future<bool> initialize() async {
    if (_initialized) return true;

    _logger.i('Initializing native export engine...');

    try {
      final engine = EngineClient.instance;
      _initialized = await engine.initialize();

      if (_initialized) {
        _logger.i('Native engine initialized successfully');
      } else {
        final detail = engine.lastInitError;
        if (detail != null && detail.isNotEmpty) {
          _logger.w('Native engine initialization failed: $detail');
        } else {
          _logger.w('Native engine initialization failed');
        }
      }

      return _initialized;
    } catch (e) {
      _logger.e('Failed to initialize native engine: $e');
      return false;
    }
  }

  /// Export video using native engine
  Future<String?> export({
    required List<Layer> layers,
    required int width,
    required int height,
    required int fps,
    required int quality,
    required VideoSettings videoSettings,
    required String outputFormat,
    required String outputPath,
    required int totalDuration,
    double? uiPlayerWidth,
    double? uiPlayerHeight,
    double? uiDevicePixelRatio,
  }) async {
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) {
        _logger.w('Native engine not initialized');
        return null;
      }
    }

    if (_exporting) {
      _logger.w('Export already in progress');
      return null;
    }

    _exporting = true;
    final jobId = 'export_${DateTime.now().millisecondsSinceEpoch}';
    _logger.i('Starting native export: $jobId');
    _perf('[AudioPerf][Export] start jobId=$jobId');

    _lastErrorMessage = null;

    try {
      final engine = EngineClient.instance;

      final List<dynamic> exportLayersJson = jsonDecode(jsonEncode(layers.map((l) => l.toJson()).toList()),) as List<dynamic>;
      final List<Layer> exportLayers = exportLayersJson.map((e) => Layer.fromJson(Map<String, dynamic>.from(e as Map))).toList();

      _progressSub = engine.progress$.listen((p) {
        _progressController.add(NativeExportProgress(
          progress: p.progress,
          currentFrame: p.currentFrame,
          totalFrames: p.totalFrames,
          fps: p.fps,
          elapsedMs: p.elapsedMs,
          videoDecodePath: p.videoDecodePath,
          videoDecodeError: p.videoDecodeError,
          setEncoderSurfaceOk: p.setEncoderSurfaceOk,
          presentOkCount: p.presentOkCount,
          presentFailCount: p.presentFailCount,
          lastEglError: p.lastEglError,
          lastPresentError: p.lastPresentError,
        ));
      });

      try {
        _progressController.add(
          NativeExportProgress(progress: 0.01, currentFrame: 0, totalFrames: 1),
        );
      } catch (_) {}
      final shaderBuilder = NativeExportShaderBuilder(
        logger: _logger,
        loader: NativeExportShaderLoader(_logger),
      );
      final swShaders = _audioPerfLogs ? (Stopwatch()..start()) : null;
      final shaders = await shaderBuilder.buildShadersForLayers(exportLayers);
      if (swShaders != null) {
        swShaders.stop();
        _perf('[AudioPerf][Export] shaders_ms=${swShaders.elapsedMilliseconds}');
      }

      try {
        _progressController.add(
          NativeExportProgress(progress: 0.03, currentFrame: 0, totalFrames: 1),
        );
      } catch (_) {}
      final fftBuilder = NativeExportFftBuilder(
        logger: _logger,
        audioAnalysis: locator.get<AudioAnalysisService>(),
        visualizerService: locator.get<VisualizerService>(),
      );
      final swFft = _audioPerfLogs ? (Stopwatch()..start()) : null;
      final fftData = await fftBuilder.buildFftDataForLayers(
        exportLayers,
        onProgress: (p) {
          try {
            _progressController.add(
              NativeExportProgress(progress: p, currentFrame: 0, totalFrames: 1),
            );
          } catch (_) {}
        },
      );
      if (swFft != null) {
        swFft.stop();
        _perf('[AudioPerf][Export] fft_build_ms=${swFft.elapsedMilliseconds} fft_sources=${fftData.length}');
      }

      try {
        _progressController.add(
          NativeExportProgress(progress: 0.05, currentFrame: 0, totalFrames: 1),
        );

        final ctx = ExportUiContext(
          exportWidth: width,
          exportHeight: height,
          uiPlayerWidth: uiPlayerWidth,
          uiPlayerHeight: uiPlayerHeight,
          uiDevicePixelRatio: uiDevicePixelRatio,
        );
        ExportTextPreprocess.apply(exportLayers, ctx);
        ExportOverlayPreprocess.apply(exportLayers, ctx);

        for (final layer in exportLayers) {
          for (final asset in layer.assets) {
            if (asset.deleted) continue;
            if (asset.type != AssetType.shader) continue;
            final data = asset.data;
            if (data is! Map<String, dynamic>) continue;
            final shader = data['shader'];
            if (shader is! Map<String, dynamic>) continue;

            double numVal(String key, double fallback) {
              final v = shader[key];
              if (v is num) {
                final d = v.toDouble();
                return d.isFinite ? d : fallback;
              }
              return fallback;
            }

            shader['x'] = numVal('x', 0.5).clamp(0.0, 1.0);
            shader['y'] = numVal('y', 0.5).clamp(0.0, 1.0);
            shader['scale'] = numVal('scale', 1.0).clamp(0.1, 4.0);
            shader['alpha'] = numVal('alpha', 1.0).clamp(0.0, 1.0);

            shader['intensity'] = numVal('intensity', 0.5).clamp(0.0, 1.0);
            shader['speed'] = numVal('speed', 1.0).clamp(0.0, 5.0);
            shader['size'] = numVal('size', 1.0).clamp(0.0, 10.0);
            shader['density'] = numVal('density', 0.5).clamp(0.0, 1.0);
            shader['angle'] = numVal('angle', 0.0).clamp(-180.0, 180.0);
            shader['frequency'] = numVal('frequency', 2.0).clamp(0.0, 50.0);
            shader['amplitude'] = numVal('amplitude', 0.3).clamp(0.0, 10.0);
            shader['blurRadius'] = numVal('blurRadius', 5.0).clamp(0.0, 100.0);
            shader['vignetteSize'] = numVal('vignetteSize', 0.5).clamp(0.0, 1.0);
          }
        }

        final String stagingDir = '${Directory.systemTemp.path}${Platform.pathSeparator}vidviz_export_assets_$jobId';
        final swStaging = _audioPerfLogs ? (Stopwatch()..start()) : null;
        await ExportVisualizerStaging.apply(
          layers: exportLayers,
          stagingDir: stagingDir,
          totalDuration: totalDuration,
        );
        if (swStaging != null) {
          swStaging.stop();
          _perf('[AudioPerf][Export] visualizer_staging_ms=${swStaging.elapsedMilliseconds}');
        }
      } catch (e, st) {
        _logger.w(
          'Native export preprocess/staging error: $e',
          error: e,
          stackTrace: st,
        );
      }

      final exportJob = ExportJob(
        jobId: jobId,
        settings: ExportSettings(
          width: width,
          height: height,
          fps: fps,
          quality: quality,
          aspectRatio: videoSettings.aspectRatio,
          cropMode: videoSettings.cropMode,
          rotation: videoSettings.rotation,
          flipHorizontal: videoSettings.flipHorizontal,
          flipVertical: videoSettings.flipVertical,
          backgroundColor: videoSettings.backgroundColor,
          outputFormat: outputFormat,
          outputPath: outputPath,
          uiPlayerWidth: uiPlayerWidth,
          uiPlayerHeight: uiPlayerHeight,
          uiDevicePixelRatio: uiDevicePixelRatio,
        ),
        layers: exportLayers.map((l) => _convertLayer(l)).toList(),
        shaders: shaders,
        fftData: fftData,
        totalDuration: totalDuration,
      );

      final result = await engine.submitJob(exportJob);

      if (result.success) {
        _lastErrorMessage = null;
        _logger.i('Native export completed: ${result.outputPath}');
        _perf('[AudioPerf][Export] complete jobId=$jobId');
        return result.outputPath;
      } else {
        _lastErrorMessage = result.errorMessage ?? 'Unknown native export error';
        _logger.e('Native export failed: ${result.errorMessage}');
        _perf('[AudioPerf][Export] failed jobId=$jobId err=${result.errorMessage ?? 'unknown'}');
        return null;
      }
    } catch (e) {
      _lastErrorMessage = e.toString();
      _logger.e('Native export error: $e');
      _perf('[AudioPerf][Export] crash jobId=$jobId err=$e');
      return null;
    } finally {
      _progressSub?.cancel();
      _progressSub = null;
      _exporting = false;
    }
  }

  ExportLayer _convertLayer(Layer layer) {
    return ExportLayer(
      id: layer.id,
      type: layer.type,
      name: layer.name,
      zIndex: layer.zIndex,
      volume: layer.volume,
      mute: layer.mute,
      useVideoAudio: layer.useVideoAudio,
      assets: layer.assets.map((a) => _convertAsset(a)).toList(),
    );
  }

  /// Convert app asset to export asset
  ExportAsset _convertAsset(dynamic asset) {
    return ExportAsset(
      id: asset.id ?? '',
      type: asset.type?.toString().split('.').last ?? 'image',
      srcPath: asset.srcPath ?? '',
      begin: asset.begin ?? 0,
      duration: asset.duration ?? 0,
      cutFrom: asset.cutFrom ?? 0,
      playbackSpeed: (asset.playbackSpeed is num) ? (asset.playbackSpeed as num).toDouble() : 1.0,
      data: (asset.data is Map<String, dynamic>) ? (asset.data as Map<String, dynamic>) : null,
    );
  }

  void cancel() {
    if (!_exporting) return;

    EngineClient.instance.cancel();
    _lastErrorMessage = 'Cancelled';
    _logger.i('Native export cancelled');
  }

  void dispose() {
    _progressSub?.cancel();
    _progressController.close();
    EngineClient.instance.dispose();
    _initialized = false;
  }
}

/// Helper to create native export job from DirectorService
Future<String?> exportWithNativeEngine({
  required List<Layer> layers,
  required int width,
  required int height,
  required int fps,
  required int quality,
  required VideoSettings videoSettings,
  String outputFormat = 'mp4',
  required String outputPath,
  required int totalDuration,
}) {
  return NativeExportService.instance.export(
    layers: layers,
    width: width,
    height: height,
    fps: fps,
    quality: quality,
    videoSettings: videoSettings,
    outputFormat: outputFormat,
    outputPath: outputPath,
    totalDuration: totalDuration,
  );
}