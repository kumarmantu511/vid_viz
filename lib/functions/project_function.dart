part of 'package:vidviz/service/director_service.dart';

extension ProjectFunction on DirectorService {

  setProject(Project _project) async {
    isEntering = true;

    _position.add(0);
    _selected.add(Selected(-1, -1));
    editingTextAsset = null;
    _editingColor.add(null);
    _pixelsPerSecond.add(DirectorService.DEFAULT_PIXELS_PER_SECONDS);
    _appBar.add(true);
    isAdding = false; // Reset flag on project load

    if (project != _project) {
      project = _project;
      if (_project.layersJson == null) {
        layers = [
          // TODO: audio mixing between layers
          Layer(type: "raster", volume: 1.0),
          Layer(type: "audio", volume: 1.0),
        ];
      } else {
        layers = List<Layer>.from(json.decode(_project.layersJson!).map((layerMap) => Layer.fromJson(layerMap)),).toList();
        _filesNotExist.add(checkSomeFileNotExists());
      }
      // Remove any empty overlay layers from legacy projects
      _purgeEmptyOverlayLayers();
      _layersChanged.add(true);

      layerPlayers = <LayerPlayer?>[];

      for (int i = 0; i < layers!.length; i++) {
        LayerPlayer? layerPlayer;
        // Only create players for media-bearing layers
        if (layers![i].type == 'raster' || layers![i].type == 'audio') {
          layerPlayer = LayerPlayer(layers![i]);
          await layerPlayer.initialize();
        } else {
          layerPlayer = null; // overlay layers (text/visualizer/shader) have no players
        }
        layerPlayers.add(layerPlayer);
      }
    }

    // Initialize history with first snapshot
    _historyStack.clear();
    _historyIndex = -1;
    _isUndoRedoOperation = true; // Prevent saving during initial snapshot
    _saveToHistory();
    _isUndoRedoOperation = false;

    isEntering = false;
    await _previewOnPosition();
  }

  exitAndSaveProject() async {
    if (isPlaying) await stop();
    if (isOperating && !isExiting) {
      // isExiting bayrağını kontrol et
      logger.i("DirectorService is still operating, cannot exit yet.");
      return false;
    }

    isExiting = true;
    _saveProject();

    Future.delayed(Duration(milliseconds: 500), () {
      project = null;
      for (int i = 0; i < layerPlayers.length; i++) {
        layerPlayers[i]?.dispose();
      }
      layerPlayers.clear();

      // Diğer state'leri sıfırla (önlem olarak)
      print("🔄 Resetting states...");
      project = null;
      layers = null; // layers listesini de sıfırla

      // Clear history stack to free memory
      _historyStack.clear();
      _historyIndex = -1;
      _historyChanged.add(true);

      isPlaying = false;
      isPreviewing = false;
      isDragging = false;
      isSizerDragging = false;
      isCutting = false;
      isScaling = false;
      isAdding = false;
      isDeleting = false;
      isGenerating = false;
      _position.add(0); // Pozisyonu sıfırla
      _selected.add(Selected(-1, -1)); // Seçimi sıfırla
      editingTextAsset = null;
      _editingColor.add(null);
      _filesNotExist.add(false); // Dosya yok hatasını sıfırla
      _appBar.add(true); // AppBar durumunu güncelle

      isExiting = false;
      print("🚪 Project exited successfully.");
    });

    _deleteThumbnailsNotUsed();
    return true;
  }

  _saveProject() {
    // Null safety checks
    if (layers == null || project == null) return;

    try {
      project!.layersJson = json.encode(layers);

      // Get thumbnail from main raster layer
      final mainLayer = getMainRasterLayer();
      project!.imagePath = (mainLayer != null && mainLayer.assets.isNotEmpty)
          ? getFirstThumbnailMedPath()
          : null;

      projectService.update(project);

      // Save to history stack (only if not during undo/redo)
      if (!_isUndoRedoOperation) {
        _saveToHistory();
      }
    } catch (e) {
      logger.e('Failed to save project: $e');
    }
  }

  _deleteThumbnailsNotUsed() async {
    // TODO: pending to implement
    Directory appDocDir = await getApplicationDocumentsDirectory();
    Directory fontsDir = Directory(p.join(appDocDir.parent.path, 'code_cache'));

    List<FileSystemEntity> entityList = fontsDir.listSync(
      recursive: true,
      followLinks: false,
    );
    for (FileSystemEntity entity in entityList) {
      if (!await FileSystemEntity.isFile(entity.path) &&
          entity.path.split('/').last.startsWith('open_director')) {}
      //print(entity.path);
    }
  }

  checkSomeFileNotExists() {
    if (layers == null) return false;
    bool _someFileNotExists = false;
    for (int i = 0; i < layers!.length; i++) {
      for (int j = 0; j < layers![i].assets.length; j++) {
        Asset asset = layers![i].assets[j];
        if (asset.srcPath != '' && !File(asset.srcPath).existsSync()) {
          asset.deleted = true;
          _someFileNotExists = true;
          print(asset.srcPath + ' does not exists');
        }
      }
    }
    return _someFileNotExists;
  }

  // Remove empty overlay-type layers to avoid blank rows in timeline
  _purgeEmptyOverlayLayers() {
    if (layers == null) return;
    for (int i = layers!.length - 1; i >= 0; i--) {
      final l = layers![i];
      final isOverlay =
          l.type == 'vector' ||
              l.type == 'visualizer' ||
              l.type == 'shader' ||
              l.type == 'overlay' ||
              l.type == 'audio_reactive';
      if (isOverlay) {
        final bool hasActive = l.assets.any(
              (a) =>
          !a.deleted &&
              a.duration > 0 &&
              (l.type != 'vector' ||
                  (a.type == AssetType.text && a.title != '')),
        );
        if (!hasActive) {
          layers!.removeAt(i);
          continue;
        }
      }
      // Remove legacy vector layer if it only contains placeholder spaces (empty titles)
      if (l.type == 'vector') {
        final bool hasRealText = l.assets.any(
              (a) => a.type == AssetType.text && a.title != '' && !a.deleted,
        );
        if (!hasRealText) {
          layers!.removeAt(i);
        }
      }
    }
  }

  /// Project seviyesindeki video ayarlarını döndürür.
  /// Eğer editingVideoSettings aktifse UI tarafında onu tercih etmelisiniz.
  VideoSettings getProjectVideoSettings() {
    return VideoSettings(
      aspectRatio: project?.aspectRatio ?? '16:9',
      cropMode: project?.cropMode ?? 'fit',
      rotation: project?.rotation ?? 0,
      flipHorizontal: project?.flipHorizontal ?? false,
      flipVertical: project?.flipVertical ?? false,
      backgroundColor: project?.backgroundColor ?? 0xFF000000,
    );
  }

  dispose() {
    // Cancel stream subscriptions to prevent memory leaks
    _layersChangedSubscription.cancel();
    scrollController.removeListener(_listenerScrollController);

    // Close all streams
    _layersChanged.close();
    _selected.close();
    _pixelsPerSecond.close();
    _position.close();
    _appBar.close();
    _editingTextAsset.close();
    _editingColor.close();
    _filesNotExist.close();
    _historyChanged.close();
    _exportStat.close();
    _editingVideoSettings.close();
    _audioOnlyPlay.close();
    // Cancel debounce timer
    try {
      _previewDebounce?.cancel();
    } catch (_) {}
  }


}