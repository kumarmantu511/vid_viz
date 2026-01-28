import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:vidviz/model/layer.dart';
import 'package:vidviz/model/project.dart';
import 'package:vidviz/service/archive/archive_io.dart';
import 'package:vidviz/service/archive/schema.dart';

class ArchiveWriter {
  Future<ArchiveEstimate> estimateProjectSize(Project project, ExportOptions opt) async {
    final assets = _collectAssets(project);
    int total = 0, cnt = 0, skipped = 0, skippedBytes = 0;
    for (final file in _filterAssetsByOptions(assets, opt)) {
      final f = File(file);
      if (!await f.exists()) continue;
      final len = await f.length();
      if (_isVideo(file) && opt.maxVideoMb > 0 && len > opt.maxVideoMb * 1024 * 1024) {
        skipped++;
        skippedBytes += len;
        continue;
      }
      total += len;
      cnt++;
    }
    return ArchiveEstimate(cnt, total, skipped, skippedBytes);
  }

  Future<String?> exportProject(
    Project project,
    ExportOptions opt, {
    String? targetDir,
    required void Function(ArchiveProgress) onProgress,
    required bool Function() isCancelled,
  }) async {
    // Destination base
    Directory outDir;
    if (targetDir != null && targetDir.isNotEmpty) {
      outDir = Directory(targetDir);
      await outDir.create(recursive: true);
    } else {
      outDir = await ArchiveIO.getDefaultExportDirectory();
    }

    final safeTitle = ArchiveIO.safeName(project.title.isEmpty ? 'Project' : project.title);
    final ts = DateTime.now().toIso8601String().replaceAll(':', '').replaceAll('.', '');
    final outPath = p.join(outDir.path, '$safeTitle $ts${ArchiveConstants.packageExtension}');

    // Collect
    final assets = _collectAssets(project);
    final filtered = _filterAssetsByOptions(assets, opt);

    // Pre-compute totals for progress
    int totalFiles = 0;
    int totalBytes = 0;
    for (final a in filtered) {
      final f = File(a);
      if (!await f.exists()) continue;
      final len = await f.length();
      if (_isVideo(a) && opt.maxVideoMb > 0 && len > opt.maxVideoMb * 1024 * 1024) {
        continue;
      }
      totalFiles++;
      totalBytes += len;
    }

    // Enforce max total size if configured
    if (opt.maxTotalMb > 0 && totalBytes > opt.maxTotalMb * 1024 * 1024) {
      onProgress(ArchiveProgress(
        phase: ArchivePhase.copying,
        error: true,
        message: 'Total package size ${(totalBytes / (1024*1024)).toStringAsFixed(1)} MB exceeds limit of ${opt.maxTotalMb} MB',
      ));
      return null;
    }

    // Build archive
    final encoder = ZipFileEncoder();
    encoder.create(outPath);

    // Manifest
    final manifest = {
      'schemaVersion': ArchiveConstants.schemaVersion,
      'appVersion': project.backgroundColor != null ? 'v2' : 'v1',
      'createdAt': DateTime.now().toIso8601String(),
      'title': project.title,
      'duration': project.duration,
      'exportOptions': {
        'includeVideos': opt.includeVideos,
        'includeAudios': opt.includeAudios,
        'maxVideoMb': opt.maxVideoMb,
        'maxTotalMb': opt.maxTotalMb,
      }
    };
    encoder.addArchiveFile(ArchiveFile.string(ArchiveConstants.manifestFile, jsonEncode(manifest)));

    final List<Map<String, dynamic>> assetsIndex = [];
    int processed = 0;
    int processedBytes = 0;

    onProgress(ArchiveProgress(
      phase: ArchivePhase.copying,
      total: totalFiles,
      bytesTotal: totalBytes,
      bytesProcessed: 0,
    ));

    final Set<String> addedDestPaths = <String>{};
    for (final src in filtered) {
      if (isCancelled()) {
        encoder.close();
        try { await File(outPath).delete(); } catch (_) {}
        onProgress(ArchiveProgress(phase: ArchivePhase.copying, error: true, message: 'Cancelled'));
        return null;
      }
      final f = File(src);
      if (!await f.exists()) continue;
      final len = await f.length();
      if (_isVideo(src) && opt.maxVideoMb > 0 && len > opt.maxVideoMb * 1024 * 1024) {
        continue; // skip
      }
      final hash = await ArchiveIO.hashFile(f);
      final ext = p.extension(src).replaceAll('.', '').toLowerCase();
      final destName = ext.isEmpty ? hash : '$hash.$ext';
      final destPath = p.join(ArchiveConstants.assetsDir, destName).replaceAll('\\', '/');

      if (!addedDestPaths.contains(destPath)) {
        encoder.addFile(f, destPath);
        addedDestPaths.add(destPath);
      }

      assetsIndex.add({
        'original': src,
        'hash': hash,
        'size': len,
        'ext': ext,
        'path': destPath,
      });

      processed++;
      processedBytes += len;
      onProgress(ArchiveProgress(
        phase: ArchivePhase.copying,
        total: totalFiles,
        bytesTotal: totalBytes,
        current: processed,
        bytesProcessed: processedBytes,
      ));
    }
    String? coverRel;
    if (project.layersJson != null && project.layersJson!.isNotEmpty) {
      try {
        final List<dynamic> rawLayers = jsonDecode(project.layersJson!);
        final List<Layer> tmpLayers = rawLayers.map((e) => Layer.fromJson(e)).toList();
        for (final layer in tmpLayers) {
          for (final a in layer.assets) {
            final List<String?> thumbs = [a.thumbnailMedPath, a.thumbnailPath];
            for (final t in thumbs) {
              if (t == null || t.isEmpty) continue;
              final tf = File(t);
              if (!await tf.exists()) continue;
              final tlen = await tf.length();
              final thash = await ArchiveIO.hashFile(tf);
              final text = p.extension(t).replaceAll('.', '').toLowerCase();
              final tname = text.isEmpty ? thash : '$thash.$text';
              final tdest = p.join(ArchiveConstants.assetsDir, tname).replaceAll('\\', '/');
              if (!addedDestPaths.contains(tdest)) {
                encoder.addFile(tf, tdest);
                addedDestPaths.add(tdest);
              }
              assetsIndex.add({
                'original': t,
                'hash': thash,
                'size': tlen,
                'ext': text,
                'path': tdest,
              });
              coverRel ??= tdest; // first available thumbnail becomes cover
            }
          }
        }
      } catch (_) {}
    }

    // Write assets-hashes.json
    encoder.addArchiveFile(ArchiveFile.string(ArchiveConstants.assetsIndexFile, jsonEncode(assetsIndex)));

    // Build project.json with srcPath and thumbnails replaced to relative assets path
    String? newLayersJson = project.layersJson;
    if (newLayersJson != null && newLayersJson.isNotEmpty) {
      final Map<String, String> mapByOriginal = {
        for (final e in assetsIndex)
          ArchiveIO.norm(e['original'] as String): (e['path'] as String)
      };
      final List<dynamic> raw = jsonDecode(newLayersJson);
      final List<Layer> layers = raw.map((e) => Layer.fromJson(e)).toList();
      for (final layer in layers) {
        for (final asset in layer.assets) {
          final k = ArchiveIO.norm(asset.srcPath);
          if (mapByOriginal.containsKey(k)) {
            asset.srcPath = mapByOriginal[k]!; // assets/<hash>.<ext>
          }
          if (asset.thumbnailPath != null && asset.thumbnailPath!.isNotEmpty) {
            final kt = ArchiveIO.norm(asset.thumbnailPath!);
            if (mapByOriginal.containsKey(kt)) {
              asset.thumbnailPath = mapByOriginal[kt]!;
            }
          }
          if (asset.thumbnailMedPath != null && asset.thumbnailMedPath!.isNotEmpty) {
            final km = ArchiveIO.norm(asset.thumbnailMedPath!);
            if (mapByOriginal.containsKey(km)) {
              asset.thumbnailMedPath = mapByOriginal[km]!;
            }
          }
        }
      }
      newLayersJson = jsonEncode(layers.map((e) => e.toJson()).toList());
    }

    final projectJson = {
      'project': {
        'title': project.title,
        'description': project.description,
        'date': project.date.millisecondsSinceEpoch,
        'duration': project.duration,
        'imagePath': coverRel,
        'aspectRatio': project.aspectRatio,
        'cropMode': project.cropMode,
        'rotation': project.rotation,
        'flipHorizontal': project.flipHorizontal,
        'flipVertical': project.flipVertical,
      },
      'layers': newLayersJson,
    };
    encoder.addArchiveFile(ArchiveFile.string(ArchiveConstants.projectFile, jsonEncode(projectJson)));

    encoder.close();

    onProgress(ArchiveProgress(phase: ArchivePhase.finalizing, finished: true, outputPath: outPath));
    return outPath;
  }

  // Helpers
  List<String> _collectAssets(Project project) {
    final List<String> files = [];
    if (project.layersJson == null || project.layersJson!.isEmpty) return files;
    try {
      final List<dynamic> raw = jsonDecode(project.layersJson!);
      final List<Layer> layers = raw.map((e) => Layer.fromJson(e)).toList();
      for (final layer in layers) {
        for (final a in layer.assets) {
          if (a.deleted) continue;
          if (a.srcPath.isNotEmpty) files.add(a.srcPath);
        }
      }
    } catch (_) {}
    return files;
  }

  Iterable<String> _filterAssetsByOptions(List<String> files, ExportOptions opt) sync* {
    for (final f in files) {
      if (_isVideo(f) && !opt.includeVideos) continue;
      if (_isAudio(f) && !opt.includeAudios) continue;
      yield f;
    }
  }

  bool _isVideo(String path) => ArchiveIO.isVideo(path);
  bool _isAudio(String path) => ArchiveIO.isAudio(path);
}
