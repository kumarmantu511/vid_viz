import 'dart:async';
import 'dart:math' as math;
import 'package:rxdart/rxdart.dart';
import 'package:logger/logger.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/model/layer.dart';
import 'package:vidviz/model/visualizer.dart';
import 'package:vidviz/service/audio_analysis_service.dart';

/// VisualizerService - Text özelliğinin tam kopyası olarak çalışır
/// DirectorService'teki editingTextAsset pattern'ini takip eder
class VisualizerService {
  final logger = locator.get<Logger>();
  final audioAnalysis = locator.get<AudioAnalysisService>();

  // Text'teki editingTextAsset benzeri (VisualizerAsset ile)
  BehaviorSubject<VisualizerAsset?> _editingVisualizerAsset = BehaviorSubject.seeded(null);
  Stream<VisualizerAsset?> get editingVisualizerAsset$ => _editingVisualizerAsset.stream;
  VisualizerAsset? get editingVisualizerAsset => _editingVisualizerAsset.value;
  set editingVisualizerAsset(VisualizerAsset? value) {
    _editingVisualizerAsset.add(value);
  }

  int? editingLayerIndex;
  int? editingAssetIndex;

  // FFT cache for performance with LRU eviction (max 5 audio files)
  static const int _maxCacheSize = 5;
  static const int _maxPreviewFftFrames = 20000;
  final Map<String, List<List<double>>> _fftCache = {};
  final Map<String, int> _hopByKey = {};
  final List<String> _cacheOrder = []; // LRU order tracking
  // Processing guard to avoid duplicate work
  final Set<String> _processing = {};

  // Visualizer assets cache (audio path -> VisualizerAsset)
  final Map<String, VisualizerAsset> _visualizerCache = {};

  // Notifier stream: bump value when any FFT finishes so UI can rebuild
  final BehaviorSubject<int> _fftReady = BehaviorSubject.seeded(0);
  Stream<int> get fftReady$ => _fftReady.stream;

  // FFT settings (static defaults, overridden by VisualizerAsset)
  static const int fftSize = 2048;
  static const int hopSize = 512;
  static const int sampleRate = 44100;

  String _fftKeyFor(
    String audioPath, {
    int bands = 64,
    double alpha = 0.6,
    double minHz = 50.0,
    double maxHz = 16000.0,
  }) {
    bands = bands.clamp(8, 256);
    alpha = (alpha.isFinite ? alpha : 0.6).clamp(0.0, 1.0);
    minHz = (minHz.isFinite ? minHz : 50.0).clamp(1.0, 22050.0);
    maxHz = (maxHz.isFinite ? maxHz : 16000.0).clamp(1.0, 22050.0);
    if (maxHz < minHz) {
      final tmp = maxHz;
      maxHz = minHz;
      minHz = tmp;
    }
    if ((maxHz - minHz) < 1.0) {
      maxHz = (minHz + 1.0).clamp(1.0, 22050.0);
    }
    return '$audioPath|b=$bands|a=${alpha.toStringAsFixed(3)}|min=${minHz.toStringAsFixed(1)}|max=${maxHz.toStringAsFixed(1)}';
  }

  String _fftKeyFromAsset(String audioPath, VisualizerAsset? asset) {
    return _fftKeyFor(
      audioPath,
      bands: asset?.fftBands ?? 64,
      alpha: asset?.smoothingAlpha ?? 0.6,
      minHz: asset?.minFrequency ?? 50.0,
      maxHz: asset?.maxFrequency ?? 16000.0,
    );
  }

  dispose() {
    _editingVisualizerAsset.close();
    _fftCache.clear();
    _hopByKey.clear();
    _cacheOrder.clear();
    _processing.clear();
    _visualizerCache.clear();
    _fftReady.close();
  }

  /// LRU cache'e FFT verisi ekle - max 5 audio dosyası tutulur
  void _addToCache(String cacheKey, List<List<double>> fftData) {
    // Zaten varsa, LRU sırasını güncelle
    if (_fftCache.containsKey(cacheKey)) {
      _cacheOrder.remove(cacheKey);
      _cacheOrder.add(cacheKey);
      return;
    }
    
    // Cache dolu ise en eski girişi sil (LRU eviction)
    while (_fftCache.length >= _maxCacheSize && _cacheOrder.isNotEmpty) {
      final oldest = _cacheOrder.removeAt(0);
      _fftCache.remove(oldest);
      _hopByKey.remove(oldest);
      _visualizerCache.remove(oldest);
      logger.i('🗑️ FFT cache evicted: $oldest (LRU)');
    }
    
    // Yeni girişi ekle
    _fftCache[cacheKey] = fftData;
    _cacheOrder.add(cacheKey);
    logger.i('📦 FFT cache size: ${_fftCache.length}/$_maxCacheSize');
  }

  int? _getHopForKey(String cacheKey) {
    if (!_hopByKey.containsKey(cacheKey)) return null;
    _cacheOrder.remove(cacheKey);
    _cacheOrder.add(cacheKey);
    return _hopByKey[cacheKey];
  }

  /// Cache'den FFT verisi al ve LRU sırasını güncelle
  List<List<double>>? _getFromCache(String cacheKey) {
    if (!_fftCache.containsKey(cacheKey)) return null;
    // LRU: erişilen öğeyi sona taşı
    _cacheOrder.remove(cacheKey);
    _cacheOrder.add(cacheKey);
    return _fftCache[cacheKey];
  }

  /// Text'teki add(AssetType.text) benzeri - Visualizer eklemeye başla
  /// Ses kaynağı olarak mevcut layer'lardan seçim yapılır
  Future<void> startAddingVisualizer(List<Asset> availableAudioSources) async {
    logger.i('VisualizerService.startAddingVisualizer()');

    editingLayerIndex = null;
    editingAssetIndex = null;

    // Eğer mevcut layer'larda ses kaynağı yoksa, boş visualizer oluştur
    if (availableAudioSources.isEmpty) {
      logger.w('No audio sources available in timeline');
      // Boş visualizer oluştur (kullanıcı daha sonra ses ekleyebilir)
      editingVisualizerAsset = VisualizerAsset(
        type: VisualizerType.bars,
        begin: 0,
        duration: 5000,
        title: 'Visualizer (No Audio)',
        srcPath: '',
        color: 0xFFFFFFFF,
        scale: 1.0,
        renderMode: 'shader',
        shaderType: 'bar',
        sensitivity: 1.0,
        barCount: 32,
      );
      return;
    }

    // İlk ses kaynağını varsayılan olarak kullan
    Asset firstAudioSource = availableAudioSources.first;
    String audioPath = firstAudioSource.srcPath;

    logger.i('Using audio source: $audioPath');

    // Yeni visualizer asset oluştur
    editingVisualizerAsset = VisualizerAsset(
      type: VisualizerType.bars,
      begin: 0,
      duration: firstAudioSource.duration,
      title: 'Visualizer',
      srcPath: audioPath,
      color: 0xFFFFFFFF,
      scale: 1.0,
      renderMode: 'shader',
      shaderType: 'bar',
      sensitivity: 1.0,
      barCount: 32,
    );

    // Arka planda FFT hesapla (asset parametreleriyle)
    _processAudioInBackground(audioPath, asset: editingVisualizerAsset);
  }

  /// Ses kaynağını değiştir
  void changeAudioSource(String audioPath, int duration) {
    if (editingVisualizerAsset == null) return;

    VisualizerAsset newAsset = VisualizerAsset.clone(editingVisualizerAsset!);
    newAsset.srcPath = audioPath;
    newAsset.duration = duration;
    editingVisualizerAsset = newAsset;

    // Yeni ses için FFT hesapla (asset parametreleriyle)
    _processAudioInBackground(audioPath, asset: newAsset);

    logger.i('Audio source changed to: $audioPath');
  }

  /// FFT verilerini arka planda hesapla ve cache'le
  Future<void> _processAudioInBackground(
    String audioPath, {
    VisualizerAsset? asset,
  }) async {
    try {
      if (audioPath.isEmpty) return;
      final cacheKey = _fftKeyFromAsset(audioPath, asset);
      if (_fftCache.containsKey(cacheKey)) return;
      if (_processing.contains(cacheKey)) return;
      _processing.add(cacheKey);
      logger.i('Processing audio for FFT: $cacheKey');

      // 1. PCM verilerini çıkar
      final pcmData = await audioAnalysis.extractPCMData(
        audioPath,
        lowDeviceSafe: true,
      );
      if (pcmData.isEmpty) {
        return;
      }

      // 2. FFT hesapla (asset parametreleriyle)
      final int bands = asset?.fftBands ?? 64;
      final double alpha = asset?.smoothingAlpha ?? 0.6;
      final double minHz = asset?.minFrequency ?? 50.0;
      final double maxHz = asset?.maxFrequency ?? 16000.0;

      int pickHopSizeOverride(int samples) {
        final int baseHop = AudioAnalysisService.hopSize;
        if (samples <= AudioAnalysisService.fftSize) return baseHop;
        final int expectedFrames =
            ((samples - AudioAnalysisService.fftSize) / baseHop).floor();
        if (expectedFrames <= _maxPreviewFftFrames) return baseHop;
        final int step = (expectedFrames / _maxPreviewFftFrames)
            .ceil()
            .clamp(1, 1000000);
        return baseHop * step;
      }

      final hopOverride = pickHopSizeOverride(pcmData.length);
      final fftData = await audioAnalysis.computeVisualizerFFT(
        pcmData: pcmData,
        bands: bands,
        alpha: alpha,
        minHz: minHz,
        maxHz: maxHz,
        hopSizeOverride: hopOverride,
      );

      // 3. Cache'e kaydet (LRU eviction)
      _addToCache(cacheKey, fftData);
      _hopByKey[cacheKey] = hopOverride;

      // 4. Visualizer asset oluştur ve cache'le
      VisualizerAsset visualizerAsset = VisualizerAsset(
        type: VisualizerType.bars,
        srcPath: audioPath,
        title: 'Visualizer',
        duration: 5000,
        begin: 0,
        cachedFFTData: fftData,
      );
      _visualizerCache[cacheKey] = visualizerAsset;

      logger.i('FFT processing completed. Frames: ${fftData.length}');
      // Notify listeners
      _fftReady.add(_fftReady.value + 1);
    } catch (e, stackTrace) {
      logger.e('Error processing audio: $e', error: e, stackTrace: stackTrace);
    } finally {
      final cacheKey = _fftKeyFromAsset(audioPath, asset);
      _processing.remove(cacheKey);
    }
  }

  /// If FFT is not cached, start processing in background (idempotent)
  void prefetchFFT(String audioPath, {VisualizerAsset? asset}) {
    if (audioPath.isEmpty) return;
    final cacheKey = _fftKeyFromAsset(audioPath, asset);
    if (_fftCache.containsKey(cacheKey)) return;
    if (_processing.contains(cacheKey)) return;
    _processAudioInBackground(audioPath, asset: asset);
  }

  /// FFT ayarları değiştiğinde cache'i temizle ve yeniden hesapla
  void recomputeFFT() {
    if (editingVisualizerAsset == null ||
        editingVisualizerAsset!.srcPath.isEmpty)
      return;
    final audioPath = editingVisualizerAsset!.srcPath;
    final cacheKey = _fftKeyFromAsset(audioPath, editingVisualizerAsset);
    // Cache'den sil
    _fftCache.remove(cacheKey);
    _processing.remove(cacheKey);
    _visualizerCache.remove(cacheKey);
    // Yeniden hesapla
    _processAudioInBackground(audioPath, asset: editingVisualizerAsset);
    logger.i('FFT recomputed with new parameters');
  }

  /// Belirli bir zaman için FFT verilerini getir
  List<double>? getFFTDataAtTime(
    String audioPath,
    int milliseconds, {
    VisualizerAsset? asset,
  }) {
    final cacheKey = _fftKeyFromAsset(audioPath, asset);
    final fftData = _getFromCache(cacheKey);
    if (fftData == null) {
      return null;
    }
    if (fftData.isEmpty) return null;

    // Zaman -> frame index
    final double seconds = milliseconds / 1000.0;
    final int effectiveHop = _getHopForKey(cacheKey) ?? hopSize;
    final int frameIndex = ((seconds * sampleRate) / effectiveHop).floor();

    if (frameIndex < 0 || frameIndex >= fftData.length) {
      return null;
    }

    return fftData[frameIndex];
  }

  List<List<double>>? getCachedFFTFrames({
    required String audioPath,
    required int bands,
    required double alpha,
    required double minHz,
    required double maxHz,
  }) {
    final key = _fftKeyFor(
      audioPath,
      bands: bands,
      alpha: alpha,
      minHz: minHz,
      maxHz: maxHz,
    );
    return _getFromCache(key);
  }

  int? getCachedHopSize({
    required String audioPath,
    required int bands,
    required double alpha,
    required double minHz,
    required double maxHz,
  }) {
    final key = _fftKeyFor(
      audioPath,
      bands: bands,
      alpha: alpha,
      minHz: minHz,
      maxHz: maxHz,
    );
    return _getHopForKey(key);
  }

  /// Tek bir FFT frame'i üzerinde smoothness ve reactivity uygulayan yardımcı fonksiyon
  /// - smoothness: bantlar arası karışımı kontrol eder (0.0 = ham, 1.0 = komşularla güçlü karışım)
  /// - reactivity: eğriyi ayarlar (1.0 = lineer, >1.0 = küçük değerleri büyütür, <1.0 = yumuşatır)
  List<double> applyDynamics(List<double> frame, VisualizerAsset? asset) {
    if (asset == null || frame.isEmpty) return frame;

    final int n = frame.length;
    if (n == 0) return frame;

    // Mevcut projelerde default smoothness=0.6 idi ve kullanılmıyordu.
    // Geriye dönük uyumluluk için bu değeri "off" kabul ediyoruz.
    double smooth = asset.smoothness;
    if ((smooth - 0.6).abs() < 0.001) smooth = 0.0;
    if (smooth < 0.0) smooth = 0.0;
    if (smooth > 1.0) smooth = 1.0;

    double reactivity = asset.reactivity;
    if (reactivity < 0.5) reactivity = 0.5;
    if (reactivity > 2.0) reactivity = 2.0;

    if (smooth == 0.0 && (reactivity - 1.0).abs() < 0.001) {
      // Varsayılan davranış: ek işleme yok
      return frame;
    }

    // 1) Bantlar arası komşu karışımı (spatial smoothing)
    final List<double> smoothed = List<double>.filled(n, 0.0);
    if (smooth > 0.0) {
      for (int i = 0; i < n; i++) {
        final double self = frame[i].clamp(0.0, 1.0);
        final double prev = (i > 0 ? frame[i - 1] : self).clamp(0.0, 1.0);
        final double next = (i < n - 1 ? frame[i + 1] : self).clamp(0.0, 1.0);
        final double avg = (prev + self + next) / 3.0;
        smoothed[i] = self * (1.0 - smooth) + avg * smooth;
      }
    } else {
      for (int i = 0; i < n; i++) {
        smoothed[i] = frame[i].clamp(0.0, 1.0);
      }
    }

    // 2) Reactivity eğrisi: 1/reactivity üssü ile eğriyi şekillendir
    if ((reactivity - 1.0).abs() < 0.001) {
      return smoothed;
    }

    final List<double> out = List<double>.filled(n, 0.0);
    final double exp = 1.0 / reactivity;
    for (int i = 0; i < n; i++) {
      final double v = smoothed[i].clamp(0.0, 1.0);
      out[i] = math.pow(v, exp).toDouble();
    }
    return out;
  }

  /// Visualizer pozisyonunu değiştir (Text'teki gibi)
  void changeVisualizerPosition(double x, double y) {
    if (editingVisualizerAsset == null) return;

    // Clone yerine direkt değiştir (performans için, Text'teki gibi)
    editingVisualizerAsset!.x = x;
    editingVisualizerAsset!.y = y;
    editingVisualizerAsset = editingVisualizerAsset; // Stream'i tetikle
  }

  /// Visualizer asset'i cache'den al
  VisualizerAsset? getVisualizerAsset(String audioPath, {VisualizerAsset? asset}) {
    final key = _fftKeyFromAsset(audioPath, asset);
    return _visualizerCache[key];
  }

  /// Cache'i temizle
  void clearCache() {
    _fftCache.clear();
    _visualizerCache.clear();
    _hopByKey.clear();
    logger.i('FFT cache cleared');
    _fftReady.add(_fftReady.value + 1);
  }

  /// Belirli bir audio path için cache var mı?
  bool hasCachedFFT(String audioPath, {VisualizerAsset? asset}) {
    final cacheKey = _fftKeyFromAsset(audioPath, asset);
    return _fftCache.containsKey(cacheKey);
  }
}
