import 'package:vidviz/model/layer.dart';
import 'package:vidviz/model/text_asset.dart';
import 'dart:math' as math;
import 'native_ui_context.dart';

class ExportTextPreprocess {
  static int _boxParityExportCount = 0;
  static void apply(
    List<Layer> layers,
    ExportUiContext ctx,
  ) {
    if (!ctx.hasUiMetrics) return;

    final sxUi = ctx.sxUi;
    final syUi = ctx.syUi;
    final int outW = ctx.exportWidth;
    final int outH = ctx.exportHeight;

    for (final layer in layers) {
      for (final asset in layer.assets) {
        if (asset.deleted) continue;
        if (asset.type != AssetType.text) continue;

        final data = asset.data;
        if (data is! Map<String, dynamic>) continue;
        final textData = data['text'];
        if (textData is! Map<String, dynamic>) continue;

        final fontV = textData['font'];
        if (fontV is String) {
          final normalized = fontV.replaceAll('\\', '/');
          if (normalized == 'ethnocentric-rg.ttf') {
            textData['font'] = 'Ethnocentric/ethnocentric-rg.ttf';
          } else if (normalized == 'ethnocentric-rg-it.ttf') {
            textData['font'] = 'Ethnocentric/ethnocentric-rg-it.ttf';
          } else if (normalized == 'Freedom-10eM.ttf') {
            textData['font'] = 'Freedom/Freedom-10eM.ttf';
          } else if (normalized == 'Freedom-nZ4J.otf') {
            textData['font'] = 'Freedom/Freedom-nZ4J.otf';
          }
        }

        TextAsset t;
        try {
          t = TextAsset.fromJson(Map<String, dynamic>.from(textData));
        } catch (_) {
          continue;
        }

        final double padPx = _computePadPxExport(t, sxUi: sxUi, syUi: syUi);
        textData['padPx'] = padPx;

        final s = 0.5 * (sxUi + syUi);
        final sStroke = sxUi > syUi ? sxUi : syUi;

        final double borderW = (t.borderw.isFinite ? t.borderw : 0.0).clamp(0.0, 20.0);
        final double glowRadius = (t.glowRadius.isFinite ? t.glowRadius : 0.0).clamp(0.0, 40.0);
        final double shadowBlur = (t.shadowBlur.isFinite ? t.shadowBlur : 0.0).clamp(0.0, 40.0);
        final double boxBorderW = (t.boxborderw.isFinite ? t.boxborderw : 0.0).clamp(0.0, 20.0);
        final double boxPad = (t.boxPad.isFinite ? t.boxPad : 0.0).clamp(0.0, 30.0);
        final double boxRadius = (t.boxRadius.isFinite ? t.boxRadius : 0.0).clamp(0.0, 2048.0);

        textData['borderw'] = borderW * s;
        textData['glowRadius'] = glowRadius * s;
        textData['shadowBlur'] = shadowBlur * s;
        textData['boxborderw'] = boxBorderW * sStroke;
        textData['boxPad'] = boxPad * s;
        textData['boxRadius'] = boxRadius * s;

        if (t.animType != 'shadow_swing') {
          textData['shadowx'] = t.shadowx * sxUi;
          textData['shadowy'] = t.shadowy * syUi;
        }

        textData['decorAlreadyScaled'] = true;

        final double boxPadPx = t.box ? ((boxPad * s).isFinite ? (boxPad * s) : 0.0).ceilToDouble() : 0.0;
        final double totalPadPx = padPx + boxPadPx;
        final double safeX = (t.x.isFinite ? t.x : 0.1).clamp(0.0, 1.0);
        final double safeY = (t.y.isFinite ? t.y : 0.1).clamp(0.0, 1.0);
        final double safeAlpha = (t.alpha.isFinite ? t.alpha : 1.0).clamp(0.0, 1.0);
        final double safeFontSize = (t.fontSize.isFinite ? t.fontSize : 0.1).clamp(0.03, 1.0);

        textData['x'] = safeX;
        textData['y'] = safeY;
        textData['alpha'] = safeAlpha;
        textData['fontSize'] = safeFontSize;

        if (t.box && _boxParityExportCount < 20) {
          _boxParityExportCount++;
          print(
            'BOX_PARITY export out=${outW}x${outH} sxUi=${sxUi.toStringAsFixed(6)} syUi=${syUi.toStringAsFixed(6)} '
            'titleLen=${t.title.length} font=${t.font} '
            'padPx=${padPx.toStringAsFixed(3)} boxPadPx=${boxPadPx.toStringAsFixed(3)} totalPadPx=${totalPadPx.toStringAsFixed(3)} '
            'boxPadUi=${t.boxPad.toStringAsFixed(3)} boxPadScaled=${(boxPad * s).toStringAsFixed(3)} '
            'boxBorderWUi=${t.boxborderw.toStringAsFixed(3)} boxBorderWScaled=${(boxBorderW * sStroke).toStringAsFixed(3)} '
            'boxRadiusUi=${t.boxRadius.toStringAsFixed(3)} boxRadiusScaled=${(boxRadius * s).toStringAsFixed(3)}',
          );
        }
      }
    }
  }

  static double _computePadPxExport(
    TextAsset t, {
    required double sxUi,
    required double syUi,
  }) {
    final s = 0.5 * (sxUi + syUi);
    final sStroke = sxUi > syUi ? sxUi : syUi;

    double glow = t.glowRadius;
    if (t.animType == 'glow_pulse') {
      glow = glow * 1.5;
    }

    double border = t.borderw;
    if (t.animType == 'outline_pulse') {
      border = border * 1.5;
    }

    double shadowAbsSumPx = (t.shadowx.abs() * sxUi) + (t.shadowy.abs() * syUi);
    if (t.animType == 'shadow_swing') {
      double a = t.animAmplitude;
      if (!a.isFinite) a = 1.0;
      a = a.clamp(1.0, 500.0);
      shadowAbsSumPx = a * math.sqrt((sxUi * sxUi) + (syUi * syUi));
    }

    double bleed = 0.0;
    final g = (glow * 2.0 * s);
    if (g > bleed) bleed = g;

    final shBlur = math.max(0.0, t.shadowBlur);
    final sh = (shBlur * 2.0 * s) + shadowAbsSumPx;
    if (sh > bleed) bleed = sh;

    final bw = (math.max(0.0, border) * s);
    if (bw > bleed) bleed = bw;

    if (t.box) {
      final bb = (math.max(0.0, t.boxborderw) * sStroke) * 0.5;
      if (bb > bleed) bleed = bb;
    }

    final bool hasShaderEffect =
        t.effectType.isNotEmpty &&
        t.effectType != 'none' &&
        t.effectType != 'inner_glow' &&
        t.effectType != 'inner_shadow';
    if (hasShaderEffect) {
      double inten = t.effectIntensity;
      if (!inten.isFinite) inten = 0.7;
      inten = inten.clamp(0.0, 1.0);
      double thick = t.effectThickness;
      if (!thick.isFinite) thick = 1.0;
      thick = thick.clamp(0.0, 5.0);
      double extra = (4.0 + 12.0 * inten + 2.0 * thick) * s;
      if (!extra.isFinite) extra = 0.0;
      extra = extra.clamp(0.0, 40.0);
      if (extra > bleed) bleed = extra;
    }

    if (!bleed.isFinite) bleed = 0.0;
    if (bleed < 0) bleed = 0.0;
    if (bleed > 80.0) bleed = 80.0;
    double pad = bleed.roundToDouble();
    if (pad < 6.0 && s >= 3.0) {
      pad = 6.0;
    }
    return pad;
  }
}
