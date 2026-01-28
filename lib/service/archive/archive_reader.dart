import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:vidviz/model/layer.dart';
import 'package:vidviz/model/project.dart';
import 'package:vidviz/service/archive/archive_io.dart';
import 'package:vidviz/service/archive/schema.dart';

class ArchiveReader {
  Future<Project?> importProject(
    String vvzPath, {
    required void Function(ArchiveProgress) onProgress,
    required bool Function() isCancelled,
  }) async {
    final bytes = await File(vvzPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // Find project.json
    final projEntry = archive.files.firstWhere(
      (f) => f.name == ArchiveConstants.projectFile,
      orElse: () => ArchiveFile('', 0, []),
    );
    if (projEntry.name.isEmpty) {
      onProgress(ArchiveProgress(phase: ArchivePhase.extracting, error: true, message: 'project.json not found'));
      return null;
    }

    final projJson = jsonDecode(utf8.decode(projEntry.content as List<int>));
    final projectMap = projJson['project'] as Map<String, dynamic>;
    // Accept both String (JSON string) and List (direct JSON) for layers
    String? layersJsonStr;
    final dynamic layersNode = projJson['layers'];
    if (layersNode is String) {
      layersJsonStr = layersNode;
    } else if (layersNode is List) {
      try {
        layersJsonStr = jsonEncode(layersNode);
      } catch (_) {
        layersJsonStr = null;
      }
    }

    // Destination folder
    final Directory appDir = await getApplicationDocumentsDirectory();
    final baseDir = Directory(p.join(appDir.path, 'imports', ArchiveIO.safeName(projectMap['title'] ?? 'Project')));
    await baseDir.create(recursive: true);
    final assetsOut = Directory(p.join(baseDir.path, 'assets'));
    await assetsOut.create(recursive: true);

    // Extract assets with progress
    final assetFiles = archive.files.where((f) => f.isFile && f.name.startsWith('${ArchiveConstants.assetsDir}/')).toList();
    int totalBytes = 0;
    for (final f in assetFiles) {
      totalBytes += f.size;
    }
    int processedBytes = 0;
    onProgress(ArchiveProgress(
      phase: ArchivePhase.extracting,
      total: assetFiles.length,
      bytesTotal: totalBytes,
      bytesProcessed: 0,
    ));

    int idx = 0;
    for (final file in assetFiles) {
      if (isCancelled()) {
        onProgress(ArchiveProgress(phase: ArchivePhase.extracting, error: true, message: 'Cancelled'));
        return null;
      }
      final outPath = p.join(baseDir.path, file.name);
      final outFile = File(outPath);
      await outFile.parent.create(recursive: true);
      final content = file.content as List<int>;
      await outFile.writeAsBytes(content);
      idx++;
      processedBytes += content.length;
      onProgress(ArchiveProgress(
        phase: ArchivePhase.extracting,
        total: assetFiles.length,
        bytesTotal: totalBytes,
        current: idx,
        bytesProcessed: processedBytes,
      ));
    }

    // Load assets-hashes.json if present for checksum verification
    final idxEntry = archive.files.firstWhere(
      (f) => f.name == ArchiveConstants.assetsIndexFile,
      orElse: () => ArchiveFile('', 0, []),
    );
    final Map<String, String> expectedHashes = {};
    if (idxEntry.name.isNotEmpty) {
      try {
        final list = jsonDecode(utf8.decode(idxEntry.content as List<int>)) as List<dynamic>;
        for (final e in list) {
          final m = e as Map<String, dynamic>;
          expectedHashes[m['path'] as String] = m['hash'] as String;
        }
      } catch (_) {}
    }
    final Set<String> corrupted = <String>{};
    if (expectedHashes.isNotEmpty) {
      for (final file in assetFiles) {
        final rel = file.name; // assets/<hash>.<ext>
        final local = p.join(baseDir.path, rel);
        final f = File(local);
        if (await f.exists() && expectedHashes.containsKey(rel)) {
          final digestStr = await ArchiveIO.hashFile(f);
          if (digestStr != expectedHashes[rel]) {
            corrupted.add(rel);
          }
        }
      }
    }

    // Remap asset paths in layersJson (string) to local paths and keep thumbnails
    String? newLayersJson = layersJsonStr;
    String? coverLocal;
    if (newLayersJson != null && newLayersJson.isNotEmpty) {
      final List<dynamic> raw = jsonDecode(newLayersJson);
      final List<Layer> layers = raw.map((e) => Layer.fromJson(e)).toList();
      for (final layer in layers) {
        for (final asset in layer.assets) {
          if (asset.srcPath.startsWith('${ArchiveConstants.assetsDir}/') || asset.srcPath.startsWith('${ArchiveConstants.assetsDir}\\')) {
            final rel = asset.srcPath;
            final relNorm = ArchiveIO.norm(rel);
            final local = p.join(baseDir.path, rel);
            asset.srcPath = local;
            if (corrupted.contains(relNorm)) {
              asset.deleted = true;
            }
            // Remap thumbnails if they point to assets/
            if (asset.thumbnailPath != null && (asset.thumbnailPath!.startsWith('${ArchiveConstants.assetsDir}/') || asset.thumbnailPath!.startsWith('${ArchiveConstants.assetsDir}\\'))) {
              asset.thumbnailPath = p.join(baseDir.path, asset.thumbnailPath!);
            } else {
              asset.thumbnailPath = null;
            }
            if (asset.thumbnailMedPath != null && (asset.thumbnailMedPath!.startsWith('${ArchiveConstants.assetsDir}/') || asset.thumbnailMedPath!.startsWith('${ArchiveConstants.assetsDir}\\'))) {
              asset.thumbnailMedPath = p.join(baseDir.path, asset.thumbnailMedPath!);
            } else {
              asset.thumbnailMedPath = null;
            }
            // Fallback cover from first available thumbnail
            coverLocal ??= asset.thumbnailMedPath ?? asset.thumbnailPath;
          } else {
            asset.deleted = true;
            asset.thumbnailPath = null;
            asset.thumbnailMedPath = null;
          }
        }
      }
      newLayersJson = jsonEncode(layers.map((e) => e.toJson()).toList());
    }

    // Remap project imagePath (cover) if provided in project.json
    String? imagePathLocal;
    final dynamic imagePathNode = projectMap['imagePath'];
    if (imagePathNode is String && imagePathNode.isNotEmpty) {
      if (imagePathNode.startsWith('${ArchiveConstants.assetsDir}/') || imagePathNode.startsWith('${ArchiveConstants.assetsDir}\\')) {
        imagePathLocal = p.join(baseDir.path, imagePathNode);
      } else {
        imagePathLocal = imagePathNode;
      }
    } else {
      imagePathLocal = coverLocal; // fallback to first found thumbnail
    }

    final proj = Project(
      title: projectMap['title'] ?? 'Imported',
      description: projectMap['description'],
      date: DateTime.now(),
      duration: (projectMap['duration'] as num?)?.toInt() ?? 0,
      layersJson: newLayersJson,
      imagePath: imagePathLocal,
      aspectRatio: projectMap['aspectRatio'],
      cropMode: projectMap['cropMode'],
      rotation: projectMap['rotation'],
      flipHorizontal: projectMap['flipHorizontal'] == true,
      flipVertical: projectMap['flipVertical'] == true,
      backgroundColor: projectMap['backgroundColor'],
    );

    final msg = (expectedHashes.isEmpty || corrupted.isEmpty)
        ? null
        : 'Imported with ${corrupted.length} corrupted assets (marked deleted)';
    onProgress(ArchiveProgress(phase: ArchivePhase.finalizing, finished: true, message: msg));
    return proj;
  }
}
