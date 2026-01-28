/// Export Job Model
/// 
/// Flutter'dan C++ engine'e gönderilen iş tanımı.
/// JSON olarak serialize edilir ve FFI ile native'e gönderilir.
library;

import 'dart:convert';

/// Video export settings
class ExportSettings {
  final int width;
  final int height;
  final int fps;
  final int quality; // 0=low, 1=medium, 2=high
  final String aspectRatio;
  final String outputPath;
  final String cropMode;
  final int rotation;
  final bool flipHorizontal;
  final bool flipVertical;
  final int backgroundColor;
  final String outputFormat;
  final double? uiPlayerWidth;
  final double? uiPlayerHeight;
  final double? uiDevicePixelRatio;

  ExportSettings({
    required this.width,
    required this.height,
    this.fps = 30,
    this.quality = 1,
    this.aspectRatio = '16:9',
    this.cropMode = 'fit',
    this.rotation = 0,
    this.flipHorizontal = false,
    this.flipVertical = false,
    this.backgroundColor = 0xFF000000,
    this.outputFormat = 'mp4',
    this.uiPlayerWidth,
    this.uiPlayerHeight,
    this.uiDevicePixelRatio,
    required this.outputPath,
  });

  Map<String, dynamic> toJson() => {
    'width': width,
    'height': height,
    'fps': fps,
    'quality': quality,
    'aspectRatio': aspectRatio,
    'cropMode': cropMode,
    'rotation': rotation,
    'flipHorizontal': flipHorizontal,
    'flipVertical': flipVertical,
    'backgroundColor': backgroundColor,
    'outputFormat': outputFormat,
    'outputPath': outputPath,
    if (uiPlayerWidth != null) 'uiPlayerWidth': uiPlayerWidth,
    if (uiPlayerHeight != null) 'uiPlayerHeight': uiPlayerHeight,
    if (uiDevicePixelRatio != null) 'uiDevicePixelRatio': uiDevicePixelRatio,
  };

  factory ExportSettings.fromJson(Map<String, dynamic> json) => ExportSettings(
    width: json['width'] as int,
    height: json['height'] as int,
    fps: json['fps'] as int? ?? 30,
    quality: json['quality'] as int? ?? 1,
    aspectRatio: json['aspectRatio'] as String? ?? '16:9',
    cropMode: json['cropMode'] as String? ?? 'fit',
    rotation: json['rotation'] as int? ?? 0,
    flipHorizontal: json['flipHorizontal'] as bool? ?? false,
    flipVertical: json['flipVertical'] as bool? ?? false,
    backgroundColor: json['backgroundColor'] as int? ?? 0xFF000000,
    outputFormat: json['outputFormat'] as String? ?? 'mp4',
    outputPath: json['outputPath'] as String,
    uiPlayerWidth: (json['uiPlayerWidth'] as num?)?.toDouble(),
    uiPlayerHeight: (json['uiPlayerHeight'] as num?)?.toDouble(),
    uiDevicePixelRatio: (json['uiDevicePixelRatio'] as num?)?.toDouble(),
  );
}

/// Layer type enum
enum LayerType {
  raster,    // Video/Image
  audio,     // Audio track
  text,      // Text overlay
  shader,    // GLSL shader effect
  visualizer,// Audio visualizer
}

/// Asset in timeline
class ExportAsset {
  final String id;
  final String type; // 'video', 'image', 'audio', 'text', 'shader', 'visualizer'
  final String srcPath;
  final int begin;      // Start time in ms
  final int duration;   // Duration in ms
  final int cutFrom;    // Trim start in ms
  final double playbackSpeed;
  final Map<String, dynamic>? data; // Type-specific data

  ExportAsset({
    required this.id,
    required this.type,
    required this.srcPath,
    required this.begin,
    required this.duration,
    this.cutFrom = 0,
    this.playbackSpeed = 1.0,
    this.data,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'srcPath': srcPath,
    'begin': begin,
    'duration': duration,
    'cutFrom': cutFrom,
    'playbackSpeed': playbackSpeed,
    'data': data,
  };

  factory ExportAsset.fromJson(Map<String, dynamic> json) => ExportAsset(
    id: json['id'] as String,
    type: json['type'] as String,
    srcPath: json['srcPath'] as String,
    begin: json['begin'] as int,
    duration: json['duration'] as int,
    cutFrom: json['cutFrom'] as int? ?? 0,
    playbackSpeed: (json['playbackSpeed'] as num?)?.toDouble() ?? 1.0,
    data: json['data'] as Map<String, dynamic>?,
  );
}

/// Layer in timeline
class ExportLayer {
  final String id;
  final String type; // 'raster', 'audio', 'text', 'shader', 'visualizer'
  final String name;
  final int zIndex;
  final double volume;
  final bool mute;
  final bool useVideoAudio;
  final List<ExportAsset> assets;

  ExportLayer({
    required this.id,
    required this.type,
    required this.name,
    this.zIndex = 0,
    this.volume = 1.0,
    this.mute = false,
    bool? useVideoAudio,
    required this.assets,
  }) : useVideoAudio = useVideoAudio ?? (type == 'raster');

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'name': name,
    'zIndex': zIndex,
    'volume': volume,
    'mute': mute,
    'useVideoAudio': useVideoAudio,
    'assets': assets.map((a) => a.toJson()).toList(),
  };

  factory ExportLayer.fromJson(Map<String, dynamic> json) => ExportLayer(
    id: json['id'] as String,
    type: json['type'] as String,
    name: json['name'] as String,
    zIndex: json['zIndex'] as int? ?? 0,
    volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
    mute: json['mute'] as bool? ?? false,
    useVideoAudio: (json['useVideoAudio'] as bool?) ?? ((json['type'] as String?) == 'raster'),
    assets: (json['assets'] as List)
        .map((a) => ExportAsset.fromJson(a as Map<String, dynamic>))
        .toList(),
  );
}

/// Shader definition
class ExportShader {
  final String id;
  final String name;
  final String source; // GLSL source code
  final Map<String, dynamic> uniforms; // Uniform values

  ExportShader({
    required this.id,
    required this.name,
    required this.source,
    this.uniforms = const {},
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'source': source,
    'uniforms': uniforms,
  };

  factory ExportShader.fromJson(Map<String, dynamic> json) => ExportShader(
    id: json['id'] as String,
    name: json['name'] as String,
    source: json['source'] as String,
    uniforms: json['uniforms'] as Map<String, dynamic>? ?? {},
  );
}

/// FFT data for visualizers
class ExportFFTData {
  final String audioPath;
  final int sampleRate;
  final int hopSize;
  final List<List<double>> frames; // [frame][band] = amplitude

  ExportFFTData({
    required this.audioPath,
    this.sampleRate = 44100,
    this.hopSize = 512,
    required this.frames,
  });

  Map<String, dynamic> toJson() => {
    'audioPath': audioPath,
    'sampleRate': sampleRate,
    'hopSize': hopSize,
    'frames': frames,
  };

  factory ExportFFTData.fromJson(Map<String, dynamic> json) => ExportFFTData(
    audioPath: json['audioPath'] as String,
    sampleRate: json['sampleRate'] as int? ?? 44100,
    hopSize: json['hopSize'] as int? ?? 512,
    frames: (json['frames'] as List)
        .map((f) => (f as List).map((v) => (v as num).toDouble()).toList())
        .toList(),
  );
}

/// Complete export job
class ExportJob {
  final String jobId;
  final ExportSettings settings;
  final List<ExportLayer> layers;
  final List<ExportShader> shaders;
  final List<ExportFFTData> fftData;
  final int totalDuration; // Total duration in ms

  ExportJob({
    required this.jobId,
    required this.settings,
    required this.layers,
    this.shaders = const [],
    this.fftData = const [],
    required this.totalDuration,
  });

  Map<String, dynamic> toJson() => {
    'jobId': jobId,
    'settings': settings.toJson(),
    'layers': layers.map((l) => l.toJson()).toList(),
    'shaders': shaders.map((s) => s.toJson()).toList(),
    'fftData': fftData.map((f) => f.toJson()).toList(),
    'totalDuration': totalDuration,
  };

  String toJsonString() => jsonEncode(toJson());

  factory ExportJob.fromJson(Map<String, dynamic> json) => ExportJob(
    jobId: json['jobId'] as String,
    settings: ExportSettings.fromJson(json['settings'] as Map<String, dynamic>),
    layers: (json['layers'] as List)
        .map((l) => ExportLayer.fromJson(l as Map<String, dynamic>))
        .toList(),
    shaders: (json['shaders'] as List?)
        ?.map((s) => ExportShader.fromJson(s as Map<String, dynamic>))
        .toList() ?? [],
    fftData: (json['fftData'] as List?)
        ?.map((f) => ExportFFTData.fromJson(f as Map<String, dynamic>))
        .toList() ?? [],
    totalDuration: json['totalDuration'] as int,
  );
}
