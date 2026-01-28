part of 'package:vidviz/service/director_service.dart';

extension AddFunction on DirectorService {

  bool _isSupportedFileForAssetType(AssetType assetType, String path) {
    final ext = p.extension(path).toLowerCase();
    switch (assetType) {
      case AssetType.video:
        return ['.mp4', '.mov', '.avi', '.mkv', '.webm'].contains(ext);
      case AssetType.image:
        return ['.jpg', '.jpeg', '.png', '.webp', '.bmp', '.heic'].contains(ext);
      case AssetType.audio:
        return ['.mp3', '.wav', '.aac', '.m4a', '.flac', '.ogg'].contains(ext);
      default:
        return true;
    }
  }

  Future<void> add(AssetType assetType) async {
    if (isOperating) {
      logger.w('add: isOperating true, returning'); // Uyarı seviyesinde log
      return;
    }
    isAdding = true;
    print('>> DirectorService.add($assetType)');

    if (assetType == AssetType.text) {
      // Initialize a fresh TextAsset for editing (not yet on timeline)
      editingTextAsset = TextAsset(
        srcPath: '',
        title: '',
        duration: 5000,
        begin: 0,
      );
    } else if (assetType == AssetType.visualizer) {
      // Visualizer service'i kullan (Text pattern'i)
      final visualizerService = locator.get<VisualizerService>();

      // Mevcut layer'lardan ses kaynakları topla (video ve audio layer'ları)
      List<Asset> availableAudioSources = [];

      // Raster layer'dan video dosyaları
      if (layers != null && layers!.isNotEmpty) {
        for (final layer in layers!) {
          if (layer.type == 'raster') {
            for (Asset asset in layer.assets) {
              if (asset.type == AssetType.video && !asset.deleted) {
                availableAudioSources.add(asset);
              }
            }
          }
        }
      }

      // Audio layer'dan ses dosyaları
      if (layers != null && layers!.isNotEmpty) {
        for (final layer in layers!) {
          if (layer.type == 'audio') {
            for (Asset asset in layer.assets) {
              if (asset.type == AssetType.audio && !asset.deleted) {
                availableAudioSources.add(asset);
              }
            }
          }
        }
      }
      // FFT işlemi arka planda çalışsın, UI'ı bloklamasın
      visualizerService.startAddingVisualizer(availableAudioSources);
    } else if (assetType == AssetType.shader) {
      // Shader effect service'i kullan (Text/Visualizer pattern'i)
      final shaderEffectService = locator.get<ShaderEffectService>();

      // Mevcut layer'lardan media kaynakları topla (video ve image layer'ları)
      List<Asset> availableMediaSources = [];

      // Raster layer'dan video ve image dosyaları
      if (layers != null && layers!.isNotEmpty) {
        for (final layer in layers!) {
          if (layer.type == 'raster') {
            for (Asset asset in layer.assets) {
              if ((asset.type == AssetType.video ||
                  asset.type == AssetType.image) &&
                  !asset.deleted) {
                availableMediaSources.add(asset);
              }
            }
          }
        }
      }
      await shaderEffectService.startAddingShaderEffect(availableMediaSources);
    }

    isAdding = false;
  }

  Future<void> mediaAdd(AssetType assetType, List<String> mediaPaths) async {
    if (isOperating || layers == null || mediaPaths.isEmpty) {
      return;
    }

    isAdding = true;
    print('>> DirectorService.mediaAdd($assetType)');

    try {
      final fileList = mediaPaths
          .map((path) => File(path))
          .where((file) => file.existsSync())
          .where((file) => _isSupportedFileForAssetType(assetType, file.path))
          .toList()
        ..sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()),);

      if (fileList.isEmpty) {
        return;
      }

      if (assetType == AssetType.video) {
        int mainIdx = getMainRasterLayerIndex();
        if (mainIdx < 0) {
          layers!.add(Layer(type: "raster", volume: 1.0));
          final newIndex = layers!.length - 1;
          if (layerPlayers.length < layers!.length) {
            layerPlayers.add(LayerPlayer(layers![newIndex]));
          } else {
            layerPlayers.insert(newIndex, LayerPlayer(layers![newIndex]));
          }
          mainIdx = newIndex;
        }
        for (final file in fileList) {
          await _addAssetToLayer(mainIdx, AssetType.video, file.path);
        }
        _generateAllVideoThumbnails(layers![mainIdx].assets);
      }
      else if (assetType == AssetType.image) {
        int mainIdx = getMainRasterLayerIndex();
        if (mainIdx < 0) {
          layers!.add(Layer(type: "raster", volume: 1.0));
          final newIndex = layers!.length - 1;
          if (layerPlayers.length < layers!.length) {
            layerPlayers.add(LayerPlayer(layers![newIndex]));
          } else {
            layerPlayers.insert(newIndex, LayerPlayer(layers![newIndex]));
          }
          mainIdx = newIndex;
        }
        for (final file in fileList) {
          await _addAssetToLayer(mainIdx, AssetType.image, file.path);
          _generateKenBurnEffects(layers![mainIdx].assets.last);
        }
        _generateAllImageThumbnails(layers![mainIdx].assets);
      }
      else if (assetType == AssetType.audio) {
        int audioLayerIdx = 2;
        for (int idx = 0; idx < layers!.length; idx++) {
          if (layers![idx].type == 'audio') {
            audioLayerIdx = idx;
            break;
          }
        }
        for (final file in fileList) {
          await _addAssetToLayer(
            audioLayerIdx,
            AssetType.audio,
            file.path,
          );
        }
      }
    } finally {
      isAdding = false;
    }
  }

  /// Add Media Overlay - Video/Image bindirme ekleme
  Future<void> addMediaOverlay() async {
    if (isOperating) {
      logger.w('addMediaOverlay: isOperating true, returning');
      return;
    }
    isAdding = true;
    print('>> DirectorService.addMediaOverlay()');

    final mediaOverlayService = locator.get<MediaOverlayService>();

    // Collect available media sources from raster layers
    List<Asset> availableMediaSources = [];
    if (layers != null && layers!.isNotEmpty) {
      for (final layer in layers!) {
        if (layer.type == 'raster') {
          for (Asset asset in layer.assets) {
            if ((asset.type == AssetType.video ||
                asset.type == AssetType.image) &&
                !asset.deleted) {
              availableMediaSources.add(asset);
            }
          }
        }
      }
    }

    if (availableMediaSources.isEmpty) {
      logger.w('No media sources available for overlay');
      isAdding = false;
      return;
    }

    await mediaOverlayService.startAddingMediaOverlay(availableMediaSources);
  }

  /// Add Audio Reactive - Overlay'leri müziğe göre hareket ettirme
  Future<void> addAudioReactive() async {
    if (isOperating) {
      logger.w('addAudioReactive: isOperating true, returning');
      return;
    }
    isAdding = true;
    print('>> DirectorService.addAudioReactive()');

    final audioReactiveService = locator.get<AudioReactiveService>();

    // Collect available overlays (text, visualizer, media, shader)
    List<Asset> availableOverlays = [];
    if (layers != null && layers!.isNotEmpty) {
      for (final layer in layers!) {
        if (layer.type == 'overlay' ||
            layer.type == 'vector' ||
            layer.type == 'visualizer' ||
            layer.type == 'shader') {
          for (Asset asset in layer.assets) {
            final overlayType = asset.data?['overlayType'];
            final bool isOverlayTarget =
                asset.type == AssetType.text ||
                    asset.type == AssetType.visualizer ||
                    asset.type == AssetType.shader ||
                    overlayType == 'media';
            if (!asset.deleted &&
                isOverlayTarget &&
                overlayType != 'audio_reactive') {
              availableOverlays.add(asset);
            }
          }
        }
      }
    }

    if (availableOverlays.isEmpty) {
      logger.w('No overlays available for audio reactive');
      isAdding = false;
      return;
    }

    // Collect available audio sources (audio tracks + raster video with audio)
    List<Asset> availableAudioSources = [];
    Asset? activeAudioSource;
    final int currentPos = position;

    if (layers != null && layers!.isNotEmpty) {
      for (int li = 0; li < layers!.length; li++) {
        final layer = layers![li];
        if (layer.type == 'audio') {
          for (final asset in layer.assets) {
            if (asset.type == AssetType.audio && !asset.deleted) {
              availableAudioSources.add(asset);
              if (activeAudioSource == null &&
                  asset.begin <= currentPos &&
                  currentPos < asset.begin + asset.duration) {
                activeAudioSource = asset;
              }
            }
          }
        } else if (layer.type == 'raster' && layer.useVideoAudio) {
          for (final asset in layer.assets) {
            if (asset.type == AssetType.video && !asset.deleted) {
              availableAudioSources.add(asset);
              if (activeAudioSource == null &&
                  asset.begin <= currentPos &&
                  currentPos < asset.begin + asset.duration) {
                activeAudioSource = asset;
              }
            }
          }
        }
      }
    }

    // Smart default: prefer the source that is active at current position
    if (activeAudioSource != null) {
      final String activeId = activeAudioSource.id;
      availableAudioSources.removeWhere((a) => a.id == activeId);
      availableAudioSources.insert(0, activeAudioSource);
    }

    // Prefer overlays that are active at current position
    if (availableOverlays.isNotEmpty) {
      final List<Asset> activeOverlays = [];
      final List<Asset> inactiveOverlays = [];
      for (final overlay in availableOverlays) {
        if (overlay.begin <= currentPos &&
            currentPos < overlay.begin + overlay.duration) {
          activeOverlays.add(overlay);
        } else {
          inactiveOverlays.add(overlay);
        }
      }
      availableOverlays = [...activeOverlays, ...inactiveOverlays];
    }

    await audioReactiveService.startAddingAudioReactive(
      availableOverlays,
      availableAudioSources,
    );
  }

  _addAssetToLayer(int layerIndex, AssetType type, String srcPath) async {
    if (layers == null) return;
    print('_addAssetToLayer: $srcPath');

    final AssetType safeType = _isSupportedFileForAssetType(type, srcPath)
        ? type
        : (type == AssetType.video ? AssetType.image : type);

    final bool hadAnyVideoBefore = (safeType == AssetType.video)
        ? layers![layerIndex].assets.any(
          (a) => a.type == AssetType.video && !a.deleted,
        )
        : false;

    final bool shouldAutoSetProjectAspect =
        project != null &&
        (
          project!.aspectRatio == null ||
          project!.aspectRatio!.isEmpty ||
          (
            project!.aspectRatio == '16:9' &&
            project!.cropMode == null &&
            project!.rotation == null &&
            project!.flipHorizontal == null &&
            project!.flipVertical == null &&
            project!.backgroundColor == null
          )
        );

    final int mainRasterIdxNow = getMainRasterLayerIndex();
    final bool isMainRasterTarget =
        (layerIndex == mainRasterIdxNow) ||
        (mainRasterIdxNow < 0 && layers![layerIndex].type == 'raster');

    if (safeType == AssetType.video &&
        !hadAnyVideoBefore &&
        shouldAutoSetProjectAspect &&
        isMainRasterTarget) {
      final probe = await mediaProbe.probeVideo(srcPath);
      if (probe != null) {
        final ar = mediaProbe.closestPresetAspect(
          probe.displayWidth,
          probe.displayHeight,
        );
        project!.aspectRatio = ar;
      }
    }

    int? assetDuration;
    if (safeType == AssetType.video || safeType == AssetType.audio) {
      assetDuration = await generator.getVideoDuration(srcPath);
    } else {
      assetDuration = 5000;
    }

    layers![layerIndex].assets.add(
      Asset(
        type: safeType,
        srcPath: srcPath,
        title: p.basename(srcPath),
        duration: assetDuration,
        begin: layers![layerIndex].assets.isEmpty
            ? 0
            : layers![layerIndex].assets.last.begin +
            layers![layerIndex].assets.last.duration,
      ),
    );

    try {
      final audioAnalysis = locator.get<AudioAnalysisService>();
      if (safeType == AssetType.audio) {
        audioAnalysis.warmupPCM(srcPath);
      } else if (safeType == AssetType.video) {
        final layer = layers![layerIndex];
        if (layer.type == 'raster' && layer.useVideoAudio) {
          audioAnalysis.warmupPCM(srcPath);
        }
      }
    } catch (_) {}

    layerPlayers[layerIndex]!.addMediaSource(
      layers![layerIndex].assets.length - 1,
      layers![layerIndex].assets.last,
    );

    _layersChanged.add(true);
    _appBar.add(true);
  }
}