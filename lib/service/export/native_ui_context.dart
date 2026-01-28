class ExportUiContext {
  final int exportWidth;
  final int exportHeight;
  final double? uiPlayerWidth;
  final double? uiPlayerHeight;
  final double? uiDevicePixelRatio;

  const ExportUiContext({
    required this.exportWidth,
    required this.exportHeight,
    required this.uiPlayerWidth,
    required this.uiPlayerHeight,
    required this.uiDevicePixelRatio,
  });

  bool get hasUiMetrics {
    final w = uiPlayerWidth;
    final h = uiPlayerHeight;
    return w != null && h != null && w.isFinite && h.isFinite && w > 0 && h > 0;
  }

  double get sxUi {
    if (!hasUiMetrics) return 1.0;
    return exportWidth / uiPlayerWidth!;
  }

  double get syUi {
    if (!hasUiMetrics) return 1.0;
    return exportHeight / uiPlayerHeight!;
  }
}
