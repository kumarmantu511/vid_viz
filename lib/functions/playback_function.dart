part of 'package:vidviz/service/director_service.dart';

extension PlaybackFunction on DirectorService {

  bool get canPlayNow {
    final bool hasRaster = hasRasterAssets();
    final bool hasAudioAtPos = mainAudioLayerForPosition(position) != -1;
    return hasRaster || hasAudioAtPos;
  }

  bool get canExportNow => duration > 0;

  int _resolveMainLayerForPlayback(int pos) {
    if (layers == null || layers!.isEmpty) return -1;

    final int mainRaster = getMainRasterLayerIndex();
    if (mainRaster >= 0 && mainRaster < layers!.length) {
      final Layer l = layers![mainRaster];
      bool hasRasterAtPos = false;
      for (final a in l.assets) {
        if (!a.deleted && a.begin <= pos && pos < a.begin + a.duration) {
          hasRasterAtPos = true;
          break;
        }
      }
      if (hasRasterAtPos) return mainRaster;
    }

    final int audioMain = mainAudioLayerForPosition(pos);
    return audioMain;
  }

  play() async {
    if (filesNotExist) {
      _filesNotExist.add(true);
      return;
    }

    if (isOperating) return;
    if (position >= duration) return;
    logger.i('DirectorService.play()');

    scrollController.removeListener(_listenerScrollController);
    _appBar.add(true);
    _selected.add(Selected(-1, -1));

    final int mainLayer = _resolveMainLayerForPlayback(position);
    if (mainLayer == -1) {
      print('⚠️ No raster and no audio at position $position, cannot start playback');
      isPlaying = false;
      _appBar.add(true);
      try {
        scrollController.addListener(_listenerScrollController);
      } catch (_) {}
      return;
    }
    mainLayerIndexForConcurrency = mainLayer;
    print('mainLayer: $mainLayer');
    if (layers != null &&
        mainLayer >= 0 &&
        mainLayer < layers!.length &&
        layers![mainLayer].type == 'audio') {
      print('🎧 Audio-driven playback: mainLayer set to audio index $mainLayer');
    }

    Future<void>? mainFuture;

    isPlaying = true;
    for (int i = 0; i < layers!.length; i++) {
      final String ltype = layers![i].type;
      final bool isMedia = (ltype == 'raster' || ltype == 'audio');

      if (!isMedia) continue;

      if (i == mainLayer) {
        mainFuture = layerPlayers[i]!.play(
          position,
          onMove: (int newPosition) {
            _position.add(newPosition);

            try {
              scrollController.animateTo(
                (300 + newPosition) / 1000 * pixelsPerSecond,
                duration: Duration(milliseconds: 100),
                curve: Curves.linear,
              );
            } catch (_) {
              scrollController.animateTo(
                (newPosition / 1000.0) * pixelsPerSecond,
                duration: Duration(milliseconds: 1),
                curve: Curves.linear,
              );
            }
            _syncAuxAudioLayers(newPosition);
          },
          onEnd: () {
            scheduleMicrotask(() async {
              await _stopAllPlayers();
              final int endPos = duration > 0 ? duration - 1 : 0;
              await previewAt(endPos);
            });
          },
        );
      } else {
        if (layers![i].type == 'raster') {
          scheduleMicrotask(() {
            layerPlayers[i]!.play(position);
          });
        }
      }
    }
    _syncAuxAudioLayers(position);
    _position.add(position);
    if (mainFuture != null) await mainFuture;
  }

  stop() async {
    if ((isOperating && !isPlaying) || !isPlaying) return;
    print('>> DirectorService.stop()');
    await _stopAllPlayers();
  }

  /// Public preview helper for external callers (e.g., pipeline exporter)
  /// Moves the main video layer to the specified timeline position and updates UI streams.
  Future<void> previewAt(int positionMs) async {
    if (filesNotExist) return;
    if (layers == null || layers!.isEmpty || layerPlayers.isEmpty) return;
    final mainIdx = getMainRasterLayerIndex();
    isPreviewing = true;
    scrollController.removeListener(_listenerScrollController);
    try {
      if (mainIdx >= 0 &&
          mainIdx < layerPlayers.length &&
          layerPlayers[mainIdx] != null) {
        await layerPlayers[mainIdx]!.preview(positionMs);
      }
      _position.add(positionMs);
    } finally {
      try {
        scrollController.addListener(_listenerScrollController);
      } catch (_) {}
      isPreviewing = false;
    }
  }

  /// Force-stop all media-bearing players regardless of current flags
  Future<void> _stopAllPlayers() async {
    if (layers == null) return;
    print('>> DirectorService._stopAllPlayers()');
    final futures = <Future<void>>[];
    for (int i = 0; i < layers!.length; i++) {
      final String ltype = layers![i].type;
      if (ltype != 'raster' && ltype != 'audio') continue;
      if (i >= layerPlayers.length) continue;
      final p = layerPlayers[i];
      if (p == null) continue;
      futures.add(
        p.stop().catchError((_) {}),
      );
    }
    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
    isPlaying = false;
    try {
      scrollController.addListener(_listenerScrollController);
    } catch (_) {}
    _appBar.add(true);
  }

  void _syncAuxAudioLayers(int position) {
    if (layers == null || layerPlayers.isEmpty) return;
    for (int i = 0; i < layers!.length; i++) {
      if (i == mainLayerIndexForConcurrency) continue;
      final layer = layers![i];
      if (layer.type != 'audio') continue;
      if (i >= layerPlayers.length) continue;
      final player = layerPlayers[i];
      if (player == null) continue;

      int activeIndex = -1;
      for (int ai = 0; ai < layer.assets.length; ai++) {
        final a = layer.assets[ai];
        if (a.deleted) continue;
        if (a.type != AssetType.audio) continue;
        final int start = a.begin;
        final int end = a.begin + a.duration;
        if (position >= start && position < end) {
          activeIndex = ai;
          break;
        }
      }

      if (activeIndex == -1) {
        if (player.isPlaying) {
          player.stop();
        }
      } else {
        if (!player.isPlaying || player.currentAssetIndex != activeIndex) {
          player.play(position);
        }
      }
    }
  }

  int mainLayerForConcurrency() {
    int mainLayer = 0, mainLayerDuration = 0;
    for (int i = 0; i < layers!.length; i++) {
      // Main layer must be raster (video/image)
      if (layers![i].type != 'raster') continue;
      if (layers![i].assets.isNotEmpty &&
          layers![i].assets.last.begin + layers![i].assets.last.duration >
              mainLayerDuration) {
        mainLayer = i;
        mainLayerDuration =
            layers![i].assets.last.begin + layers![i].assets.last.duration;
      }
    }
    return mainLayer;
  }

  /// Pick the audio layer that has an active asset at position and ends the latest
  int mainAudioLayerForPosition(int pos) {
    if (layers == null) return -1;
    int idx = -1;
    int bestEnd = -1;
    for (int i = 0; i < layers!.length; i++) {
      final l = layers![i];
      if (l.type != 'audio') continue;
      for (final a in l.assets) {
        if (!a.deleted &&
            a.type == AssetType.audio &&
            a.begin <= pos &&
            pos < a.begin + a.duration) {
          final int end = a.begin + a.duration;
          if (end > bestEnd) {
            bestEnd = end;
            idx = i;
          }
        }
      }
    }
    return idx;
  }


  /// Regenerate unique capture keys to avoid GlobalKey duplication
  /// when multiple DirectorScreen routes are mounted during navigation transitions.
  void regenerateCaptureKeys() {
    shaderCaptureKey = GlobalKey(
      debugLabel: 'shaderCapture_${DateTime.now().microsecondsSinceEpoch}',
    );
    exportCaptureKey = GlobalKey(
      debugLabel: 'exportCapture_${DateTime.now().microsecondsSinceEpoch}',
    );
  }


}