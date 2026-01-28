class VideoSettings {
  String aspectRatio;
  String cropMode;
  int rotation;
  bool flipHorizontal;
  bool flipVertical;
  int backgroundColor;

  VideoSettings({
    this.aspectRatio = '16:9',
    this.cropMode = 'fit',
    this.rotation = 0,
    this.flipHorizontal = false,
    this.flipVertical = false,
    this.backgroundColor = 0xFF000000,
  });

  VideoSettings.clone(VideoSettings settings)
      : aspectRatio = settings.aspectRatio,
        cropMode = settings.cropMode,
        rotation = settings.rotation,
        flipHorizontal = settings.flipHorizontal,
        flipVertical = settings.flipVertical,
        backgroundColor = settings.backgroundColor;

  Map<String, dynamic> toJson() => {
        'aspectRatio': aspectRatio,
        'cropMode': cropMode,
        'rotation': rotation,
        'flipHorizontal': flipHorizontal,
        'flipVertical': flipVertical,
        'backgroundColor': backgroundColor,
      };

  VideoSettings.fromJson(Map<String, dynamic> json)
      : aspectRatio = json['aspectRatio'] ?? '16:9',
        cropMode = json['cropMode'] ?? 'fit',
        rotation = json['rotation'] ?? 0,
        flipHorizontal = json['flipHorizontal'] ?? false,
        flipVertical = json['flipVertical'] ?? false,
        backgroundColor = json['backgroundColor'] ?? 0xFF000000;
}
