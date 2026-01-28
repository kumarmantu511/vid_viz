/// Shader Effect model - follows the Text and Visualizer patterns
/// Represents shader effects on the timeline
class ShaderEffectAsset {
  String type; // shader type: 'rain', 'snow', 'water', 'blur', 'vignette'
  String srcPath; // source video/image asset path
  String title;
  int duration;
  int begin;
  
  // Position and appearance
  double x;
  double y;
  double scale;
  double alpha;
  
  // Shader specific parameters
  double intensity; // effect strength (0.0 - 1.0)
  double speed; // animation speed (rain/snow)
  int color; // effect color (some shaders)
  double size; // particle size (rain/snow)
  double density; // amount/density (rain/snow)
  double angle; // direction angle (rain)
  double frequency; // frequency (water)
  double amplitude; // amplitude (water)
  double blurRadius; // blur radius (blur)
  double vignetteSize; // vignette size (vignette)
  
  bool deleted;

  ShaderEffectAsset({
    required this.type,
    required this.srcPath,
    required this.title,
    required this.duration,
    required this.begin,
    this.x = 0.5,
    this.y = 0.5,
    this.scale = 1.0,
    this.alpha = 1.0,
    this.intensity = 0.5,
    this.speed = 1.0,
    this.color = 0xFFFFFFFF,
    this.size = 1.0,
    this.density = 0.5,
    this.angle = 0.0,
    this.frequency = 1.0,
    this.amplitude = 0.5,
    this.blurRadius = 5.0,
    this.vignetteSize = 0.5,
    this.deleted = false,
  });

  ShaderEffectAsset.clone(ShaderEffectAsset asset)
      : type = asset.type,
        srcPath = asset.srcPath,
        title = asset.title,
        duration = asset.duration,
        begin = asset.begin,
        x = asset.x,
        y = asset.y,
        scale = asset.scale,
        alpha = asset.alpha,
        intensity = asset.intensity,
        speed = asset.speed,
        color = asset.color,
        size = asset.size,
        density = asset.density,
        angle = asset.angle,
        frequency = asset.frequency,
        amplitude = asset.amplitude,
        blurRadius = asset.blurRadius,
        vignetteSize = asset.vignetteSize,
        deleted = asset.deleted;

  ShaderEffectAsset.fromJson(Map<String, dynamic> map)
      : type = map['type'] ?? 'rain',
        srcPath = map['srcPath'] ?? '',
        title = map['title'] ?? '',
        duration = (map['duration'] as num?)?.toInt() ?? 0,
        begin = (map['begin'] as num?)?.toInt() ?? 0,
        x = (map['x'] as num?)?.toDouble() ?? 0.5,
        y = (map['y'] as num?)?.toDouble() ?? 0.5,
        scale = (map['scale'] as num?)?.toDouble() ?? 1.0,
        alpha = (map['alpha'] as num?)?.toDouble() ?? 1.0,
        intensity = (map['intensity'] as num?)?.toDouble() ?? 0.5,
        speed = (map['speed'] as num?)?.toDouble() ?? 1.0,
        color = (map['color'] as num?)?.toInt() ?? 0xFFFFFFFF,
        size = (map['size'] as num?)?.toDouble() ?? 1.0,
        density = (map['density'] as num?)?.toDouble() ?? 0.5,
        angle = (map['angle'] as num?)?.toDouble() ?? 0.0,
        frequency = (map['frequency'] as num?)?.toDouble() ?? 1.0,
        amplitude = (map['amplitude'] as num?)?.toDouble() ?? 0.5,
        blurRadius = (map['blurRadius'] as num?)?.toDouble() ?? 5.0,
        vignetteSize = (map['vignetteSize'] as num?)?.toDouble() ?? 0.5,
        deleted = map['deleted'] ?? false;

  Map<String, dynamic> toJson() => {
        'type': type,
        'srcPath': srcPath,
        'title': title,
        'duration': duration,
        'begin': begin,
        'x': x,
        'y': y,
        'scale': scale,
        'alpha': alpha,
        'intensity': intensity,
        'speed': speed,
        'color': color,
        'size': size,
        'density': density,
        'angle': angle,
        'frequency': frequency,
        'amplitude': amplitude,
        'blurRadius': blurRadius,
        'vignetteSize': vignetteSize,
        'deleted': deleted,
      };
  
  /// Convert to params map for shader painter
  Map<String, dynamic> toParamsMap() => {
        'type': type,
        'intensity': intensity,
        'speed': speed,
        'color': color,
        'size': size,
        'density': density,
        'angle': angle,
        'frequency': frequency,
        'amplitude': amplitude,
        'blurRadius': blurRadius,
        'vignetteSize': vignetteSize,
        'alpha': alpha,
      };
}

/// Shader effect types
class ShaderEffectType {
  static const String rain = 'rain';
  static const String rainGlass = 'rain_glass';
  static const String snow = 'snow';
  static const String water = 'water';
  static const String blur = 'blur';
  static const String vignette = 'vignette';
  // fractal and psychedelic were removed (empty effects)
  // Extended overlay shaders
  static const String halfTone = 'half_tone';
  static const String tiles = 'tiles';
  static const String circleRadius = 'circle_radius';
  static const String dunes = 'dunes';
  static const String heatVision = 'heat_vision';
  static const String spectrum = 'spectrum';
  static const String waveWater = 'wave_water';
  static const String wavePropagation = 'wave_propagation';
  static const String water2d = 'water2d';
  static const String waterSurface = 'water_surface';
  static const String waterBlobs = 'water_blobs';
  static const String sphere = 'sphere';
  static const String fishe = 'fishe';
  static const String sfishe = 'sfishe';
  // Popular/pro effects
  static const String chromAberration = 'chrom_aberration';
  static const String crt = 'crt';
  static const String pixelate = 'pixelate';
  static const String posterize = 'posterize';
  static const String edgeDetect = 'edge_detect';
  static const String sharpenFx = 'sharpen';
  static const String swirl = 'swirl';
  static const String fisheye = 'fisheye';
  static const String zoomBlur = 'zoom_blur';
  static const String filmGrain = 'film_grain';
  static const String hdBoost = 'hd_boost';
  
  static List<String> get allTypes => [
    rain, rainGlass, snow, water, blur, vignette,
    halfTone, tiles, circleRadius, dunes, heatVision, spectrum,
    waveWater, water2d,
    sphere, fishe,
    chromAberration, crt, pixelate, posterize, edgeDetect, sharpenFx, swirl, fisheye, zoomBlur, filmGrain,
    hdBoost,
  ];

  // Grouping for UI: Effects vs Filters
  static List<String> get effectTypes => [
    rain, rainGlass, snow, water,
    halfTone, tiles, circleRadius, dunes, heatVision, spectrum,
    waveWater, water2d,
    sphere, fishe,
  ];

  static List<String> get filterTypes => [
    hdBoost, sharpenFx, edgeDetect, pixelate, posterize, chromAberration, crt, swirl, fisheye, zoomBlur, filmGrain,
    blur, vignette,
  ];
  
  static String getDisplayName(String type) {
    switch (type) {
      case rain:
        return 'Rain';
      case rainGlass:
        return 'Rain Glass';
      case snow:
        return 'Snow';
      case water:
        return 'Water Ripple';
      case blur:
        return 'Blur';
      case vignette:
        return 'Vignette';
      case halfTone:
        return 'Halftone';
      case tiles:
        return 'Tiles';
      case circleRadius:
        return 'Circle Radius';
      case dunes:
        return 'Dunes';
      case heatVision:
        return 'Heat Vision';
      case spectrum:
        return 'Spectrum Shift';
      case waveWater:
        return 'Wave Water';
      case wavePropagation:
        return 'Wave Propagation';
      case water2d:
        return 'Water 2D';
      case waterSurface:
        return 'Water Surface';
      case waterBlobs:
        return 'Water Blobs';
      case sphere:
        return 'Sphere';
      case fishe:
        return 'Fisheye FX';
      case sfishe:
        return 'Smooth Fisheye FX';
      case chromAberration:
        return 'Chromatic Aberration';
      case crt:
        return 'CRT Display';
      case pixelate:
        return 'Pixelate';
      case posterize:
        return 'Posterize';
      case edgeDetect:
        return 'Edge Detect';
      case sharpenFx:
        return 'Sharpen';
      case swirl:
        return 'Swirl';
      case fisheye:
        return 'Fisheye';
      case zoomBlur:
        return 'Zoom Blur';
      case filmGrain:
        return 'Film Grain';
      case hdBoost:
        return 'HD Boost';
      default:
        return 'Unknown';
    }
  }
  
  static String getDescription(String type) {
    switch (type) {
      case rain:
        return 'Animated rain drops';
      case rainGlass:
        return 'Rain on glass with foggy streaks';
      case snow:
        return 'Animated snow flakes';
      case water:
        return 'Water ripple distortion';
      case blur:
        return 'Gaussian blur';
      case vignette:
        return 'Cinematic vignette';
      case halfTone:
        return 'Halftone dot raster effect';
      case tiles:
        return 'Tiles/mosaic segmentation effect';
      case circleRadius:
        return 'Circle pixelization based on luminance';
      case dunes:
        return 'Dunes-like quantization look';
      case heatVision:
        return 'Heat map style color mapping';
      case spectrum:
        return 'RGB spectrum shift/aberration';
      case waveWater:
        return 'Simple water wave refraction';
      case wavePropagation:
        return 'Expanding wave propagation refraction';
      case water2d:
        return 'Fast 2D water lens distortion';
      case waterSurface:
        return 'Layered sine-based water surface refraction';
      case waterBlobs:
        return 'Metaball water blobs refraction';
      case sphere:
        return 'Spinning sphere overlay simulation';
      case fishe:
        return 'Fisheye distortion with chromatic aberration';
      case sfishe:
        return 'Smoother fisheye distortion variant';
      case chromAberration:
        return 'Offsets color channels outward (lens CA)';
      case crt:
        return 'Old CRT display (scanlines + barrel distortion)';
      case pixelate:
        return 'Large pixel blocks posterized look';
      case posterize:
        return 'Reduces color levels (posterize)';
      case edgeDetect:
        return 'Sobel-based edge detection';
      case sharpenFx:
        return 'Basic sharpening (unsharp mask variant)';
      case swirl:
        return 'Swirl distortion around center';
      case fisheye:
        return 'Fisheye (barrel) distortion';
      case zoomBlur:
        return 'Radial zoom blur towards center';
      case filmGrain:
        return 'Subtle animated film grain';
      case hdBoost:
        return 'Boosts sharpness and micro-contrast';
      default:
        return '';
    }
  }
  
  /// Available parameters per shader
  static List<String> getAvailableParams(String type) {
    switch (type) {
      case rain:
        return ['intensity', 'speed', 'size', 'density'];
      case rainGlass:
        return ['intensity', 'speed', 'size', 'density'];
      case snow:
        return ['intensity', 'speed', 'size', 'density'];
      case water:
        return ['intensity', 'frequency', 'amplitude', 'speed'];
      case blur:
        return ['intensity', 'blurRadius'];
      case vignette:
        return ['intensity', 'vignetteSize'];
      case halfTone:
      case tiles:
      case circleRadius:
      case dunes:
      case heatVision:
      case spectrum:
      case waveWater:
      case wavePropagation:
      case water2d:
      case waterSurface:
      case waterBlobs:
      case sphere:
      case fishe:
      case sfishe:
        return ['intensity'];
      default:
        return ['intensity'];
    }
  }
}
