import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:vidviz/model/layer.dart';
import 'package:vidviz/service/export/native_generator.dart';

Future<String> postProcessNativeAudioIfNeeded({
  required Generator generator,
  required List<Layer> layers,
  required String inputVideoPath,
  required int totalDurationMs,
}) async {
  bool hasAnyAudio = false;
  bool needsMix = false;

  for (final layer in layers) {
    final double lvol = (layer.mute == true) ? 0.0 : layer.volume;
    if (layer.type == 'audio') {
      for (final a in layer.assets) {
        if (!a.deleted && a.type == AssetType.audio && a.srcPath.isNotEmpty) {
          hasAnyAudio = true;
          break;
        }
      }
    }
    if (layer.type == 'raster' && layer.useVideoAudio == true) {
      for (final a in layer.assets) {
        if (!a.deleted && a.type == AssetType.video && a.srcPath.isNotEmpty) {
          hasAnyAudio = true;
          break;
        }
      }
    }

    if ((lvol - 1.0).abs() > 1e-6 || layer.mute == true) {
      needsMix = true;
    }
    for (final a in layer.assets) {
      final v = a.data?['volume'];
      if (v is num && (v.toDouble() - 1.0).abs() > 1e-6) {
        needsMix = true;
      }
    }
  }

  if (!hasAnyAudio) {
    return inputVideoPath;
  }

  final bool outHasAudio = await generator.hasAudioStream(inputVideoPath);

  // Even if no explicit volume changes, native path may skip overlaps.
  // If you prefer zero overhead, toggle this to `if (!needsMix) return inputVideoPath;`.
  if (!needsMix && outHasAudio) {
    return inputVideoPath;
  }

  final inputs = <String>['-i "$inputVideoPath"'];
  final filterParts = <String>[];
  final amixLabels = <String>[];

  int inIdx = 1;
  int aCount = 0;

  String atempoChain(double s) {
    final parts = <String>[];
    double x = s;
    while (x > 2.0 + 1e-6) {
      parts.add('atempo=2.0');
      x /= 2.0;
    }
    while (x < 0.5 - 1e-6) {
      parts.add('atempo=0.5');
      x *= 2.0;
    }
    if ((x - 1.0).abs() > 1e-6) {
      final y = x.clamp(0.5, 2.0);
      parts.add('atempo=${(y as num).toStringAsFixed(3)}');
    }
    return parts.join(',');
  }

  for (final layer in layers) {
    if (layer.type == 'audio') {
      final double baseVol = (layer.mute == true) ? 0.0 : layer.volume;
      for (final a in layer.assets) {
        if (a.deleted || a.type != AssetType.audio || a.srcPath.isEmpty) continue;

        final int durMs = (a.duration > 0)
            ? a.duration
            : (totalDurationMs - a.begin).clamp(0, totalDurationMs);
        if (durMs <= 0) continue;

        final v = a.data?['volume'];
        final double gain = (v is num) ? v.clamp(0.0, 1.0).toDouble() : 1.0;
        final double vol = (baseVol * gain).clamp(0.0, 2.0);
        if (vol <= 1e-6) continue;

        inputs.add('-i "${a.srcPath}"');

        final start = (a.cutFrom / 1000.0).toStringAsFixed(3);
        final end = ((a.cutFrom + durMs) / 1000.0).toStringAsFixed(3);
        final delay = a.begin.clamp(0, totalDurationMs);

        filterParts.add(
          '[${inIdx}:a]atrim=$start:$end,asetpts=PTS-STARTPTS,adelay=${delay}|${delay},volume=${vol.toStringAsFixed(3)}[a$aCount]',
        );
        amixLabels.add('[a$aCount]');
        inIdx++;
        aCount++;
      }
    }

    if (layer.type == 'raster' && layer.useVideoAudio == true) {
      final double baseVol = (layer.mute == true) ? 0.0 : layer.volume;
      for (final a in layer.assets) {
        if (a.deleted || a.type != AssetType.video || a.srcPath.isEmpty) continue;

        final int durMs = (a.duration > 0) ? a.duration : (totalDurationMs - a.begin).clamp(0, totalDurationMs);
        if (durMs <= 0) continue;

        final bool hasAud = await generator.hasAudioStream(a.srcPath);
        if (!hasAud) continue;

        final v = a.data?['volume'];
        final double gain = (v is num) ? v.clamp(0.0, 1.0).toDouble() : 1.0;
        final double vol = (baseVol * gain).clamp(0.0, 2.0);
        if (vol <= 1e-6) continue;

        inputs.add('-i "${a.srcPath}"');

        final double spd = (a.playbackSpeed <= 0) ? 1.0 : a.playbackSpeed;
        final start = (a.cutFrom / 1000.0).toStringAsFixed(3);
        final end =
            ((a.cutFrom / 1000.0) + (durMs / 1000.0) * spd).toStringAsFixed(3);
        final delay = a.begin.clamp(0, totalDurationMs);

        final atempo = atempoChain(spd);
        final tempoPart = atempo.isEmpty ? '' : '$atempo,';

        filterParts.add(
          '[${inIdx}:a]atrim=$start:$end,asetpts=PTS-STARTPTS,${tempoPart}adelay=${delay}|${delay},volume=${vol.toStringAsFixed(3)}[a$aCount]',
        );
        amixLabels.add('[a$aCount]');
        inIdx++;
        aCount++;
      }
    }
  }

  final dir = p.dirname(inputVideoPath);
  final base = p.basenameWithoutExtension(inputVideoPath);
  final outPath = p.join(dir, '${base}_audio.mp4');

  if (aCount == 0) {
    final cmd = '-loglevel error -y -i "$inputVideoPath" -c:v copy -an -movflags +faststart "$outPath"';
    await generator.executeCommand(cmd, finished: true, outputPath: outPath);
    try {
      if (outPath != inputVideoPath) {
        await File(inputVideoPath).delete();
      }
    } catch (_) {}
    return outPath;
  }

  final durSec = (totalDurationMs / 1000.0).toStringAsFixed(3);
  filterParts.add('${amixLabels.join()}amix=inputs=$aCount:normalize=0,apad,atrim=0:$durSec[aout]');

  final cmd = <String>[
    '-loglevel error -y',
    ...inputs,
    '-filter_complex "${filterParts.join(';')}"',
    '-map 0:v:0 -map [aout]',
    '-c:v copy -c:a aac -b:a 192k -movflags +faststart',
    '"$outPath"',
  ].join(' ');

  await generator.executeCommand(cmd, finished: true, outputPath: outPath);
  try {
    if (outPath != inputVideoPath) {
      await File(inputVideoPath).delete();
    }
  } catch (_) {}
  return outPath;
}
