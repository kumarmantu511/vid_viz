import 'dart:async';
import 'dart:typed_data';
import 'package:rxdart/rxdart.dart';
import 'package:logger/logger.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/model/audio_reactive.dart';
import 'package:vidviz/model/layer.dart';
import 'package:vidviz/service/audio_analysis_service.dart';

/// Audio Reactive Service - Overlay'leri müziğe göre hareket ettirme yönetimi
/// Text/Visualizer/MediaOverlay pattern'ini takip eder + FFT analizi
class AudioReactiveService {
  final logger = locator.get<Logger>();
  final audioAnalysis = locator.get<AudioAnalysisService>();

  static const int _maxPreviewFftFrames = 20000;

  // Editing state
  AudioReactiveAsset? _editingAudioReactive;
  final BehaviorSubject<AudioReactiveAsset?> _editingAudioReactive$ =
      BehaviorSubject<AudioReactiveAsset?>.seeded(null);

  // Available overlays to attach (target overlays)
  List<Asset> _availableOverlays = [];
  final BehaviorSubject<List<Asset>> _availableOverlays$ =
      BehaviorSubject<List<Asset>>.seeded([]);

  // Available audio sources
  List<Asset> _availableAudioSources = [];
  final BehaviorSubject<List<Asset>> _availableAudioSources$ =
      BehaviorSubject<List<Asset>>.seeded([]);

  // FFT cache for real-time audio analysis (VisualizerService pattern)
  static const int _maxCacheSize = 3;
  final Map<String, List<List<double>>> _fftCache = {};
  final Map<String, int> _hopByAudio = {};
  final List<String> _cacheOrder = [];
  final Set<String> _processing = {};
  final BehaviorSubject<int> _fftReady = BehaviorSubject.seeded(0);
  Stream<int> get fftReady$ => _fftReady.stream;

  // Log throttling
  final Map<String, int> _lastLogMs = {};

  void _addToCache(String key, List<List<double>> fftData) {
    if (_fftCache.containsKey(key)) {
      _cacheOrder.remove(key);
      _cacheOrder.add(key);
      return;
    }

    while (_fftCache.length >= _maxCacheSize && _cacheOrder.isNotEmpty) {
      final oldest = _cacheOrder.removeAt(0);
      _fftCache.remove(oldest);
      _hopByAudio.remove(oldest);
    }

    _fftCache[key] = fftData;
    _cacheOrder.add(key);
  }

  int? _getHopForAudio(String canon) {
    if (!_hopByAudio.containsKey(canon)) return null;
    _cacheOrder.remove(canon);
    _cacheOrder.add(canon);
    return _hopByAudio[canon];
  }

  // Getters
  AudioReactiveAsset? get editingAudioReactive => _editingAudioReactive;
  Stream<AudioReactiveAsset?> get editingAudioReactive$ =>
      _editingAudioReactive$.stream;

  List<Asset> get availableOverlays => _availableOverlays;
  Stream<List<Asset>> get availableOverlays$ => _availableOverlays$.stream;

  List<Asset> get availableAudioSources => _availableAudioSources;
  Stream<List<Asset>> get availableAudioSources$ =>
      _availableAudioSources$.stream;

  // Setters
  set editingAudioReactive(AudioReactiveAsset? value) {
    _editingAudioReactive = value;
    _editingAudioReactive$.add(value);
  }

  set availableOverlays(List<Asset> value) {
    _availableOverlays = value;
    _availableOverlays$.add(value);
  }

  set availableAudioSources(List<Asset> value) {
    _availableAudioSources = value;
    _availableAudioSources$.add(value);
  }

  /// Start adding new audio reactive
  Future<void> startAddingAudioReactive(
    List<Asset> overlays,
    List<Asset> audioSources,
  ) async {
    availableOverlays = overlays;
    availableAudioSources = audioSources;

    // If overlays available, create default audio reactive with first overlay
    if (overlays.isNotEmpty) {
      final firstOverlay = overlays.first;

      // Default behavior (Adobe-like): do not shrink by default.
      // Scale reactive defaults to "only grow" around the target's current base.
      double baseScale = 1.0;
      final overlayType = firstOverlay.data?['overlayType'];
      if (overlayType == 'media') {
        baseScale = (firstOverlay.data?['scale'] as num?)?.toDouble() ?? 1.0;
      } else if (overlayType == 'visualizer') {
        baseScale = (firstOverlay.data?['scale'] as num?)?.toDouble() ?? 1.0;
      } else if (overlayType == 'shader') {
        baseScale = (firstOverlay.data?['scale'] as num?)?.toDouble() ?? 1.0;
      } else if (firstOverlay.type == AssetType.text || overlayType == 'text') {
        // Text scale is a multiplier, not a stored scale field.
        baseScale = 1.0;
      }
      if (!baseScale.isFinite) baseScale = 1.0;

      double minValue = baseScale;
      double maxValue = baseScale * 1.1;

      // Keep within general safety bounds used elsewhere.
      minValue = minValue.clamp(0.1, 4.0);
      maxValue = maxValue.clamp(0.1, 4.0);
      if (maxValue < minValue) {
        final t = minValue;
        minValue = maxValue;
        maxValue = t;
      }

      editingAudioReactive = AudioReactiveAsset(
        targetOverlayId: firstOverlay.id,
        audioSourceId: audioSources.isNotEmpty ? audioSources.first.id : null,
        title: 'Audio Reactive',
        // Başlangıçta hedef overlay ile hizalı olsun
        duration: firstOverlay.duration,
        begin: firstOverlay.begin,
        reactiveType: 'scale',
        sensitivity: 1.2,
        frequencyRange: 'all',
        smoothing: 0.2,
        minValue: minValue,
        maxValue: maxValue,
      );
    }
  }

  /// Convert Asset to AudioReactiveAsset
  AudioReactiveAsset assetToAudioReactive(Asset asset) {
    return AudioReactiveAsset.fromAsset(asset);
  }

  /// Convert AudioReactiveAsset to Asset
  Asset audioReactiveToAsset(AudioReactiveAsset reactive) {
    return reactive.toAsset();
  }

  /// FFT verilerini arka planda hesapla ve cache'le (VisualizerService pattern)
  Future<void> processAudioForFFT(String audioPath) async {
    try {
      final canon = audioAnalysis.canonicalizeAudioPath(audioPath);
      if (canon.isEmpty) {
        _logOnce('[AudioReactive] FFT skip: empty audioPath');
        return;
      }
      if (_fftCache.containsKey(canon)) {
        _logOnce('[AudioReactive] FFT cache hit: $canon', key: 'hit:$canon');
        return;
      }
      if (_processing.contains(canon)) {
        _logOnce('[AudioReactive] FFT already processing: $canon', key: 'proc:$canon');
        return;
      }
      _processing.add(canon);
      logger.i('[AudioReactive] Processing audio for FFT: $canon');

      // 1. PCM verilerini çıkar (ortak analiz servisi)
      final pcmData = await audioAnalysis.extractPCMData(
        canon,
        lowDeviceSafe: true,
      );
      if (pcmData.isEmpty) {
        _logOnce('[AudioReactive] PCM empty/too-large, skip FFT: $canon', key: 'pcmempty:$canon');
        return;
      }

      int pickHopSizeOverride(Float32List pcm) {
        final int baseHop = AudioAnalysisService.hopSize;
        if (pcm.length <= AudioAnalysisService.fftSize) return baseHop;
        final int expectedFrames =
            ((pcm.length - AudioAnalysisService.fftSize) / baseHop).floor();
        if (expectedFrames <= _maxPreviewFftFrames) return baseHop;
        final int step = (expectedFrames / _maxPreviewFftFrames)
            .ceil()
            .clamp(1, 1000000);
        return baseHop * step;
      }

      final hopOverride = pickHopSizeOverride(pcmData);

      // 2. FFT hesapla (AudioReactive için compact format - OOM önler)
      final fftData = await audioAnalysis.computeAudioReactiveCompactFFT(
        pcmData,
        hopSizeOverride: hopOverride,
      );

      // 3. Cache'e kaydet
      _addToCache(canon, fftData);
      _hopByAudio[canon] = hopOverride;

      logger.i(
        '[AudioReactive] FFT processing completed. Frames: ${fftData.length}',
      );
      _fftReady.add(_fftReady.value + 1);
    } catch (e, stackTrace) {
      logger.e(
        '[AudioReactive] Error processing audio: $e',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      final canon = audioAnalysis.canonicalizeAudioPath(audioPath);
      _processing.remove(canon);
    }
  }

  /// Belirli bir zaman için FFT verilerini getir ve frequency range'e göre filtrele
  double? getAudioLevelAtTime(
    String audioPath,
    int milliseconds,
    String frequencyRange,
  ) {
    final canon = audioAnalysis.canonicalizeAudioPath(audioPath);
    if (!_fftCache.containsKey(canon)) {
      _logOnce(
        '[AudioReactive] FFT cache miss for $canon at $milliseconds ms',
        key: 'miss:$canon',
      );
      return null;
    }

    final fftData = _fftCache[canon]!;
    if (fftData.isEmpty) {
      _logOnce(
        '[AudioReactive] FFT empty for $canon at $milliseconds ms',
        key: 'empty:$canon',
      );
      return null;
    }

    // Ortak analiz servisi ile seviye hesapla
    return audioAnalysis.getAudioLevelAtTime(
      fftData: fftData,
      milliseconds: milliseconds,
      frequencyRange: frequencyRange,
      hopSizeOverride: _getHopForAudio(canon),
    );
  }

  void _logOnce(String message, {String? key, int intervalMs = 1500}) {
    final k = key ?? message;
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _lastLogMs[k];
    if (last != null && (now - last) < intervalMs) return;
    _lastLogMs[k] = now;
    try {
      logger.i(message);
    } catch (_) {}
  }

  /// Cache'de FFT var mı?
  bool hasCachedFFT(String audioPath) {
    final canon = audioAnalysis.canonicalizeAudioPath(audioPath);
    return _fftCache.containsKey(canon);
  }

  /// Tüm cached FFT verilerini temizle (ayarlar ekranından çağrılabilir)
  void clearCache() {
    _fftCache.clear();
    _cacheOrder.clear();
    _processing.clear();
    _hopByAudio.clear();
    _fftReady.add(_fftReady.value + 1);
  }

  /// Dispose
  void dispose() {
    _editingAudioReactive$.close();
    _availableOverlays$.close();
    _availableAudioSources$.close();
    _fftReady.close();
    _fftCache.clear();
    _cacheOrder.clear();
    _processing.clear();
    _hopByAudio.clear();
  }
}
