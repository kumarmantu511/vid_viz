import 'dart:io';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:vidviz/l10n/generated/app_localizations.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/model/generated.dart';
import 'package:vidviz/model/project.dart';
import 'package:vidviz/service/generated_service.dart';
import 'package:vidviz/ui/widgets/export/playback_screen.dart';

import 'package:vidviz/core/theme.dart' as app_theme;

import '../ads/home_banner_ad.dart';


class ExportVideoList extends StatelessWidget {
  final generatedVideoService = locator.get<GeneratedService>();
  final Project project;

  ExportVideoList(this.project) {
    generatedVideoService.refresh(project.id!);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? app_theme.projectListBg : app_theme.background;
    final textColor = isDark ? app_theme.darkTextPrimary : app_theme.textPrimary;
    //final secondaryTextColor = isDark ? app_theme.darkTextSecondary : app_theme.textSecondary;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: textColor, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          project.title.isNotEmpty  ? project.title  : loc.exportVideoListFallbackTitle,
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const Center(child: HomeBannerAd()),
          Expanded(
            child: StreamBuilder(
            stream: generatedVideoService.generatedVideoListChanged$,
            initialData: false,
            builder: (context, snapshot) {
              final list = generatedVideoService.generatedVideoList;
              final loc = AppLocalizations.of(context);
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final textColor = isDark ? app_theme.darkTextPrimary : app_theme.textPrimary;
              final secondaryTextColor = isDark ? app_theme.darkTextSecondary : app_theme.textSecondary;

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 1 + list.length, // 1 = başlık, gerisi liste
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // 👇 BAŞLIK BURADA (ilk eleman)
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8), // sol/sağ 20 → 4 çünkü padding zaten 16
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: app_theme.accent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.video_library_rounded,
                              color: app_theme.accent,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  loc.exportVideoListHeaderTitle,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  loc.exportVideoListCount(list.length),
                                  style: TextStyle(
                                    color: secondaryTextColor,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  } else {
                    // 👇 LİSTE ELEMANLARI
                    final video = list[index - 1];
                    return _GeneratedVideoCard(video: video, index: index - 1);
                  }
                },
              );
            },
                ),
          ),
        ],
      ),
    );
  }
}

/// Ana sayfadaki _StyledListCard ile aynı stil
class _GeneratedVideoCard extends StatelessWidget {
  final generatedVideoService = locator.get<GeneratedService>();
  final GeneratedVideo video;
  final int index;

  _GeneratedVideoCard({
    required this.video,
    required this.index,
  });

  void _showFileNotExistDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? app_theme.projectListCardBg : app_theme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(app_theme.radiusL)),
          title: Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.red.shade400, size: 24),
              const SizedBox(width: 10),
              Text(
                loc.exportVideoListFileNotFoundTitle,
                style: TextStyle(
                  color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            loc.exportVideoListFileNotFoundMessage,
            style: TextStyle(
              color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                loc.commonOk,
                style: TextStyle(
                  color: app_theme.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _playVideo(BuildContext context) {
    if (!generatedVideoService.fileExists(index)) {
      _showFileNotExistDialog(context);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlaybackScreen(path: video.path),
        ),
      );
    }
  }

  void _deleteVideo(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? app_theme.projectListCardBg : app_theme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(app_theme.radiusL)),
          title: Text(
            loc.exportVideoListDeleteDialogTitle,
            style: TextStyle(
              color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            loc.exportVideoListDeleteDialogMessage,
            style: TextStyle(
              color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                loc.commonCancel,
                style: TextStyle(
                  color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                generatedVideoService.delete(index);
              },
              child: Text(
                loc.commonDelete,
                style: TextStyle(
                  color: Colors.red.shade400,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? app_theme.projectListCardBg : app_theme.surface;
    final borderColor = isDark ? app_theme.projectListCardBorder : app_theme.border;
    final textColor = isDark ? app_theme.darkTextPrimary : app_theme.textPrimary;
    final secondaryTextColor = isDark ? app_theme.darkTextSecondary : app_theme.textSecondary;

    final bool thumbnailExists = video.thumbnail != null && File(video.thumbnail!).existsSync();
    final dateStr = DateFormat.yMMMd().format(video.date);
    final timeStr = DateFormat.Hm().format(video.date);

    return GestureDetector(
      onTap: () => _playVideo(context),
      child: Container(
        margin: EdgeInsets.only(bottom: app_theme.spaceS),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(app_theme.radiusL),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            // 👉 Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(app_theme.radiusM),
              child: Container(
                width: 64,
                height: 64,
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (thumbnailExists)
                      Image.file(
                        File(video.thumbnail!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _buildPlaceholder(secondaryTextColor),
                      )
                    else
                      _buildPlaceholder(secondaryTextColor),
                    // Play overlay
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 14),

            // 👉 Metin Alanı (esnek)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dateStr,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        timeStr,
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: app_theme.accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          video.resolution ?? '?',
                          style: TextStyle(
                            color: app_theme.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 👉 Aksiyon Butonları
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _MiniButton(
                    icon: Icons.play_arrow_rounded,
                    color: app_theme.accent,
                    onTap: () => _playVideo(context),
                  ),
                  const SizedBox(height: 6),
                  _MiniButton(
                    icon: Icons.delete_outline_rounded,
                    color: Colors.red.shade400,
                    onTap: () => _deleteVideo(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(Color color) {
    return Center(
      child: Icon(
        Icons.movie_rounded,
        color: color.withOpacity(0.5),
        size: 32,
      ),
    );
  }
}

/// Mini aksiyon butonu
class _MiniButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MiniButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}
