class NativeExportProgress {
  final double progress;
  final int currentFrame;
  final int totalFrames;
  final int? fps;
  final int? elapsedMs;
  final String? videoDecodePath;
  final String? videoDecodeError;
  final bool? setEncoderSurfaceOk;
  final int? presentOkCount;
  final int? presentFailCount;
  final int? lastEglError;
  final String? lastPresentError;

  NativeExportProgress({
    required this.progress,
    required this.currentFrame,
    required this.totalFrames,
    this.fps,
    this.elapsedMs,
    this.videoDecodePath,
    this.videoDecodeError,
    this.setEncoderSurfaceOk,
    this.presentOkCount,
    this.presentFailCount,
    this.lastEglError,
    this.lastPresentError,
  });

  int get percentage => (progress * 100).round();
}
