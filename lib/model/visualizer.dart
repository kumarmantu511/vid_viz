import 'layer.dart';

/// Visualizer asset model - similar to text assets but for audio visualization
class VisualizerAsset {
  String type; // visualizer type: 'bars', 'wave', 'circle', 'spectrum', 'particle'
  String srcPath; // audio source path
  String title;
  int duration;
  int begin;
  
  // Position and appearance
  double x;
  double y;
  double scale;
  int color;
  int? gradientColor; // Optional second color for gradient
  int backgroundColor;
  double alpha;
  // Shader speed (used in shader mode)
  double speed;
  
  // Full-screen background mode (draws visualizer as background)
  bool fullScreen;
  
  // Visualizer specific settings
  int barCount; // for bars effect (max 128)
  double barSpacing; // bar spacing (0.5-1.0, default 0.75)
  double amplitude; // bar/wave height multiplier (0.5-2.0, default 1.0)
  double glowIntensity; // glow effect intensity (0.0-1.0, default 0.5)
  double rotation; // rotation angle for all effects (0.0-360.0, default 0.0)
  double strokeWidth; // line thickness for wave/circle (1.0-5.0, default 2.5)
  double smoothness; // animation smoothness (0.0-1.0, default 0.6)
  double reactivity; // audio reactivity speed (0.5-2.0, default 1.0)
  double sensitivity; // audio sensitivity
  bool mirror; // mirror effect
  String effectStyle; // effect variation
  // Centralized shader/canvas fields
  String renderMode; // 'canvas' | 'shader'
  String? shaderType; // null when canvas
  Map<String, dynamic>? shaderParams;
  
  // Visual overlay images (pro_nation shader)
  String? centerImagePath;     // Orta daire icindeki resim
  int? ringColor;              // Cember/halka rengi (gökkuşağı gibi)
  String? backgroundImagePath; // Arkaplan resmi
  
  // Advanced FFT settings (for music producers)
  int fftBands; // 32, 64, 128 - number of output bands
  double smoothingAlpha; // 0.0-1.0 - EMA smoothing coefficient
  double minFrequency; // Hz - minimum analyzed frequency
  double maxFrequency; // Hz - maximum analyzed frequency
  
  bool deleted;
  
  // Cached FFT data for performance
  List<List<double>>? cachedFFTData;

  VisualizerAsset({
    required this.type,
    required this.srcPath,
    required this.title,
    required this.duration,
    required this.begin,
    this.x = 0.5,
    this.y = 0.5,
    this.scale = 1.0,
    this.color = 0xFFFFFFFF, // Default white instead of green
    this.gradientColor,
    this.backgroundColor = 0x00000000,
    this.alpha = 1.0,
    this.speed = 1.0,
    this.fullScreen = false,
    this.barCount = 48,
    this.barSpacing = 0.75,
    this.amplitude = 1.0,
    this.glowIntensity = 0.5,
    this.rotation = 0.0,
    this.strokeWidth = 2.5,
    this.smoothness = 0.6,
    this.reactivity = 1.0,
    this.sensitivity = 1.0,
    this.mirror = false,
    this.effectStyle = 'default',
    this.renderMode = 'shader',
    this.shaderType,
    this.shaderParams,
    this.centerImagePath,
    this.ringColor,
    this.backgroundImagePath,
    this.fftBands = 64,
    this.smoothingAlpha = 0.6,
    this.minFrequency = 50.0,
    this.maxFrequency = 16000.0,
    this.deleted = false,
    this.cachedFFTData,
  });

  VisualizerAsset.clone(VisualizerAsset asset)
      : type = asset.type,
        srcPath = asset.srcPath,
        title = asset.title,
        duration = asset.duration,
        begin = asset.begin,
        x = asset.x,
        y = asset.y,
        scale = asset.scale,
        color = asset.color,
        gradientColor = asset.gradientColor,
        backgroundColor = asset.backgroundColor,
        alpha = asset.alpha,
        speed = asset.speed,
        fullScreen = asset.fullScreen,
        barCount = asset.barCount,
        barSpacing = asset.barSpacing,
        amplitude = asset.amplitude,
        glowIntensity = asset.glowIntensity,
        rotation = asset.rotation,
        strokeWidth = asset.strokeWidth,
        smoothness = asset.smoothness,
        reactivity = asset.reactivity,
        sensitivity = asset.sensitivity,
        mirror = asset.mirror,
        effectStyle = asset.effectStyle,
        renderMode = asset.renderMode,
        shaderType = asset.shaderType,
        shaderParams = asset.shaderParams,
        centerImagePath = asset.centerImagePath,
        ringColor = asset.ringColor,
        backgroundImagePath = asset.backgroundImagePath,
        fftBands = asset.fftBands,
        smoothingAlpha = asset.smoothingAlpha,
        minFrequency = asset.minFrequency,
        maxFrequency = asset.maxFrequency,
        deleted = asset.deleted,
        cachedFFTData = asset.cachedFFTData;

  VisualizerAsset.fromJson(Map<String, dynamic> map)
      : type = map['type'] ?? 'bars',
        srcPath = map['srcPath'] ?? '',
        title = map['title'] ?? '',
        duration = (map['duration'] as num?)?.toInt() ?? 0,
        begin = (map['begin'] as num?)?.toInt() ?? 0,
        x = (map['x'] as num?)?.toDouble() ?? 0.5,
        y = (map['y'] as num?)?.toDouble() ?? 0.5,
        scale = (map['scale'] as num?)?.toDouble() ?? 1.0,
        color = (map['color'] as num?)?.toInt() ?? 0xFFFFFFFF,
        gradientColor = (map['gradientColor'] as num?)?.toInt(),
        backgroundColor = (map['backgroundColor'] as num?)?.toInt() ?? 0x00000000,
        alpha = (map['alpha'] as num?)?.toDouble() ?? 1.0,
        speed = (map['speed'] as num?)?.toDouble() ?? 1.0,
        fullScreen = (map['fullScreen'] as bool?) ?? false,
        barCount = (map['barCount'] as num?)?.toInt() ?? 48,
        barSpacing = (map['barSpacing'] as num?)?.toDouble() ?? 0.75,
        amplitude = (map['amplitude'] as num?)?.toDouble() ?? 1.0,
        glowIntensity = (map['glowIntensity'] as num?)?.toDouble() ?? 0.5,
        rotation = (map['rotation'] as num?)?.toDouble() ?? 0.0,
        strokeWidth = (map['strokeWidth'] as num?)?.toDouble() ?? 2.5,
        smoothness = (map['smoothness'] as num?)?.toDouble() ?? 0.6,
        reactivity = (map['reactivity'] as num?)?.toDouble() ?? 1.0,
        sensitivity = (map['sensitivity'] as num?)?.toDouble() ?? 1.0,
        mirror = map['mirror'] ?? false,
        effectStyle = map['effectStyle'] ?? 'default',
        renderMode = map['renderMode'] as String? ?? 'shader',
        shaderType = map['shaderType'] as String?,
        shaderParams = (map['shaderParams'] as Map<String, dynamic>?),
        centerImagePath = map['centerImagePath'] as String?,
        ringColor = (map['ringColor'] as num?)?.toInt(),
        backgroundImagePath = map['backgroundImagePath'] as String?,
        fftBands = (map['fftBands'] as num?)?.toInt() ?? 64,
        smoothingAlpha = (map['smoothingAlpha'] as num?)?.toDouble() ?? 0.6,
        minFrequency = (map['minFrequency'] as num?)?.toDouble() ?? 50.0,
        maxFrequency = (map['maxFrequency'] as num?)?.toDouble() ?? 16000.0,
        deleted = map['deleted'] ?? false,
        cachedFFTData = null; // Don't serialize FFT data

  Map<String, dynamic> toJson() => {
        'type': type,
        'srcPath': srcPath,
        'title': title,
        'duration': duration,
        'begin': begin,
        'x': x,
        'y': y,
        'scale': scale,
        'color': color,
        'gradientColor': gradientColor,
        'backgroundColor': backgroundColor,
        'alpha': alpha,
        'speed': speed,
        'fullScreen': fullScreen,
        'barCount': barCount,
        'barSpacing': barSpacing,
        'amplitude': amplitude,
        'glowIntensity': glowIntensity,
        'rotation': rotation,
        'strokeWidth': strokeWidth,
        'smoothness': smoothness,
        'reactivity': reactivity,
        'sensitivity': sensitivity,
        'mirror': mirror,
        'effectStyle': effectStyle,
        'renderMode': renderMode,
        'shaderType': shaderType,
        'shaderParams': shaderParams,
        'centerImagePath': centerImagePath,
        'ringColor': ringColor,
        'backgroundImagePath': backgroundImagePath,
        'fftBands': fftBands,
        'smoothingAlpha': smoothingAlpha,
        'minFrequency': minFrequency,
        'maxFrequency': maxFrequency,
        'deleted': deleted,
      };

  /// Convert from core Asset to VisualizerAsset (centralized model mapping)
  static VisualizerAsset fromAsset(Asset a) {
    // New storage: Asset.data contains serialized model under 'visualizer'
    if (a.data != null && a.data!['visualizer'] != null) {
      final Map<String, dynamic> m = Map<String, dynamic>.from(a.data!['visualizer']);
      return VisualizerAsset.fromJson(m);
    }
    // Fallback default (new assets before saved)
    return VisualizerAsset(
      type: VisualizerType.bars,
      srcPath: a.srcPath,
      title: a.title,
      duration: a.duration,
      begin: a.begin,
    );
  }

  /// Convert VisualizerAsset back to core Asset
  Asset toAsset() {
    return Asset(
      type: AssetType.visualizer,
      srcPath: srcPath,
      title: title,
      duration: duration,
      begin: begin,
      data: {
        'visualizer': toJson(),
      },
    );
  }
}

/// Visualizer effect types
class VisualizerType {
  static const String bars = 'bars';
  static const String wave = 'wave';
  static const String circle = 'circle';
  static const String spectrum = 'spectrum';
  static const String particle = 'particle';
  
  static List<String> get allTypes => [bars, wave, spectrum, particle];
  
  static String getDisplayName(String type) {
    switch (type) {
      case bars:
        return 'Bars';
      case wave:
        return 'Wave';
      case circle:
        return 'Circle';
      case spectrum:
        return 'Spectrum';
      case particle:
        return 'Particle';
      default:
        return 'Unknown';
    }
  }
}
