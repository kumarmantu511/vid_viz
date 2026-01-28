part of 'package:vidviz/service/director_service.dart';

extension AssetFunction on DirectorService {

  sizerDragStart(bool sizerEnd) {
    if (isOperating) return;
    isSizerDragging = true;
    isSizerDraggingEnd = sizerEnd;
    dxSizerDrag = 0;
  }

  sizerDragUpdate(bool sizerEnd, double dx) {
    dxSizerDrag += dx;
    _selected.add(selected); // To refresh UI
  }

  sizerDragEnd(bool sizerEnd) async {
    await executeSizer(sizerEnd);
    _selected.add(selected); // To refresh UI
    dxSizerDrag = 0;
    isSizerDragging = false;
  }

  executeSizer(bool sizerEnd) async {
    final asset = assetSelected;
    if (asset == null) return;
    if (asset.type == AssetType.text ||
        asset.type == AssetType.image ||
        asset.type == AssetType.visualizer ||
        asset.type == AssetType.shader) {
      int dxSizerDragMillis = (dxSizerDrag / pixelsPerSecond * 1000).floor();

      if (!isSizerDraggingEnd) {
        if (asset.begin + dxSizerDragMillis < 0) {
          dxSizerDragMillis = -asset.begin;
        }
        if (asset.duration - dxSizerDragMillis < 1000) {
          dxSizerDragMillis = asset.duration - 1000;
        }
        asset.begin += dxSizerDragMillis;
        asset.duration -= dxSizerDragMillis;
      } else {
        if (asset.duration + dxSizerDragMillis < 1000) {
          dxSizerDragMillis = -asset.duration + 1000;
        }
        asset.duration += dxSizerDragMillis;
      }
      if (asset.type == AssetType.text) {
        // Legacy single text layer uses reorganize; dedicated overlay layers do not
        if (selected.layerIndex == 1) {
          reorganizeTextAssets(1);
        }
      } else if (asset.type == AssetType.image) {
        // Overlay images (media overlay, audio reactive) do not update players or chain assets
        final bool isOverlayImage = asset.data?['overlayType'] != null;
        if (!isOverlayImage) {
          // Base image in raster layer: update chaining and refresh player if present
          refreshCalculatedFieldsInAssets(
            selected.layerIndex,
            selected.assetIndex,
          );
          if (layers![selected.layerIndex].type == 'raster' &&
              layerPlayers[selected.layerIndex] != null) {
            await layerPlayers[selected.layerIndex]!.removeMediaSource(
              selected.assetIndex,
            );
            await layerPlayers[selected.layerIndex]!.addMediaSource(
              selected.assetIndex,
              asset,
            );
          }
        }
      } else if (asset.type == AssetType.visualizer) {
        // Visualizer için reorganize gerekmez (Text gibi değil)
        // Sadece duration ve begin güncellenmiş olur
      } else if (asset.type == AssetType.shader) {
        // Shader effect için reorganize gerekmez
        // Sadece duration ve begin güncellenmiş olur
      }
      _selected.add(Selected(-1, -1));
    } else if (asset.type == AssetType.video || asset.type == AssetType.audio) {
      // Ripple trim for media-bearing layers (raster/audio)
      int dxMs = (dxSizerDrag / pixelsPerSecond * 1000).floor();
      // Get cached media duration or probe once
      int mediaLen;
      if (_mediaDurationCache.containsKey(asset.srcPath)) {
        mediaLen = _mediaDurationCache[asset.srcPath]!;
      } else {
        mediaLen = await generator.getVideoDuration(asset.srcPath);
        if (mediaLen <= 0) {
          // Fallback: keep current values if probe fails
          mediaLen = asset.cutFrom + asset.duration;
        }
        _mediaDurationCache[asset.srcPath] = mediaLen;
      }

      int newCutFrom = asset.cutFrom;
      int newDuration = asset.duration;
      final double spd =
      (asset.type == AssetType.video && asset.playbackSpeed > 0)
          ? asset.playbackSpeed
          : 1.0;

      if (asset.type == AssetType.audio) {
        if (!isSizerDraggingEnd) {
          // Audio left handle: move timeline IN (begin) and file IN (cutFrom) together,
          // keeping the right edge (end) anchored.
          const int minDur = 1000;
          int lowerDx = -asset.cutFrom;
          lowerDx = math.max(lowerDx, -asset.begin);
          int upperDx = asset.duration - minDur;
          if (upperDx < lowerDx) {
            upperDx = lowerDx;
          }
          dxMs = dxMs.clamp(lowerDx, upperDx);

          asset.begin += dxMs;
          newCutFrom = asset.cutFrom + dxMs;
          newDuration = asset.duration - dxMs;
        } else {
          // Audio right handle: move OUT point (duration) only.
          newDuration = asset.duration + dxMs;
          int maxDurBySpeed = ((mediaLen - asset.cutFrom) / spd).floor();
          if (maxDurBySpeed < 1000) {
            newDuration = maxDurBySpeed;
          } else {
            if (newDuration < 1000) newDuration = 1000;
            if (newDuration > maxDurBySpeed) newDuration = maxDurBySpeed;
          }
        }
      } else {
        if (!isSizerDraggingEnd) {
          // Left handle: move IN point
          newCutFrom = asset.cutFrom + dxMs;
          newDuration = asset.duration - dxMs;
          // Clamp IN >= 0
          if (newCutFrom < 0) {
            // push back into duration
            newDuration += newCutFrom; // newCutFrom is negative
            newCutFrom = 0;
          }
          // Do not exceed media end (speed-aware) and respect UI min when possible
          int maxDurBySpeed = ((mediaLen - newCutFrom) / spd).floor();
          if (maxDurBySpeed < 1000) {
            // Near end: allow shorter than 1s to avoid overshooting media end
            newDuration = maxDurBySpeed;
          } else {
            if (newDuration < 1000) newDuration = 1000;
            if (newDuration > maxDurBySpeed) newDuration = maxDurBySpeed;
          }
        } else {
          // Right handle: move OUT point
          newDuration = asset.duration + dxMs;
          // Do not exceed media end (speed-aware) and respect UI min when possible
          int maxDurBySpeed = ((mediaLen - asset.cutFrom) / spd).floor();
          if (maxDurBySpeed < 1000) {
            newDuration = maxDurBySpeed;
          } else {
            if (newDuration < 1000) newDuration = 1000;
            if (newDuration > maxDurBySpeed) newDuration = maxDurBySpeed;
          }
        }
      }

      asset.cutFrom = math.max(0, newCutFrom);
      // newDuration already clamped with speed and min when possible
      asset.duration = math.max(0, newDuration);

      final String ltype = layers![selected.layerIndex].type;
      // Recompute chaining for following assets in this layer
      if (ltype == 'raster') {
        refreshCalculatedFieldsInAssets(
          selected.layerIndex,
          selected.assetIndex,
        );
      }
      // Refresh player source for this asset if player exists
      if ((ltype == 'raster' || ltype == 'audio') &&
          layerPlayers[selected.layerIndex] != null) {
        await layerPlayers[selected.layerIndex]!.removeMediaSource(
          selected.assetIndex,
        );
        await layerPlayers[selected.layerIndex]!.addMediaSource(
          selected.assetIndex,
          asset,
        );
      }
      _selected.add(Selected(-1, -1));
    }
    _layersChanged.add(true);
    // Immediate preview to keep UI in sync after trimming
    await _previewOnPosition();
  }

  dragStart(layerIndex, assetIndex) {
    if (isOperating || layers == null) return;
    if (layerIndex == 1 && layers![layerIndex].assets[assetIndex].title == '')
      return;
    isDragging = true;
    Selected sel = Selected(layerIndex, assetIndex);
    sel.initScrollOffset = scrollController.offset;
    _selected.add(sel);
    _appBar.add(true);
  }

  dragSelected(
      int layerIndex,
      int assetIndex,
      double dragX,
      double scrollWidth,
      ) {
    if (layers == null) return;
    if (layerIndex == 1 && layers![layerIndex].assets[assetIndex].title == '')
      return;
    Asset assetSelected = layers![layerIndex].assets[assetIndex];
    int closest = assetIndex;
    int pos =
        assetSelected.begin +
            ((dragX + scrollController.offset - selected.initScrollOffset) /
                pixelsPerSecond *
                1000)
                .floor();
    if (dragX + scrollController.offset - selected.initScrollOffset < 0) {
      closest = getClosestAssetIndexLeft(layerIndex, assetIndex, pos);
    } else {
      pos = pos + assetSelected.duration;
      closest = getClosestAssetIndexRight(layerIndex, assetIndex, pos);
    }
    updateScrollOnDrag(pos, scrollWidth);
    Selected sel = Selected(
      layerIndex,
      assetIndex,
      dragX: dragX,
      closestAsset: closest,
      initScrollOffset: selected.initScrollOffset,
      incrScrollOffset: scrollController.offset - selected.initScrollOffset,
    );
    _selected.add(sel);
  }

  dragEnd() async {
    if (layers == null ||
        selected.layerIndex == -1 ||
        selected.assetIndex == -1) {
      isDragging = false;
      _appBar.add(true);
      return;
    }

    Asset asset = layers![selected.layerIndex].assets[selected.assetIndex];

    // Text, Image, Visualizer, Shader and Audio (in audio layers): move by timeline position
    if (asset.type == AssetType.text ||
        asset.type == AssetType.image ||
        asset.type == AssetType.visualizer ||
        asset.type == AssetType.shader ||
        asset.type == AssetType.audio) {
      // Synchronous operation, no await needed
      moveAssetByPosition();
    } else {
      // Video (and other non-overlay media in non-audio layers): exchange positions (async operation)
      await exchange();
    }

    // Set flags after all operations complete
    isDragging = false;
    _appBar.add(true);
  }

  Asset? getAssetByPosition(int layerIndex) {
    if (layers == null) return null;
    for (int i = 0; i < layers![layerIndex].assets.length; i++) {
      if (layers![layerIndex].assets[i].begin +
          layers![layerIndex].assets[i].duration -
          1 >=
          position) {
        return layers![layerIndex].assets[i];
      }
    }
    return null;
  }

  /// Get all active assets of a given type at a given timeline position across all layers
  List<Asset> getActiveAssetsOfType(AssetType type, {int? at}) {
    final int pos = at ?? position;
    final List<Asset> out = [];
    if (layers == null) return out;
    for (final layer in layers!) {
      for (final a in layer.assets) {
        if (a.deleted) continue;
        if (a.type != type) continue;
        final int start = a.begin;
        final int end = a.begin + a.duration;
        if (pos >= start && pos < end) {
          out.add(a);
        }
      }
    }
    return out;
  }

  /// Convenience: first active asset of a given type (e.g., top-most shader to draw)
  Asset? getFirstActiveAssetOfType(AssetType type, {int? at}) {
    final list = getActiveAssetsOfType(type, at: at);
    if (list.isEmpty) return null;
    return list.last; // Prefer most recently added (top-most)
  }

  select(int layerIndex, int assetIndex) async {
    if (isOperating || layers == null) return;
    if (layerIndex == 1 && layers![layerIndex].assets[assetIndex].title == '') {
      _selected.add(Selected(-1, -1));
    } else {
      _selected.add(Selected(layerIndex, assetIndex));
    }
    _appBar.add(true);
  }

  refreshCalculatedFieldsInAssets(int layerIndex, int assetIndex) {
    if (layers == null) return;
    for (int i = assetIndex; i < layers![layerIndex].assets.length; i++) {
      layers![layerIndex].assets[i].begin = (i == 0)
          ? 0
          : layers![layerIndex].assets[i - 1].begin +
          layers![layerIndex].assets[i - 1].duration;
    }
  }


  int getClosestAssetIndexLeft(int layerIndex, int assetIndex, int pos) {
    if (layers == null) return assetIndex;
    int closest = assetIndex;
    int distance = (pos - layers![layerIndex].assets[assetIndex].begin).abs().toInt();
    if (assetIndex < 1) return assetIndex;
    for (int i = assetIndex - 1; i >= 0; i--) {
      int d = (pos - layers![layerIndex].assets[i].begin).abs().toInt();
      if (d < distance) {
        closest = i;
        distance = d;
      }
    }
    return closest;
  }

  int getClosestAssetIndexRight(int layerIndex, int assetIndex, int pos) {
    if (layers == null) return assetIndex;
    int closest = assetIndex;
    int endAsset =
        layers![layerIndex].assets[assetIndex].begin +
            layers![layerIndex].assets[assetIndex].duration;
    int distance = (pos - endAsset).abs();
    if (assetIndex >= layers![layerIndex].assets.length - 1) return assetIndex;
    for (int i = assetIndex + 1; i < layers![layerIndex].assets.length; i++) {
      int end =
          layers![layerIndex].assets[i].begin +
              layers![layerIndex].assets[i].duration;
      int d = (pos - end).abs();
      if (d < distance) {
        closest = i;
        distance = d;
      }
    }
    return closest;
  }

  updateScrollOnDrag(int pos, double scrollWidth) {
    double outOfScrollRight =
        pos * pixelsPerSecond / 1000 -
            scrollController.offset -
            scrollWidth / 2;
    double outOfScrollLeft =
        scrollController.offset -
            pos * pixelsPerSecond / 1000 -
            scrollWidth / 2 +
            32; // Layer header width: 32
    if (outOfScrollRight > 0 && outOfScrollLeft < 0) {
      scrollController.animateTo(
        scrollController.offset + math.min(outOfScrollRight, 50),
        duration: Duration(milliseconds: 100),
        curve: Curves.linear,
      );
    }
    if (outOfScrollRight < 0 && outOfScrollLeft > 0) {
      scrollController.animateTo(
        scrollController.offset - math.min(outOfScrollLeft, 50),
        duration: Duration(milliseconds: 100),
        curve: Curves.linear,
      );
    }
  }

  Future<void> replaceSelectedAssetMedia() async {
    if (isOperating || layers == null) return;
    final int li = selected.layerIndex;
    final int ai = selected.assetIndex;
    if (li < 0 || ai < 0) return;
    if (li >= layers!.length) return;
    final Layer layer = layers![li];
    if (ai >= layer.assets.length) return;

    final Asset asset = layer.assets[ai];
    final AssetType type = asset.type;
    final dynamic overlayType = asset.data?['overlayType'];

    if (type != AssetType.video &&
        type != AssetType.image &&
        type != AssetType.audio) {
      return;
    }
    if (overlayType != null) {
      return;
    }

    isAdding = true;
    try {
      FilePickerResult? result;
      if (type == AssetType.video) {
        result = await FilePicker.platform.pickFiles(
          type: FileType.video,
          allowMultiple: false,
        );
      } else if (type == AssetType.image) {
        result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );
      } else {
        result = await FilePicker.platform.pickFiles(
          type: FileType.audio,
          allowMultiple: false,
        );
      }

      if (result == null ||
          result.files.isEmpty ||
          result.files.first.path == null) {
        return;
      }

      final String newPath = result.files.first.path!;
      final file = File(newPath);
      if (!file.existsSync()) {
        print('❌ replaceSelectedAssetMedia: file does not exist: $newPath');
        return;
      }

      int oldDuration = asset.duration;
      if (type == AssetType.video || type == AssetType.audio) {
        int newDur;
        if (_mediaDurationCache.containsKey(newPath)) {
          newDur = _mediaDurationCache[newPath]!;
        } else {
          newDur = await generator.getVideoDuration(newPath);
          if (newDur > 0) {
            _mediaDurationCache[newPath] = newDur;
          }
        }
        if (newDur <= 0) {
          newDur = oldDuration;
        }
        final int finalDur = math.max(1000, math.min(oldDuration, newDur));
        asset.duration = finalDur;
        asset.cutFrom = 0;
        if (ai + 1 < layer.assets.length) {
          refreshCalculatedFieldsInAssets(li, ai + 1);
        }
      }

      asset.srcPath = newPath;
      asset.title = p.basename(newPath);
      asset.deleted = false;
      asset.thumbnailPath = null;
      asset.thumbnailMedPath = null;

      if (layer.type == 'raster') {
        if (type == AssetType.video) {
          _generateAllVideoThumbnails(layer.assets);
        } else if (type == AssetType.image) {
          _generateKenBurnEffects(asset);
          _generateAllImageThumbnails(layer.assets);
        }
      }

      if (layerPlayers.length > li && layerPlayers[li] != null) {
        try {
          await layerPlayers[li]!.addMediaSource(ai, asset);
        } catch (_) {}
      }

      _saveToHistory();
      _layersChanged.add(true);
      _appBar.add(true);

      final int currentPos = position;
      final int assetStart = asset.begin;
      final int assetEnd = asset.begin + asset.duration;
      int previewPos = currentPos;
      if (previewPos < assetStart || previewPos >= assetEnd) {
        previewPos = assetStart;
      }
      await previewAt(previewPos);
    } finally {
      isAdding = false;
    }
  }

  Future<void> cloneSelectedAsset() async {
    if (isOperating || layers == null) return;
    final int li = selected.layerIndex;
    final int ai = selected.assetIndex;
    if (li < 0 || ai < 0) return;
    if (li >= layers!.length) return;
    final layer = layers![li];
    if (ai >= layer.assets.length) return;

    final Asset original = layer.assets[ai];
    if (original.type != AssetType.video &&
        original.type != AssetType.image &&
        original.type != AssetType.audio) {
      return;
    }

    isAdding = true;
    try {
      final Asset cloned = Asset.clone(original);
      final int insertIndex = ai + 1;
      layer.assets.insert(insertIndex, cloned);

      final String ltype = layer.type;
      final bool layerHasPlayer = (ltype == 'raster' || ltype == 'audio');
      if (layerHasPlayer) {
        refreshCalculatedFieldsInAssets(li, insertIndex);

        final bool isOverlayImage =
            (cloned.type == AssetType.image) &&
                (cloned.data?['overlayType'] != null);
        if (!isOverlayImage &&
            (cloned.type == AssetType.video ||
                cloned.type == AssetType.audio ||
                cloned.type == AssetType.image) &&
            layerPlayers.length > li &&
            layerPlayers[li] != null) {
          try {
            await layerPlayers[li]!.addMediaSource(insertIndex, cloned);
          } catch (_) {}
        }
      }

      _saveToHistory();
      _layersChanged.add(true);
      _appBar.add(true);

      // Select the newly cloned asset
      _selected.add(Selected(li, insertIndex));

      // Light preview update to reflect new timeline state
      Future.delayed(const Duration(milliseconds: 100), () {
        _previewOnPosition();
      });
    } finally {
      isAdding = false;
    }
  }

  reorganizeTextAssets(int layerIndex) {
    if (layers == null || layers![layerIndex].assets.isEmpty) return;
    // After adding an asset in a position (begin = position),
    // it´s neccesary to sort
    layers![layerIndex].assets.sort((a, b) => a.begin - b.begin);

    // Configuring other assets and spaces after that
    for (int i = 1; i < layers![layerIndex].assets.length; i++) {
      Asset asset = layers![layerIndex].assets[i];
      Asset prevAsset = layers![layerIndex].assets[i - 1];

      if (prevAsset.title == '' && asset.title == '') {
        asset.begin = prevAsset.begin;
        asset.duration += prevAsset.duration;
        prevAsset.duration = 0; // To delete at the end
      } else if (prevAsset.title == '' && asset.title != '') {
        prevAsset.duration = asset.begin - prevAsset.begin;
      } else if (prevAsset.title != '' && asset.title == '') {
        asset.duration -= prevAsset.begin + prevAsset.duration - asset.begin;
        asset.duration = math.max(asset.duration, 0);
        asset.begin = prevAsset.begin + prevAsset.duration;
      } else if (prevAsset.title != '' && asset.title != '') {
        // Nothing, only insert space in a second loop if it´s neccesary
      }
    }

    // Remove duplicated spaces
    layers![layerIndex].assets.removeWhere((asset) => asset.duration <= 0);

    // Second loop to insert spaces between assets or move asset
    for (int i = 1; i < layers![layerIndex].assets.length; i++) {
      Asset asset = layers![layerIndex].assets[i];
      Asset prevAsset = layers![layerIndex].assets[i - 1];
      if (asset.begin > prevAsset.begin + prevAsset.duration) {
        Asset newAsset = Asset(
          type: AssetType.text,
          begin: prevAsset.begin + prevAsset.duration,
          duration: asset.begin - (prevAsset.begin + prevAsset.duration),
          title: '',
          srcPath: '',
        );
        layers![layerIndex].assets.insert(i, newAsset);
      } else {
        asset.begin = prevAsset.begin + prevAsset.duration;
      }
    }
    if (layers![layerIndex].assets.isNotEmpty &&
        layers![layerIndex].assets[0].begin > 0) {
      Asset newAsset = Asset(
        type: AssetType.text,
        begin: 0,
        duration: layers![layerIndex].assets[0].begin,
        title: '',
        srcPath: '',
      );
      layers![layerIndex].assets.insert(0, newAsset);
    }

    // Last space until video duration
    if (layers![layerIndex].assets.last.title == '') {
      layers![layerIndex].assets.last.duration =
          duration - layers![layerIndex].assets.last.begin;
    } else {
      Asset prevAsset = layers![layerIndex].assets.last;
      Asset asset = Asset(
        type: AssetType.text,
        begin: prevAsset.begin + prevAsset.duration,
        duration: duration - (prevAsset.begin + prevAsset.duration),
        title: '',
        srcPath: '',
      );
      layers![layerIndex].assets.add(asset);
    }
  }


}