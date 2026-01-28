import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter_svg/svg.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/ad_service.dart';
import 'package:vidviz/service/director_service.dart';
import 'package:vidviz/core/theme.dart' as app_theme;
import 'package:vidviz/ui/widgets/ads/home_banner_ad.dart';
import 'package:vidviz/service/export/native_generator.dart';
import 'package:vidviz/l10n/generated/app_localizations.dart';
import 'package:vidviz/ui/widgets/export/playback_screen.dart';

class ExportProgress extends StatefulWidget {
  const ExportProgress({super.key});

  @override
  State<ExportProgress> createState() => _ExportProgressState();
}

class _ExportProgressState extends State<ExportProgress> {
  final DirectorService directorService = locator.get<DirectorService>();
  bool _interstitialShown = false;
  Timer? _exportInterstitialTimer;
  FFmpegStat? _lastStat;
  bool _exportStarted = false;
  int _exportProgressAdSessionId = 0;

  @override
  void initState() {
    super.initState();
    try {
      _exportProgressAdSessionId = locator.get<AdService>().beginExportProgressSession();
    } catch (_) {}
  }

  @override
  void dispose() {
    _exportInterstitialTimer?.cancel();
    _exportInterstitialTimer = null;
    try {
      locator.get<AdService>().endExportProgressSession(_exportProgressAdSessionId);
    } catch (_) {}
    super.dispose();
  }

  bool _hasExportStarted(FFmpegStat stat) {
    return (stat.timeElapsed ?? 0) > 0 ||
        (stat.time ?? 0) > 0 ||
        stat.totalFiles != null ||
        stat.fileNum != null;
  }

  void _maybeStartExportInterstitialTimer(FFmpegStat stat) {
    if (_exportStarted) return;
    if (!_hasExportStarted(stat)) return;
    _exportStarted = true;

    _exportInterstitialTimer?.cancel();
    _exportInterstitialTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      if (_interstitialShown) return;
      final latest = _lastStat;
      if (latest == null) return;
      final bool isFinished = latest.finished ?? false;
      final bool isError = latest.error ?? false;
      if (isFinished || isError) return;
      if (!_hasExportStarted(latest)) return;

      _interstitialShown = true;
      try {
        locator.get<AdService>().showExportInterstitialThrottled(
          exportProgressSessionId: _exportProgressAdSessionId,
        );
      } catch (_) {}
    });
  }

  String? get _thumbnailPath {
    final exportThumb = directorService.exportPreviewThumbnailPath;
    if (exportThumb != null && exportThumb.isNotEmpty && File(exportThumb).existsSync()) {
      return exportThumb;
    }
    final projectImage = directorService.project?.imagePath;
    if (projectImage != null && projectImage.isNotEmpty && File(projectImage).existsSync()) {
      return projectImage;
    }
    final thumbMed = directorService.getFirstThumbnailMedPath();
    if (thumbMed != null && thumbMed.isNotEmpty && File(thumbMed).existsSync()) {
      return thumbMed;
    }
    return null;
  }

  void _cancelExport() {
    Navigator.of(context).pop();
    Future.delayed(const Duration(milliseconds: 100), () {
      directorService.cancelExport();
    });
  }

  void _openVideo(String path) async {
    final nav = Navigator.of(context);
    nav.pop();
    await nav.push(
      MaterialPageRoute(
        builder: (_) => PlaybackScreen(path: path),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    // Tema renkleri
    final bgColor = isDark ? app_theme.projectListBg : app_theme.background;
    final textColor = isDark ? app_theme.darkTextPrimary : app_theme.textPrimary;
    final secondaryTextColor = isDark ? app_theme.darkTextSecondary : app_theme.textSecondary;
    final cardBgColor = isDark ? app_theme.projectListCardBg : app_theme.surface;
    final errorColor = Colors.red.shade400;
    final successColor = app_theme.accent;

    return Scaffold(
      backgroundColor: bgColor,
      body: StreamBuilder<FFmpegStat>(
        stream: directorService.progress$,
        initialData: FFmpegStat(),
        builder: (context, snapshot) {
          final thumbnail = _thumbnailPath;
          final FFmpegStat stat = snapshot.data!;
          _lastStat = stat;
          _maybeStartExportInterstitialTimer(stat);

          // Durum ve ilerleme hesaplama
          String title;
          String subtitle;
          double progress = 0;
          String remainingText = '';
          String extraText = '';
          bool isFinished = stat.finished ?? false;
          bool isError = stat.error ?? false;

          if (isFinished) {
            title = loc.exportProgressSavedTitle;
            subtitle = '';
            progress = 1.0;
          } else if (isError) {
            title = loc.exportProgressErrorTitle;
            subtitle = (stat.message != null && stat.message!.isNotEmpty)
                ? stat.message!
                : loc.exportProgressErrorMessage;
            progress = 0;
          } else if (stat.totalFiles != null && stat.fileNum != null) {
            // Preprocessing aşaması
            title = loc.exportProgressPreprocessingTitle;
            subtitle = loc.exportProgressFileOfTotal(stat.fileNum!, stat.totalFiles!);
            progress = (stat.fileNum! - 1 + (stat.time ?? 0) / directorService.duration) / stat.totalFiles!;
          } else if ((stat.time ?? 0) > 100) {
            // Building aşaması
            title = loc.exportProgressBuildingTitle;
            subtitle = '';
            progress = (stat.time ?? 0) / directorService.duration;

            // Kalan süre hesaplama
            if ((stat.timeElapsed ?? 0) > 0 && (stat.time ?? 0) > 0) {
              int remaining = (stat.timeElapsed! * (directorService.duration / stat.time! - 1)).floor();
              if (remaining > 0) {
                int minutes = Duration(milliseconds: remaining).inMinutes;
                int seconds = Duration(milliseconds: remaining).inSeconds - 60 * minutes;
                remainingText = loc.exportProgressRemaining(minutes, seconds);
              }
            }
          } else {
            title = loc.exportProgressBuildingTitle;
            subtitle = '';
            progress = 0;
          }

          // Extra bilgiler (boyut, hız)
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

          // Progress rengi duruma göre
          Color progressColor = isError ? errorColor : (isFinished ? successColor : app_theme.accent);

          return Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 32),
                  const Center(child: HomeBannerAd()),
                  const SizedBox(height: 12),
                  // Başlık
                  Text(
                    title,
                    style: TextStyle(
                      color: isError ? errorColor : textColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),

                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 4),
                  // Progress görseli + Thumbnail
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Arka plan container + Thumbnail
                      Container(
                        width: 200,
                        height: 300,
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? app_theme.projectListCardBorder : app_theme.border,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: progressColor.withOpacity(0.15),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: _buildThumbnailContent(
                            thumbnail: thumbnail,
                            isFinished: isFinished,
                            isError: isError,
                            successColor: successColor,
                            errorColor: errorColor,
                            cardBgColor: cardBgColor,
                          ),
                        ),
                      ),

                      // Progress çerçevesi
                      SizedBox(
                        width: 200,
                        height: 300,
                        child: CustomPaint(
                          painter: RectangularProgressPainter(
                            percentage: progress.clamp(0.0, 1.0),
                            color: progressColor,
                            strokeWidth: 4.0,
                            borderRadius: 12,
                          ),
                        ),
                      ),

                      // Yüzde gösterimi - Smooth animasyonlu
                      if (!isFinished && !isError)
                        SmoothCounter(
                          value: (progress * 100).toInt(),
                          color: Colors.white,
                          bgColor: Colors.black.withOpacity(0.7),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  // Alt bilgiler
                  if (remainingText.isNotEmpty)
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 0),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.15),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: Text(
                        remainingText,
                        key: ValueKey<String>(remainingText),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: app_theme.accent,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  if (extraText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.12),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: Text(
                          extraText,
                          key: ValueKey<String>(extraText),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  if (!isFinished && !isError)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        loc.exportFullDoNotLock,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: secondaryTextColor.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),
                  // Alt butonlar - sabit
                  Container(
                    padding: const EdgeInsets.only(left: 75,right: 75,bottom: 75),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Share butonları (sadece tamamlandığında)
                        if (isFinished && stat.outputPath != null && stat.outputPath!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8,top: 8),
                            child: _ShareButtons(
                              videoPath: stat.outputPath!,
                              cardBgColor: cardBgColor,
                              borderColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
                            ),
                          ),

                        // Video aç butonu (sadece tamamlandığında)
                        if (isFinished && stat.outputPath != null && stat.outputPath!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12 ),
                            child: SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: app_theme.neonButtonGradient,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: app_theme.accent.withOpacity(0.3),
                                      blurRadius: 15,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton.icon(
                                  onPressed: () => _openVideo(stat.outputPath!),
                                  icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                                  label: Text(
                                    loc.exportProgressOpenVideoButton,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // Cancel / Close butonu - ortada
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: Container(
                            decoration: BoxDecoration(
                              color: isFinished || isError
                                  ? (isDark ? app_theme.projectListCardBg : app_theme.surface)
                                  : null,
                              gradient: isFinished || isError ? null : app_theme.neonButtonGradient,
                              borderRadius: BorderRadius.circular(12),
                              border: isFinished || isError
                                  ? Border.all(
                                      color: isDark ? app_theme.projectListCardBorder : app_theme.border,
                                    )
                                  : null,
                              boxShadow: isFinished || isError
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: app_theme.accent.withOpacity(0.3),
                                        blurRadius: 15,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                            ),
                            child: ElevatedButton(
                              onPressed: isFinished || isError
                                  ? () {
                                      Navigator.of(context).pop();
                                    }
                                  : _cancelExport,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                isFinished || isError
                                    ? loc.exportFullCloseButton
                                    : loc.exportFullCancelButton,
                                style: TextStyle(
                                  color: isFinished || isError
                                      ? (isDark ? app_theme.darkTextPrimary : app_theme.textPrimary)
                                      : Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Thumbnail içeriğini oluştur
  Widget _buildThumbnailContent({
    required String? thumbnail,
    required bool isFinished,
    required bool isError,
    required Color successColor,
    required Color errorColor,
    required Color cardBgColor,
  }) {
    // Tamamlandı durumunda
    if (isFinished) {
      return Stack(
        fit: StackFit.expand,
        children: [
          if (thumbnail != null)
            Image.file(
              File(thumbnail),
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.3),
              colorBlendMode: BlendMode.darken,
            ),
          Center(
            child: Icon(Icons.check_circle_rounded, color: successColor, size: 70),
          ),
        ],
      );
    }
    
    // Hata durumunda
    if (isError) {
      return Stack(
        fit: StackFit.expand,
        children: [
          if (thumbnail != null)
            Image.file(
              File(thumbnail),
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.5),
              colorBlendMode: BlendMode.darken,
            ),
          Center(
            child: Icon(Icons.error_rounded, color: errorColor, size: 70),
          ),
        ],
      );
    }
    
    // Export sırasında thumbnail göster
    // Blur arka plan + contain resim (yatay/dikey uyumlu)
    if (thumbnail != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          // Arka plan - blur + cover (boşlukları doldurur)
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Image.file(
              File(thumbnail),
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.4),
              colorBlendMode: BlendMode.darken,
            ),
          ),
          // Ön plan - contain (orantılı, net)
          Image.file(
            File(thumbnail),
            fit: BoxFit.contain,
          ),
        ],
      );
    }
    
    // Thumbnail yoksa placeholder
    return Container(
      color: cardBgColor,
      child: Center(
        child: Icon(
          Icons.movie_rounded,
          color: app_theme.accent.withOpacity(0.3),
          size: 50,
        ),
      ),
    );
  }
}

/// Rounded corners destekli progress painter
class RectangularProgressPainter extends CustomPainter {
  final double percentage; 
  final Color color;
  final double strokeWidth;
  final double borderRadius;

  RectangularProgressPainter({
    required this.percentage,
    required this.color,
    required this.strokeWidth,
    this.borderRadius = 16,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));
    
    // Arka plan çerçevesi
    final Paint bgPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawRRect(rrect, bgPaint);

    // Aktif progress
    final Paint activePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // RRect path oluştur
    final Path path = Path()..addRRect(rrect);
    final PathMetrics pathMetrics = path.computeMetrics();
    final PathMetric pathMetric = pathMetrics.first;
    final double totalLength = pathMetric.length;
    
    // Üst ortadan başla
    final double startOffset = totalLength * 0.125; // Üst kenarın ortası
    final double drawLength = totalLength * percentage;
    
    if (drawLength > 0) {
      Path extractPath;
      if (startOffset + drawLength <= totalLength) {
        extractPath = pathMetric.extractPath(startOffset, startOffset + drawLength);
      } else {
        // Wrap around
        final firstPart = pathMetric.extractPath(startOffset, totalLength);
        final secondPart = pathMetric.extractPath(0, (startOffset + drawLength) - totalLength);
        extractPath = Path()..addPath(firstPart, Offset.zero)..addPath(secondPart, Offset.zero);
      }

      // Glow efekti
      final Paint glowPaint = Paint()
        ..color = color.withAlpha(50)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 4
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawPath(extractPath, glowPaint);
      canvas.drawPath(extractPath, activePaint);
    }
  }

  @override
  bool shouldRepaint(covariant RectangularProgressPainter oldDelegate) {
    return oldDelegate.percentage != percentage || oldDelegate.color != color;
  }
}

/// Akıcı sayaç widget
class SmoothCounter extends StatelessWidget {
  final int value;
  final Color color;
  final Color bgColor;
  final double fontSize;

  const SmoothCounter({
    super.key,
    required this.value,
    required this.color,
    required this.bgColor,
    this.fontSize = 28,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, animValue, child) {
        final displayValue = animValue.round().clamp(0, 99);
        final displayText = displayValue.toString().padLeft(2, '0');
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(64),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AnimatedDigit(
                value: displayText[0],
                color: color,
                fontSize: fontSize,
              ),
              const SizedBox(width: 2),
              _AnimatedDigit(
                value: displayText[1],
                color: color,
                fontSize: fontSize,
              ),
              Text(
                '%',
                style: TextStyle(
                  color: color,
                  fontSize: fontSize * 0.7,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AnimatedDigit extends StatelessWidget {
  final String value;
  final Color color;
  final double fontSize;

  const _AnimatedDigit({
    required this.value,
    required this.color,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.2),
              end: Offset.zero,
            ).animate(animation),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOut),
              ),
              child: child,
            ),
          ),
        );
      },
      child: Text(
        value,
        key: ValueKey<String>(value),
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Share butonları widget'ı
class _ShareButtons extends StatelessWidget {
  final String videoPath;
  final Color cardBgColor;
  final Color borderColor;

  const _ShareButtons({
    required this.videoPath,
    required this.cardBgColor,
    required this.borderColor,
  });

  Future<void> _shareToApp(BuildContext context, String? packageName) async {
    final file = XFile(videoPath);

    final params = ShareParams(
      text: AppLocalizations.of(context).exportShareMessage,
      files: [file],
    );

    final result = await SharePlus.instance.share(params);

    if (result.status == ShareResultStatus.success) {
      print('Thank you for sharing the video!');
    }
    //await SharePlus.shareXFiles(
    //  [file],
    //  text: AppLocalizations.of(context).exportShareMessage,
    //);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Instagram
          _ShareButton(
            icon: 'youtube',
            label: 'YouTube',
            color: app_theme.surface,
            onTap: () => _shareToApp(context, 'com.youtube'),
          ),

          const SizedBox(width: 6),
          // WhatsApp
          _ShareButton(
            icon: 'tiktok',
            label: loc.exportShareTikTok,
            color: app_theme.surface,
            onTap: () => _shareToApp(context, 'com.whatsapp'),
          ),

          const SizedBox(width: 6),
          // TikTok
          _ShareButton(
            icon:  'instagram',
            label: loc.exportShareInstagram,
            color: app_theme.surface,
            onTap: () => _shareToApp(context, 'com.zhiliaoapp.musically'),
            height:40,
            width:40,
          ),

        /// const SizedBox(width: 6),
        /// // More
        /// _ShareButton(
        ///   icon: 'facebook',
        ///   label: 'Fecebook',
        ///   color: app_theme.surface,
        ///   onTap: () => _shareToApp(context, null),
        /// ),
          const SizedBox(width: 6),
          // More
          _ShareButton(
            icon: 'more',
            label: loc.exportShareMore,
            color:  app_theme.surface,
            onTap: () => _shareToApp(context, null),
            height:22,
            width:22,
          ),

        ],
      ),
    );
  }
}


/// Tek share butonu (SVG)
class _ShareButton extends StatelessWidget {
  final String icon; // SADECE icon adı
  final String label;
  final double? width;
  final double? height;
  final Color color;
  final VoidCallback onTap;

  const _ShareButton({
    this.width = 42,
    this.height = 42,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
    isDark ? app_theme.darkTextSecondary : app_theme.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
             color: color,
             borderRadius: BorderRadius.circular(10),
             boxShadow: [
               BoxShadow(
                 color: color.withOpacity(0.3),
                 blurRadius: 8,
                 offset: const Offset(0, 3),
               ),
             ],
            ),
            child: Center(
              child: SvgPicture.asset(
                'assets/social/$icon.svg',
                width: width,
                height: height,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}