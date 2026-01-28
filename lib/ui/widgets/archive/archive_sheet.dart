import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:vidviz/l10n/generated/app_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:vidviz/model/project.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/project_service.dart';
import 'package:vidviz/service/archive/project_archive_service.dart';
import 'package:vidviz/service/archive/archive_io.dart';
import 'package:vidviz/service/archive/schema.dart';
import 'package:vidviz/ui/screens/director.dart';
import 'package:vidviz/model/layer.dart';
import 'package:vidviz/ui/widgets/archive/archive_progress_dialog.dart';
import 'package:vidviz/ui/widgets/archive/relink_missing_media_sheet.dart';
import 'package:vidviz/core/theme.dart' as app_theme;

enum _ImportMode { replaceCurrent, createNew, cancel }

class ArchiveSheet extends StatefulWidget {
  final Project project;
  const ArchiveSheet({super.key, required this.project});

  @override
  State<ArchiveSheet> createState() => _ArchiveSheetState();
}

class _ArchiveSheetState extends State<ArchiveSheet> {
  final _svc = locator.get<ProjectArchiveService>();
  final _projectSvc = locator.get<ProjectService>();

  bool _includeVideos = true;
  bool _includeAudios = true;
  int _maxVideoMb = 500;
  int _maxTotalMb = 0; // 0 = unlimited
  ArchiveEstimate? _estimate;
  bool _estimating = false;
  String? _targetDir; // user selected export folder
  String? _defaultDir; // resolved default (Downloads or fallback)
  bool _resolvingDefault = true;

  @override
  void initState() {
    super.initState();
    _resolveDefaultDir();
  }

  Map<String, int> _computeStats() {
    int total = 0, videos = 0, audios = 0, images = 0, missing = 0;
    try {
      if (widget.project.layersJson != null && widget.project.layersJson!.isNotEmpty) {
        final raw = (jsonDecode(widget.project.layersJson!) as List).cast<dynamic>();
        final layers = raw.map((e) => Layer.fromJson(e)).toList();
        for (final l in layers) {
          for (final a in l.assets) {
            if (a.deleted) { missing++; continue; }
            if (a.srcPath.isEmpty) { missing++; continue; }
            total++;
            switch (a.type) {
              case AssetType.video: videos++; break;
              case AssetType.audio: audios++; break;
              case AssetType.image: images++; break;
              default: break;
            }
          }
        }
      }
    } catch (_) {}
    return {
      'total': total,
      'videos': videos,
      'audios': audios,
      'images': images,
      'missing': missing,
    };
  }

  String _previewFilename() {
    final title = ArchiveIO.safeName(widget.project.title.isEmpty ? 'Project' : widget.project.title);
    final ts = DateTime.now().toIso8601String().replaceAll(':', '').replaceAll('.', '');
    return '$title $ts${ArchiveConstants.packageExtension}';
  }

  void _showRelinkSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => RelinkMissingMediaSheet(project: widget.project),
    );
  }

  Future<void> _resolveDefaultDir() async {
    setState(() => _resolvingDefault = true);
    try {
      final d = await _svc.getDefaultExportDirectory();
      if (!mounted) return;
      setState(() => _defaultDir = d.path);
    } finally {
      if (mounted) setState(() => _resolvingDefault = false);
    }
  }

  bool _isCurrentProjectEmpty() {
    final s = _computeStats();
    return (s['total'] ?? 0) == 0;
  }

  Future<_ImportMode?> _askImportMode() async {
    final loc = AppLocalizations.of(context);
    return showDialog<_ImportMode>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(loc.archiveImportProjectDialogTitle),
        content: Text(loc.archiveImportProjectDialogMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_ImportMode.createNew),
            child: Text(loc.archiveImportProjectCreateNew),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_ImportMode.replaceCurrent),
            child: Text(loc.archiveImportProjectReplaceCurrent),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_ImportMode.cancel),
            child: Text(loc.commonCancel),
          ),
        ],
      ),
    );
  }

  Future<void> _estimateSize() async {
    setState(() => _estimating = true);
    try {
      final est = await _svc.estimateProjectSize(
        widget.project,
        ExportOptions(
          includeVideos: _includeVideos,
          includeAudios: _includeAudios,
          maxVideoMb: _maxVideoMb,
        ),
      );
      setState(() => _estimate = est);
    } finally {
      if (mounted) setState(() => _estimating = false);
    }
  }

  Future<void> _export() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ArchiveProgressDialog(),
    );
    final path = await _svc.exportProject(
      widget.project,
      ExportOptions(
        includeVideos: _includeVideos,
        includeAudios: _includeAudios,
        maxVideoMb: _maxVideoMb,
        maxTotalMb: _maxTotalMb,
      ),
      targetDir: _targetDir,
    );
    // Dialog is self-controlled by stream; we just leave it to user to close.
    if (!mounted) return;
    if (path != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).archiveExportedSnack(path),
          ),
        ),
      );
    }
  }

  Future<void> _import() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['vvz'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ArchiveProgressDialog(),
    );

    final proj = await _svc.importProject(file.path!);

    if (!mounted) return;

    if (proj != null) {
      // Close progress dialog if still visible
      Navigator.of(context, rootNavigator: true).maybePop();

      final isEmpty = _isCurrentProjectEmpty();
      _ImportMode mode = _ImportMode.createNew;
      if (!isEmpty) {
        final picked = await _askImportMode();
        if (picked == null || picked == _ImportMode.cancel) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context).archiveImportCancelled,
              ),
            ),
          );
          return;
        }
        mode = picked;
      } else {
        mode = _ImportMode.replaceCurrent;
      }

      if (mode == _ImportMode.replaceCurrent) {
        // Overwrite current project
        if (widget.project.id != null) {
          proj.id = widget.project.id;
          proj.date = DateTime.now();
          await _projectSvc.update(proj);
        } else {
          // Current project not persisted: insert imported one instead
          await _projectSvc.insert(proj);
        }
        if (!mounted) return;
        final rootNav = Navigator.of(context, rootNavigator: true);
        // Close the ArchiveSheet itself before navigating
        Navigator.of(context).pop();
        rootNav.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => DirectorScreen(proj)),
          (route) => route.isFirst,
        );
      } else {
        // Create as new project (ensure only one DirectorScreen on stack)
        await _projectSvc.insert(proj);
        if (!mounted) return;
        final rootNav = Navigator.of(context, rootNavigator: true);
        // Close the ArchiveSheet itself before navigating
        Navigator.of(context).pop();
        rootNav.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => DirectorScreen(proj)),
          (route) => route.isFirst,
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).archiveImportFailed,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final stats = _computeStats();
    final noMedia = stats['total'] == 0;
    final blockedByLimit = _estimate != null && _maxTotalMb > 0 && _estimate!.bytes > _maxTotalMb * 1024 * 1024;

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
                      loc.archiveHeaderTitle,
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
                IconButton(
                  icon: const Icon(Icons.check, color: app_theme.accent, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Divider(color: isDark ? app_theme.projectListCardBorder : app_theme.border, height: 1),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

            // Export section
            Row(
              children: [
                const Icon(Icons.archive_rounded, size: 20, color: app_theme.accent),
                const SizedBox(width: 8),
                Text(
                  loc.archiveExportSectionTitle,
                  style: TextStyle(
                    color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Target folder selector
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  loc.archiveTargetFolderLabel,
                  style: TextStyle(
                    color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Text(
                      _targetDir ??
                          (_resolvingDefault
                              ? loc.archiveTargetFolderResolving
                              : (_defaultDir ?? loc.archiveTargetFolderDefault)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                  ElevatedButton.icon(
                  onPressed: () async {
                    if (Platform.isIOS) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            AppLocalizations.of(context).archiveIosFolderUnsupported,
                          ),
                        ),
                      );
                      return;
                    }
                    final dir = await FilePicker.platform.getDirectoryPath();
                    if (dir != null && mounted) setState(() => _targetDir = dir);
                  },
                  icon: const Icon(Icons.folder_open_rounded, size: 18),
                  label: Text(
                    loc.archiveChooseFolder,
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: app_theme.accent,
                    foregroundColor: app_theme.surface,
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: app_theme.transparent),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_targetDir != null)
                  TextButton.icon(
                    onPressed: () => setState(() => _targetDir = null),
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(loc.archiveResetFolder),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Project media stats
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Tooltip(
                    message: 'Toplam medya (deleted/missing hariç)',
                    child: Chip(
                      label: Text(
                        '${loc.archiveStatsTotalLabel}: ${stats['total']}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: isDark ? app_theme.projectListCardBg : app_theme.surface,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Chip(
                    label: Text(
                      '${loc.archiveStatsVideosLabel}: ${stats['videos']}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: isDark ? app_theme.projectListCardBg : app_theme.surface,
                  ),
                  const SizedBox(width: 6),
                  Chip(
                    label: Text(
                      '${loc.archiveStatsAudiosLabel}: ${stats['audios']}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: isDark ? app_theme.projectListCardBg : app_theme.surface,
                  ),
                  const SizedBox(width: 6),
                  Chip(
                    label: Text(
                      '${loc.archiveStatsImagesLabel}: ${stats['images']}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: isDark ? app_theme.projectListCardBg : app_theme.surface,
                  ),
                  const SizedBox(width: 6),
                  if ((stats['missing'] ?? 0) > 0)
                    Tooltip(
                      message: 'Eksik/silinmiş sayısı (relink önerilir)',
                      child: Chip(
                        label: Text(
                          '${loc.archiveStatsMissingLabel}: ${stats['missing']}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: Theme.of(context).colorScheme.error.withOpacity(0.15),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Include toggles
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  loc.archiveIncludeVideos,
                  style: TextStyle(color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary),
                ),
                Tooltip(
                  message: 'Video dosyalarını pakete dahil et',
                  child: Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: _includeVideos,
                      onChanged: (v) => setState(() => _includeVideos = v),
                      activeColor: app_theme.accent,
                    ),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  loc.archiveIncludeAudios,
                  style: TextStyle(color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary),
                ),
                Tooltip(
                  message: 'Ses dosyalarını pakete dahil et',
                  child: Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: _includeAudios,
                      onChanged: (v) => setState(() => _includeAudios = v),
                      activeColor: app_theme.accent,
                    ),
                  ),
                ),
              ],
            ),


            Row(
              children: [
                Text(loc.archiveMaxVideoSizeLabel),
                const SizedBox(width: 12),
                Expanded(
                  child: Slider(
                    value: _maxVideoMb.toDouble(),
                    min: 100,
                    max: 2000,
                    divisions: 19,
                    label: '$_maxVideoMb',
                    onChanged: (v) => setState(() => _maxVideoMb = v.round()),
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Text('$_maxVideoMb', textAlign: TextAlign.end),
                ),
              ],
            ),

            // Max total size (MB)
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  loc.archiveMaxTotalSizeLabel,
                  style: TextStyle(color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Slider(
                    value: _maxTotalMb.toDouble(),
                    min: 0,
                    max: 5000,
                    divisions: 50,
                    label: _maxTotalMb == 0 ? loc.archiveUnlimited : '$_maxTotalMb',
                    onChanged: (v) => setState(() => _maxTotalMb = v.round()),
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    _maxTotalMb == 0 ? loc.archiveUnlimited : '$_maxTotalMb',
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                loc.archiveUnlimitedHint,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                ),
              ),
            ),

            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _estimating
                    ? Text(loc.archiveEstimating)
                    : Expanded(
                      child: Text(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                          _estimate == null
                              ? loc.archiveSizeEstimateNone
                              : loc.archiveSizeEstimate(
                                  _estimate!.files,
                                  _estimate!.bytes / (1024 * 1024),
                                  _estimate!.skippedFiles,
                                ),
                        ),
                    ),
                TextButton(
                  onPressed: _estimating ? null : _estimateSize,
                  child: const Text('Estimate'),
                ),
              ],
            ),
            if (_estimate != null && _maxTotalMb > 0 && _estimate!.bytes > _maxTotalMb * 1024 * 1024)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  loc.archiveSizeWarning,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
            if (noMedia)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  loc.archiveNoMedia,
                  style: TextStyle(
                    color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),

            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Export Button
                  Container(
                    width: 135,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: (_estimating || blockedByLimit || noMedia) ? null : app_theme.neonButtonGradient,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: (_estimating || blockedByLimit || noMedia) ? null
                          : [
                              BoxShadow(
                                color: app_theme.neonCyan.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _estimating || blockedByLimit || noMedia ? null : () async { await _export(); },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: app_theme.transparent,
                        shadowColor: app_theme.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      icon: const Icon(Icons.upload_file, color: Colors.white, size: 20),
                      label: Text(
                        loc.archiveExportButton,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Import Button
                  Container(
                    width: 135,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: app_theme.neonButtonGradient,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: app_theme.neonCyan.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _import,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: app_theme.transparent,
                        shadowColor: app_theme.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      icon: const Icon(Icons.file_open_outlined, color: Colors.white, size: 20),
                      label: Text(
                        loc.archiveImportButton,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Relink Button
                  Container(
                    width: 150,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: app_theme.neonButtonGradient,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: app_theme.neonCyan.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _showRelinkSheet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: app_theme.transparent,
                        shadowColor: app_theme.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      icon: const Icon(Icons.link_rounded, color: Colors.white, size: 20),
                      label: Text(
                        loc.archiveRelinkButton,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(
                    loc.archiveExportPathHint,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${loc.archivePreviewLabel}: ${_previewFilename()}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                  ),
                ),
              ],
            ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
