import 'package:sqflite/sqflite.dart';
import 'package:vidviz/model/project.dart';
import 'package:vidviz/model/generated.dart';

class ProjectDao {
  late Database db;

  final migrationScripts = [
'''
create table project (
  _id integer primary key autoincrement
  , title text not null
  , description text
  , date integer not null
  , duration integer not null
  , layersJson text
  , imagePath text
)
''',
'''
create table generatedVideo (
  _id integer primary key autoincrement
  , projectId integer not null
  , path text not null
  , date integer not null
  , resolution text
  , thumbnail text
)
''',
 // Migration 2: Add video settings columns
'''
ALTER TABLE project ADD COLUMN aspectRatio text;
''',
'''
ALTER TABLE project ADD COLUMN cropMode text;
''',
'''
ALTER TABLE project ADD COLUMN rotation integer;
''',
'''
ALTER TABLE project ADD COLUMN flipHorizontal integer DEFAULT 0;
''',
'''
ALTER TABLE project ADD COLUMN flipVertical integer DEFAULT 0;
''',
'''
ALTER TABLE project ADD COLUMN backgroundColor integer;
''',];

  Future open() async {
    db = await openDatabase(
      'project',
      version: migrationScripts.length,
      onCreate: (Database db, int version) async {
        // Run all migration scripts on fresh DB (from 0 → version)
        for (var i = 0; i < migrationScripts.length; i++) {
          await db.execute(migrationScripts[i]);
        }
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        for (var i = oldVersion; i < newVersion; i++) {
          await db.execute(migrationScripts[i]);
        }
      },
    );
  }

  Future<Project?> insert(Project project) async {
    try {
      project.id = await db.insert('project', project.toMap());
      return project;
    } catch (e) {
      print('❌ Database insert failed: $e');
      return null;
    }
  }

  Future<GeneratedVideo?> insertGeneratedVideo(GeneratedVideo generatedVideo) async {
    try {
      generatedVideo.id = await db.insert('generatedVideo', generatedVideo.toMap());
      return generatedVideo;
    } catch (e) {
      print('❌ Database insertGeneratedVideo failed: $e');
      return null;
    }
  }

  Future<Project?> get(int id) async {
    List<Map<String, dynamic>> maps = await db.query('project',
        columns: [
          '_id',
          'title',
          'description',
          'date',
          'duration',
          'layersJson',
          'imagePath',
          'aspectRatio',
          'cropMode',
          'rotation',
          'flipHorizontal',
          'flipVertical',
          'backgroundColor',
        ],
        where: '_id = ?',
        whereArgs: [id]);
    if (maps.isNotEmpty) {
      return Project.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Project>> findAll() async {
    List<Map<String, dynamic>> maps = await db.query(
      'project',
      columns: [
        '_id',
        'title',
        'description',
        'date',
        'duration',
        'layersJson',
        'imagePath',
        'aspectRatio',
        'cropMode',
        'rotation',
        'flipHorizontal',
        'flipVertical',
        'backgroundColor',
      ],
      // 👇 BURAYI EKLEMEN GEREKİYOR EN SON PROJELER ÜSTE GÖZÜKECEK
      orderBy: '_id DESC',
    );
    return maps.map((m) => Project.fromMap(m)).toList();
  }

  Future<List<GeneratedVideo>> findAllGeneratedVideo(int projectId) async {
    List<Map<String, dynamic>> maps = await db.query(
      'generatedVideo',
      columns: [
        '_id',
        'projectId',
        'path',
        'date',
        'resolution',
        'thumbnail',
      ],
      where: 'projectId = ?',
      whereArgs: [projectId],
      orderBy: '_id desc'
    );
    return maps.map((m) => GeneratedVideo.fromMap(m)).toList();
  }

  Future<int> delete(int id) async {
    try {
      return await db.delete('project', where: '_id = ?', whereArgs: [id]);
    } catch (e) {
      print('❌ Database delete failed: $e');
      return 0;
    }
  }

  Future<int> deleteGeneratedVideo(int id) async {
    try {
      return await db.delete('generatedVideo', where: '_id = ?', whereArgs: [id]);
    } catch (e) {
      print('❌ Database deleteGeneratedVideo failed: $e');
      return 0;
    }
  }

  Future<int> deleteAll() async {
    try {
      return await db.delete('project');
    } catch (e) {
      print('❌ Database deleteAll failed: $e');
      return 0;
    }
  }

  Future<int> update(Project project) async {
    try {
      return await db.update('project', project.toMap(),
          where: '_id = ?', whereArgs: [project.id]);
    } catch (e) {
      print('❌ Database update failed: $e');
      return 0;
    }
  }

  Future close() async => db.close();
}
