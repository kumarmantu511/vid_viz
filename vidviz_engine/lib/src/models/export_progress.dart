/// Export Progress Model
/// 
/// C++ engine'den Flutter'a gelen ilerleme bilgisi.
library;

/// Export progress data
class ExportProgress {
  final double progress;     // 0.0 - 1.0
  final int currentFrame;    // Current frame number
  final int totalFrames;     // Total frames to render
  final int? fps;            // Current render FPS
  final int? elapsedMs;      // Elapsed time in ms
  final int? estimatedMs;    // Estimated remaining time in ms
  final String? videoDecodePath;
  final String? videoDecodeError;
  final bool? setEncoderSurfaceOk;
  final int? presentOkCount;
  final int? presentFailCount;
  final int? lastEglError;
  final String? lastPresentError;

  ExportProgress({
    required this.progress,
    required this.currentFrame,
    required this.totalFrames,
    this.fps,
    this.elapsedMs,
    this.estimatedMs,
    this.videoDecodePath,
    this.videoDecodeError,
    this.setEncoderSurfaceOk,
    this.presentOkCount,
    this.presentFailCount,
    this.lastEglError,
    this.lastPresentError,
  });

  /// Progress percentage (0-100)
  int get percentage => (progress * 100).round();

  /// Human readable elapsed time
  String get elapsedFormatted {
    if (elapsedMs == null) return '--:--';
    final seconds = elapsedMs! ~/ 1000;
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Human readable remaining time
  String get remainingFormatted {
    if (estimatedMs == null) return '--:--';
    final seconds = estimatedMs! ~/ 1000;
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  factory ExportProgress.fromJson(Map<String, dynamic> json) => ExportProgress(
    progress: (json['progress'] as num).toDouble(),
    currentFrame: json['currentFrame'] as int,
    totalFrames: json['totalFrames'] as int,
    fps: json['fps'] as int?,
    elapsedMs: json['elapsedMs'] as int?,
    estimatedMs: json['estimatedMs'] as int?,
    videoDecodePath: json['videoDecodePath'] as String?,
    videoDecodeError: json['videoDecodeError'] as String?,
    setEncoderSurfaceOk: json['setEncoderSurfaceOk'] as bool?,
    presentOkCount: (json['presentOkCount'] as num?)?.toInt(),
    presentFailCount: (json['presentFailCount'] as num?)?.toInt(),
    lastEglError: (json['lastEglError'] as num?)?.toInt(),
    lastPresentError: json['lastPresentError'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'progress': progress,
    'currentFrame': currentFrame,
    'totalFrames': totalFrames,
    'fps': fps,
    'elapsedMs': elapsedMs,
    'estimatedMs': estimatedMs,
    'videoDecodePath': videoDecodePath,
    'videoDecodeError': videoDecodeError,
    'setEncoderSurfaceOk': setEncoderSurfaceOk,
    'presentOkCount': presentOkCount,
    'presentFailCount': presentFailCount,
    'lastEglError': lastEglError,
    'lastPresentError': lastPresentError,
  };
}
