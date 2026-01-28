part of 'package:vidviz/service/director_service.dart';

extension SaveFunction on DirectorService {

  saveTextAsset() {
    if (layers == null) return;
    if (editingTextAsset == null) return;
    if (editingTextAsset!.title == '') {
      editingTextAsset!.title = 'No title';
    }
    // Convert TextAsset to core Asset for timeline storage
    if (assetSelected == null) {
      // Create dedicated overlay layer for this text
      final newLayer = Layer(type: 'vector', name: 'Text', volume: 0.1);
      layers!.add(newLayer);
      // Align layerPlayers list (no player for overlay layer)
      layerPlayers.add(null);

      final TextAsset temp = TextAsset.clone(editingTextAsset!);
      temp.begin = position;
      newLayer.assets.add(temp.toAsset());
      // No reorganize for dedicated overlay layers
    } else {
      // Update existing asset in its layer
      layers![selected.layerIndex].assets[selected.assetIndex] =
          editingTextAsset!.toAsset();
      // If it's the legacy single text layer, keep reorganize behavior
      if (selected.layerIndex == 1) {
        reorganizeTextAssets(1);
      }
    }
    _layersChanged.add(true);
    editingTextAsset = null;
    isAdding = false; // Reset flag after save
  }

  // Visualizer için save metodu (Text'in kopyası)
  saveVisualizerAsset() {
    final visualizerService = locator.get<VisualizerService>();
    if (layers == null || visualizerService.editingVisualizerAsset == null)
      return;

    VisualizerAsset vAsset = visualizerService.editingVisualizerAsset!;
    if (vAsset.title == '') {
      vAsset.title = 'Visualizer';
    }
    final Asset visualizerAsset = vAsset.toAsset();

    logger.i(
      '💾 SAVE Visualizer: renderMode=${vAsset.renderMode}, shaderType=${vAsset.shaderType}, color=${vAsset.color.toRadixString(16)}',
    );

    final int? editingLayerIndex = visualizerService.editingLayerIndex;
    final int? editingAssetIndex = visualizerService.editingAssetIndex;

    bool hasEditingIndices =
        editingLayerIndex != null &&
            editingAssetIndex != null &&
            editingLayerIndex >= 0 &&
            editingLayerIndex < layers!.length &&
            editingAssetIndex >= 0 &&
            editingAssetIndex < layers![editingLayerIndex].assets.length;

    if (hasEditingIndices) {
      logger.i(
        'Visualizer GÜNCELLENİYOR (editing indices): layerIndex=$editingLayerIndex, assetIndex=$editingAssetIndex, color=${vAsset.color.toRadixString(16)}',
      );
      layers![editingLayerIndex].assets[editingAssetIndex] = visualizerAsset;
      logger.i(
        'Visualizer GÜNCELLENDİ (editing indices): index=$editingAssetIndex',
      );
    } else if (assetSelected == null) {
      // Yeni visualizer ekleniyor: dedicated overlay layer
      final newLayer = Layer(
        type: 'visualizer',
        name: 'Visualizer',
        volume: 0.0,
      );
      layers!.add(newLayer);
      layerPlayers.add(null);
      visualizerAsset.begin = position;
      newLayer.assets.add(visualizerAsset);
      logger.i(
        'Visualizer EKLENDI (overlay layer): color=${vAsset.color.toRadixString(16)}',
      );
    } else {
      // Mevcut visualizer düzenleniyor (seçili asset üzerinden geri dönüş)
      logger.i(
        'Visualizer GÜNCELLENİYOR (selected): layerIndex=${selected.layerIndex}, assetIndex=${selected.assetIndex}, color=${vAsset.color.toRadixString(16)}',
      );
      layers![selected.layerIndex].assets[selected.assetIndex] =
          visualizerAsset;
      logger.i(
        'Visualizer GÜNCELLENDİ (selected): index=${selected.assetIndex}',
      );
    }

    _layersChanged.add(true);
    visualizerService.editingVisualizerAsset = null;
    visualizerService.editingLayerIndex = null;
    visualizerService.editingAssetIndex = null;
    isAdding = false; // Reset flag after save
  }

  // Shader effect için save metodu (Text pattern'i - basit ve temiz)
  saveShaderEffectAsset() {
    final shaderEffectService = locator.get<ShaderEffectService>();
    if (layers == null || shaderEffectService.editingShaderEffectAsset == null)
      return;

    // ShaderEffectAsset'i Asset'e dönüştür
    Asset shaderEffectAsset = shaderEffectService.shaderEffectToAsset(
      shaderEffectService.editingShaderEffectAsset!,
    );

    if (shaderEffectAsset.title == '') {
      shaderEffectAsset.title = 'Shader Effect';
    }

    if (assetSelected == null) {
      // Yeni shader effect: dedicated overlay layer
      final newLayer = Layer(type: 'shader', name: 'Shader', volume: 0.0);
      layers!.add(newLayer);
      layerPlayers.add(null);
      shaderEffectAsset.begin = position;
      newLayer.assets.add(shaderEffectAsset);
    } else {
      // Mevcut shader effect güncelleniyor (dinamik index)
      layers![selected.layerIndex].assets[selected.assetIndex] =
          shaderEffectAsset;
    }

    _layersChanged.add(true);
    shaderEffectService.editingShaderEffectAsset = null;
    isAdding = false; // Reset flag after save
  }

  // Media Overlay için save metodu (Text/Visualizer/Shader pattern'i)
  saveMediaOverlayAsset() {
    final mediaOverlayService = locator.get<MediaOverlayService>();
    if (layers == null || mediaOverlayService.editingMediaOverlay == null)
      return;

    final overlay = mediaOverlayService.editingMediaOverlay!;
    if (overlay.title == '') {
      overlay.title = 'Media Overlay';
    }
    final Asset mediaOverlayAsset = overlay.toAsset();
    // Önce aynı id'ye sahip mevcut bir media overlay var mı kontrol et
    int existingLayerIndex = -1;
    int existingAssetIndex = -1;
    for (int li = 0; li < layers!.length; li++) {
      for (int ai = 0; ai < layers![li].assets.length; ai++) {
        final a = layers![li].assets[ai];
        if (a.deleted) continue;
        if (a.id == mediaOverlayAsset.id &&
            MediaOverlayAsset.isMediaOverlay(a)) {
          existingLayerIndex = li;
          existingAssetIndex = ai;
          break;
        }
      }
      if (existingLayerIndex != -1) break;
    }

    if (existingLayerIndex != -1 && existingAssetIndex != -1) {
      // Mevcut media overlay, id üzerinden bulundu: direkt güncelle
      layers![existingLayerIndex].assets[existingAssetIndex] =
          mediaOverlayAsset;
      logger.i(
        'Media Overlay GÜNCELLENDİ (id match): ${overlay.title} layer=$existingLayerIndex asset=$existingAssetIndex',
      );
    } else if (assetSelected == null) {
      // Yeni media overlay: dedicated overlay layer
      final newLayer = Layer(
        type: 'overlay',
        name: 'Media Overlay',
        volume: 0.0,
      );
      layers!.add(newLayer);
      layerPlayers.add(null);
      mediaOverlayAsset.begin = position;
      // Varsayılan olarak overlay, projedeki kalan süre boyunca aktif olsun
      // Örnek: Proje 60s, position 30s ise -> duration = 30s (30-60 arası)
      final int projectDuration = duration;
      if (projectDuration > mediaOverlayAsset.begin) {
        mediaOverlayAsset.duration = projectDuration - mediaOverlayAsset.begin;
      }
      newLayer.assets.add(mediaOverlayAsset);
      logger.i('Media Overlay EKLENDI (overlay layer): ${overlay.title}');
    } else {
      // Mevcut media overlay, seçili asset üzerinden güncelleniyor
      layers![selected.layerIndex].assets[selected.assetIndex] =
          mediaOverlayAsset;
      logger.i('Media Overlay GÜNCELLENDİ (selected): ${overlay.title}');
    }

    _layersChanged.add(true);
    mediaOverlayService.editingMediaOverlay = null;
    isAdding = false; // Reset flag after save
  }

  // Audio Reactive için save metodu (Text/Visualizer pattern'i)
  saveAudioReactiveAsset() {
    final audioReactiveService = locator.get<AudioReactiveService>();
    if (layers == null || audioReactiveService.editingAudioReactive == null)
      return;

    final reactive = audioReactiveService.editingAudioReactive!;
    if (reactive.title == '') {
      reactive.title = 'Audio Reactive';
    }
    final Asset audioReactiveAsset = reactive.toAsset();

    // Önce aynı id'ye sahip mevcut bir audio reactive var mı kontrol et
    int existingLayerIndex = -1;
    int existingAssetIndex = -1;
    for (int li = 0; li < layers!.length; li++) {
      for (int ai = 0; ai < layers![li].assets.length; ai++) {
        final a = layers![li].assets[ai];
        if (a.deleted) continue;
        if (a.id == audioReactiveAsset.id &&
            AudioReactiveAsset.isAudioReactive(a)) {
          existingLayerIndex = li;
          existingAssetIndex = ai;
          break;
        }
      }
      if (existingLayerIndex != -1) break;
    }

    if (existingLayerIndex != -1 && existingAssetIndex != -1) {
      // Mevcut audio reactive, id üzerinden bulundu: direkt güncelle
      layers![existingLayerIndex].assets[existingAssetIndex] =
          audioReactiveAsset;
      logger.i(
        'Audio Reactive GÜNCELLENDİ (id match): ${reactive.title} layer=$existingLayerIndex asset=$existingAssetIndex',
      );
    } else if (assetSelected == null) {
      // Yeni audio reactive: dedicated overlay layer
      final newLayer = Layer(
        type: 'audio_reactive',
        name: 'Audio Reactive',
        volume: 0.0,
      );
      layers!.add(newLayer);
      layerPlayers.add(null);

      // Hedef overlay'i bul ve begin/duration'ı ona göre hizala
      Asset? targetOverlay;
      for (final layer in layers!) {
        for (final a in layer.assets) {
          if (a.deleted) continue;
          if (a.id == reactive.targetOverlayId) {
            targetOverlay = a;
            break;
          }
        }
        if (targetOverlay != null) break;
      }

      if (targetOverlay != null) {
        audioReactiveAsset.begin = targetOverlay.begin;
        audioReactiveAsset.duration = targetOverlay.duration;
      } else {
        // Fallback: eski davranış - current position'dan projedeki kalan süre boyunca
        audioReactiveAsset.begin = position;
        final int projectDuration = duration;
        if (projectDuration > audioReactiveAsset.begin) {
          audioReactiveAsset.duration =
              projectDuration - audioReactiveAsset.begin;
        }
      }

      newLayer.assets.add(audioReactiveAsset);
      logger.i(
        'Audio Reactive EKLENDI (audio_reactive layer): ${reactive.title}',
      );
    } else {
      // Mevcut audio reactive, seçili asset üzerinden güncelleniyor
      layers![selected.layerIndex].assets[selected.assetIndex] =
          audioReactiveAsset;
      logger.i('Audio Reactive GÜNCELLENDİ (selected): ${reactive.title}');
    }

    _layersChanged.add(true);
    audioReactiveService.editingAudioReactive = null;
    isAdding = false; // Reset flag after save
  }

  // Video Settings için save metodu
  saveVideoSettings() {
    if (editingVideoSettings == null || project == null) return;

    // Project'e kaydet
    project!.aspectRatio = editingVideoSettings!.aspectRatio;
    project!.cropMode = editingVideoSettings!.cropMode;
    project!.rotation = editingVideoSettings!.rotation;
    project!.flipHorizontal = editingVideoSettings!.flipHorizontal;
    project!.flipVertical = editingVideoSettings!.flipVertical;
    project!.backgroundColor = editingVideoSettings!.backgroundColor;

    // Database'e kaydet
    projectService.update(project!);

    logger.i(
      '💾 Video Settings saved: ${editingVideoSettings!.aspectRatio}, ${editingVideoSettings!.cropMode}',
    );

    editingVideoSettings = null;
    _appBar.add(true);
  }

}