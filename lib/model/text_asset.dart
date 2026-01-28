import 'package:vidviz/model/layer.dart';

/// TextAsset: Text-specific model isolated from generic Asset
/// - Holds only text-related fields
/// - Provides adapters to convert to/from core Asset for timeline/storage
class TextAsset {
  // Common timeline fields
  String srcPath;
  String title;
  int duration;
  int begin;
  double x;
  double y;
  bool deleted;

  // Text appearance
  String font;
  double fontSize;
  int fontColor;
  double alpha;

  // Decorations
  double borderw;
  int bordercolor;
  int shadowcolor;
  double shadowx;
  double shadowy;
  double shadowBlur;
  bool box;
  double boxborderw;
  int boxcolor;
  double boxPad;
  double boxRadius;
  double glowRadius;
  int glowColor;

  // Text shader effect (applies to glyph fill via ShaderMask)
  String
  effectType; // e.g. 'none', 'gradient_fill', 'wave_fill', 'glitch_fill', 'metallic_fill'
  double effectIntensity; // 0..1
  int effectColorA; // primary color
  int effectColorB; // secondary color
  double effectSpeed; // general speed param
  double effectThickness; // outline/thickness-like param
  double effectAngle; // degrees/radians based orientation

  // Text animation (transform over time). Can be used with effect simultaneously
  String animType; // e.g. 'none', 'typing', 'bounce', 'wave'
  double animSpeed; // 0.5..2.0
  double animAmplitude; // amount of transform
  double animPhase; // offset

  TextAsset({
    this.srcPath = '',
    this.title = '',
    this.duration = 5000,
    this.begin = 0,
    this.x = 0.1,
    this.y = 0.4,// sornadna biz4 yaptık center için
    this.deleted = false,
    this.font = 'Lato/Lato-Regular.ttf',
    this.fontSize = 0.1,
    this.fontColor = 0xFFFFFFFF,
    this.alpha = 1.0,
    this.borderw = 0.0,
    this.bordercolor = 0xFFFFFFFF,
    this.shadowcolor = 0xFFFFFFFF,
    this.shadowx = 0.0,
    this.shadowy = 0.0,
    this.shadowBlur = 0.0,
    this.box = false,
    this.boxborderw = 0.0,
    this.boxcolor = 0x88000000,
    this.boxPad = 0.0,
    this.boxRadius = 4.0,
    this.glowRadius = 0.0,
    this.glowColor = 0xFFFFFFFF,
    // Effects defaults
    this.effectType = 'none',
    this.effectIntensity = 0.7,
    this.effectColorA = 0xFF00FFFF,
    this.effectColorB = 0xFFFF00FF,
    this.effectSpeed = 1.0,
    this.effectThickness = 1.0,
    this.effectAngle = 0.0,
    // Anim defaults
    this.animType = 'none',
    this.animSpeed = 1.0,
    this.animAmplitude = 0.0,
    this.animPhase = 0.0,
  });

  TextAsset.clone(TextAsset a)
    : srcPath = a.srcPath,
      title = a.title,
      duration = a.duration,
      begin = a.begin,
      x = a.x,
      y = a.y,
      deleted = a.deleted,
      font = a.font,
      fontSize = a.fontSize,
      fontColor = a.fontColor,
      alpha = a.alpha,
      borderw = a.borderw,
      bordercolor = a.bordercolor,
      shadowcolor = a.shadowcolor,
      shadowx = a.shadowx,
      shadowy = a.shadowy,
      shadowBlur = a.shadowBlur,
      box = a.box,
      boxborderw = a.boxborderw,
      boxcolor = a.boxcolor,
      boxPad = a.boxPad,
      boxRadius = a.boxRadius,
      glowRadius = a.glowRadius,
      glowColor = a.glowColor,
      effectType = a.effectType,
      effectIntensity = a.effectIntensity,
      effectColorA = a.effectColorA,
      effectColorB = a.effectColorB,
      effectSpeed = a.effectSpeed,
      effectThickness = a.effectThickness,
      effectAngle = a.effectAngle,
      animType = a.animType,
      animSpeed = a.animSpeed,
      animAmplitude = a.animAmplitude,
      animPhase = a.animPhase;

  // JSON helpers for Asset.data storage
  TextAsset.fromJson(Map<String, dynamic> map)
    : srcPath = map['srcPath'] ?? '',
      title = map['title'] ?? '',
      duration = (map['duration'] as num?)?.toInt() ?? 0,
      begin = (map['begin'] as num?)?.toInt() ?? 0,
      x = (map['x'] as num?)?.toDouble() ?? 0.1,
      y = (map['y'] as num?)?.toDouble() ?? 0.1,
      deleted = map['deleted'] ?? false,
      font = map['font'] ?? 'Lato/Lato-Regular.ttf',
      fontSize = (map['fontSize'] as num?)?.toDouble() ?? 0.1,
      fontColor = (map['fontColor'] as num?)?.toInt() ?? 0xFFFFFFFF,
      alpha = (map['alpha'] as num?)?.toDouble() ?? 1.0,
      borderw = (map['borderw'] as num?)?.toDouble() ?? 0.0,
      bordercolor = (map['bordercolor'] as num?)?.toInt() ?? 0xFFFFFFFF,
      shadowcolor = (map['shadowcolor'] as num?)?.toInt() ?? 0xFFFFFFFF,
      shadowx = (map['shadowx'] as num?)?.toDouble() ?? 0.0,
      shadowy = (map['shadowy'] as num?)?.toDouble() ?? 0.0,
      shadowBlur = (map['shadowBlur'] as num?)?.toDouble() ?? 0.0,
      box = map['box'] ?? false,
      boxborderw = (map['boxborderw'] as num?)?.toDouble() ?? 0.0,
      boxcolor = (map['boxcolor'] as num?)?.toInt() ?? 0x88000000,
      boxPad = (map['boxPad'] as num?)?.toDouble() ?? 0.0,
      boxRadius = (map['boxRadius'] as num?)?.toDouble() ?? 4.0,
      glowRadius = (map['glowRadius'] as num?)?.toDouble() ?? 0.0,
      glowColor = (map['glowColor'] as num?)?.toInt() ?? 0xFFFFFFFF,
      effectType = map['effectType'] ?? 'none',
      effectIntensity = (map['effectIntensity'] as num?)?.toDouble() ?? 0.7,
      effectColorA = (map['effectColorA'] as num?)?.toInt() ?? 0xFF00FFFF,
      effectColorB = (map['effectColorB'] as num?)?.toInt() ?? 0xFFFF00FF,
      effectSpeed = (map['effectSpeed'] as num?)?.toDouble() ?? 1.0,
      effectThickness = (map['effectThickness'] as num?)?.toDouble() ?? 1.0,
      effectAngle = (map['effectAngle'] as num?)?.toDouble() ?? 0.0,
      animType = map['animType'] ?? 'none',
      animSpeed = (map['animSpeed'] as num?)?.toDouble() ?? 1.0,
      animAmplitude = (map['animAmplitude'] as num?)?.toDouble() ?? 0.0,
      animPhase = (map['animPhase'] as num?)?.toDouble() ?? 0.0;

  Map<String, dynamic> toJson() => {
    'srcPath': srcPath,
    'title': title,
    'duration': duration,
    'begin': begin,
    'x': x,
    'y': y,
    'deleted': deleted,
    'font': font,
    'fontSize': fontSize,
    'fontColor': fontColor,
    'alpha': alpha,
    'borderw': borderw,
    'bordercolor': bordercolor,
    'shadowcolor': shadowcolor,
    'shadowx': shadowx,
    'shadowy': shadowy,
    'shadowBlur': shadowBlur,
    'box': box,
    'boxborderw': boxborderw,
    'boxcolor': boxcolor,
    'boxPad': boxPad,
    'boxRadius': boxRadius,
    'glowRadius': glowRadius,
    'glowColor': glowColor,
    'effectType': effectType,
    'effectIntensity': effectIntensity,
    'effectColorA': effectColorA,
    'effectColorB': effectColorB,
    'effectSpeed': effectSpeed,
    'effectThickness': effectThickness,
    'effectAngle': effectAngle,
    'animType': animType,
    'animSpeed': animSpeed,
    'animAmplitude': animAmplitude,
    'animPhase': animPhase,
  };

  /// Adapter: build TextAsset from generic Asset
  static TextAsset fromAsset(Asset a) {
    if (a.data != null && a.data!['text'] != null) {
      final Map<String, dynamic> m = Map<String, dynamic>.from(a.data!['text']);
      final t = TextAsset.fromJson(m);
      if (a.duration > 0) {
        t.duration = a.duration;
      }
      if (a.begin >= 0) {
        t.begin = a.begin;
      }
      t.srcPath = a.srcPath;
      t.title = a.title;
      return t;
    }
    // Fallback for new, unsaved editing assets
    return TextAsset(
      srcPath: a.srcPath,
      title: a.title,
      duration: a.duration,
      begin: a.begin,
    );
  }

  /// Adapter: convert TextAsset back to generic Asset for timeline/storage
  Asset toAsset() {
    return Asset(
      type: AssetType.text,
      srcPath: srcPath,
      title: title,
      duration: duration,
      begin: begin,
      data: {'text': toJson()},
    );
  }
}
