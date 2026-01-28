import 'package:vidviz/model/layer.dart';

/// Media Overlay Asset - Video/Image bindirme için özel model
/// Text/Visualizer gibi overlay olarak çalışır ama media içerir
class MediaOverlayAsset {
  String id;
  String srcPath; // Kaynak video/image path
  String? thumbnailPath;
  String title;
  int duration; // Overlay süresi
  int begin; // Timeline başlangıç
  AssetType mediaType; // video veya image

  // Overlay özellikleri
  double x; // Ekran pozisyonu (0-1 normalized, center anchor)
  double y;
  double scale; // Boyut ölçeği (0.1 - 2.0)
  double opacity; // Şeffaflık (0-1)
  double rotation; // Döndürme (0-360)
  double borderRadius; // Köşe yuvarlaklığı (0-50)

  // Media trim
  int cutFrom; // Media başlangıç noktası (ms)

  String cropMode; // 'none' | 'custom'
  double cropZoom; // 1.0 - 4.0
  double cropPanX; // -1.0 - 1.0
  double cropPanY; // -1.0 - 1.0

  String frameMode; // 'square' | 'portrait' | 'landscape' | 'fullscreen'
  String fitMode; // 'cover' | 'contain' | 'stretch'

  // Animation özellikleri
  String animationType; // 'none', 'fade_in', 'fade_out', 'slide_*', 'zoom_*'
  int animationDuration; // Animation süresi (ms)

  MediaOverlayAsset({
    String? id,
    required this.srcPath,
    this.thumbnailPath,
    required this.title,
    required this.duration,
    required this.begin,
    required this.mediaType,
    this.x = 0.5,
    this.y = 0.5,
    this.scale = 0.3,
    this.opacity = 1.0,
    this.rotation = 0.0,
    this.borderRadius = 8.0,
    this.cutFrom = 0,
    this.cropMode = 'none',
    this.cropZoom = 1.0,
    this.cropPanX = 0.0,
    this.cropPanY = 0.0,
    this.frameMode = 'square',
    this.fitMode = 'cover',
    this.animationType = 'none',
    this.animationDuration = 500,
  }) : id = id ?? 'moa_${DateTime.now().microsecondsSinceEpoch}';

  /// Clone constructor
  MediaOverlayAsset.clone(MediaOverlayAsset other)
    : id = other.id,
      srcPath = other.srcPath,
      thumbnailPath = other.thumbnailPath,
      title = other.title,
      duration = other.duration,
      begin = other.begin,
      mediaType = other.mediaType,
      x = other.x,
      y = other.y,
      scale = other.scale,
      opacity = other.opacity,
      rotation = other.rotation,
      borderRadius = other.borderRadius,
      cutFrom = other.cutFrom,
      cropMode = other.cropMode,
      cropZoom = other.cropZoom,
      cropPanX = other.cropPanX,
      cropPanY = other.cropPanY,
      frameMode = other.frameMode,
      fitMode = other.fitMode,
      animationType = other.animationType,
      animationDuration = other.animationDuration;

  /// Convert to core Asset for timeline storage
  Asset toAsset() {
    return Asset(
      id: id,
      type: AssetType.image, // Media overlay stored as special image type
      srcPath: srcPath,
      thumbnailPath: thumbnailPath,
      title: title,
      duration: duration,
      begin: begin,
      cutFrom: cutFrom,
      data: {
        'overlayType': 'media',
        'mediaType': mediaType == AssetType.video ? 'video' : 'image',
        'x': x,
        'y': y,
        'scale': scale,
        'opacity': opacity,
        'rotation': rotation,
        'borderRadius': borderRadius,
        'cropMode': cropMode,
        'cropZoom': cropZoom,
        'cropPanX': cropPanX,
        'cropPanY': cropPanY,
        'frameMode': frameMode,
        'fitMode': fitMode,
        'animationType': animationType,
        'animationDuration': animationDuration,
      },
    );
  }

  /// Create from core Asset
  static MediaOverlayAsset fromAsset(Asset asset) {
    final data = asset.data ?? {};
    return MediaOverlayAsset(
      id: asset.id,
      srcPath: asset.srcPath,
      thumbnailPath: asset.thumbnailPath,
      title: asset.title,
      duration: asset.duration,
      begin: asset.begin,
      mediaType: (data['mediaType'] == 'video')
          ? AssetType.video
          : AssetType.image,
      x: (data['x'] as num?)?.toDouble() ?? 0.5,
      y: (data['y'] as num?)?.toDouble() ?? 0.5,
      scale: (data['scale'] as num?)?.toDouble() ?? 0.3,
      opacity: (data['opacity'] as num?)?.toDouble() ?? 1.0,
      rotation: (data['rotation'] as num?)?.toDouble() ?? 0.0,
      borderRadius: (data['borderRadius'] as num?)?.toDouble() ?? 8.0,
      cutFrom: asset.cutFrom,
      cropMode: (data['cropMode'] as String?) ?? 'none',
      cropZoom: (data['cropZoom'] as num?)?.toDouble() ?? 1.0,
      cropPanX: (data['cropPanX'] as num?)?.toDouble() ?? 0.0,
      cropPanY: (data['cropPanY'] as num?)?.toDouble() ?? 0.0,
      frameMode: (data['frameMode'] as String?) ?? 'square',
      fitMode: (data['fitMode'] as String?) ?? 'cover',
      animationType: (data['animationType'] as String?) ?? 'none',
      animationDuration: (data['animationDuration'] as int?) ?? 500,
    );
  }

  /// Check if asset is media overlay
  static bool isMediaOverlay(Asset asset) {
    return asset.data?['overlayType'] == 'media';
  }
}
