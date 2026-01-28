import 'dart:io';
import 'package:rxdart/rxdart.dart';
import 'package:vidviz/model/project.dart';
import 'package:vidviz/service/archive/schema.dart';
import 'package:vidviz/service/archive/archive_io.dart';
import 'package:vidviz/service/archive/archive_writer.dart';
import 'package:vidviz/service/archive/archive_reader.dart';

class ProjectArchiveService {
  final BehaviorSubject<ArchiveProgress> _progress =
      BehaviorSubject.seeded(const ArchiveProgress(phase: ArchivePhase.hashing));
  Stream<ArchiveProgress> get progress$ => _progress.stream;
  bool _cancelRequested = false;

  void cancel() {
    _cancelRequested = true;
  }

  Future<ArchiveEstimate> estimateProjectSize(Project project, ExportOptions opt) async {
    final writer = ArchiveWriter();
    return writer.estimateProjectSize(project, opt);
  }

  Future<Directory> getDefaultExportDirectory() => ArchiveIO.getDefaultExportDirectory();

  Future<String?> exportProject(Project project, ExportOptions opt, {String? targetDir}) async {
    try {
      _cancelRequested = false;
      final writer = ArchiveWriter();
      return await writer.exportProject(
        project,
        opt,
        targetDir: targetDir,
        onProgress: (p) => _progress.add(p),
        isCancelled: () => _cancelRequested,
      );
    } catch (e) {
      _progress.add(_progress.value.copyWith(error: true, message: e.toString()));
      return null;
    }
  }

  Future<Project?> importProject(String vvzPath) async {
    try {
      _cancelRequested = false;
      final reader = ArchiveReader();
      return await reader.importProject(
        vvzPath,
        onProgress: (p) => _progress.add(p),
        isCancelled: () => _cancelRequested,
      );
    } catch (e) {
      _progress.add(_progress.value.copyWith(error: true, message: e.toString()));
      return null;
    }
  }

  // Thin facade: writer/reader handle heavy lifting.
}
