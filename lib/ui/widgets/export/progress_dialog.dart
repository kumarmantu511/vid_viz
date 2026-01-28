import 'dart:core';
import 'package:flutter/material.dart';
import 'package:vidviz/l10n/generated/app_localizations.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/director_service.dart';
import 'package:vidviz/service/export/native_generator.dart';
import 'package:vidviz/ui/widgets/export/playback_screen.dart';

class ProgressDialog extends StatelessWidget {
  final directorService = locator.get<DirectorService>();

  String _formatDurationMs(int ms) {
    final d = Duration(milliseconds: ms);
    final int minutes = d.inMinutes;
    final int seconds = d.inSeconds - minutes * 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return StreamBuilder(
      stream: directorService.progress$,
      initialData: FFmpegStat(),
      builder: (BuildContext context, AsyncSnapshot<FFmpegStat> ffmepegStat) {
        final FFmpegStat stat = ffmepegStat.data!;
        String title, progressText;
        double progress = 0;
        String buttonText = loc.exportProgressCancelButton;
        if (stat.totalFiles != null && stat.fileNum != null) {
          title = loc.exportProgressPreprocessingTitle;
          progress =
              (stat.fileNum! -
                  1 +
                  (stat.time ?? 0) / directorService.duration) /
              stat.totalFiles!;
          progressText = loc.exportProgressFileOfTotal(stat.fileNum!, stat.totalFiles!);
        } else if ((stat.time ?? 0) > 100) {
          title = loc.exportProgressBuildingTitle;
          progress = (stat.time ?? 0) / directorService.duration;
          int remaining = 0;
          if ((stat.timeElapsed ?? 0) > 0 && (stat.time ?? 0) > 0) {
            remaining =
                (stat.timeElapsed! *
                        (directorService.duration / stat.time! - 1))
                    .floor();
          }
          int minutes = Duration(milliseconds: remaining).inMinutes;
          int seconds =
              Duration(milliseconds: remaining).inSeconds -
              60 * Duration(milliseconds: remaining).inMinutes;
          progressText = remaining > 0
              ? loc.exportProgressRemaining(minutes, seconds)
              : '';
        } else {
          title = loc.exportProgressBuildingTitle;
          progress = (stat.time ?? 0) / directorService.duration;
          progressText = '';
        }

        // Extra details: elapsed/total and optional size/speed
        String timelineText = '';
        String extraText = '';
        if ((stat.timeElapsed ?? 0) > 0 && directorService.duration > 0) {
          final elapsedMs = stat.timeElapsed!;
          final totalMs = directorService.duration;
          timelineText =
              '${_formatDurationMs(elapsedMs)} / ${_formatDurationMs(totalMs)}';
        }
        final int bytes = stat.size ?? 0;
        final double speed = stat.speed ?? 0;
        List<String> parts = [];
        if (bytes > 0) {
          final mb = (bytes / (1024 * 1024)).toStringAsFixed(1);
          parts.add('$mb MB');
        }
        if (speed > 0) {
          parts.add('${speed.toStringAsFixed(2)}x');
        }
        if (parts.isNotEmpty) {
          extraText = parts.join(' • ');
        }

        Widget child = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            progress == 0
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
                      const Padding(padding: EdgeInsets.symmetric(vertical: 4)),
                      if (progressText.isNotEmpty) Text(progressText),
                      if (timelineText.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            timelineText,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      if (extraText.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            extraText,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      const Padding(padding: EdgeInsets.symmetric(vertical: 1)),
                    ],
                  ),
          ],
        );
        if (ffmepegStat.data!.finished!) {
          title = loc.exportProgressSavedTitle;
          buttonText = loc.commonOk;
          child = LinearProgressIndicator(value: 1);
        } else if (ffmepegStat.data!.error!) {
          title = loc.exportProgressErrorTitle;
          buttonText = loc.commonOk;
          child = Text(
            loc.exportProgressErrorMessage,
          );
        }
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: MediaQuery.of(context).size.width / 2,
                child: child,
              ),
            ],
          ),
          actions: [
            ffmepegStat.data!.finished!
                ? ElevatedButton(
                    child: Text(
                      loc.exportProgressOpenVideoButton,
                      style: const TextStyle(color: Colors.white),
                    ),
                    onPressed: () async {
                      final path = ffmepegStat.data!.outputPath;
                      if (path != null && path.isNotEmpty) {
                        Navigator.of(context).pop();
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PlaybackScreen(path: path),
                          ),
                        );
                      }
                    },
                  )
                : Container(),
            ElevatedButton(
              child: Text(buttonText, style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.of(context).pop();
                // Delay to not see changes in dialog
                Future.delayed(Duration(milliseconds: 100), () {
                  directorService.cancelExport();
                });
              },
            ),
          ],
        );
      },
    );
  }
}
