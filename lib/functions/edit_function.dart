part of 'package:vidviz/service/director_service.dart';

extension EditFunction on DirectorService {



  editTextAsset() {
    if (assetSelected == null) return;
    if (assetSelected!.type != AssetType.text) return;
    editingTextAsset = TextAsset.fromAsset(assetSelected!);
    scrollController.animateTo(
      assetSelected!.begin / 1000 * pixelsPerSecond,
      duration: Duration(milliseconds: 300),
      curve: Curves.linear,
    );
  }

  editVisualizerAsset() {
    final visualizerService = locator.get<VisualizerService>();
    if (assetSelected == null) return;
    if (assetSelected!.type != AssetType.visualizer) return;
    final vis = VisualizerAsset.fromAsset(assetSelected!);
    visualizerService.editingVisualizerAsset = vis;
    visualizerService.editingLayerIndex = selected.layerIndex;
    visualizerService.editingAssetIndex = selected.assetIndex;

    // Progress modunda, paneli açınca timeline'ı asset.begin'e zıplatma;
    // progress bar'ın anlık pozisyonu göstermeye devam etmesi için mevcut position'u koru.
    if (vis.renderMode != 'progress') {
      scrollController.animateTo(
        assetSelected!.begin / 1000 * pixelsPerSecond,
        duration: Duration(milliseconds: 300),
        curve: Curves.linear,
      );
    }
  }

  editShaderEffectAsset() {
    final shaderEffectService = locator.get<ShaderEffectService>();
    if (assetSelected == null) return;
    if (assetSelected!.type != AssetType.shader) return;
    // Asset'i ShaderEffectAsset'e dönüştür (Text pattern'i)
    shaderEffectService.editingShaderEffectAsset = shaderEffectService
        .assetToShaderEffect(assetSelected!);
    scrollController.animateTo(
      assetSelected!.begin / 1000 * pixelsPerSecond,
      duration: Duration(milliseconds: 300),
      curve: Curves.linear,
    );
  }

  editMediaOverlayAsset() {
    final mediaOverlayService = locator.get<MediaOverlayService>();
    if (assetSelected == null) return;
    if (assetSelected!.type != AssetType.image ||
        assetSelected!.data?['overlayType'] != 'media')
      return;

    // Collect available media sources
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
    mediaOverlayService.availableMediaSources = availableMediaSources;

    // Asset'i MediaOverlayAsset'e dönüştür
    mediaOverlayService.editingMediaOverlay = mediaOverlayService
        .assetToMediaOverlay(assetSelected!);
    scrollController.animateTo(
      assetSelected!.begin / 1000 * pixelsPerSecond,
      duration: Duration(milliseconds: 300),
      curve: Curves.linear,
    );
  }

  editAudioReactiveAsset() {
    final audioReactiveService = locator.get<AudioReactiveService>();
    if (assetSelected == null) return;
    if (assetSelected!.type != AssetType.image ||
        assetSelected!.data?['overlayType'] != 'audio_reactive')
      return;

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

    // Prefer overlays that are active at current position
    final int currentPos = position;
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

    // Collect available audio sources
    List<Asset> availableAudioSources = [];
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

    audioReactiveService.availableOverlays = availableOverlays;
    audioReactiveService.availableAudioSources = availableAudioSources;

    // Asset'i AudioReactiveAsset'e dönüştür
    audioReactiveService.editingAudioReactive = audioReactiveService
        .assetToAudioReactive(assetSelected!);
    scrollController.animateTo(
      assetSelected!.begin / 1000 * pixelsPerSecond,
      duration: Duration(milliseconds: 300),
      curve: Curves.linear,
    );
  }

  // Video Settings için edit metodu (sadece video/image asset seçiliyken)
  editVideoSettings() {
    if (project == null) return;
    if (assetSelected == null) return;

    // Sadece video veya image asset için
    if (assetSelected!.type != AssetType.video &&
        assetSelected!.type != AssetType.image)
      return;

    // Sadece raster layer'daki asset'ler için (overlay değil)
    if (selected.layerIndex >= 0 && selected.layerIndex < layers!.length) {
      if (layers![selected.layerIndex].type != 'raster') return;
    }

    // Project'ten mevcut ayarları al veya default değerler kullan
    editingVideoSettings = VideoSettings(
      aspectRatio: project!.aspectRatio ?? '16:9',
      cropMode: project!.cropMode ?? 'fit',
      rotation: project!.rotation ?? 0,
      flipHorizontal: project!.flipHorizontal ?? false,
      flipVertical: project!.flipVertical ?? false,
      backgroundColor: project!.backgroundColor ?? 0xFF000000,
    );

    scrollController.animateTo(
      assetSelected!.begin / 1000 * pixelsPerSecond,
      duration: Duration(milliseconds: 300),
      curve: Curves.linear,
    );
    logger.i('🎬 Video Settings editing started for ${assetSelected!.type}');
  }


}