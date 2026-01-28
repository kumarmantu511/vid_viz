part of 'package:vidviz/service/director_service.dart';

extension SetFunction on DirectorService {


  /// Set playback speed for the currently selected video asset (0.25x .. 4.0x)
  /// If [ripple] is true (default), re-chains following assets in the same layer
  /// so that the new end of this asset becomes the start of the next one.
  /// This removes gaps when duration shortens and prevents overlaps when it extends.
  void setPlaybackSpeedForSelected(double speed, {bool ripple = true}) {
    if (layers == null) return;
    final li = selected.layerIndex;
    final ai = selected.assetIndex;
    if (li < 0 || ai < 0) return;
    if (li >= layers!.length) return;
    final layer = layers![li];
    if (ai >= layer.assets.length) return;
    final asset = layer.assets[ai];
    if (asset.type != AssetType.video) return;
    final s = speed.clamp(0.25, 4.0);
    final double newSpeed = s.toDouble();
    final double oldSpeed = (asset.playbackSpeed > 0)
        ? asset.playbackSpeed
        : 1.0;
    // Keep source consumption constant: srcDurMs = durationMs * speed
    final int baseSrcDurMs = (asset.duration * oldSpeed).round();
    final int newDurationMs = (baseSrcDurMs / newSpeed).round().clamp(
      1000,
      2 * 60 * 60 * 1000,
    ); // 1s..2h (UI sizer min)
    asset.playbackSpeed = newSpeed;
    asset.duration = newDurationMs;

    // Ripple: re-chain subsequent assets in this layer to keep timeline contiguous
    if (ripple && ai + 1 < layer.assets.length) {
      refreshCalculatedFieldsInAssets(li, ai + 1);
    }
    _saveToHistory();
    _layersChanged.add(true);
    _appBar.add(true);
  }

  // ---- Audio controls (minimal, live-apply) ----
  Future<void> setLayerMute(int layerIndex, bool mute) async {
    if (layers == null) return;
    if (layerIndex < 0 || layerIndex >= layers!.length) return;
    final layer = layers![layerIndex];
    layer.mute = mute;
    try {
      // Effective volume for playback
      double vol = mute ? 0.0 : layer.volume;
      if (layer.type == 'raster' && layer.useVideoAudio == false) {
        vol = 0.0;
      }
      if (layerPlayers.length > layerIndex &&
          layerPlayers[layerIndex] != null) {
        await layerPlayers[layerIndex]!.setVolume(vol);
      }
    } catch (_) {}
    _layersChanged.add(true);
    _appBar.add(true);
  }

  Future<void> setLayerVolume(int layerIndex, double volume) async {
    if (layers == null) return;
    if (layerIndex < 0 || layerIndex >= layers!.length) return;
    final layer = layers![layerIndex];
    final double v = volume.clamp(0.0, 1.0);
    layer.volume = v;
    try {
      double vol = layer.mute ? 0.0 : v;
      if (layer.type == 'raster' && layer.useVideoAudio == false) {
        vol = 0.0;
      }
      if (layerPlayers.length > layerIndex &&
          layerPlayers[layerIndex] != null) {
        await layerPlayers[layerIndex]!.setVolume(vol);
      }
    } catch (_) {}
    _layersChanged.add(true);
    _appBar.add(true);
  }

  Future<void> setRasterUseVideoAudio(int layerIndex, bool use) async {
    if (layers == null) return;
    if (layerIndex < 0 || layerIndex >= layers!.length) return;
    final layer = layers![layerIndex];
    if (layer.type != 'raster') return;
    layer.useVideoAudio = use;
    try {
      double vol = (layer.mute || !use) ? 0.0 : layer.volume;
      if (layerPlayers.length > layerIndex &&
          layerPlayers[layerIndex] != null) {
        await layerPlayers[layerIndex]!.setVolume(vol);
      }
    } catch (_) {}
    _layersChanged.add(true);
    _appBar.add(true);
  }

  void setAudioOnlyPlay(bool value) {
    _audioOnlyPlay.add(value);
    _appBar.add(true);
  }

  Future<void> setSelectedAssetVolume(double volume) async {
    if (layers == null) return;
    final int li = selected.layerIndex;
    final int ai = selected.assetIndex;
    if (li < 0 || ai < 0) return;
    if (li >= layers!.length) return;
    final layer = layers![li];
    if (ai >= layer.assets.length) return;
    final asset = layer.assets[ai];
    if (asset.type != AssetType.video && asset.type != AssetType.audio) return;

    final double v = volume.clamp(0.0, 1.0);
    final Map<String, dynamic> data = asset.data == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(asset.data!);
    data['volume'] = v;
    asset.data = data;

    _saveToHistory();
    _layersChanged.add(true);
    _appBar.add(true);

    if (layerPlayers.length > li && layerPlayers[li] != null) {
      double base;
      if (layer.mute == true) {
        base = 0.0;
      } else if (layer.type == 'raster' && (layer.useVideoAudio == false)) {
        base = 0.0;
      } else {
        base = layer.volume.clamp(0.0, 1.0);
      }
      final double eff = (base * v).clamp(0.0, 1.0);
      try {
        await layerPlayers[li]!.setVolume(eff);
      } catch (_) {}
    }
  }

  Future<void> setSelectedAssetFade({int? fadeInMs, int? fadeOutMs}) async {
    if (layers == null) return;
    final int li = selected.layerIndex;
    final int ai = selected.assetIndex;
    if (li < 0 || ai < 0) return;
    if (li >= layers!.length) return;
    final layer = layers![li];
    if (ai >= layer.assets.length) return;
    final asset = layer.assets[ai];
    if (asset.type != AssetType.video && asset.type != AssetType.audio) return;

    if (fadeInMs == null && fadeOutMs == null) return;

    final Map<String, dynamic> data = asset.data == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(asset.data!);

    final int dur = asset.duration;
    if (fadeInMs != null) {
      final int v = fadeInMs.clamp(0, dur);
      data['fadeInMs'] = v;
    }
    if (fadeOutMs != null) {
      final int v = fadeOutMs.clamp(0, dur);
      data['fadeOutMs'] = v;
    }
    asset.data = data;

    _saveToHistory();
    _layersChanged.add(true);
    _appBar.add(true);
  }

}