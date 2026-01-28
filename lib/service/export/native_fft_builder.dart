import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:vidviz/model/layer.dart';
import 'package:vidviz/service/audio_analysis_service.dart';
import 'package:vidviz/service/visualizer_service.dart';
import 'package:vidviz_engine/vidviz_engine.dart';
import 'native_audio_picker.dart';

class NativeExportFftBuilder {
  final Logger logger;
  final AudioAnalysisService audioAnalysis;
  final VisualizerService? visualizerService;

  static const int _maxExportFftFrames = 20000;
  static const bool _audioPerfLogs = kDebugMode || kProfileMode;

  void _perf(String msg) {
    if (!_audioPerfLogs) return;
    try {
      logger.i(msg);
    } catch (_) {}
  }

  NativeExportFftBuilder({
    required this.logger,
    required this.audioAnalysis,
    this.visualizerService,
  });

  Future<List<ExportFFTData>> buildFftDataForLayers(
    List<Layer> layers, {
    void Function(double progress)? onProgress,
  }) async {
    final swTotal = _audioPerfLogs ? (Stopwatch()..start()) : null;
    final sources = <String, Map<String, dynamic>>{};
    final fallbackAudio = NativeExportAudioPicker.pickBestAudioSourcePath(layers);

    if (fallbackAudio != null && fallbackAudio.isNotEmpty) {
      logger.i('[ExportFFT] Fallback audio source: $fallbackAudio');
    }

    for (final layer in layers) {
      for (final asset in layer.assets) {
        final t = asset.type.toString().split('.').last;

        if (t != 'visualizer') continue;

        final data = asset.data;
        if (data is! Map<String, dynamic>) continue;
        final vis = data['visualizer'];
        if (vis is! Map<String, dynamic>) continue;

        final rm = vis['renderMode'];
        final renderMode = (rm is String ? rm : '').toString().split('.').last;
        if (renderMode == 'counter') continue;
        if (renderMode == 'progress') continue;

        String audioPath = asset.srcPath;

        if (audioPath.isEmpty || !File(audioPath).existsSync()) {
          final explicit = (vis['audioPath'] as String?)?.toString();
          if (explicit != null && explicit.isNotEmpty && File(explicit).existsSync()) {
            audioPath = explicit;
          } else if (fallbackAudio != null) {
            audioPath = fallbackAudio;
          }
        }
        if (audioPath.isEmpty || !File(audioPath).existsSync()) continue;

        try {
          vis['audioPath'] = audioPath;
        } catch (_) {}

        if (!sources.containsKey(audioPath)) {
          logger.i(
            '[ExportFFT] visualizer source: $audioPath '
            'bands=${vis['fftBands'] ?? 'n/a'}',
          );
        }
        sources.putIfAbsent(audioPath, () => vis);
      }
    }

    for (final layer in layers) {
      for (final asset in layer.assets) {
        if (asset.deleted) continue;
        if (asset.type != AssetType.image) continue;
        final data = asset.data;
        if (data is! Map<String, dynamic>) continue;
        if (data['overlayType'] != 'audio_reactive') continue;

        String? audioPath;
        final audioSourceId = data['audioSourceId'];
        if (audioSourceId is String && audioSourceId.isNotEmpty) {
          audioPath = NativeExportAudioPicker.pickAudioPathByAssetId(layers, audioSourceId);
        }
        audioPath ??= fallbackAudio;

        if (audioPath == null || audioPath.isEmpty) continue;
        if (!File(audioPath).existsSync()) continue;

        try {
          data['audioPath'] = audioPath;
        } catch (_) {}

        if (!sources.containsKey(audioPath)) {
          logger.i(
            '[ExportFFT] audio_reactive source: $audioPath '
            'freq=${data['frequencyRange'] ?? 'all'}',
          );
        }
        sources.putIfAbsent(
          audioPath,
          () => <String, dynamic>{
            'overlayType': 'audio_reactive',
            'frequencyRange': data['frequencyRange'],
          },
        );
      }
    }

    if (sources.isEmpty) {
      logger.i('[ExportFFT] No FFT sources found for export');
      return const [];
    }

    _perf('[AudioPerf][ExportFFT] start sources=${sources.length}');

    final out = <ExportFFTData>[];
    final total = sources.length;
    var idx = 0;

    for (final e in sources.entries) {
      idx++;
      try {
        onProgress?.call(0.01 + (0.02 * (idx / total)));
      } catch (_) {}

      final audioPath = e.key;
      final cfg = e.value;
      final overlayType = (cfg['overlayType'] as String?)?.toString();
      final bool isAudioReactive = overlayType == 'audio_reactive';

      try {
        final swSource = _audioPerfLogs ? (Stopwatch()..start()) : null;
        List<List<double>> frames;
        var hopSize = AudioAnalysisService.hopSize;
        bool computedAtSource = false;

        int _pickHopSizeOverrideForPcm(Float32List pcm) {
          final int baseHop = AudioAnalysisService.hopSize;
          if (pcm.length <= AudioAnalysisService.fftSize) return baseHop;
          final int expectedFrames =
              ((pcm.length - AudioAnalysisService.fftSize) / baseHop).floor();
          if (expectedFrames <= _maxExportFftFrames) return baseHop;
          final int step = (expectedFrames / _maxExportFftFrames).ceil().clamp(1, 1000000);
          return baseHop * step;
        }

        if (isAudioReactive) {
          _perf('[AudioPerf][ExportFFT] src=$audioPath mode=audio_reactive pcm_start');
          final pcm = await audioAnalysis.extractPCMData(
            audioPath,
            lowDeviceSafe: false,
          );
          final hopOverride = _pickHopSizeOverrideForPcm(pcm);
          hopSize = hopOverride;
          computedAtSource = true;

          _perf(
            '[AudioPerf][ExportFFT] src=$audioPath mode=audio_reactive pcm_ok samples=${pcm.length} hop=$hopOverride fft_start',
          );
          frames = await audioAnalysis.computeAudioReactiveCompactFFT(
            pcm,
            hopSizeOverride: hopOverride,
          );
        } else {
          int bands = (cfg['fftBands'] as num?)?.toInt() ?? 64;
          double alpha = (cfg['smoothingAlpha'] as num?)?.toDouble() ?? 0.6;
          double minHz = (cfg['minFrequency'] as num?)?.toDouble() ?? 50.0;
          double maxHz = (cfg['maxFrequency'] as num?)?.toDouble() ?? 16000.0;

          bands = bands.clamp(8, 256);
          alpha = (alpha.isFinite ? alpha : 0.6).clamp(0.0, 1.0);
          minHz = (minHz.isFinite ? minHz : 50.0).clamp(1.0, 22050.0);
          maxHz = (maxHz.isFinite ? maxHz : 16000.0).clamp(1.0, 22050.0);
          if (maxHz < minHz) {
            final tmp = maxHz;
            maxHz = minHz;
            minHz = tmp;
          }
          if ((maxHz - minHz) < 1.0) {
            maxHz = (minHz + 1.0).clamp(1.0, 22050.0);
          }

          // Prefer preview cache if available (avoids duplicate FFT compute at export).
          final cached = visualizerService?.getCachedFFTFrames(
            audioPath: audioPath,
            bands: bands,
            alpha: alpha,
            minHz: minHz,
            maxHz: maxHz,
          );
          if (cached != null && cached.isNotEmpty) {
            frames = cached;
            hopSize =
                visualizerService?.getCachedHopSize(
                  audioPath: audioPath,
                  bands: bands,
                  alpha: alpha,
                  minHz: minHz,
                  maxHz: maxHz,
                ) ??
                AudioAnalysisService.hopSize;
            logger.i(
              '[ExportFFT] Reusing cached FFT for $audioPath frames=${frames.length}',
            );
            _perf(
              '[AudioPerf][ExportFFT] src=$audioPath mode=visualizer cache_hit frames=${frames.length}',
            );
          } else {
            _perf('[AudioPerf][ExportFFT] src=$audioPath mode=visualizer pcm_start');
            final pcm = await audioAnalysis.extractPCMData(
              audioPath,
              lowDeviceSafe: false,
            );
            final hopOverride = _pickHopSizeOverrideForPcm(pcm);
            hopSize = hopOverride;
            computedAtSource = true;

            _perf(
              '[AudioPerf][ExportFFT] src=$audioPath mode=visualizer pcm_ok samples=${pcm.length} hop=$hopOverride fft_start bands=$bands',
            );
            frames = await audioAnalysis.computeVisualizerFFT(
              pcmData: pcm,
              bands: bands,
              alpha: alpha,
              minHz: minHz,
              maxHz: maxHz,
              hopSizeOverride: hopOverride,
            );
          }
        }

        final int originalFrames = frames.length;
        if (!computedAtSource && frames.length > _maxExportFftFrames) {
          final step = (frames.length / 20000).ceil();
          final decimated = <List<double>>[];
          for (var i = 0; i < frames.length; i += step) {
            decimated.add(frames[i]);
          }
          frames = decimated;
          hopSize = hopSize * step;
          logger.i(
            '[ExportFFT] Decimated FFT for $audioPath '
            'frames=$originalFrames->${frames.length} hop=$hopSize',
          );
        }

        logger.i(
          '[ExportFFT] FFT ready for $audioPath '
          'frames=${frames.length} hop=$hopSize '
          'mode=${isAudioReactive ? 'audio_reactive' : 'visualizer'}',
        );

        if (swSource != null) {
          swSource.stop();
          _perf(
            '[AudioPerf][ExportFFT] src=$audioPath done ms=${swSource.elapsedMilliseconds} frames=${frames.length} hop=$hopSize mode=${isAudioReactive ? 'audio_reactive' : 'visualizer'} computedAtSource=$computedAtSource',
          );
        }

        out.add(ExportFFTData(
          audioPath: audioPath,
          sampleRate: AudioAnalysisService.sampleRate,
          hopSize: hopSize,
          frames: frames,
        ));
      } catch (err) {
        logger.w('FFT build failed for $audioPath: $err');
      }
    }

    if (swTotal != null) {
      swTotal.stop();
      _perf(
        '[AudioPerf][ExportFFT] done ms=${swTotal.elapsedMilliseconds} sources=${sources.length} out=${out.length}',
      );
    }
    return out;
  }
}
