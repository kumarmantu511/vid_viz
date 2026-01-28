import 'dart:io';
import 'package:rxdart/rxdart.dart';
import 'package:file_picker/file_picker.dart';
import 'package:vidviz/model/media_overlay.dart';
import 'package:vidviz/model/layer.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/export/native_generator.dart';

/// Media Overlay Service - Video/Image bindirme yönetimi
/// Text/Visualizer pattern'ini takip eder
class MediaOverlayService {
  // Editing state
  MediaOverlayAsset? _editingMediaOverlay;
  final BehaviorSubject<MediaOverlayAsset?> _editingMediaOverlay$ =
      BehaviorSubject<MediaOverlayAsset?>.seeded(null);

  // Available media sources for overlay
  List<Asset> _availableMediaSources = [];
  final BehaviorSubject<List<Asset>> _availableMediaSources$ =
      BehaviorSubject<List<Asset>>.seeded([]);

  // Getters
  MediaOverlayAsset? get editingMediaOverlay => _editingMediaOverlay;
  Stream<MediaOverlayAsset?> get editingMediaOverlay$ => _editingMediaOverlay$.stream;

  List<Asset> get availableMediaSources => _availableMediaSources;
  Stream<List<Asset>> get availableMediaSources$ => _availableMediaSources$.stream;

  // Setters
  set editingMediaOverlay(MediaOverlayAsset? value) {
    _editingMediaOverlay = value;
    _editingMediaOverlay$.add(value);
  }

  set availableMediaSources(List<Asset> value) {
    _availableMediaSources = value;
    _availableMediaSources$.add(value);
  }

  /// Start adding new media overlay
  Future<void> startAddingMediaOverlay(List<Asset> sources) async {
    availableMediaSources = sources;

    // If sources available, create default overlay with first source
    if (sources.isNotEmpty) {
      final firstSource = sources.first;
      editingMediaOverlay = MediaOverlayAsset(
        srcPath: firstSource.srcPath,
        thumbnailPath: firstSource.thumbnailPath,
        title: 'Media Overlay',
        duration: 5000, // Default 5 seconds
        begin: 0,
        mediaType: firstSource.type,
        x: 0.5, // Varsayılan olarak ekranın ortası
        y: 0.5,
        scale: 1.0, // Biraz daha büyük başlangıç boyutu
        opacity: 1.0,
      );
    }
  }

  /// Update source media
  void updateSourceMedia(Asset source) {
    if (_editingMediaOverlay == null) return;
    _editingMediaOverlay!.srcPath = source.srcPath;
    _editingMediaOverlay!.thumbnailPath = source.thumbnailPath;
    _editingMediaOverlay!.mediaType = source.type;
    _editingMediaOverlay!.title = source.title;
    editingMediaOverlay = _editingMediaOverlay; // Trigger stream
  }

  /// Convert Asset to MediaOverlayAsset
  MediaOverlayAsset assetToMediaOverlay(Asset asset) {
    return MediaOverlayAsset.fromAsset(asset);
  }

  /// Convert MediaOverlayAsset to Asset
  Asset mediaOverlayToAsset(MediaOverlayAsset overlay) {
    return overlay.toAsset();
  }

  /// Pick new media source (video or image) from device
  Future<void> pickNewMediaSource(bool isVideo) async {
    final generator = locator.get<Generator>();

    FilePickerResult? result;
    if (isVideo) {
      result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );
    } else {
      result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
    }

    if (result == null ||
        result.files.isEmpty ||
        result.files.first.path == null) {
      return;
    }

    final pickedPath = result.files.first.path!;
    final pickedFile = File(pickedPath);

    if (!pickedFile.existsSync()) {
      print('❌ Picked file does not exist: $pickedPath');
      return;
    }

    // Generate thumbnail (mini resolution for overlay preview)
    String? thumbnailPath;
    try {
      if (isVideo) {
        // Video thumbnail - use mini resolution
        final tempThumbPath = pickedPath.replaceAll(RegExp(r'\.[^.]+$'), '_thumb.jpg',);
        thumbnailPath = await generator.generateVideoThumbnail(
          pickedPath,
          tempThumbPath,
          0, // Position 0ms
          VideoResolution.mini,
        );
      } else {
        // Image thumbnail - use mini resolution
        final tempThumbPath = pickedPath.replaceAll(RegExp(r'\.[^.]+$'), '_thumb.jpg',);
        thumbnailPath = await generator.generateImageThumbnail(
          pickedPath,
          tempThumbPath,
          VideoResolution.mini,
        );
      }
    } catch (e) {
      print('⚠️ Thumbnail generation failed: $e');
      thumbnailPath = null;
    }

    // Get duration
    int duration = 5000; // Default for images
    if (isVideo) {
      duration = await generator.getVideoDuration(pickedPath);
      if (duration <= 0) {
        duration = 5000;
      }
    }

    // Create new Asset and add to available sources
    final newAsset = Asset(
      type: isVideo ? AssetType.video : AssetType.image,
      srcPath: pickedPath,
      thumbnailPath: thumbnailPath,
      title: pickedFile.uri.pathSegments.last,
      duration: duration,
      begin: 0,
    );

    // Add to available sources
    _availableMediaSources.add(newAsset);
    availableMediaSources = _availableMediaSources;

    // Auto-select the new source
    if (_editingMediaOverlay != null) {
      _editingMediaOverlay!.srcPath = newAsset.srcPath;
      _editingMediaOverlay!.thumbnailPath = newAsset.thumbnailPath;
      _editingMediaOverlay!.mediaType = newAsset.type;
      _editingMediaOverlay!.title = newAsset.title;
      editingMediaOverlay = _editingMediaOverlay; // Trigger stream
    }

    print('✅ New media picked: ${newAsset.title} (${isVideo ? "video" : "image"})',);
  }

  /// Dispose
  void dispose() {
    _editingMediaOverlay$.close();
    _availableMediaSources$.close();
  }
}
