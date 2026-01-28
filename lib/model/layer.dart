class Layer {
  String id;
  String type; // TODO: enums (e.g., 'raster', 'vector', 'audio', 'visualizer', 'shader', 'overlay')
  String name;
  int zIndex;
  List<Asset> assets;
  double volume;
  bool mute;
  bool useVideoAudio; // for raster: include embedded video audio in export/mix
  Layer({
    String? id,
    required this.type,
    String? name,
    int? zIndex,
    List<Asset>? assets,
    required this.volume,
    bool? mute,
    bool? useVideoAudio,
  })  : id = id ?? 'lyr_${DateTime.now().microsecondsSinceEpoch}',
        name = name ?? type,
        zIndex = zIndex ?? 0,
        assets = assets ?? <Asset>[],
        mute = mute ?? false,
        // Default: enable embedded video audio for raster layers
        useVideoAudio = useVideoAudio ?? (type == 'raster');

  Layer.clone(Layer layer)
      : id = layer.id,
        type = layer.type,
        name = layer.name,
        zIndex = layer.zIndex,
        assets = layer.assets.map((asset) => Asset.clone(asset)).toList(),
        volume = layer.volume,
        mute = layer.mute,
        useVideoAudio = layer.useVideoAudio;

  Layer.fromJson(Map<String, dynamic> map)
      : id = (map['id'] as String?) ?? 'lyr_${DateTime.now().microsecondsSinceEpoch}',
        type = map['type'],
        name = (map['name'] as String?) ?? (map['type'] as String? ?? 'layer'),
        zIndex = (map['zIndex'] as num?)?.toInt() ?? 0,
        assets = List<Asset>.from(map['assets'].map((json) => Asset.fromJson(json)).toList()),
        volume = (map['volume'] as num?)?.toDouble() ?? 1.0,
        mute = (map['mute'] as bool?) ?? false,
        // Backward-compatible default: ON for raster layers when missing
        useVideoAudio = (map['useVideoAudio'] as bool?) ?? ((map['type'] as String?) == 'raster');

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'name': name,
        'zIndex': zIndex,
        'assets': assets.map((asset) => asset.toJson()).toList(),
        'volume': volume,
        'mute': mute,
        'useVideoAudio': useVideoAudio,
      };
}

enum AssetType {
  video,
  image,
  text,
  audio,
  visualizer,
  shader,
}

class Asset {
  String id;
  AssetType type;
  String srcPath;
  String? thumbnailPath;
  String? thumbnailMedPath;
  String title;
  int duration;
  int begin;
  int cutFrom;
  double playbackSpeed;

  int kenBurnZSign;
  double kenBurnXTarget;
  double kenBurnYTarget;
  bool deleted;
  // Feature-specific serialized model (e.g., TextAsset/VisualizerAsset/ShaderEffectAsset)
  Map<String, dynamic>? data;

  Asset({
    String? id,
    required this.type,
    required this.srcPath,
    this.thumbnailPath,
    this.thumbnailMedPath,
    required this.title,
    required this.duration,
    required this.begin,
    this.cutFrom = 0,
    this.playbackSpeed = 1.0,
    this.kenBurnZSign = 0,
    this.kenBurnXTarget = 0.5,
    this.kenBurnYTarget = 0.5,
    this.deleted = false,
    this.data,
  }) : id = id ?? 'ast_${DateTime.now().microsecondsSinceEpoch}';

  Asset.clone(Asset asset)
      : id = asset.id,
        type = asset.type,
        srcPath = asset.srcPath,
        thumbnailPath = asset.thumbnailPath,
        thumbnailMedPath = asset.thumbnailMedPath,
        title = asset.title,
        duration = asset.duration,
        begin = asset.begin,
        cutFrom = asset.cutFrom,
        playbackSpeed = asset.playbackSpeed,
        kenBurnZSign = asset.kenBurnZSign,
        kenBurnXTarget = asset.kenBurnXTarget,
        kenBurnYTarget = asset.kenBurnYTarget,
        deleted = asset.deleted,
        data = asset.data == null ? null : Map<String, dynamic>.from(asset.data!);

  Asset.fromJson(Map<String, dynamic> map)
      : id = (map['id'] as String?) ?? 'ast_${DateTime.now().microsecondsSinceEpoch}',
        type = getAssetTypeFromString(map['type']) ?? AssetType.image,
        srcPath = map['srcPath'] ?? '',
        thumbnailPath = map['thumbnailPath'],
        thumbnailMedPath = map['thumbnailMedPath'],
        title = map['title'] ?? '',
        duration = (map['duration'] as num?)?.toInt() ?? 0,
        begin = (map['begin'] as num?)?.toInt() ?? 0,
        cutFrom = (map['cutFrom'] as num?)?.toInt() ?? 0,
        playbackSpeed = (map['playbackSpeed'] as num?)?.toDouble() ?? 1.0,
        kenBurnZSign = (map['kenBurnZSign'] as num?)?.toInt() ?? 0,
        kenBurnXTarget = (map['kenBurnXTarget'] as num?)?.toDouble() ?? 0.5,
        kenBurnYTarget = (map['kenBurnYTarget'] as num?)?.toDouble() ?? 0.5,
        deleted = map['deleted'] ?? false,
        data = (map['data'] as Map<String, dynamic>?);

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.toString(),
        'srcPath': srcPath,
        'thumbnailPath': thumbnailPath,
        'thumbnailMedPath': thumbnailMedPath,
        'title': title,
        'duration': duration,
        'begin': begin,
        'cutFrom': cutFrom,
        'playbackSpeed': playbackSpeed,
        'kenBurnZSign': kenBurnZSign,
        'kenBurnXTarget': kenBurnXTarget,
        'kenBurnYTarget': kenBurnYTarget,
        'deleted': deleted,
        'data': data,
      };

  static AssetType? getAssetTypeFromString(String assetTypeAsString) {
    for (AssetType element in AssetType.values) {
      if (element.toString() == assetTypeAsString) {
        return element;
      }
    }
    return null;
  }
}

class Selected {
  int layerIndex;
  int assetIndex;
  double initScrollOffset;
  double incrScrollOffset;
  double dragX;
  int closestAsset;
  Selected(this.layerIndex, this.assetIndex,
      {this.dragX = 0,
      this.closestAsset = -1,
      this.initScrollOffset = 0,
      this.incrScrollOffset = 0});

  bool isSelected(int layerIndex, int assetIndex) {
    return (layerIndex == this.layerIndex && assetIndex == this.assetIndex);
  }
}
