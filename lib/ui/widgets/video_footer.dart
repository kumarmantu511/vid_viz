import 'package:flutter/material.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/ui/widgets/svg_icon.dart';
import '../../l10n/generated/app_localizations.dart';
import 'package:vidviz/service/director_service.dart';
import 'package:vidviz/ui/widgets/audio_mixer_sheet.dart';
import 'package:vidviz/core/theme.dart' as app_theme;
import 'archive/archive_sheet.dart';
import 'export/export_sheet.dart';
import 'export/export_video_list.dart';

class VideoFooter extends StatelessWidget {
  const VideoFooter({super.key});

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');

    // Extract hours and minutes
    String hours = twoDigits(duration.inMinutes);
    String minutes = twoDigits(duration.inSeconds.remainder(60));

    return "$hours:$minutes";
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return isLandscape ? landscapeLayout(context) : portraitLayout(context);
  }


  Widget portraitLayout(BuildContext context) {
    final directorService = locator.get<DirectorService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    double width = MediaQuery.of(context).size.width;
    //double aspectRatio = MediaQuery.of(context).size.aspectRatio;

    // Tema renkleri
    final iconColor = isDark ? app_theme.darkTextPrimary : app_theme.textPrimary;
    final disabledIconColor = isDark ? app_theme.darkTextSecondary.withValues(alpha: 0.4) : app_theme.textSecondary.withValues(alpha: 0.4);
    final textColor = isDark ? app_theme.darkTextPrimary : app_theme.textPrimary;
    final secondaryTextColor = isDark ? app_theme.darkTextSecondary : app_theme.textSecondary;


    final iconSize = (width / 360.0) * 22.0; // 360px referans
    final safeIconSize = iconSize.clamp(18.0, 24.0); // Min/max koruma

    final fontSize = (width / 360.0) * 14.0; // 360px = referans genişlik
    final safeFontSize = fontSize.clamp(14.0, 18.0); // Minimum/maksimum koruma

    return Row(
      children: [
        SizedBox(
          width: width * .35,
          child: StreamBuilder(
            stream: directorService.historyChanged$,
            initialData: false,
            builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
              final bool canUndo = directorService.canUndo;
              final bool canRedo = directorService.canRedo;

              return Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: width * 0.05),
                  // Audio mixer button
                  GestureDetector(
                      onTap: () async {
                        showModalBottomSheet(
                          context: context,
                          useSafeArea: true,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                          ),
                          builder: (ctx) => FractionallySizedBox(
                            heightFactor: 0.6,
                            child: AudioMixerSheet(),
                          ),
                        );
                      },
                      child: SvgIcon(
                        asset: 'volume',
                        color: iconColor,
                        size: safeIconSize,
                      ),
                    ),

                  SizedBox(width: width * 0.04),
                  // Undo button
                   GestureDetector(
                      onTap: canUndo? () async {await directorService.undo();} : null,
                      child: SvgIcon(
                        asset: 'undo',
                        color: canUndo ? iconColor : disabledIconColor,
                        size: safeIconSize,
                      ),
                    ),

                  SizedBox(width: width * 0.02),
                  // Redo button
                  GestureDetector(
                    onTap: canRedo ? () async {await directorService.redo();} : null,
                    child: SvgIcon(
                      asset: 'redo',
                      color: canRedo ? iconColor : disabledIconColor,
                      size: safeIconSize,
                    ),
                  ),

                ],
              );
            },
          ),
        ),

        const Spacer(),
        // Play/Pause butonu - directorService stream'ine bağlı
        StreamBuilder(
          stream: directorService.appBar$,
          initialData: false,
          builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
            final bool hasRasterAssets = directorService.hasRasterAssets();
            final bool hasAudioAtPos =
                directorService.mainAudioLayerForPosition(directorService.position) != -1;
            final bool canPlayNow = hasRasterAssets || hasAudioAtPos;
            final bool isPlaying = directorService.isPlaying;

            return IconButton(
              onPressed: canPlayNow
                  ? () {
                if (isPlaying) {
                  directorService.stop();
                } else {
                  directorService.play();
                }
              }
                  : null,
              icon: SvgIcon(
                asset:  isPlaying ? 'pause' : 'play',
                color: canPlayNow ? app_theme.accent : disabledIconColor,
                size: safeIconSize,
                //fill: 1.0,
                //weight: 700,
                //grade: 200,
              ),
            );
          },
        ),
        const Spacer(),
        SizedBox(
          width: width * .35,
          child: FittedBox(
            fit: BoxFit.scaleDown, // Sığarsa normal kalır, sığmazsa küçülür
            alignment: Alignment.centerLeft, // Sola yaslı küçülsün
            child: Row(
              mainAxisSize: MainAxisSize.min, // 👈 KRİTİK: Sadece içerik genişliği
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Mevcut pozisyon
                StreamBuilder(
                  stream: directorService.position$,
                  initialData: 0,
                  builder: (BuildContext context, AsyncSnapshot<int> position) {
                    return Text(
                      '${directorService.positionMinutes}:${directorService.positionSeconds}',
                      style: TextStyle(
                        fontSize: safeFontSize,
                        color: textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: width * .003),
                  child: Text(
                    '/',
                    style: TextStyle(
                      fontSize: safeFontSize,
                      color: app_theme.accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Toplam süre
                StreamBuilder(
                  stream: directorService.layersChanged$,
                  initialData: false,
                  builder: (BuildContext context, AsyncSnapshot<bool?> layersChanged) {
                    final int durationMs = directorService.duration;
                    final int minutes = (durationMs / 60000).floor();
                    final int seconds = ((durationMs % 60000) / 1000).floor();
                    final String minutesStr = minutes.toString().padLeft(2, '0',);
                    final String secondsStr = seconds.toString().padLeft(2, '0',);

                    return Text(
                      '$minutesStr:$secondsStr',
                      style: TextStyle(
                        fontSize: safeFontSize,
                        color: secondaryTextColor,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }


  Widget landscapeLayout(BuildContext context) {
    final directorService = locator.get<DirectorService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    // Tema renkleri
    final iconColor = isDark ? app_theme.darkTextPrimary : app_theme.textPrimary;
    final disabledIconColor = isDark ? app_theme.darkTextSecondary.withValues(alpha: 0.4) : app_theme.textSecondary.withValues(alpha: 0.4);

    return Container(
      color: isDark ? app_theme.projectListBg : app_theme.background,
      padding: EdgeInsets.symmetric(horizontal: 8,),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          StreamBuilder(
            stream: directorService.layersChanged$,
            initialData: false,
            builder: (BuildContext context, AsyncSnapshot<bool?> snapshot) {
              final hasAssets = directorService.hasRasterAssets();
              final bool canExport = directorService.duration > 0;
              return Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Archive (Import/Export .vvz)
                  SizedBox(
                    height: 36, // 🔽 alt–üst boşluk burada kontrol edilir
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        if (directorService.project == null) return;
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          builder: (context) => ArchiveSheet(project: directorService.project!),
                        );
                      },
                      icon: SvgIcon(
                        asset: 'save_library',
                        size: 22,
                        color: hasAssets ? iconColor : disabledIconColor,
                      ),
                      tooltip: loc.editorHeaderArchiveTooltip,
                    ),
                  ),
                  SizedBox(
                    height: 36, // 🔽 alt–üst boşluk burada kontrol edilir
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        if (directorService.project == null) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => ExportVideoList(directorService.project!),
                          ),
                        );
                      },
                      icon: SvgIcon(
                        asset: 'video_library',
                        color: iconColor,
                        size: 22,
                      ),
                      tooltip: loc.editorHeaderViewGeneratedTooltip,
                    ),
                  ),
                  SizedBox(
                    height: 36, // 🔽 alt–üst boşluk burada kontrol edilir
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: canExport
                          ? () {
                        showModalBottomSheet(
                          context: context,
                          useSafeArea: true,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                          ),
                          builder: (ctx) => FractionallySizedBox(
                            heightFactor: 0.7,
                            child: const ExportSheet(),
                          ),
                        );
                      }
                          : null,
                      icon: SvgIcon(
                        asset: 'export',
                        size: 22,
                        color: canExport ? app_theme.accent : disabledIconColor,
                      ),
                      tooltip: canExport ? loc.editorHeaderExportTooltip : loc.editorHeaderAddVideoFirstTooltip,
                    ),
                  ),
                  SizedBox(width: 70,)
                ],
              );
            },
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [

              // Audio mixer button
              SizedBox(
                height: 36, // 🔽 alt–üst boşluk burada kontrol edilir
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () async {
                    showModalBottomSheet(
                      context: context,
                      useSafeArea: true,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      builder: (ctx) => FractionallySizedBox(
                        heightFactor: 0.6,
                        child: AudioMixerSheet(),
                      ),
                    );
                  },
                  icon: SvgIcon(
                    asset: 'volume',
                    color: iconColor,
                    size: 22,
                  ),
                ),
              ),
              StreamBuilder(
                stream: directorService.appBar$,
                initialData: false,
                builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
                  final bool hasRasterAssets = directorService.hasRasterAssets();
                  final bool hasAudioAtPos =
                      directorService.mainAudioLayerForPosition(directorService.position) != -1;
                  final bool canPlayNow = hasRasterAssets || hasAudioAtPos;
                  final bool isPlaying = directorService.isPlaying;

                  return SizedBox(
                    height: 36, // 🔽 alt–üst boşluk burada kontrol edilir
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: canPlayNow ? () {
                        if (isPlaying) {
                          directorService.stop();
                        } else {
                          directorService.play();
                        }
                      } : null,
                      icon: SvgIcon(
                        asset:  isPlaying ? 'pause' : 'play',
                        color: canPlayNow ? app_theme.accent : disabledIconColor,
                        size: 22,
                      ),
                    ),
                  );
                },
              ),

            ],
          ),
        ],
      ),
    );
  }
}
