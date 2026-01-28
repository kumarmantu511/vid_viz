part of 'package:vidviz/service/director_service.dart';

extension ExportFunction on DirectorService {

  generateVideo(
      List<Layer> layers,
      VideoResolution videoResolution, {
        int? framerate,
        int? quality,
        String? outputFormat,
      }) async {
    try {
      saveVisualizerAsset();
    } catch (_) {}

    if (filesNotExist) {
      _filesNotExist.add(true);
      return false;
    }
    exportPreviewThumbnailPath = null;
    isGenerating = true;
    _layersChanged.add(true); // Hide images for memory
    resetExportProgress();
    try {
      await generator.finishVideoGeneration();
    } catch (_) {}

    // Single entry: ExportPipeline (native engine export)
    String? outputFile;
    _exportCancelled = false;
    try {
      final exportPipeline = locator.get<ExportPipeline>();
      outputFile = await exportPipeline.export(
        layers: layers,
        videoResolution: videoResolution,
        captureKey: exportCaptureKey,
        previewAt: previewAt,
        generator: generator,
        onProgress: reportExportProgress,
        isCancelled: () => _exportCancelled,
        fps: framerate ?? 30,
        quality: quality ?? 1,
        outputFormat: outputFormat,
        videoSettings: editingVideoSettings ?? getProjectVideoSettings(),
      );
    } catch (_) {
      // If user cancelled, do not fallback
      // Long-term: avoid legacy fallback which ignores VideoSettings
    }
    if (outputFile != null) {
      DateTime date = DateTime.now();
      String resolutionStr = generator.videoResolutionString(videoResolution);

      projectDao.insertGeneratedVideo(
        GeneratedVideo(
          projectId: project!.id!,
          path: outputFile,
          date: date,
          resolution: resolutionStr,
          thumbnail: null,
        ),
      );
    }
    isGenerating = false;
    _layersChanged.add(true); // Show images
    // Re-sync preview with current timeline position after export completes
    try {
      await _previewOnPosition();
    } catch (_) {}
  }

  void cancelExport() {
    if (!isGenerating) {
      logger.w('cancelExport called but not generating');
      return;
    }

    print('🛑 Export cancellation requested');
    _exportCancelled = true;
    // Immediately unlock UI; export pipeline will wind down asynchronously
    isGenerating = false;
    try {
      _layersChanged.add(true);
      _appBar.add(true);
    } catch (_) {}
    if (isNativeExportAvailable) {
      try {
        NativeExportService.instance.cancel();
      } catch (_) {}
    } else {
      generator.finishVideoGeneration();
    }
  }
}