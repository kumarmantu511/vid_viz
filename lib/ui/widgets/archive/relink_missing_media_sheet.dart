import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:vidviz/l10n/generated/app_localizations.dart';
import 'package:path/path.dart' as p;
import 'package:vidviz/model/layer.dart';
import 'package:vidviz/model/project.dart';
import 'package:vidviz/service/project_service.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/core/theme.dart' as app_theme;

class RelinkMissingMediaSheet extends StatefulWidget {
  final Project project;
  const RelinkMissingMediaSheet({super.key, required this.project});

  @override
  State<RelinkMissingMediaSheet> createState() => _RelinkMissingMediaSheetState();
}

class _RelinkMissingMediaSheetState extends State<RelinkMissingMediaSheet> {
  final _projectSvc = locator.get<ProjectService>();
  late List<Layer> _layers;
  final List<_MissingItem> _missing = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _layers = [];
    _missing.clear();
    if (widget.project.layersJson == null || widget.project.layersJson!.isEmpty) return;
    try {
      final raw = (jsonDecode(widget.project.layersJson!) as List).cast<dynamic>();
      _layers = raw.map((e) => Layer.fromJson(e)).toList();
      for (int li = 0; li < _layers.length; li++) {
        final layer = _layers[li];
        for (int ai = 0; ai < layer.assets.length; ai++) {
          final a = layer.assets[ai];
          final missing = a.deleted || a.srcPath.isEmpty || !File(a.srcPath).existsSync();
          if (missing) {
            _missing.add(_MissingItem(layerIndex: li, assetIndex: ai));
          }
        }
      }
    } catch (_) {}
    setState(() {});
  }

  Future<void> _relinkFromFolder() async {
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir == null) return;
    setState(() => _busy = true);
    final loc = AppLocalizations.of(context);
    int relinked = 0;
    try {
      final Map<String, String> fileMap = {};
      final root = Directory(dir);
      if (!await root.exists()) return;
      await for (final ent in root.list(recursive: true, followLinks: false)) {
        if (ent is File) {
          fileMap[p.basename(ent.path).toLowerCase()] = ent.path;
        }
      }

      for (final item in _missing) {
        final a = _layers[item.layerIndex].assets[item.assetIndex];
        String base = '';
        if (a.srcPath.isNotEmpty) {
          base = p.basename(a.srcPath);
        } else if (a.title.isNotEmpty) {
          base = a.title;
        }
        if (base.isEmpty) continue;
        final found = fileMap[base.toLowerCase()];
        if (found != null) {
          a.srcPath = found;
          a.deleted = false;
          a.thumbnailPath = null;
          a.thumbnailMedPath = null;
          relinked++;
        }
      }

      await _save();
      _load();
      if (mounted) {
        if (relinked > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.relinkSuccessSnack(relinked)),
              backgroundColor: app_theme.accent,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.relinkNoMatchesSnack),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Relink error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.relinkErrorScanSnack(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _relinkOne(_MissingItem item) async {
    final a = _layers[item.layerIndex].assets[item.assetIndex];
    String? picked;
    // Optional: filter by type
    if (a.type == AssetType.audio) {
      picked = await FilePicker.platform.pickFiles(type: FileType.audio).then((r) => r?.files.single.path);
    } else if (a.type == AssetType.video) {
      picked = await FilePicker.platform.pickFiles(type: FileType.video).then((r) => r?.files.single.path);
    } else {
      picked = await FilePicker.platform.pickFiles(type: FileType.media).then((r) => r?.files.single.path);
    }
    if (picked == null) return;
    setState(() => _busy = true);
    final loc = AppLocalizations.of(context);
    try {
      a.srcPath = picked;
      a.deleted = false;
      a.thumbnailPath = null;
      a.thumbnailMedPath = null;
      await _save();
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              loc.relinkRelinkedSnack(p.basename(picked)),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final newJson = jsonEncode(_layers.map((e) => e.toJson()).toList());
    widget.project.layersJson = newJson;
    await _projectSvc.update(widget.project);
  }

  Future<void> _onDone() async {
    setState(() => _busy = true);
    try {
      await _save();
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? app_theme.projectListBg : app_theme.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.close, color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary, size: 26),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Container(
                  width: 1, height: 20,
                  color: isDark ? app_theme.projectListCardBorder : app_theme.border,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      loc.relinkHeaderTitle,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 1, height: 20,
                  color: isDark ? app_theme.projectListCardBorder : app_theme.border,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: app_theme.accent)),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.check, color: app_theme.accent, size: 28),
                    onPressed: _onDone,
                    tooltip: loc.relinkSaveAndCloseTooltip,
                  ),
              ],
            ),
          ),
          Divider(color: isDark ? app_theme.projectListCardBorder : app_theme.border, height: 1),

          Expanded(
            child: Column(
              children: [
                // Content List
                Expanded(
                  child: _missing.isEmpty
                      ? Center(
                          child: Text(
                            loc.relinkNoMissingMedia,
                            style: TextStyle(
                              color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _missing.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: isDark ? app_theme.projectListCardBorder : app_theme.border,
                          ),
                          itemBuilder: (context, index) {
                            final item = _missing[index];
                            final a = _layers[item.layerIndex].assets[item.assetIndex];
                            final fileName = a.title.isEmpty ? p.basename(a.srcPath) : a.title;
                            
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              leading: Icon(
                                Icons.broken_image_rounded,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              title: Text(
                                fileName,
                                style: TextStyle(
                                  color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                a.srcPath,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: _busy
                                  ? null
                                  : TextButton(
                                      onPressed: () => _relinkOne(item),
                                      style: TextButton.styleFrom(
                                        foregroundColor: app_theme.accent,
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(loc.archiveRelinkButton),
                                    ),
                            );
                          },
                        ),
                ),
                
                // Bottom Actions
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 45,
                          decoration: BoxDecoration(
                            gradient: app_theme.neonButtonGradient,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: app_theme.neonCyan.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _busy ? null : _relinkFromFolder,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: app_theme.transparent,
                              shadowColor: app_theme.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.folder_open_rounded, color: Colors.white),
                            label: Text(
                              loc.relinkScanFolderButton,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: _busy ? null : _load,
                        tooltip: loc.relinkRescanTooltip,
                        style: IconButton.styleFrom(
                           backgroundColor: isDark ? app_theme.projectListCardBg : app_theme.surface,
                           shape: RoundedRectangleBorder(
                             borderRadius: BorderRadius.circular(12),
                             side: BorderSide(color: isDark ? app_theme.projectListCardBorder : app_theme.border),
                           ),
                        ),
                        icon: Icon(Icons.refresh, color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingItem {
  final int layerIndex;
  final int assetIndex;
  _MissingItem({required this.layerIndex, required this.assetIndex});
}
