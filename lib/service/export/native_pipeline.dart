import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:vidviz/model/layer.dart';
import 'package:flutter/widgets.dart';
import 'package:vidviz/model/video_settings.dart';
import 'package:vidviz/service/export/native_export.dart';
import 'package:vidviz/service/export/native_generator.dart';
import 'package:vidviz/service/export/native_audio_postprocess.dart';
import 'native_progress.dart';

/// Single entrypoint: native engine export (Android/iOS)
class ExportPipeline {
  Future<bool> _ensureDirWritable(Directory dir) async {
    try {
      await dir.create(recursive: true);
      final probe = File(p.join(dir.path, '.vvz_write_probe'));
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
      return true;
    } catch (_) {
      return false;
    }
  }
  Future<String?> export({
    required List<Layer> layers,
    required VideoResolution videoResolution,
    required GlobalKey captureKey,
    required Future<void> Function(int positionMs) previewAt,
    required Generator generator,
    required void Function(FFmpegStat stat) onProgress,
    required bool Function() isCancelled,
    int? totalDurationMs,
    int fps = 30,
    int quality = 1,
    String? outputFormat,
    required VideoSettings videoSettings,
  }) async {
    final fmt = (outputFormat ?? 'MP4').toString().trim().toLowerCase();

    final int duration = totalDurationMs ?? _computeTotalDurationMs(layers);

    bool _anyPipelineSupportsFormat(String f) {
      // Current implementation reliably supports MP4 only.
      // MOV is accepted as a UI alias but still uses MP4 container in native.
      return f == 'mp4' || f == 'mov';
    }

    if (!_anyPipelineSupportsFormat(fmt)) {
      onProgress(
        FFmpegStat(
          time: 0,
          timeElapsed: 0,
          message: 'Selected output format is not supported yet: $fmt. Please choose MP4.',
        )
          ..error = true,
      );
      return null;
    }

    bool _nativeSupportsFormat(String f) {
      return f == 'mp4' || f == 'mov';
    }

    String _nativeOutputExt(String f) {
      // Native engine currently muxes MP4; keep extension consistent.
      // ignore: unused_local_variable
      final _ = f;
      return 'mp4';
    }

    // Native-only export: UI capture + legacy FFmpeg paths are intentionally disabled.
    if (!isNativeExportAvailable) {
      onProgress(
        FFmpegStat(
          time: 0,
          timeElapsed: 0,
          message: 'Native export is not available on this platform.',
        )
          ..error = true,
      );
      return null;
    }

    // 0) Native Engine - tek export yolu (Android/iOS) (only for supported formats)
    if (_nativeSupportsFormat(fmt)) {
      StreamSubscription<NativeExportProgress>? nativeProgressSub;
      final sw = Stopwatch()..start();
      try {
        final ctx = captureKey.currentContext;
        final double? uiPlayerW = (ctx != null && ctx.findRenderObject() is RenderBox)
            ? (ctx.findRenderObject() as RenderBox).size.width
            : null;
        final double? uiPlayerH = (ctx != null && ctx.findRenderObject() is RenderBox)
            ? (ctx.findRenderObject() as RenderBox).size.height
            : null;
        final double? uiDpr = (ctx != null) ? MediaQuery.of(ctx).devicePixelRatio : null;

        final target = _videoResolutionSizeForAspect(
          generator: generator,
          videoResolution: videoResolution,
          aspect: videoSettings.aspectRatio,
        );
        
        // Output path
        String outDirPath = Directory.systemTemp.path;
        if (Platform.isAndroid) {
          final d = Directory('/storage/emulated/0/Download/vidviz');
          final ok = await _ensureDirWritable(d);
          if (ok) {
            outDirPath = d.path;
          }
        }

        await Directory(outDirPath).create(recursive: true);
        final dateSuffix = _dateTimeString(DateTime.now());
        final outputPath = p.join(
          outDirPath,
          'vidviz_$dateSuffix.${_nativeOutputExt(fmt)}',
        );

        nativeProgressSub = NativeExportService.instance.progress$.listen((p) {
          final elapsed = (sw.elapsedMilliseconds <= 0) ? 1 : sw.elapsedMilliseconds;
          final t = (p.progress * duration * 0.97).round().clamp(0, duration);
          final fpsEstimate = p.currentFrame / (elapsed / 1000.0);
          onProgress(
            FFmpegStat(
              time: t,
              timeElapsed: elapsed,
              videoFrameNumber: p.currentFrame,
              videoFps: fpsEstimate,
            ),
          );
        });

        final result = await NativeExportService.instance.export(
          layers: layers,
          width: target.width,
          height: target.height,
          fps: fps,
          quality: quality,
          videoSettings: videoSettings,
          outputFormat: fmt,
          outputPath: outputPath,
          totalDuration: duration,
          uiPlayerWidth: uiPlayerW,
          uiPlayerHeight: uiPlayerH,
          uiDevicePixelRatio: uiDpr,
        );

        if (result != null && result.isNotEmpty) {
          final fixed = await postProcessNativeAudioIfNeeded(
            generator: generator,
            layers: layers,
            inputVideoPath: result,
            totalDurationMs: duration,
          );
          final elapsed = (sw.elapsedMilliseconds <= 0) ? 1 : sw.elapsedMilliseconds;
          final out = FFmpegStat(
            time: duration,
            timeElapsed: elapsed,
            outputPath: fixed,
          );
          out.finished = true;
          onProgress(out);
          print('✅ Native engine export success: $fixed');
          return fixed;
        }

        if (!isCancelled()) {
          final msg = NativeExportService.instance.lastErrorMessage;
          final elapsed = (sw.elapsedMilliseconds <= 0) ? 1 : sw.elapsedMilliseconds;
          final out = FFmpegStat(
            time: 0,
            timeElapsed: elapsed,
            message: (msg != null && msg.isNotEmpty)
                ? msg
                : 'Native export failed',
          );
          out.error = true;
          onProgress(out);
        }

        print('⚠️ Native engine returned null');
        return null;
      } catch (e) {
        if (!isCancelled()) {
          final elapsed = (sw.elapsedMilliseconds <= 0) ? 1 : sw.elapsedMilliseconds;
          final out = FFmpegStat(
            time: 0,
            timeElapsed: elapsed,
            message: e.toString(),
          );
          out.error = true;
          onProgress(out);
        }
        print('⚠️ Native engine error: $e');
        return null;
      } finally {
        try {
          await nativeProgressSub?.cancel();
        } catch (_) {}
        sw.stop();
      }
    }

    onProgress(
      FFmpegStat(
        time: 0,
        timeElapsed: 0,
        message: 'Native export does not support selected output format yet: $fmt',
      )
        ..error = true,
    );
    return null;
  }

  int _computeTotalDurationMs(List<Layer> layers) {
    int maxDuration = 0;
    for (final layer in layers) {
      for (final a in layer.assets) {
        if (a.deleted) continue;
        if (a.type == AssetType.text && a.title == '') continue;
        final end = a.begin + a.duration;
        if (end > maxDuration) maxDuration = end;
      }
    }
    return maxDuration;
  }

  VideoResolutionSize _videoResolutionSizeForAspect(
    {
      required Generator generator,
      required VideoResolution videoResolution,
      required String aspect,
    }
  ) {
    final base = generator.videoResolutionSize(videoResolution);

    final int longEdge = (base.width >= base.height) ? base.width : base.height;

    double parseAspect(String s) {
      if (s.contains(':')) {
        final parts = s.split(':');
        final w = double.tryParse(parts[0]) ?? 16;
        final h = double.tryParse(parts[1]) ?? 9;
        if (h == 0) return 16 / 9;
        return w / h;
      }
      return 16 / 9;
    }

    final targetAspect = parseAspect(aspect);

    int w;
    int h;

    if (targetAspect >= 1.0) {
      // Geniş video: uzun kenar olarak base.width'i koru
      w = longEdge;
      h = (w / targetAspect).round();
    } else {
      // Dikey video: uzun kenar olarak base.height'i koru
      h = longEdge;
      w = (h * targetAspect).round();
    }

    if (w < 2) w = 2;
    if (h < 2) h = 2;

    if (w % 2 != 0) w++;
    if (h % 2 != 0) h++;

    return VideoResolutionSize(width: w, height: h);
  }
}

String _two(int v) => v.toString().padLeft(2, '0');
String _dateTimeString(DateTime dt) =>
    '${dt.year.toString().padLeft(4, '0')}'
    '${_two(dt.month)}'
    '${_two(dt.day)}'
    '_${_two(dt.hour)}'
    '${_two(dt.minute)}'
    '${_two(dt.second)}';
