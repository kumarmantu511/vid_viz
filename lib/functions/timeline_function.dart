part of 'package:vidviz/service/director_service.dart';

extension TimelineFunction on DirectorService {

  endScroll() async {
    _position.sink.add(
      ((scrollController.offset / pixelsPerSecond) * 1000).floor(),
    );
    // Delayed 200 because position may not be updated at this time
    Future.delayed(Duration(milliseconds: 200), () {
      _previewOnPosition();
    });
  }

  _previewOnPosition() async {
    if (filesNotExist) return;
    if (isOperating) return;
    isPreviewing = true;
    scrollController.removeListener(_listenerScrollController);

    final mainIdx = getMainRasterLayerIndex();
    if (mainIdx >= 0 &&
        mainIdx < layerPlayers.length &&
        layerPlayers[mainIdx] != null) {
      await layerPlayers[mainIdx]!.preview(position);
    }
    _position.add(position);

    scrollController.addListener(_listenerScrollController);
    isPreviewing = false;
  }

  _listenerScrollController() async {
    // When playing position is defined by the video player
    if (isPlaying) return;
    // In other case by the scroll manually
    _position.sink.add(
      ((scrollController.offset / pixelsPerSecond) * 1000).floor(),
    );
    // Debounce preview to ~60fps to avoid black frames while scrubbing
    _previewDebounce?.cancel();
    _previewDebounce = Timer(const Duration(milliseconds: 16), () {
      _previewOnPosition();
    });
  }

  exchange() async {
    if (layers == null) return;
    int layerIndex = selected.layerIndex;
    int assetIndex1 = selected.assetIndex;
    int assetIndex2 = selected.closestAsset;
    // Reset selected before
    _selected.add(Selected(-1, -1));

    if (layerIndex == -1 ||
        assetIndex1 == -1 ||
        assetIndex2 == -1 ||
        assetIndex1 == assetIndex2)
      return;

    Asset asset1 = layers![layerIndex].assets[assetIndex1];

    layers![layerIndex].assets.removeAt(assetIndex1);
    await layerPlayers[layerIndex]!.removeMediaSource(assetIndex1);

    layers![layerIndex].assets.insert(assetIndex2, asset1);
    await layerPlayers[layerIndex]!.addMediaSource(assetIndex2, asset1);

    refreshCalculatedFieldsInAssets(layerIndex, 0);
    _layersChanged.add(true);

    // Delayed 100 because it seems updating mediaSources is not immediate
    Future.delayed(Duration(milliseconds: 100), () async {
      await _previewOnPosition();
    });
  }

  // Legacy method name for backward compatibility
  moveTextAsset() {
    moveAssetByPosition();
  }

  // Universal move method for text, image, visualizer, shader
  moveAssetByPosition() {
    if (layers == null) return;
    int layerIndex = selected.layerIndex;
    int assetIndex = selected.assetIndex;
    if (layerIndex == -1 || assetIndex == -1) return;

    // Get asset reference BEFORE clearing selection
    final Asset asset = layers![layerIndex].assets[assetIndex];
    final AssetType assetType = asset.type;

    int pos =
        asset.begin +
            ((selected.dragX +
                scrollController.offset -
                selected.initScrollOffset) /
                pixelsPerSecond *
                1000)
                .floor();

    // Reset selected before
    _selected.add(Selected(-1, -1));

    layers![layerIndex].assets[assetIndex].begin = math.max(pos, 0);

    // Reorganize only for legacy single text layer (index 1, vector)
    if (assetType == AssetType.text &&
        layers![layerIndex].type == 'vector' &&
        layerIndex == 1) {
      reorganizeTextAssets(1);
    } else if (assetType == AssetType.image) {
      // Only base raster images should trigger chaining refresh
      final bool isBaseRasterImage =
          (layers![layerIndex].type == 'raster') &&
              (asset.data == null || asset.data?['overlayType'] == null);
      if (isBaseRasterImage) {
        // Image may need Ken Burns recalculation and chaining
        refreshCalculatedFieldsInAssets(layerIndex, assetIndex);
      }
    }
    // Visualizer and Shader don't need reorganization

    _layersChanged.add(true);
    _previewOnPosition();
  }

  // Legacy method name for backward compatibility
  cutVideo() async {
    await cutAsset();
  }

  // Universal cut/split method for all asset types
  cutAsset() async {
    if (isOperating || layers == null) return;
    if (selected.layerIndex == -1 || selected.assetIndex == -1) return;
    print('>> DirectorService.cutAsset()');
    final Asset assetAfter =
    layers![selected.layerIndex].assets[selected.assetIndex];
    final int diff = position - assetAfter.begin;
    if (diff <= 0 || diff >= assetAfter.duration) return;
    isCutting = true;

    final Asset assetBefore = Asset.clone(assetAfter);
    layers![selected.layerIndex].assets.insert(
      selected.assetIndex,
      assetBefore,
    );

    // Keep LayerPlayer indices in sync with asset list insertion
    if (layerPlayers.length > selected.layerIndex &&
        layerPlayers[selected.layerIndex] != null) {
      await layerPlayers[selected.layerIndex]!.onAssetInserted(
        selected.assetIndex,
      );
    }

    assetBefore.duration = diff;
    assetAfter.begin = assetBefore.begin + diff;
    assetAfter.cutFrom = assetBefore.cutFrom + diff;
    assetAfter.duration = assetAfter.duration - diff;

    /* ... ESKİ remove/addMediaSource bloğu burada comment edildi çünkü siyahlık oluşturuyrodu  ... */

    // Update media sources only for media-bearing layers (raster/audio) and non-overlay images
    /*final String ltype = layers![selected.layerIndex].type;

    final bool layerHasPlayer = (ltype == 'raster' || ltype == 'audio');
    final bool isOverlayImage =  (assetAfter.type == AssetType.image) &&(assetAfter.data?['overlayType'] != null);
    if (layerHasPlayer && !isOverlayImage && (assetAfter.type == AssetType.video ||     assetAfter.type == AssetType.audio ||     assetAfter.type == AssetType.image)) {
      if (layerPlayers[selected.layerIndex] != null) {
        await layerPlayers[selected.layerIndex]!.removeMediaSource(
          selected.assetIndex,
        );
        await layerPlayers[selected.layerIndex]!.addMediaSource(
          selected.assetIndex,
          assetBefore,
        );
        await layerPlayers[selected.layerIndex]!.addMediaSource(
          selected.assetIndex + 1,
          assetAfter,
        );
      }
    }
    */
    _layersChanged.add(true);
    _position.add(position);

    // Regenerate thumbnails for video assets
    if (assetAfter.type == AssetType.video) {
      assetAfter.thumbnailPath = null;
      _generateAllVideoThumbnails(layers![selected.layerIndex].assets);
    }

    // Reorganize text assets only for legacy text layer (index 1, vector)
    if (assetAfter.type == AssetType.text &&
        layers![selected.layerIndex].type == 'vector' &&
        selected.layerIndex == 1) {
      reorganizeTextAssets(1);
    }

    _selected.add(Selected(-1, -1));
    _appBar.add(true);

    // Delayed blocking 300 because it seems updating mediaSources is not immediate
    // because preview can fail
    Future.delayed(Duration(milliseconds: 200), () {
      isCutting = false;
      // After split completes and media sources are updated, refresh preview at current position
      _previewOnPosition();
    });
  }

  delete() {
    if (isOperating || layers == null) return;
    if (selected.layerIndex == -1 || selected.assetIndex == -1) return;
    print('>> DirectorService.delete()');
    isDeleting = true;

    // Snapshot selection to avoid index drift during mutations
    final int layerIndex = selected.layerIndex;
    final int assetIndex = selected.assetIndex;
    final Layer layer = layers![layerIndex];
    final Asset removedAsset = layer.assets[assetIndex];
    final AssetType removedType = removedAsset.type;

    // Remove from timeline
    layer.assets.removeAt(assetIndex);

    // Only update player if this layer has a player (raster/audio)
    if (layerPlayers.length > layerIndex && layerPlayers[layerIndex] != null) {
      layerPlayers[layerIndex]!.removeMediaSource(assetIndex);
    }

    // Legacy single text layer (index 1) keeps space management
    if (removedType == AssetType.text &&
        layer.type == 'vector' &&
        layerIndex == 1) {
      reorganizeTextAssets(1);
    }

    // If overlay-type dedicated layer is now empty, remove the whole layer
    final bool isOverlayLayer =
        layer.type == 'vector' ||
            layer.type == 'visualizer' ||
            layer.type == 'shader' ||
            layer.type == 'overlay' ||
            layer.type == 'audio_reactive';

    bool hasActiveOverlayAsset = layer.assets.any(
          (a) => !a.deleted && a.duration > 0,
    );
    if (isOverlayLayer && (!hasActiveOverlayAsset || layer.assets.isEmpty)) {
      layers!.removeAt(layerIndex);
      if (layerPlayers.length > layerIndex) {
        layerPlayers.removeAt(layerIndex);
      }
    } else {
      // For media-bearing raster layers, refresh calculated fields (begin chaining).
      // Audio layers keep gaps on delete (no ripple re-chaining).
      if (layer.type == 'raster' && removedType != AssetType.text) {
        refreshCalculatedFieldsInAssets(
          layerIndex,
          math.max(0, assetIndex - 1),
        );
      }
      // If legacy vector layer keeps only placeholders, remove the whole layer
      if (layer.type == 'vector') {
        final bool hasRealText = layer.assets.any(
              (a) => a.type == AssetType.text && a.title != '' && !a.deleted,
        );
        if (!hasRealText) {
          layers!.removeAt(layerIndex);
          if (layerPlayers.length > layerIndex) {
            layerPlayers.removeAt(layerIndex);
          }
        }
      }
    }

    _selected.add(Selected(-1, -1));
    _filesNotExist.add(checkSomeFileNotExists());

    if (position > duration) {
      _position.add(duration);
      scrollController.jumpTo(duration / 1000 * pixelsPerSecond);
    }

    isDeleting = false;
    _layersChanged.add(true);
    _appBar.add(true);

    // Delayed because it seems updating mediaSources is not immediate
    Future.delayed(Duration(milliseconds: 100), () {
      _previewOnPosition();
    });
  }

  scaleStart() {
    if (isOperating) return;
    isScaling = true;
    _selected.add(Selected(-1, -1));
    _pixelsPerSecondOnInitScale = pixelsPerSecond;
    _scrollOffsetOnInitScale = scrollController.offset;
  }

  scaleUpdate(double scale) {
    if (!isScaling) return;
    double pixPerSecond = _pixelsPerSecondOnInitScale * scale;
    pixPerSecond = math.min(pixPerSecond, 100);
    pixPerSecond = math.max(pixPerSecond, 1);
    _pixelsPerSecond.add(pixPerSecond);

    _layersChanged.add(true);
    scrollController.jumpTo(
      _scrollOffsetOnInitScale * pixPerSecond / _pixelsPerSecondOnInitScale,
    );
  }

  scaleEnd() {
    isScaling = false;
    _layersChanged.add(true);
  }

  /// Get first raster layer index (for base video/image layer)
  int getMainRasterLayerIndex() {
    if (layers == null || layers!.isEmpty) return -1;
    // Prefer the first raster layer that has media
    for (int i = 0; i < layers!.length; i++) {
      if (layers![i].type == 'raster' && layers![i].assets.isNotEmpty) {
        return i;
      }
    }
    // Fallback: return first raster layer even if empty
    for (int i = 0; i < layers!.length; i++) {
      if (layers![i].type == 'raster') {
        return i;
      }
    }
    return -1;
  }

  /// Get main raster layer
  Layer? getMainRasterLayer() {
    final idx = getMainRasterLayerIndex();
    if (idx >= 0 && idx < layers!.length) return layers![idx];
    return null;
  }

  /// Check if any raster layer has assets
  bool hasRasterAssets() {
    if (layers == null) return false;
    for (final layer in layers!) {
      if (layer.type == 'raster' && layer.assets.isNotEmpty) return true;
    }
    return false;
  }

}