class Project {
  int? id;
  String title;
  String? description;
  DateTime date;
  int duration;
  String? layersJson;
  String? imagePath;
  
  // Video settings
  String? aspectRatio;
  String? cropMode;
  int? rotation;
  bool? flipHorizontal;
  bool? flipVertical;
  int? backgroundColor;

  Project({
    required this.title,
    this.description,
    required this.date,
    required this.duration,
    this.layersJson,
    this.imagePath,
    this.aspectRatio,
    this.cropMode,
    this.rotation,
    this.flipHorizontal,
    this.flipVertical,
    this.backgroundColor,
  });

  Map<String, dynamic> toMap() {
    var map = <String, dynamic>{
      'title': title,
      'description': description,
      'date': date.millisecondsSinceEpoch,
      'duration': duration,
      'layersJson': layersJson,
      'imagePath': imagePath,
      'aspectRatio': aspectRatio,
      'cropMode': cropMode,
      'rotation': rotation,
      'flipHorizontal': flipHorizontal == true ? 1 : 0,
      'flipVertical': flipVertical == true ? 1 : 0,
      'backgroundColor': backgroundColor,
    };
    if (id != null) {
      map['_id'] = id;
    }
    return map;
  }

  Project.fromMap(Map<String, dynamic> map)
      : id = map['_id'],
        title = map['title'],
        description = map['description'],
        date = DateTime.fromMillisecondsSinceEpoch(map['date']),
        duration = map['duration'],
        layersJson = map['layersJson'],
        imagePath = map['imagePath'],
        aspectRatio = map['aspectRatio'],
        cropMode = map['cropMode'],
        rotation = map['rotation'],
        flipHorizontal = map['flipHorizontal'] == 1,
        flipVertical = map['flipVertical'] == 1,
        backgroundColor = map['backgroundColor'];

  @override
  String toString() {
    return 'Project {'
        'id: $id, '
        'title: $title, '
        'description: $description, '
        'date: $date, '
        'duration: $duration, '
        'imagePath: $imagePath}';
  }
}
