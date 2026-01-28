import 'package:flutter/material.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/director_service.dart';
import 'package:vidviz/ui/widgets/export/export_video_list.dart';
import 'package:vidviz/l10n/generated/app_localizations.dart';
import 'package:vidviz/ui/widgets/archive/archive_sheet.dart';
import 'package:vidviz/ui/widgets/export/export_sheet.dart';
import 'package:vidviz/ui/widgets/svg_icon.dart';
import 'package:vidviz/core/theme.dart' as app_theme;

class EditorHeader extends StatelessWidget {
  EditorHeader({super.key});

  final directorService = locator.get<DirectorService>();

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return isLandscape ? landscapeLayout(context) : portraitLayout(context);
  }

  Widget portraitLayout(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    final iconColor = isDark ? app_theme.darkTextPrimary : app_theme.textPrimary;
    final disabledIconColor = isDark ? app_theme.darkTextSecondary.withAlpha(120) : app_theme.textSecondary.withAlpha(120);

    return Container(
      color: isDark ? app_theme.projectListBg : app_theme.background,
      padding: EdgeInsets.symmetric(
        horizontal: isLandscape ? 8 : 4,
        vertical: 4,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () async {
              bool exit = await directorService.exitAndSaveProject();
              if (exit) Navigator.pop(context);
            },
            icon: Icon(
              Icons.close_rounded,
              color: iconColor,
              weight: 700,
              grade: 200,
            ),
            tooltip: loc.editorHeaderCloseTooltip,
          ),
          SizedBox(width: 8),
          Expanded(
            child: StreamBuilder(
              stream: directorService.layersChanged$,
              initialData: false,
              builder: (BuildContext context, AsyncSnapshot<bool?> snapshot) {
                return Text(
                  directorService.project?.title ?? '',
                  style: TextStyle(
                    color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
                    fontSize: isLandscape ? 16 : 18,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                );
              },
            ),
          ),

          StreamBuilder(
            stream: directorService.layersChanged$,
            initialData: false,
            builder: (BuildContext context, AsyncSnapshot<bool?> snapshot) {
              final bool hasRasterAssets = directorService.hasRasterAssets();
              final bool canExport = directorService.duration > 0;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Archive (Import/Export .vvz)
                  IconButton(
                    onPressed: () {
                      if (hasRasterAssets){
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          builder: (context) => ArchiveSheet(project: directorService.project!),
                        );
                      }else{
                        return;
                      }
                    },
                    icon: SvgIcon(
                      asset: 'save_library',
                      size: 22,
                      color: hasRasterAssets ? app_theme.primary : disabledIconColor,
                    ),
                    tooltip: loc.editorHeaderArchiveTooltip,
                  ),
                  IconButton(
                    onPressed: () {
                      if (directorService.project == null) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ExportVideoList(directorService.project!),
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
                  Container(
                    height: 36,
                    margin: EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      gradient: canExport ? app_theme.neonButtonGradient : LinearGradient(colors: [Color(0xFF7BB6BD), Color(0xFF7E97BD)],),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: app_theme.neonCyan.withAlpha(15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: canExport ? () {
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
                            heightFactor: 0.8,
                            child: ExportSheet(),
                          ),
                        );
                      } : null,
                      icon: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(loc.archiveExportButton , style: TextStyle(fontSize: 11,fontWeight: FontWeight.bold,color: app_theme.textOnAccent),),
                            SizedBox(width: 4,),
                            SvgIcon(
                              asset: 'export',
                              size: 20,
                              color: app_theme.textOnAccent,
                            ),
                          ],
                        ),
                      tooltip: canExport ? loc.editorHeaderExportTooltip : loc.editorHeaderAddVideoFirstTooltip,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget landscapeLayout(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final iconColor = isDark ? app_theme.darkTextPrimary : app_theme.textPrimary;

    double width = MediaQuery.of(context).size.width;
    //double height = MediaQuery.of(context).size.height;
    double aspectRatio = MediaQuery.of(context).size.aspectRatio;
    // Tema renkleri
     final disabledIconColor = isDark ? app_theme.darkTextSecondary.withValues(alpha: 0.4) : app_theme.textSecondary.withValues(alpha: 0.4);
    final textColor = isDark ? app_theme.darkTextPrimary : app_theme.textPrimary;
    final secondaryTextColor = isDark ? app_theme.darkTextSecondary : app_theme.textSecondary;


    return Container(
      color: isDark ? app_theme.projectListBg : app_theme.background,
      padding: EdgeInsets.symmetric(horizontal: 8,),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () async {
                  bool exit = await directorService.exitAndSaveProject();
                  if (exit) Navigator.pop(context);
                },
                icon: Icon(
                  Icons.close_rounded,
                  color: iconColor,
                  weight: 700,
                  grade: 200,
                ),
                tooltip: loc.editorHeaderCloseTooltip,
              ),
              SizedBox(width: 6),
              Expanded(
                child: StreamBuilder(
                  stream: directorService.layersChanged$,
                  initialData: false,
                  builder: (BuildContext context, AsyncSnapshot<bool?> snapshot) {
                    return Text(
                      directorService.project?.title ?? '',
                      style: TextStyle(
                        color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
                        fontSize: isLandscape ? 16 : 18,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    );
                  },
                ),
              ),
            ],
          ),
          const Spacer(),
          StreamBuilder(
            stream: directorService.historyChanged$,
            initialData: false,
            builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
              final bool canUndo = directorService.canUndo;
              final bool canRedo = directorService.canRedo;

              return Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown, // Sığarsa normal kalır, sığmazsa küçülür
                      alignment: Alignment.centerLeft, // Sola yaslı küçülsün
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
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
                                  fontSize: aspectRatio * 6,
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),

                          Container(
                            padding: EdgeInsets.symmetric(horizontal: width * .002),
                            child: Text(
                              '/',
                              style: TextStyle(
                                fontSize: aspectRatio * 6,
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
                                  fontSize: aspectRatio * 6,
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

                  // Undo button
                  SizedBox(
                    height: 36, // 🔽 alt–üst boşluk burada kontrol edilir
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed:  canUndo? () async {await directorService.undo();} : null,
                      icon: SvgIcon(
                        asset: 'undo',
                        color: canUndo ? iconColor : disabledIconColor,
                        size: 22,
                      ),
                    ),
                  ),

                  // Redo button
                  SizedBox(
                    height: 36, // 🔽 alt–üst boşluk burada kontrol edilir
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: canRedo ? () async {await directorService.redo();} : null,
                      icon: SvgIcon(
                        asset: 'redo',
                        color: canRedo ? iconColor : disabledIconColor,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
