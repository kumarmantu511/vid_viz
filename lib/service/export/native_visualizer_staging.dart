import 'dart:io';

import 'package:vidviz/model/layer.dart';

class ExportVisualizerStaging {
  static Future<void> apply({
    required List<Layer> layers,
    required String stagingDir,
    required int totalDuration,
  }) async {
    await Directory(stagingDir).create(recursive: true);

    double _num(Map<String, dynamic> m, String key, double fallback) {
      final v = m[key];
      if (v is num) {
        final d = v.toDouble();
        return d.isFinite ? d : fallback;
      }
      return fallback;
    }

    int _int(Map<String, dynamic> m, String key, int fallback) {
      final v = m[key];
      if (v is num) {
        return v.toInt();
      }
      return fallback;
    }

    for (final layer in layers) {
      for (final asset in layer.assets) {
        final t = asset.type.toString().split('.').last;
        if (t != 'visualizer') continue;
        final data = asset.data;
        if (data is! Map<String, dynamic>) continue;
        final vis = data['visualizer'];
        if (vis is! Map<String, dynamic>) continue;

        vis['projectDuration'] = totalDuration;

        // Advanced FFT params (used by NativeExportFftBuilder)
        final int safeBands = _int(vis, 'fftBands', 64).clamp(8, 256);
        final double safeAlpha = _num(vis, 'smoothingAlpha', 0.6).clamp(0.0, 1.0);
        double minHz = _num(vis, 'minFrequency', 50.0);
        double maxHz = _num(vis, 'maxFrequency', 16000.0);
        minHz = (minHz.isFinite ? minHz : 50.0).clamp(1.0, 22050.0);
        maxHz = (maxHz.isFinite ? maxHz : 16000.0).clamp(1.0, 22050.0);
        if (maxHz < minHz) {
          final tmp = maxHz;
          maxHz = minHz;
          minHz = tmp;
        }
        // Avoid degenerate ranges
        if ((maxHz - minHz) < 1.0) {
          maxHz = (minHz + 1.0).clamp(1.0, 22050.0);
        }
        vis['fftBands'] = safeBands;
        vis['smoothingAlpha'] = safeAlpha;
        vis['minFrequency'] = minHz;
        vis['maxFrequency'] = maxHz;

        vis['x'] = _num(vis, 'x', 0.5).clamp(-1.0, 2.0);
        vis['y'] = _num(vis, 'y', 0.5).clamp(-1.0, 2.0);
        vis['scale'] = _num(vis, 'scale', 1.0).clamp(0.1, 4.0);
        vis['alpha'] = _num(vis, 'alpha', 1.0).clamp(0.0, 1.0);
        vis['rotation'] = _num(vis, 'rotation', 0.0).clamp(0.0, 360.0);
        vis['speed'] = _num(vis, 'speed', 1.0).clamp(0.5, 2.0);
        vis['amplitude'] = _num(vis, 'amplitude', 1.0).clamp(0.5, 2.0);
        vis['barCount'] = _int(vis, 'barCount', 48).clamp(1, 256);
        vis['barSpacing'] = _num(vis, 'barSpacing', 0.75).clamp(0.35, 0.92);
        vis['glowIntensity'] = _num(vis, 'glowIntensity', 0.5).clamp(0.0, 1.0);
        vis['smoothness'] = _num(vis, 'smoothness', 0.6).clamp(0.0, 1.0);
        vis['reactivity'] = _num(vis, 'reactivity', 1.0).clamp(0.5, 2.0);
        vis['sensitivity'] = _num(vis, 'sensitivity', 1.0).clamp(0.0, 10.0);

        final String shaderType = (vis['shaderType'] as String?)?.toString() ?? '';
        if (shaderType == 'pro_nation') {
          final String center = (vis['centerImagePath'] as String?)?.toString() ?? '';
          if (center.isNotEmpty && File(center).existsSync()) {
            final dst = _joinPath(
              stagingDir,
              'vis_${asset.id}_center${_safeExt(center)}',
            );
            try {
              await File(center).copy(dst);
              vis['centerImagePath'] = dst;
              vis['uCenterImg'] = dst;
              vis['uHasCenter'] = 1.0;
            } catch (_) {
              vis['uHasCenter'] = 0.0;
            }
          } else {
            vis['uHasCenter'] = 0.0;
          }

          final String bg = (vis['backgroundImagePath'] as String?)?.toString() ?? '';
          if (bg.isNotEmpty && File(bg).existsSync()) {
            final dst = _joinPath(
              stagingDir,
              'vis_${asset.id}_bg${_safeExt(bg)}',
            );
            try {
              await File(bg).copy(dst);
              vis['backgroundImagePath'] = dst;
              vis['uBgImg'] = dst;
              vis['uHasBg'] = 1.0;
            } catch (_) {
              vis['uHasBg'] = 0.0;
            }
          } else {
            vis['uHasBg'] = 0.0;
          }
        }

        final rm = vis['renderMode'];
        if (rm is String && rm == 'progress') {
          final sw = vis['strokeWidth'];
          if (sw is num) {
            if (sw.toDouble() < 6.0) {
              vis['strokeWidth'] = 6.0;
            }
          } else {
            vis['strokeWidth'] = 6.0;
          }
        }
      }
    }
  }

  static String _safeExt(String path) {
    final idx = path.lastIndexOf('.');
    if (idx < 0 || idx == path.length - 1) return '';
    return path.substring(idx);
  }

  static String _joinPath(String dir, String name) {
    if (dir.isEmpty) return name;
    final sep = Platform.pathSeparator;
    if (dir.endsWith(sep)) return '$dir$name';
    return '$dir$sep$name';
  }
}
