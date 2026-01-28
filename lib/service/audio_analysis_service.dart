import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:fftea/fftea.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';
import 'package:vidviz/service_locator.dart';

/// Central audio analysis service (PCM extraction + FFT helpers)
/// Used by VisualizerService and AudioReactiveService.
class AudioAnalysisService {
  final logger = locator.get<Logger>();

  static const bool _audioPerfLogs = kDebugMode || kProfileMode;

  void _perf(String msg) {
    if (!_audioPerfLogs) return;
    try {
      logger.i(msg);
    } catch (_) {}
  }

  // PCM extraction cache: avoid repeated FFmpeg decode work across preview/export.
  // Keyed by audioPath + file mtime + file size.
  final Map<String, Future<Float32List>> _pcmInFlight = {};

  final Queue<String> _pcmWarmupQueue = Queue<String>();
  final Set<String> _pcmWarmupEnqueued = <String>{};
  bool _pcmWarmupRunning = false;
  static const int _pcmWarmupQueueLimit = 3;

  // Shared FFT configuration (must stay in sync with existing services)
  static const int fftSize = 2048;
  static const int hopSize = 512;
  static const int sampleRate = 44100;
  static const int _maxPreviewPcmBytes = 80 * 1024 * 1024;

  String canonicalizeAudioPath(String audioPath) {
    if (audioPath.isEmpty) return '';
    final normalized = p.normalize(audioPath).replaceAll('\\', '/');
    if (Platform.isWindows) return normalized.toLowerCase();
    return normalized;
  }

  void warmupPCM(String audioPath) {
    final canon = canonicalizeAudioPath(audioPath);
    if (canon.isEmpty) return;
    if (_pcmWarmupEnqueued.contains(canon)) return;

    if (_pcmWarmupQueue.length >= _pcmWarmupQueueLimit) {
      final String dropped = _pcmWarmupQueue.removeFirst();
      _pcmWarmupEnqueued.remove(dropped);
    }

    _pcmWarmupQueue.addLast(canon);
    _pcmWarmupEnqueued.add(canon);
    _drainPcmWarmupQueue();
  }

  Future<void> _drainPcmWarmupQueue() async {
    if (_pcmWarmupRunning) return;
    _pcmWarmupRunning = true;
    try {
      while (_pcmWarmupQueue.isNotEmpty) {
        final String path = _pcmWarmupQueue.removeFirst();
        _pcmWarmupEnqueued.remove(path);
        try {
          await extractPCMData(path, lowDeviceSafe: true);
        } catch (_) {}
      }
    } finally {
      _pcmWarmupRunning = false;
    }
  }

  Future<Directory> _pcmCacheDir() async {
    final Directory tempDir = await getTemporaryDirectory();
    final dir = Directory(p.join(tempDir.path, 'vidviz_pcm_cache'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> _prunePcmCache({int maxFiles = 6}) async {
    try {
      final dir = await _pcmCacheDir();
      final items = await dir
          .list(followLinks: false)
          .where((e) => e is File && e.path.endsWith('.pcm'))
          .toList();
      if (items.length <= maxFiles) return;

      items.sort((a, b) {
        try {
          final sa = (a as File).statSync();
          final sb = (b as File).statSync();
          return sa.modified.compareTo(sb.modified);
        } catch (_) {
          return 0;
        }
      });

      final int removeCount = items.length - maxFiles;
      for (var i = 0; i < removeCount; i++) {
        try {
          await (items[i] as File).delete();
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// Extract mono 44.1kHz 32-bit float PCM data using FFmpeg.
  Future<Float32List> extractPCMData(
    String audioPath, {
    bool lowDeviceSafe = false,
  }) async {
    final canon = canonicalizeAudioPath(audioPath);
    final src = File(canon);
    final stat = await src.stat();
    final String safeName = p
        .basenameWithoutExtension(canon)
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final String cacheKey =
        '$canon|${stat.modified.millisecondsSinceEpoch}|${stat.size}|m=${lowDeviceSafe ? 'preview' : 'full'}';

    Future<Float32List> run() async {
      final swTotal = Stopwatch()..start();
      final dir = await _pcmCacheDir();
      final String pcmPath = p.join(
        dir.path,
        'audio_${safeName}_${stat.modified.millisecondsSinceEpoch}_${stat.size}.pcm',
      );
      final pcmFile = File(pcmPath);

      if (await pcmFile.exists()) {
        try {
          if (lowDeviceSafe) {
            final int fileLen = await pcmFile.length();
            if (fileLen > _maxPreviewPcmBytes) {
              _perf(
                '[AudioPerf][PCM] skip_too_large mode=preview bytes=$fileLen path=$canon',
              );
              return Float32List(0);
            }
          }
          final swRead = Stopwatch()..start();
          final bytes = await pcmFile.readAsBytes();
          swRead.stop();
          if (bytes.isNotEmpty) {
            final int byteLen = bytes.lengthInBytes;
            if (byteLen < 4) {
              return Float32List(0);
            }
            final int aligned = byteLen - (byteLen % 4);
            swTotal.stop();
            _perf(
              '[AudioPerf][PCM] cache_hit readMs=${swRead.elapsedMilliseconds} totalMs=${swTotal.elapsedMilliseconds} bytes=$byteLen samples=${aligned ~/ 4} mode=${lowDeviceSafe ? 'preview' : 'full'} path=$canon',
            );
            return Float32List.view(
              bytes.buffer,
              bytes.offsetInBytes,
              aligned ~/ 4,
            );
          }
        } catch (_) {
          // fallthrough to re-generate
        }
      }

      final String command =
          '-i "$canon" -f f32le -acodec pcm_f32le -ar $sampleRate -ac 1 -y "$pcmPath"';

      _perf('[AudioPerf][PCM] ffmpeg_start mode=${lowDeviceSafe ? 'preview' : 'full'} path=$canon');

      final swFfmpeg = Stopwatch()..start();
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();
      swFfmpeg.stop();

      if (!returnCode!.isValueSuccess()) {
        final output = await session.getOutput();
        _perf(
          '[AudioPerf][PCM] ffmpeg_fail ms=${swFfmpeg.elapsedMilliseconds} mode=${lowDeviceSafe ? 'preview' : 'full'} path=$canon',
        );
        throw Exception('FFmpeg failed: $output');
      }

      if (lowDeviceSafe) {
        final int fileLen = await pcmFile.length();
        if (fileLen > _maxPreviewPcmBytes) {
          try {
            await _prunePcmCache();
          } catch (_) {}
          _perf(
            '[AudioPerf][PCM] skip_too_large_after_ffmpeg ms=${swFfmpeg.elapsedMilliseconds} bytes=$fileLen path=$canon',
          );
          return Float32List(0);
        }
      }

      final swRead = Stopwatch()..start();
      final bytes = await pcmFile.readAsBytes();
      swRead.stop();
      try {
        await _prunePcmCache();
      } catch (_) {}
      final int byteLen = bytes.lengthInBytes;
      if (byteLen < 4) {
        return Float32List(0);
      }
      final int aligned = byteLen - (byteLen % 4);
      swTotal.stop();
      _perf(
        '[AudioPerf][PCM] ffmpeg_ok ffmpegMs=${swFfmpeg.elapsedMilliseconds} readMs=${swRead.elapsedMilliseconds} totalMs=${swTotal.elapsedMilliseconds} bytes=$byteLen samples=${aligned ~/ 4} mode=${lowDeviceSafe ? 'preview' : 'full'} path=$canon',
      );
      return Float32List.view(
        bytes.buffer,
        bytes.offsetInBytes,
        aligned ~/ 4,
      );
    }

    final existing = _pcmInFlight[cacheKey];
    if (existing != null) return await existing;

    final fut = run();
    _pcmInFlight[cacheKey] = fut;
    try {
      return await fut;
    } finally {
      _pcmInFlight.remove(cacheKey);
    }
  }

  /// Compute log-scaled, band-reduced FFT spectrogram for visualizers.
  /// This mirrors the previous VisualizerService _computeFFTIsolate logic.
  Future<List<List<double>>> computeVisualizerFFT({
    required Float32List pcmData,
    int bands = 64,
    double alpha = 0.6,
    double minHz = 50.0,
    double maxHz = 16000.0,
    int? hopSizeOverride,
  }) async {
    final sw = _audioPerfLogs ? (Stopwatch()..start()) : null;
    _perf(
      '[AudioPerf][FFT][Visualizer] start samples=${pcmData.length} bands=$bands hop=${hopSizeOverride ?? hopSize}',
    );

    try {
      final result = await compute(_computeVisualizerFFTIsolate, {
        'pcmData': pcmData,
        'bands': bands,
        'alpha': alpha,
        'minHz': minHz,
        'maxHz': maxHz,
        'fftSize': fftSize,
        'hopSize': hopSizeOverride ?? hopSize,
        'sampleRate': sampleRate,
      });
      if (sw != null) sw.stop();
      _perf(
        '[AudioPerf][FFT][Visualizer] done ms=${sw?.elapsedMilliseconds ?? -1} frames=${result.length} bands=$bands hop=${hopSizeOverride ?? hopSize}',
      );
      return result;
    } catch (e) {
      try {
        logger.e('[AudioAnalysis] Visualizer FFT computation failed: $e');
      } catch (_) {}
      if (sw != null) {
        sw.stop();
        _perf(
          '[AudioPerf][FFT][Visualizer] fail ms=${sw.elapsedMilliseconds} bands=$bands hop=${hopSizeOverride ?? hopSize}',
        );
      }
      return [];
    }
  }

  /// Isolate entry for visualizer FFT computation.
  static List<List<double>> _computeVisualizerFFTIsolate(
    Map<String, dynamic> params,
  ) {
    final Float32List pcmData = params['pcmData'];
    final int bands = params['bands'];
    final double alpha = params['alpha'];
    final double minHz = params['minHz'];
    final double maxHz = params['maxHz'];
    final int fftSize = params['fftSize'];
    final int hopSize = params['hopSize'];
    final int sampleRate = params['sampleRate'];

    final fft = FFT(fftSize);
    final List<List<double>> spectrogram = [];

    final hann = Float64List(fftSize);
    for (int j = 0; j < fftSize; j++) {
      hann[j] = 0.5 * (1 - math.cos(2 * math.pi * j / (fftSize - 1)));
    }
    final window = Float64List(fftSize);

    // Log-scale band boundaries
    final int posBins = (fftSize ~/ 2) + 1;
    final double nyquist = sampleRate / 2.0;
    final double effectiveMaxHz = math.min(maxHz, nyquist);
    final double logBase = effectiveMaxHz / minHz;
    final List<int> bandStarts = List<int>.filled(bands, 0);
    final List<int> bandEnds = List<int>.filled(bands, 0);

    for (int b = 0; b < bands; b++) {
      final double t0 = b / bands;
      final double t1 = (b + 1) / bands;
      final double f0 = minHz * math.pow(logBase, t0).toDouble();
      final double f1 = minHz * math.pow(logBase, t1).toDouble();
      int i0 = (f0 * fftSize / sampleRate).floor();
      int i1 = (f1 * fftSize / sampleRate).floor();
      if (i0 < 1) i0 = 1;
      if (i1 <= i0) i1 = i0 + 1;
      if (i1 > posBins - 1) i1 = posBins - 1;
      bandStarts[b] = i0;
      bandEnds[b] = i1;
    }

    List<double>? prevBands;

    for (int i = 0; i < pcmData.length - fftSize; i += hopSize) {
      for (int j = 0; j < fftSize; j++) {
        window[j] = pcmData[i + j] * hann[j];
      }

      final freq = fft.realFft(window);
      final magnitudes = freq.discardConjugates().magnitudes();

      final List<double> bandsVals = List<double>.filled(bands, 0.0);
      for (int b = 0; b < bands; b++) {
        final int s = bandStarts[b];
        final int e = bandEnds[b];
        double sum = 0.0;
        int count = 0;
        for (int k = s; k < e; k++) {
          final double v = magnitudes[k];
          sum += v.isFinite ? v : 0.0;
          count++;
        }
        bandsVals[b] = count > 0 ? (sum / count) : 0.0;
      }

      double maxBand = 0.0;
      for (final v in bandsVals) {
        if (v > maxBand) maxBand = v;
      }
      if (maxBand > 0) {
        for (int b = 0; b < bands; b++) {
          bandsVals[b] = bandsVals[b] / maxBand;
        }
      }

      if (prevBands != null) {
        for (int b = 0; b < bands; b++) {
          bandsVals[b] = alpha * bandsVals[b] + (1 - alpha) * prevBands[b];
        }
      }
      prevBands = List<double>.from(bandsVals);

      spectrogram.add(bandsVals);
    }

    return spectrogram;
  }

  static List<List<double>> _computeAudioReactiveCompactFFTIsolate(
    Map<String, dynamic> params,
  ) {
    final Float32List pcmData = params['pcmData'];
    final int fftSize = params['fftSize'];
    final int hopSize = params['hopSize'];
    final int sampleRate = params['sampleRate'];

    final fft = FFT(fftSize);
    final List<List<double>> out = [];

    final hann = Float64List(fftSize);
    for (int j = 0; j < fftSize; j++) {
      hann[j] = 0.5 * (1 - math.cos(2 * math.pi * j / (fftSize - 1)));
    }
    final window = Float64List(fftSize);

    final int bassEnd = (250 * fftSize / sampleRate).floor().clamp(0, (fftSize ~/ 2));
    final int midStart = bassEnd;
    final int midEnd = (4000 * fftSize / sampleRate).floor().clamp(midStart, (fftSize ~/ 2));
    final int trebleEnd = (fftSize ~/ 2) + 1;

    for (int i = 0; i < pcmData.length - fftSize; i += hopSize) {
      for (int j = 0; j < fftSize; j++) {
        window[j] = pcmData[i + j] * hann[j];
      }

      final freq = fft.realFft(window);
      final magnitudes = freq.discardConjugates().magnitudes();

      final maxMag = magnitudes.reduce((a, b) => a > b ? a : b);

      final double scale = (maxMag > 0) ? (1.0 / maxMag) : 0.0;

      double bassSum = 0.0;
      int bassCnt = 0;
      double midSum = 0.0;
      int midCnt = 0;
      double trebleSum = 0.0;
      int trebleCnt = 0;
      double allSum = 0.0;
      int allCnt = 0;

      final int n = magnitudes.length;
      for (int k = 0; k < n; k++) {
        final double m = magnitudes[k];
        final double v = (m.isFinite ? m : 0.0) * scale;

        allSum += v;
        allCnt++;

        if (k < bassEnd) {
          bassSum += v;
          bassCnt++;
        } else if (k < midEnd) {
          midSum += v;
          midCnt++;
        } else if (k < trebleEnd) {
          trebleSum += v;
          trebleCnt++;
        }
      }

      double clamp01(double v) {
        if (v < 0.0) return 0.0;
        if (v > 1.0) return 1.0;
        return v;
      }

      final bass = clamp01(bassCnt > 0 ? (bassSum / bassCnt) : 0.0);
      final mid = clamp01(midCnt > 0 ? (midSum / midCnt) : 0.0);
      final treble = clamp01(trebleCnt > 0 ? (trebleSum / trebleCnt) : 0.0);
      final all = clamp01(allCnt > 0 ? (allSum / allCnt) : 0.0);
      out.add([bass, mid, treble, all]);
    }

    return out;
  }

  /// Compute full-resolution FFT magnitude spectrogram for AudioReactive.
  /// Mirrors previous AudioReactiveService _computeFFT behavior.
  Future<List<List<double>>> computeAudioReactiveFFT(
    Float32List pcmData,
  ) async {
    try {
      logger.i(
        '[AudioAnalysis] Computing audio reactive FFT. samples=${pcmData.length}',
      );
    } catch (_) {}

    try {
      final result = await compute(_computeAudioReactiveFFTIsolate, {
        'pcmData': pcmData,
        'fftSize': fftSize,
        'hopSize': hopSize,
        'sampleRate': sampleRate,
      });
      return result;
    } catch (e) {
      try {
        logger.e('[AudioAnalysis] Audio reactive FFT computation failed: $e');
      } catch (_) {}
      return [];
    }
  }

  Future<List<List<double>>> computeAudioReactiveCompactFFT(
    Float32List pcmData,
    {int? hopSizeOverride,}
  ) async {
    final sw = _audioPerfLogs ? (Stopwatch()..start()) : null;
    _perf(
      '[AudioPerf][FFT][AudioReactive] start samples=${pcmData.length} hop=${hopSizeOverride ?? hopSize}',
    );

    try {
      final result = await compute(_computeAudioReactiveCompactFFTIsolate, {
        'pcmData': pcmData,
        'fftSize': fftSize,
        'hopSize': hopSizeOverride ?? hopSize,
        'sampleRate': sampleRate,
      });
      if (sw != null) sw.stop();
      _perf(
        '[AudioPerf][FFT][AudioReactive] done ms=${sw?.elapsedMilliseconds ?? -1} frames=${result.length} hop=${hopSizeOverride ?? hopSize}',
      );
      return result;
    } catch (e) {
      try {
        logger.e('[AudioAnalysis] Audio reactive compact FFT computation failed: $e');
      } catch (_) {}
      if (sw != null) {
        sw.stop();
        _perf(
          '[AudioPerf][FFT][AudioReactive] fail ms=${sw.elapsedMilliseconds} hop=${hopSizeOverride ?? hopSize}',
        );
      }
      return [];
    }
  }

  /// Isolate entry for audio reactive FFT computation.
  static List<List<double>> _computeAudioReactiveFFTIsolate(
    Map<String, dynamic> params,
  ) {
    final Float32List pcmData = params['pcmData'];
    final int fftSize = params['fftSize'];
    final int hopSize = params['hopSize'];

    final fft = FFT(fftSize);
    final List<List<double>> spectrogram = [];

    final hann = Float64List(fftSize);
    for (int j = 0; j < fftSize; j++) {
      hann[j] = 0.5 * (1 - math.cos(2 * math.pi * j / (fftSize - 1)));
    }
    final window = Float64List(fftSize);

    for (int i = 0; i < pcmData.length - fftSize; i += hopSize) {
      for (int j = 0; j < fftSize; j++) {
        window[j] = pcmData[i + j] * hann[j];
      }

      final freq = fft.realFft(window);
      final magnitudes = freq.discardConjugates().magnitudes();

      final maxMag = magnitudes.reduce((a, b) => a > b ? a : b);
      final normalized = magnitudes
          .map((m) => maxMag > 0 ? m / maxMag : 0.0)
          .toList();

      spectrogram.add(normalized);
    }

    return spectrogram;
  }

  /// Utility to compute audio level at a given time using a precomputed
  /// spectrogram (as produced by [computeAudioReactiveFFT]).
  double? getAudioLevelAtTime({
    required List<List<double>> fftData,
    required int milliseconds,
    required String frequencyRange,
    int? hopSizeOverride,
  }) {
    if (fftData.isEmpty) return null;

    final double seconds = milliseconds / 1000.0;
    final int effectiveHop = hopSizeOverride ?? hopSize;
    final int frameIndex = ((seconds * sampleRate) / effectiveHop).floor();

    if (frameIndex < 0 || frameIndex >= fftData.length) {
      return null;
    }

    final magnitudes = fftData[frameIndex];

    if (magnitudes.length == 4) {
      switch (frequencyRange) {
        case 'bass':
          return magnitudes[0];
        case 'mid':
          return magnitudes[1];
        case 'treble':
          return magnitudes[2];
        case 'all':
        default:
          return magnitudes[3];
      }
    }

    return _extractFrequencyLevel(magnitudes, frequencyRange);
  }

  double _extractFrequencyLevel(
    List<double> magnitudes,
    String frequencyRange,
  ) {
    switch (frequencyRange) {
      case 'bass':
        final bassEnd = (250 * fftSize / sampleRate).floor();
        return _averageMagnitude(magnitudes, 0, bassEnd);
      case 'mid':
        final midStart = (250 * fftSize / sampleRate).floor();
        final midEnd = (4000 * fftSize / sampleRate).floor();
        return _averageMagnitude(magnitudes, midStart, midEnd);
      case 'treble':
        final trebleStart = (4000 * fftSize / sampleRate).floor();
        return _averageMagnitude(magnitudes, trebleStart, magnitudes.length);
      case 'all':
      default:
        return _averageMagnitude(magnitudes, 0, magnitudes.length);
    }
  }

  double _averageMagnitude(List<double> magnitudes, int start, int end) {
    if (start >= end) return 0.0;
    double sum = 0.0;
    for (int i = start; i < end && i < magnitudes.length; i++) {
      sum += magnitudes[i];
    }
    return (sum / (end - start)).clamp(0.0, 1.0);
  }
}
