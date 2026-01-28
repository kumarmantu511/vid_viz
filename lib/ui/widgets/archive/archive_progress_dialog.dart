import 'package:flutter/material.dart';
import 'package:vidviz/l10n/generated/app_localizations.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:vidviz/service/archive/schema.dart';
import 'package:vidviz/service/archive/project_archive_service.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/core/theme.dart' as app_theme;

class ArchiveProgressDialog extends StatelessWidget {
  final _svc = locator.get<ProjectArchiveService>();

  ArchiveProgressDialog({super.key});

  String _phaseText(AppLocalizations loc, ArchivePhase p) {
    switch (p.name) {
      case 'hashing':
        return loc.archiveProgressPreparing;
      case 'copying':
        return loc.archiveProgressPackaging;
      case 'zipping':
        return loc.archiveProgressCompressing;
      case 'extracting':
        return loc.archiveProgressExtracting;
      case 'finalizing':
        return loc.archiveProgressFinalizing;
      default:
        return loc.archiveProgressWorking;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    
    return StreamBuilder<ArchiveProgress>(
      stream: _svc.progress$,
      initialData: const ArchiveProgress(phase: ArchivePhase.hashing),
      builder: (context, snap) {
        final d = snap.data!;
        final total = d.bytesTotal > 0 ? d.bytesTotal.toDouble() : 1.0;
        final value = (d.bytesProcessed / total).clamp(0.0, 1.0);
        final title = d.finished
            ? loc.archiveProgressCompletedTitle
            : d.error
                ? loc.archiveProgressErrorTitle
                : _phaseText(loc, d.phase);
        final msg = d.error
            ? (d.message ?? loc.archiveProgressUnexpectedError)
            : d.finished
                ? (d.outputPath ?? loc.archiveProgressDone)
                : '${d.current}/${d.total} • ${(d.bytesProcessed / (1024 * 1024)).toStringAsFixed(1)} / ${(d.bytesTotal / (1024 * 1024)).toStringAsFixed(1)} MB';

        return Dialog(
          backgroundColor: isDark ? app_theme.projectListCardBg : app_theme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: d.finished || d.error ? 1 : value,
                    backgroundColor: isDark ? Colors.black26 : Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      d.error ? Theme.of(context).colorScheme.error : app_theme.accent,
                    ),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  msg,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (d.finished && d.outputPath != null && d.outputPath!.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          final path = d.outputPath!;
                          Navigator.of(context).pop();
                          OpenFile.open(path);
                        },
                        child: Text(loc.archiveProgressOpenFile),
                      ),
                    if (d.finished && d.outputPath != null && d.outputPath!.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          final path = d.outputPath!;
                          Share.shareXFiles([XFile(path)]);
                        },
                        child: Text(loc.archiveProgressShare),
                      ),
                    if (!d.finished && !d.error)
                      TextButton(
                        onPressed: () {
                          _svc.cancel();
                          Navigator.of(context).pop();
                        },
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: Text(loc.archiveProgressCancel),
                      ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
                      ),
                      child: Text(d.finished || d.error ? loc.commonOk : loc.archiveProgressHide),
                    )
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
