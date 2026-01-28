part of 'package:vidviz/service/director_service.dart';

extension ThumbnailFunction on DirectorService {


  _generateKenBurnEffects(Asset asset) {
    asset.kenBurnZSign = math.Random().nextInt(2) - 1;
    asset.kenBurnXTarget = (math.Random().nextInt(2) / 2).toDouble();
    asset.kenBurnYTarget = (math.Random().nextInt(2) / 2).toDouble();
    if (asset.kenBurnZSign == 0 &&
        asset.kenBurnXTarget == 0.5 &&
        asset.kenBurnYTarget == 0.5) {
      asset.kenBurnZSign = 1;
    }
  }

  _generateAllVideoThumbnails(List<Asset> assets) async {
    await _generateVideoThumbnails(assets, VideoResolution.mini);
    await _generateVideoThumbnails(assets, VideoResolution.sd);
  }

  _generateVideoThumbnails(List<Asset> assets, VideoResolution videoResolution,) async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    await Directory(p.join(appDocDir.path, 'thumbnails')).create();

    // Parallel thumbnail generation for better performance
    final futures = <Future<void>>[];

    for (int i = 0; i < assets.length; i++) {
      Asset asset = assets[i];
      if (((videoResolution == VideoResolution.mini &&
          asset.thumbnailPath == null) ||
          asset.thumbnailMedPath == null) &&
          !asset.deleted) {
        futures.add(() async {
          try {
            String thumbnailFileName =
                p.setExtension(asset.srcPath, '').split('/').last +
                    '_pos_${asset.cutFrom}.jpg';
            String thumbnailPath = p.join(
              appDocDir.path,
              'thumbnails',
              thumbnailFileName,
            );
            thumbnailPath = await generator.generateVideoThumbnail(
              asset.srcPath,
              thumbnailPath,
              asset.cutFrom,
              videoResolution,
            );

            if (videoResolution == VideoResolution.mini) {
              asset.thumbnailPath = thumbnailPath;
            } else {
              asset.thumbnailMedPath = thumbnailPath;
            }
          } catch (e) {
            logger.e('Thumbnail generation failed for ${asset.srcPath}: $e');
          }
        }());
      }
    }

    // Wait for all thumbnails to complete
    if (futures.isNotEmpty) {
      await Future.wait(futures);
      _layersChanged.add(true);
    }
  }

  _generateAllImageThumbnails(List<Asset> assets) async {
    await _generateImageThumbnails(assets, VideoResolution.mini);
    await _generateImageThumbnails(assets, VideoResolution.sd);
  }

  _generateImageThumbnails(List<Asset> assets, VideoResolution videoResolution,) async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    await Directory(p.join(appDocDir.path, 'thumbnails')).create();

    // Parallel thumbnail generation for better performance
    final futures = <Future<void>>[];

    for (int i = 0; i < assets.length; i++) {
      Asset asset = assets[i];
      if (((videoResolution == VideoResolution.mini &&
          asset.thumbnailPath == null) ||
          asset.thumbnailMedPath == null) &&
          !asset.deleted) {
        futures.add(() async {
          try {
            String thumbnailFileName =
                p.setExtension(asset.srcPath, '').split('/').last + '_min.jpg';
            String thumbnailPath = p.join(
              appDocDir.path,
              'thumbnails',
              thumbnailFileName,
            );
            thumbnailPath = await generator.generateImageThumbnail(
              asset.srcPath,
              thumbnailPath,
              videoResolution,
            );

            if (videoResolution == VideoResolution.mini) {
              asset.thumbnailPath = thumbnailPath;
            } else {
              asset.thumbnailMedPath = thumbnailPath;
            }
          } catch (e) {
            logger.e(
              'Image thumbnail generation failed for ${asset.srcPath}: $e',
            );
          }
        }());
      }
    }

    // Wait for all thumbnails to complete
    if (futures.isNotEmpty) {
      await Future.wait(futures);
      _layersChanged.add(true);
    }
  }


  String? getFirstThumbnailMedPath() {
    if (layers == null || layers!.isEmpty) return null;
    final mainLayer = getMainRasterLayer();
    if (mainLayer == null) return null;
    for (int i = 0; i < mainLayer.assets.length; i++) {
      Asset asset = mainLayer.assets[i];
      if (asset.thumbnailMedPath != null &&
          File(asset.thumbnailMedPath!).existsSync()) {
        return asset.thumbnailMedPath!;
      }
    }
    return null;
  }


}