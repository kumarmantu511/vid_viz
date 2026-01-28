import 'package:vidviz/model/layer.dart';

/// Audio Reactive Asset - Overlay'leri müziğe göre hareket ettirme
/// Text/Visualizer/MediaOverlay pattern'ini takip eder
class AudioReactiveAsset {
  String id;
  String
  targetOverlayId; // Hangi overlay'e bağlı? (text/visualizer/media/shader)
  String? audioSourceId; // Hangi audio layer? (null = tüm audio'lar)
  String title;
  int duration; // Reactive süresi
  int begin; // Timeline başlangıç

  // Reactive özellikleri
  String reactiveType; // 'scale', 'rotation', 'opacity', 'x', 'y'
  double sensitivity; // Hassasiyet (0.1 - 3.0)
  String frequencyRange; // 'bass', 'mid', 'treble', 'all'
  double smoothing; // Yumuşatma (0.0 - 1.0)

  // Advanced
  double minValue; // Min değer (örn: scale için 0.1)
  double maxValue; // Max değer (örn: scale için 2.0)
  bool invertReaction; // Ters tepki (ses yüksek = küçül)
  int offsetMs; // Audio'ya göre ileri/geri kaydırma (ms)

  AudioReactiveAsset({
    String? id,
    required this.targetOverlayId,
    this.audioSourceId,
    required this.title,
    required this.duration,
    required this.begin,
    this.reactiveType = 'scale',
    this.sensitivity = 1.0,
    this.frequencyRange = 'all',
    this.smoothing = 0.3,
    this.minValue = 0.1,
    this.maxValue = 2.0,
    this.invertReaction = false,
    this.offsetMs = 0,
  }) : id = id ?? 'ar_${DateTime.now().microsecondsSinceEpoch}';

  /// Clone constructor
  AudioReactiveAsset.clone(AudioReactiveAsset other)
    : id = other.id,
      targetOverlayId = other.targetOverlayId,
      audioSourceId = other.audioSourceId,
      title = other.title,
      duration = other.duration,
      begin = other.begin,
      reactiveType = other.reactiveType,
      sensitivity = other.sensitivity,
      frequencyRange = other.frequencyRange,
      smoothing = other.smoothing,
      minValue = other.minValue,
      maxValue = other.maxValue,
      invertReaction = other.invertReaction,
      offsetMs = other.offsetMs;

  /// Convert to core Asset for timeline storage
  Asset toAsset() {
    return Asset(
      id: id,
      type: AssetType.image, // Audio reactive stored as special image type
      srcPath: '', // No source file
      title: title,
      duration: duration,
      begin: begin,
      data: {
        'overlayType': 'audio_reactive',
        'targetOverlayId': targetOverlayId,
        'audioSourceId': audioSourceId,
        'reactiveType': reactiveType,
        'sensitivity': sensitivity,
        'frequencyRange': frequencyRange,
        'smoothing': smoothing,
        'minValue': minValue,
        'maxValue': maxValue,
        'invertReaction': invertReaction,
        'offsetMs': offsetMs,
      },
    );
  }

  /// Create from core Asset
  static AudioReactiveAsset fromAsset(Asset asset) {
    final data = asset.data ?? {};
    return AudioReactiveAsset(
      id: asset.id,
      targetOverlayId: (data['targetOverlayId'] as String?) ?? '',
      audioSourceId: data['audioSourceId'] as String?,
      title: asset.title,
      duration: asset.duration,
      begin: asset.begin,
      reactiveType: (data['reactiveType'] as String?) ?? 'scale',
      sensitivity: (data['sensitivity'] as num?)?.toDouble() ?? 1.0,
      frequencyRange: (data['frequencyRange'] as String?) ?? 'all',
      smoothing: (data['smoothing'] as num?)?.toDouble() ?? 0.3,
      minValue: (data['minValue'] as num?)?.toDouble() ?? 0.1,
      maxValue: (data['maxValue'] as num?)?.toDouble() ?? 2.0,
      invertReaction: (data['invertReaction'] as bool?) ?? false,
      offsetMs: (data['offsetMs'] as num?)?.toInt() ?? 0,
    );
  }

  /// Check if asset is audio reactive
  static bool isAudioReactive(Asset asset) {
    return asset.data?['overlayType'] == 'audio_reactive';
  }
}
