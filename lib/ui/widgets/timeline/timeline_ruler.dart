import 'package:flutter/material.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/director_service.dart';
import 'package:vidviz/core/params.dart';
import 'package:vidviz/core/theme.dart' as app_theme;

/// Timeline üzerindeki zaman çizgisi (ruler)
class TimelineRuler extends StatelessWidget {
  final directorService = locator.get<DirectorService>();

   TimelineRuler({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    /// perfonmas için RepaintBoundary
    return RepaintBoundary(
      child: CustomPaint(
        painter: _RulerPainter(context: context, isDark: isDark),
        child: Container(
          height: Params.RULER_HEIGHT - 4,
          width: MediaQuery.of(context).size.width + directorService.pixelsPerSecond * directorService.duration / 1000,
          margin: const EdgeInsets.fromLTRB(0, 2, 0, 2),
        ),
      ),
    );
  }
}

/// Ruler çizim sınıfı
class _RulerPainter extends CustomPainter {
  final directorService = locator.get<DirectorService>();
  final BuildContext context;
  final bool isDark;

  _RulerPainter({required this.context, required this.isDark});

  /// Zoom seviyesine göre bölüm aralığını hesapla
  int _getSecondsPerDivision(double pixPerSec) {
    if (pixPerSec > 40) return 1;
    if (pixPerSec > 20) return 2;
    if (pixPerSec > 10) return 5;
    if (pixPerSec > 4) return 10;
    if (pixPerSec > 1.5) return 30;
    return 60;
  }

  /// Saniyeyi MM:SS formatına çevir
  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void paint(Canvas canvas, Size size) {
    final screenWidth = MediaQuery.of(context).size.width;
    final double totalWidth = directorService.duration / 1000 * directorService.pixelsPerSecond + screenWidth;

    final int secondsPerDivision = _getSecondsPerDivision(directorService.pixelsPerSecond);
    final double pixelsPerDivision = secondsPerDivision * directorService.pixelsPerSecond;
    final int numberOfDivisions = ((totalWidth - screenWidth / 2) / pixelsPerDivision).floor();

    // Renkler - tema uyumlu
    final bgColor = isDark ? app_theme.projectListCardBg : app_theme.surface;
    final lineColor = isDark ? app_theme.darkTextSecondary.withValues(alpha: 0.4) : app_theme.textSecondary.withValues(alpha: 0.4);
    final textColor = isDark ? app_theme.darkTextSecondary.withValues(alpha: 0.8) : app_theme.textSecondary.withValues(alpha: 0.8);
    final accentLineColor = app_theme.accent.withValues(alpha: 0.3);

    // Arka plan
    final bgPaint = Paint()..color = bgColor;
    canvas.drawRect(Rect.fromLTWH(0, 2, totalWidth, size.height - 4), bgPaint);

    // Alt çizgi
    final linePaint = Paint()..color = lineColor..style = PaintingStyle.stroke..strokeWidth = 1;

    final bottomLine = Path()..moveTo(0, size.height - 2)..lineTo(totalWidth, size.height - 2);
    canvas.drawPath(bottomLine, linePaint);

    // Bölümler ve zaman etiketleri
    for (int i = 0; i <= numberOfDivisions; i++) {
      final int seconds = i * secondsPerDivision;
      final double x = screenWidth / 2 + i * pixelsPerDivision;

      // Zaman etiketi
      final textPainter = TextPainter(
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.left,
        text: TextSpan(
          text: _formatTime(seconds),
          style: TextStyle(
            color: textColor,
            fontSize: 10,
            fontWeight: FontWeight.w500,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x + 6, 5));

      // Ana bölüm çizgisi
      final divisionPaint = Paint()
        ..color = i % 5 == 0 ? accentLineColor : lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = i % 5 == 0 ? 1.5 : 1;

      final divisionPath = Path()
        ..moveTo(x + 1, size.height - 4)
        ..lineTo(x + 1, size.height - 12);
      canvas.drawPath(divisionPath, divisionPaint);

      // Ara bölüm çizgisi (yarım)
      final halfDivisionPath = Path()
        ..moveTo(x + 1 + 0.5 * pixelsPerDivision, size.height - 4)
        ..lineTo(x + 1 + 0.5 * pixelsPerDivision, size.height - 7);
      canvas.drawPath(halfDivisionPath, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RulerPainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}
