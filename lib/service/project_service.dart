import 'dart:io';
import 'package:rxdart/rxdart.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/model/project.dart';
import 'package:vidviz/dao/project_dao.dart';

class ProjectService {
  final ProjectDao projectDao = locator.get<ProjectDao>();

  List<Project> projectList = [];
  Project? project;

  BehaviorSubject<bool> _projectListChanged = BehaviorSubject.seeded(false);
  Stream<bool> get projectListChanged$ => _projectListChanged.stream;
  bool get projectListChanged => _projectListChanged.value;

  ProjectService() {
    load();
  }

  dispose() {
    _projectListChanged.close();
  }

  void load() async {
    await projectDao.open();
    refresh();
  }

  Project createNew() {
    return Project(title: '', duration: 0, date: DateTime.now());
  }

  void refresh() async {
    projectList = await projectDao.findAll();
    _projectListChanged.add(true);
    checkSomeFileNotExists();
  }

  insert(_project) async {
    _project.date = DateTime.now();
    await projectDao.insert(_project);
    refresh();
  }

  update(_project) async {
    await projectDao.update(_project);
    refresh();
  }

  delete(int index) async {
    // Index bounds check
    if (index < 0 || index >= projectList.length) return;
    final project = projectList[index];
    // ID null check
    if (project.id == null) return;
    await projectDao.delete(project.id!);
    refresh();
  }

  checkSomeFileNotExists() {
    for (int i = 0; i < projectList.length; i++) {
      if (projectList[i].imagePath != null && !File(projectList[i].imagePath!).existsSync()) {
        print('${projectList[i].imagePath} does not exists');
        projectList[i].imagePath = null;
      }
    }
  }
}
