import 'package:flutter/material.dart';
import 'package:vidviz/l10n/generated/app_localizations.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/director_service.dart';
import 'package:vidviz/service/export/native_generator.dart';
import 'package:vidviz/service/pro_service.dart';
import 'package:vidviz/ui/screens/pro_subscription_screen.dart';
import 'package:vidviz/ui/widgets/export/export_progress.dart';
import 'package:vidviz/core/theme.dart' as app_theme;

class ExportSheet extends StatefulWidget {
  const ExportSheet({super.key});

  @override
  State<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<ExportSheet> {
  final directorService = locator.get<DirectorService>();
  final proService = locator.get<ProService>();

  // --- STATE DEĞİŞKENLERİ ---

  // Çözünürlük Seçenekleri (Demo Data)
  final List<String> _resolutions = [
    //"8k UHD 4320p",
    //"6k UHD 3456p",
    "4k UHD 2160p",
    "2k QHD 1440p",
    "Full HD 1080p",
    "HD 720p",
    "SD 360p",
  ];
  String _selectedResolution = "Full HD 1080p";

  // Format Seçenekleri (Kaydırılabilir liste için)
  final List<String> _formats = ["MOV", "MP4"/*, "GIF", "AVI", "MKV", "WEBM"*/];
  String _selectedFormat = 'MOV';

  // FPS Slider
  double _sliderValue = 2.0;
  final List<String> _fpsLabels = ['24f', '25f', '30f', '50f', '60f'];

  // Quality / Bitrate (0=Low,1=Medium,2=High)
  int _qualityIndex = 1;
  final List<String> _qualityLabels = ['Low', 'Medium', 'High'];

  VideoResolution _resolutionFromLabel(String value) {
    switch (value) {
      //case "8k UHD 4320p":
      //  return VideoResolution.uhd8k;
      //case "6k UHD 3456p":
      //  return VideoResolution.uhd6k;
      case "4k UHD 2160p":
        return VideoResolution.uhd4k;
      case "2k QHD 1440p":
        return VideoResolution.qhd;
      case "Full HD 1080p":
        return VideoResolution.fullHd;
      case "HD 720p":
        return VideoResolution.hd;
      case "SD 360p":
      default:
        return VideoResolution.sd;
    }
  }

  String _resolutionLabel(AppLocalizations loc, String value) {
    switch (value) {
      //case "8k UHD 4320p":
      //  return loc.videoRes8k;
      //case "6k UHD 3456p":
      //  return loc.videoRes6k;
      case "4k UHD 2160p":
        return loc.videoRes4k;
      case "2k QHD 1440p":
        return loc.videoRes2k;
      case "Full HD 1080p":
        return loc.videoResFullHd;
      case "HD 720p":
        return loc.videoResHd;
      case "SD 360p":
        return loc.videoResSd;
      default:
        return value;
    }
  }

  void _exportVideo() {
    VideoResolution resolution = _resolutionFromLabel(_selectedResolution);

    if (!proService.canUseResolution(resolution)) {
      _showProRequiredDialog();
      return;
    }

    final List<int> fpsValues = [24, 25, 30, 50, 60];
    final int fps = fpsValues[
      _sliderValue.clamp(0, (fpsValues.length - 1).toDouble()).round()
    ];

    // 2. Sheet'i kapat
    Navigator.pop(context);

    // 3. Export işlemini başlat
    // Not: FPS, Quality ve mevcut VideoSettings bilgisi ExportPipeline üzerinden uygulanır.
    if (directorService.layers != null) {
      directorService.generateVideo(
        directorService.layers!,
        resolution,
        framerate: fps,
        quality: _qualityIndex,
        outputFormat: _selectedFormat,
      );
      
      // 4. Progress Dialog göster todo dialog sonr abkacaz şuan rota
       Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ExportProgress(), // Yeni sayfa
        ),
      );

         /* showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return ExportProgress();
        },
      );*/
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final size = MediaQuery.of(context).size;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? app_theme.background : app_theme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            // Handle
            Column(
              //mainAxisSize: MainAxisSize.min, // İçerik kadar yer kaplasın (veya fixed height)
              //crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? app_theme.darkTextSecondary : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Başlık ve Kapat Butonu
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16,  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text( loc.exportSheetTitle, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5, color: app_theme.textPrimary)),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.black12,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.close_rounded, size: 20, color: app_theme.textPrimary),
                        ),
                      )
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 2. RESOLUTION (Çalışan Dropdown)
                        Text(
                          loc.exportSheetResolutionLabel,
                          style: TextStyle(
                              color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          loc.exportSheetResolutionHelp,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                              fontSize: 12
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Dropdown Tetikleyici Kutu
                        PopupMenuButton<String>(
                          offset: const Offset(0, 50),
                          color: isDark ? app_theme.projectListCardBg : app_theme.surface,
                          onSelected: (String value) {
                            final resolution = _resolutionFromLabel(value);
                            if (!proService.canUseResolution(resolution)) {
                              _showProRequiredDialog();
                              return;
                            }
                            setState(() {
                              _selectedResolution = value;
                            });
                          },
                          itemBuilder: (BuildContext context) {
                            return _resolutions.map((String choice) {
                              final resolution = _resolutionFromLabel(choice);
                              final isProOnly = proService.isResolutionProOnly(resolution);
                              return PopupMenuItem<String>(
                                value: choice,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                        _resolutionLabel(loc, choice),
                                        style: TextStyle(color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary)
                                    ),
                                    if (isProOnly)
                                      Icon(Icons.workspace_premium, color: app_theme.accent, size: 16),
                                  ],
                                ),
                              );
                            }).toList();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark ? app_theme.projectListCardBg : app_theme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: isDark ? app_theme.projectListCardBorder : app_theme.border
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      _resolutionLabel(loc, _selectedResolution),
                                      style: TextStyle(
                                          color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    if (proService.isResolutionProOnly(_resolutionFromLabel(_selectedResolution)))
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                            color: app_theme.accent.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: app_theme.accent, width: 1)
                                        ),
                                        child: Icon(Icons.workspace_premium, color: app_theme.accent, size: 14),
                                      ),
                                  ],
                                ),
                                Icon(Icons.keyboard_arrow_down, color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // 3. FILE FORMAT (Yana Kayan Liste)
                        Text(
                          loc.exportSheetFileFormatLabel,
                          style: TextStyle(
                              color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Scrollable Container
                        SizedBox(
                          height: 34,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _formats.length,
                            separatorBuilder: (context, index) => const SizedBox(width: 10),
                            itemBuilder: (context, index) {
                              final format = _formats[index];
                              final isSelected = _selectedFormat == format;
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedFormat = format;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? app_theme.accent.withOpacity(0.2)
                                        : (isDark ? app_theme.projectListCardBg : app_theme.surface),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected ? app_theme.accent : (isDark ? app_theme.projectListCardBorder : app_theme.border),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    format,
                                    style: TextStyle(
                                      color: isSelected
                                          ? app_theme.accent
                                          : (isDark ? app_theme.darkTextSecondary : app_theme.textSecondary),
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 12),

                        // 4. FRAMES PER SECOND (Custom Slider)
                        Text(
                          loc.exportSheetFpsLabel,
                          style: TextStyle(
                              color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          loc.exportSheetFpsHelp,
                          style: TextStyle(
                              color: isDark ? app_theme.darkTextSecondary : app_theme.textSecondary,
                              fontSize: 12
                          ),
                        ),
                        const SizedBox(height: 12),

                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: app_theme.accent,
                            inactiveTrackColor: isDark ? app_theme.projectListCardBorder : app_theme.border,
                            trackHeight: 4.0,
                            thumbColor: app_theme.accent,
                            overlayColor: app_theme.accent.withOpacity(0.1),
                            thumbShape: _CustomThumbShape(thumbColor: app_theme.accent),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                          ),
                          child: Slider(
                            value: _sliderValue,
                            min: 0,
                            max: 4,
                            divisions: 4,
                            onChanged: (value) {
                              setState(() {
                                _sliderValue = value;
                              });
                            },
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(_fpsLabels.length, (index) {
                              bool isSelected = index == _sliderValue.toInt();
                              return Text(
                                _fpsLabels[index],
                                style: TextStyle(
                                  color: isSelected
                                      ? (isDark ? app_theme.darkTextPrimary : app_theme.textPrimary)
                                      : (isDark ? app_theme.darkTextSecondary : app_theme.textSecondary),
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 12,
                                ),
                              );
                            }),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // 5. QUALITY / BITRATE
                        Text(
                          loc.exportSheetQualityLabel,
                          style: TextStyle(
                            color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: List.generate(_qualityLabels.length, (index) {
                            final bool isSelected = _qualityIndex == index;
                            String label;
                            switch (index) {
                              case 0:
                                label = loc.exportSheetQualityLow;
                                break;
                              case 1:
                                label = loc.exportSheetQualityMedium;
                                break;
                              default:
                                label = loc.exportSheetQualityHigh;
                            }
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () {
                                  setState(() {
                                    _qualityIndex = index;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? app_theme.accent.withOpacity(0.18) : (isDark ? app_theme.projectListCardBg : app_theme.surface),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected ? app_theme.accent : (isDark ? app_theme.projectListCardBorder : app_theme.border),
                                    ),
                                  ),
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                      color: isSelected
                                          ? app_theme.accent
                                          : (isDark ? app_theme.darkTextSecondary : app_theme.textSecondary),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),

                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // 5. EXPORT BUTONU

            Positioned(
              bottom: 20,
              left: size.width * 0.20,
              right: size.width * 0.20,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  gradient: app_theme.neonButtonGradient,
                  borderRadius: BorderRadius.circular(app_theme.radiusM + 4),
                  boxShadow: [
                    BoxShadow(
                      color: app_theme.neonCyan.withAlpha(50),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _exportVideo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: app_theme.transparent,
                    shadowColor: app_theme.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(app_theme.radiusM + 4),
                    ),
                  ),
                  child:Text(
                    loc.exportSheetButtonExport,
                    style: TextStyle(
                      color: app_theme.buttonTextColor,
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
    );
  }

  void _showProRequiredDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? app_theme.projectListCardBg : app_theme.surface,
          title: const Text('PRO gerekli'),
          content: const Text('Bu çözünürlük için PRO abonelik gerekiyor.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProSubscriptionScreen())).then((_) {
                  if (mounted) {
                    setState(() {});
                  }
                });
              },
              child: const Text('PRO paketleri'),
            ),
          ],
        );
      },
    );
  }
}

// Slider için Özel Uç Tasarımı
class _CustomThumbShape extends SliderComponentShape {
  final double thumbRadius = 8.0;
  final Color thumbColor;

  _CustomThumbShape({required this.thumbColor});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.fromRadius(thumbRadius);
  }

  @override
  void paint(
      PaintingContext context,
      Offset center, {
        required Animation<double> activationAnimation,
        required Animation<double> enableAnimation,
        required bool isDiscrete,
        required TextPainter labelPainter,
        required RenderBox parentBox,
        required SliderThemeData sliderTheme,
        required TextDirection textDirection,
        required double value,
        required double textScaleFactor,
        required Size sizeWithOverflow,
      }) {
    final Canvas canvas = context.canvas;

    final Paint outerPaint = Paint()
      ..color = thumbColor
      ..style = PaintingStyle.fill;

    final Paint innerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final Paint shadowPaint = Paint()
      ..color = thumbColor.withAlpha(120)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawCircle(center, thumbRadius + 3, shadowPaint);
    canvas.drawCircle(center, thumbRadius, outerPaint);
    canvas.drawCircle(center, thumbRadius - 3.5, innerPaint);
  }
}