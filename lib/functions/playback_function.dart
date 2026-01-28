part of 'package:vidviz/service/director_service.dart';

extension PlaybackFunction on DirectorService {

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

    int mainLayer = getMainRasterLayerIndex();
    mainLayerIndexForConcurrency = mainLayer;
    print('mainLayer: $mainLayer');

    final bool allowAudioFallback = audioOnlyPlay || !hasRasterAssets();

    Future<void>? mainFuture;
    // Guard: if main raster has no media at current position, optionally fall back to audio-only
    if (layers != null && mainLayer >= 0 && mainLayer < layers!.length) {
      final Layer mainL = layers![mainLayer];

      bool hasRasterAtPos = false;
      for (final a in mainL.assets) {
        if (!a.deleted &&
            a.begin <= position &&
            position < a.begin + a.duration) {
          hasRasterAtPos = true;
          break;
        }
      }
      if (!hasRasterAtPos) {
        if (allowAudioFallback) {
          final int audioMain = mainAudioLayerForPosition(position);
          if (audioMain != -1) {
            mainLayer = audioMain; // drive playback by an audio layer
            mainLayerIndexForConcurrency = mainLayer;
            print(
              '🎧 Audio-only playback: mainLayer set to audio index $audioMain',
            );

          } else {
            print('⚠️ No audio at position $position, cannot start playback');
            isPlaying = false;
            _appBar.add(true);
            try {
              scrollController.addListener(_listenerScrollController);
            } catch (_) {}
            return;
          }
        } else {
          print(
            '⚠️ Prevented audio-only playback: no raster at position $position',
          );
          isPlaying = false;
          _appBar.add(true);
          try {
            scrollController.addListener(_listenerScrollController);
          } catch (_) {}
          return;
        }
      }
    }

    if (mainLayer == -1) {
      if (allowAudioFallback) {
        final int audioMain = mainAudioLayerForPosition(position);
        if (audioMain == -1) {
          print('⚠️ No raster and no audio at position $position, cannot start playback');
          isPlaying = false;
          _appBar.add(true);

          try {
            scrollController.addListener(_listenerScrollController);
          } catch (_) {}
          return;
        }
        mainLayer = audioMain;
        mainLayerIndexForConcurrency = mainLayer;
        print('🎧 Audio-only playback: mainLayer set to audio index $audioMain');
      } else {
        print('⚠️ No raster main layer available, cannot start playback');
        isPlaying = false;
        _appBar.add(true);
        try {
          scrollController.addListener(_listenerScrollController);
        } catch (_) {}
        return;
      }
    }

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

            final double maxOffset =
                (scrollController.hasClients)
                    ? scrollController.position.maxScrollExtent
                    : double.infinity;
            final double primaryTarget =
                ((300 + newPosition) / 1000 * pixelsPerSecond)
                    .clamp(0.0, maxOffset);

            try {
              scrollController.animateTo(
                primaryTarget,
                duration: Duration(milliseconds: 100),
                curve: Curves.linear,
              );
            } catch (_) {
              scrollController.animateTo(
                primaryTarget,
                duration: Duration(milliseconds: 1),
                curve: Curves.linear,
              );
            }
            _syncAuxAudioLayers(newPosition);
          },
          onEnd: () {
            scheduleMicrotask(() async {
              final int endPos = duration > 0 ? duration - 1 : 0;
              await previewAt(endPos);
              try {
                await Future.delayed(const Duration(milliseconds: 16));
              } catch (_) {}
              await _stopAllPlayers();
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
    if (mainIdx < 0 ||
        mainIdx >= layerPlayers.length ||
        layerPlayers[mainIdx] == null)
      return;
    isPreviewing = true;
    scrollController.removeListener(_listenerScrollController);
    await layerPlayers[mainIdx]!.preview(positionMs);
    _position.add(positionMs);
    scrollController.addListener(_listenerScrollController);
    isPreviewing = false;
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