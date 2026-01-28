import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:logger/logger.dart';
import 'package:vidviz/service_locator.dart';

class VideoProbeInfo {
  final int width;
  final int height;
  final int rotationDeg;

  const VideoProbeInfo({
    required this.width,
    required this.height,
    required this.rotationDeg,
  });

  int get displayWidth {
    final r = rotationDeg.abs() % 180;
    return (r == 90) ? height : width;
  }

  int get displayHeight {
    final r = rotationDeg.abs() % 180;
    return (r == 90) ? width : height;
  }
}

class MediaProbe {
  final Logger _logger = locator.get<Logger>();
  final Map<String, VideoProbeInfo> _videoCache = {};

  Future<VideoProbeInfo?> probeVideo(String path) async {
    if (path.isEmpty) return null;
    if (_videoCache.containsKey(path)) return _videoCache[path];

    try {
      final session = await FFprobeKit.getMediaInformation(path);
      final info = session.getMediaInformation();
      final streams = info?.getStreams();
      if (streams == null || streams.isEmpty) return null;

      for (final s in streams) {
        final t = (s.getType() ?? '').toString().toLowerCase();
        if (t != 'video') continue;

        int w = 0;
        int h = 0;
        try {
          final dynamic ds = s;
          w = _toInt(ds.getWidth()) ?? 0;
        } catch (_) {}
        try {
          final dynamic ds = s;
          h = _toInt(ds.getHeight()) ?? 0;
        } catch (_) {}

        Map<dynamic, dynamic> props = const {};
        try {
          final dynamic d = s;
          final dynamic p = d.getAllProperties();
          if (p is Map) {
            props = p;
          }
        } catch (_) {
          props = const {};
        }

        if (w <= 0) w = _toInt(props['width']) ?? 0;
        if (h <= 0) h = _toInt(props['height']) ?? 0;
        if (w <= 0 || h <= 0) {
          continue;
        }

        int rot = 0;
        try {
          final tags = props['tags'];
          if (tags is Map) {
            rot = _toInt(tags['rotate']) ?? rot;
          }
        } catch (_) {}
        rot = _normalizeRotationDeg(rot);

        final out = VideoProbeInfo(width: w, height: h, rotationDeg: rot);
        _videoCache[path] = out;
        return out;
      }
    } catch (e) {
      try {
        _logger.w('probeVideo error: $e');
      } catch (_) {}
    }

    return null;
  }

  String closestPresetAspect(int w, int h) {
    if (w <= 0 || h <= 0) return '16:9';

    final a = w / h;
    final presets = <String, double>{
      '16:9': 16 / 9,
      '9:16': 9 / 16,
      '1:1': 1.0,
      '4:3': 4 / 3,
      '21:9': 21 / 9,
    };

    String bestKey = '16:9';
    double bestDist = double.infinity;
    for (final e in presets.entries) {
      final d = (a - e.value).abs();
      if (d < bestDist) {
        bestDist = d;
        bestKey = e.key;
      }
    }
    return bestKey;
  }

  int _normalizeRotationDeg(int v) {
    int r = v % 360;
    if (r < 0) r += 360;
    if (r == 90 || r == 180 || r == 270) return r;

    final int nearest = (r / 90).round() * 90;
    final int n = nearest % 360;
    return (n == 90 || n == 180 || n == 270) ? n : 0;
  }

  int? _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v);
    return null;
  }
}
