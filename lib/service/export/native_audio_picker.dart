import 'dart:io';
import 'package:vidviz/model/layer.dart';

class NativeExportAudioPicker {
  static bool _isSupportedVideoPath(String path) {
    final p = path.toLowerCase();
    return p.endsWith('.mp4') ||
        p.endsWith('.mov') ||
        p.endsWith('.avi') ||
        p.endsWith('.mkv') ||
        p.endsWith('.webm');
  }

  static bool _isSupportedAudioPath(String path) {
    final p = path.toLowerCase();
    return p.endsWith('.mp3') ||
        p.endsWith('.wav') ||
        p.endsWith('.aac') ||
        p.endsWith('.m4a') ||
        p.endsWith('.flac') ||
        p.endsWith('.ogg');
  }

  static String? pickBestAudioSourcePath(List<Layer> layers) {
    for (final layer in layers) {
      if (layer.type != 'raster') continue;
      if (layer.useVideoAudio != true) continue;
      if (layer.mute == true) continue;
      if ((layer.volume).abs() <= 1e-6) continue;
      for (final a in layer.assets) {
        if (a.deleted) continue;
        if (a.type != AssetType.video) continue;
        final p = a.srcPath;
        if (p.isNotEmpty && _isSupportedVideoPath(p) && File(p).existsSync()) {
          return p;
        }
      }
    }

    for (final layer in layers) {
      if (layer.type != 'audio') continue;
      if (layer.mute == true) continue;
      if ((layer.volume).abs() <= 1e-6) continue;
      for (final a in layer.assets) {
        if (a.deleted) continue;
        if (a.type != AssetType.audio) continue;
        final p = a.srcPath;
        if (p.isNotEmpty && _isSupportedAudioPath(p) && File(p).existsSync()) {
          return p;
        }
      }
    }

    return null;
  }

  static String? pickAudioPathByAssetId(List<Layer> layers, String assetId) {
    if (assetId.isEmpty) return null;
    for (final layer in layers) {
      for (final a in layer.assets) {
        if (a.deleted) continue;
        if (a.id != assetId) continue;
        if (a.srcPath.isEmpty) continue;

        if (a.type == AssetType.audio) {
          if (_isSupportedAudioPath(a.srcPath) && File(a.srcPath).existsSync()) return a.srcPath;
        }

        if (a.type == AssetType.video && layer.type == 'raster' && layer.useVideoAudio == true) {
          if (_isSupportedVideoPath(a.srcPath) && File(a.srcPath).existsSync()) return a.srcPath;
        }
      }
    }
    return null;
  }
}
