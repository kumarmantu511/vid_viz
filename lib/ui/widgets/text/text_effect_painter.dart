import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:vidviz/model/text_asset.dart';

class TextEffectPainter extends CustomPainter {
  final TextAsset asset;
  final ui.FragmentShader? shader;
  final double time;
  final TextStyle textStyle;
  final String title;
  final double extraPad;

  TextEffectPainter({
    required this.asset,
    required this.shader,
    required this.time,
    required this.textStyle,
    required this.title,
    this.extraPad = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double ep = (extraPad.isFinite ? extraPad : 0.0).clamp(0.0, 200.0);
    final Size contentSize = (ep > 0.0)
        ? Size(size.width - 2 * ep, size.height - 2 * ep)
        : size;
    if (!contentSize.width.isFinite || !contentSize.height.isFinite || contentSize.width <= 0 || contentSize.height <= 0) {
      return;
    }

    if (ep > 0.0) {
      canvas.save();
      canvas.translate(ep, ep);
    }

    try {

    final double bp = (asset.box && asset.boxPad.isFinite) ? asset.boxPad.clamp(0.0, 30.0) : 0.0;
    Rect tight = Offset.zero & contentSize;
    if (title.isNotEmpty) {
      final tpMeasure = TextPainter(
        text: TextSpan(text: title, style: textStyle),
        textDirection: TextDirection.ltr,
      );
      tpMeasure.layout();
      final boxes = tpMeasure.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: title.length),
      );
      if (boxes.isNotEmpty) {
        Rect r = boxes.first.toRect();
        for (final b in boxes.skip(1)) {
          r = r.expandToInclude(b.toRect());
        }
        if (r.width.isFinite && r.height.isFinite && !r.isEmpty) {
          tight = r;
        }
      } else {
        tight = Offset.zero & tpMeasure.size;
      }
    }

    final Offset baseOff = Offset(bp - tight.left, bp - tight.top);
    Color _mulOpacity(Color c, double m) => c.withOpacity((c.opacity * m).clamp(0.0, 1.0));
    // Global alpha with fade_in modulation
    double gAlphaBase = asset.alpha.clamp(0.0, 1.0);
    double gAlpha = gAlphaBase;
    if (asset.animType == 'fade_in') {
      final spd = asset.animSpeed.clamp(0.2, 2.0);
      final p = (time * spd) % 1.0;
      gAlpha = (gAlphaBase * p).clamp(0.0, 1.0);
    }

    // Helper to paint text (optionally per-char wave/scan), using provided style
    void paintTextWithStyle(TextStyle style, {Offset offset = Offset.zero}) {
      final String s = title;
      final wave = (asset.animType == 'wave');
      final scan = (asset.animType == 'scan');
      final scanRL = (asset.animType == 'scan_rl');
      final sweep = (asset.animType == 'sweep_lr_rl');
      final scramble = (asset.animType == 'scramble_letters');
      final spd = asset.animSpeed.clamp(0.2, 2.0);
      final amp = (!asset.animAmplitude.isFinite ? 0.0 : asset.animAmplitude).clamp(0.0, 500.0);
      final ph = (!asset.animPhase.isFinite ? 0.0 : asset.animPhase);

      if (wave || scan || scanRL || sweep || scramble) {
        double dx = 0.0;
        int n = s.length;
        // scan: compute active character index with ping-pong motion
        int activeIndex = -1;
        if ((scan || scanRL) && n > 0) {
          final t = time * spd;
          final period = math.max(1, n - 1) * 1.0;
          final pos = t % 2.0; // 0..2
          final u = pos < 1.0 ? pos : 2.0 - pos; // 0..1..0
          int idx = (u * period).round().clamp(0, n - 1);
          activeIndex = scanRL ? (n - 1 - idx) : idx;
        }
        // scramble progress (0..1)
        double scrP = 1.0;
        if (scramble && n > 0) {
          final sp = asset.animSpeed.clamp(0.2, 2.0);
          scrP = ((time * sp) % 1.0);
        }
        for (int i = 0; i < n; i++) {
          String ch = s[i];
          if (scramble) {
            final showCount = (scrP * n).floor();
            if (i > showCount) {
              final base = 'A'.codeUnitAt(0);
              final v = (i * 31 + ((time * 60.0).floor())) % 26;
              ch = String.fromCharCode(base + v);
            }
          }
          TextStyle st = style;
          double dy = 0.0;
          if (wave) {
            dy = math.sin(ph + time * spd + i * 0.4) * amp;
          }
          if (scan || scanRL) {
            // dim non-active characters
            final base = (st.color ?? const Color(0xFFFFFFFF));
            final factor = (i == activeIndex) ? 1.0 : 0.25;
            st = st.copyWith(color: _mulOpacity(base, factor));
          }
          if (sweep) {
            // Stage A: left->right turning OFF one-by-one; Stage B: right->left turning ON one-by-one
            final t = time * spd;
            final pos = t % 2.0; // 0..2
            final total = n + 1;
            double factor = 1.0; // on by default
            if (pos < 1.0) {
              // OFF prefix length
              final offCount = (pos * total).floor();
              if (i < offCount) factor = 0.25; // off
            } else {
              // ON suffix length
              final onCount = ((pos - 1.0) * total).floor();
              final boundary = (n - 1) - onCount;
              if (i <= boundary) factor = 0.25; // still off
            }
            final base = (st.color ?? const Color(0xFFFFFFFF));
            st = st.copyWith(color: _mulOpacity(base, factor));
          }
          final tp = TextPainter(
            text: TextSpan(text: ch, style: st),
            textDirection: TextDirection.ltr,
          );
          tp.layout();
          tp.paint(canvas, Offset(dx, dy) + offset);
          dx += tp.size.width;
        }
      } else {
        final tp = TextPainter(
          text: TextSpan(text: s, style: style),
          textDirection: TextDirection.ltr,
        );
        tp.layout();
        tp.paint(canvas, offset);
      }
    }

    // Animation: typing (clip increasing width)
    canvas.save();
    if (asset.animType == 'typing' || asset.animType == 'type_delete') {
      final spd = asset.animSpeed.clamp(0.2, 2.0);
      double t = time * spd;
      double p;
      if (asset.animType == 'typing') {
        p = t % 1.0;
      } else {
        final x = t % 2.0; // 0..2
        p = x < 1.0 ? x : (2.0 - x); // 0..1..0
      }
      final clip = Rect.fromLTWH(0, 0, size.width * p, size.height);
      canvas.clipRect(clip);
    }

    // Animation: bounce (translate whole word vertically)
    canvas.save();
    if (asset.animType == 'bounce') {
      final spd = asset.animSpeed.clamp(0.2, 2.0);
      final amp = (!asset.animAmplitude.isFinite ? 0.0 : asset.animAmplitude).clamp(0.0, 500.0);
      final offY = math.sin(time * spd) * amp;
      canvas.translate(0, offY);
    }

    // Animation: jitter (small x/y shake)
    canvas.save();
    if (asset.animType == 'jitter') {
      final spd = asset.animSpeed.clamp(0.2, 2.0);
      final amp = (!asset.animAmplitude.isFinite ? 0.0 : asset.animAmplitude).clamp(0.0, 500.0);
      final ph = asset.animPhase;
      final offX = math.sin(time * spd + ph) * amp * 0.5;
      final offY = math.cos(time * (spd * 1.3) + ph * 1.7) * amp * 0.5;
      canvas.translate(offX, offY);
    }

    // Extra transforms: marquee, pulse, slide, rotate, shake
    canvas.save();
    double spd = asset.animSpeed;
    if (!spd.isFinite) spd = 1.0;
    spd = spd.clamp(0.2, 2.0);
    if (asset.animType == 'marquee') {
      final w = (!asset.animAmplitude.isFinite ? 0.0 : asset.animAmplitude).clamp(0.0, 500.0); // pixel range
      final x = ((time * spd) % 1.0) * w;
      canvas.translate(-x, 0);
    } else if (asset.animType == 'pulse') {
      final a = (!asset.animAmplitude.isFinite ? 0.0 : asset.animAmplitude).clamp(0.0, 500.0);
      final k = 1.0 + 0.05 * a * math.sin(time * spd + asset.animPhase);
      canvas.translate(size.width / 2, size.height / 2);
      canvas.scale(k, k);
      canvas.translate(-size.width / 2, -size.height / 2);
    } else if (asset.animType == 'slide_lr') {
      final a = (!asset.animAmplitude.isFinite ? 0.0 : asset.animAmplitude).clamp(0.0, 500.0);
      final x = (time * spd % 1.0) * a;
      canvas.translate(x, 0);
    } else if (asset.animType == 'slide_rl') {
      final a = (!asset.animAmplitude.isFinite ? 0.0 : asset.animAmplitude).clamp(0.0, 500.0);
      final x = (time * spd % 1.0) * a;
      canvas.translate(-x, 0);
    } else if (asset.animType == 'shake_h') {
      final a = (!asset.animAmplitude.isFinite ? 0.0 : asset.animAmplitude).clamp(0.0, 500.0);
      final x = math.sin(time * spd * 6.0) * a * 0.5;
      canvas.translate(x, 0);
    } else if (asset.animType == 'shake_v') {
      final a = (!asset.animAmplitude.isFinite ? 0.0 : asset.animAmplitude).clamp(0.0, 500.0);
      final y = math.sin(time * spd * 6.0) * a * 0.5;
      canvas.translate(0, y);
    } else if (asset.animType == 'rotate') {
      final a = (!asset.animAmplitude.isFinite ? 0.0 : asset.animAmplitude).clamp(0.0, 720.0);
      final ang = a * math.pi / 180.0 * math.sin(time * spd);
      canvas.translate(size.width / 2, size.height / 2);
      canvas.rotate(ang);
      canvas.translate(-size.width / 2, -size.height / 2);
    } else if (asset.animType == 'zoom_in') {
      final p = (time * spd) % 1.0;
      final k = 0.7 + 0.3 * p; // 0.7 -> 1.0
      canvas.translate(size.width / 2, size.height / 2);
      canvas.scale(k, k);
      canvas.translate(-size.width / 2, -size.height / 2);
    } else if (asset.animType == 'slide_up') {
      final a = (!asset.animAmplitude.isFinite ? 40.0 : asset.animAmplitude).clamp(0.0, 500.0);
      final p = (time * spd) % 1.0;
      final y = (1.0 - p) * a; // a -> 0
      canvas.translate(0, y);
    } else if (asset.animType == 'flip_x') {
      // Smooth horizontal flip via scaleX cos curve
      final kx = math.cos(time * spd * math.pi);
      canvas.translate(size.width / 2, size.height / 2);
      canvas.scale(kx.abs().clamp(0.1, 1.0) * (kx >= 0 ? 1.0 : -1.0), 1.0);
      canvas.translate(-size.width / 2, -size.height / 2);
    } else if (asset.animType == 'flip_y') {
      // Smooth vertical flip via scaleY cos curve
      final ky = math.cos(time * spd * math.pi);
      canvas.translate(size.width / 2, size.height / 2);
      canvas.scale(1.0, ky.abs().clamp(0.1, 1.0) * (ky >= 0 ? 1.0 : -1.0));
      canvas.translate(-size.width / 2, -size.height / 2);
    } else if (asset.animType == 'pop_in') {
      // Ease-out scale from 0.6 -> 1.0
      final p = (time * spd) % 1.0;
      final eased = 1.0 - math.pow(1.0 - p, 3);
      final k = 0.6 + 0.4 * eased;
      canvas.translate(size.width / 2, size.height / 2);
      canvas.scale(k, k);
      canvas.translate(-size.width / 2, -size.height / 2);
    } else if (asset.animType == 'rubber_band') {
      // Opposite-phase squash/stretch
      final a = (!asset.animAmplitude.isFinite ? 8.0 : asset.animAmplitude).clamp(0.0, 100.0);
      final f = (a / 40.0).clamp(0.0, 0.4);
      final s = math.sin(time * spd * 4.0 + asset.animPhase);
      final kx = (1.0 + f * s).clamp(0.7, 1.3);
      final ky = (1.0 - f * s).clamp(0.7, 1.3);
      canvas.translate(size.width / 2, size.height / 2);
      canvas.scale(kx, ky);
      canvas.translate(-size.width / 2, -size.height / 2);
    } else if (asset.animType == 'wobble') {
      // Small rotation + lateral sway
      final a = (!asset.animAmplitude.isFinite ? 10.0 : asset.animAmplitude).clamp(0.0, 200.0);
      final sway = math.sin(time * spd * 2.0 + asset.animPhase) * a * 0.2;
      final ang = (a * 0.2).clamp(0.0, 30.0) * math.pi / 180.0 * math.sin(time * spd * 2.0);
      canvas.translate(size.width / 2 + sway, size.height / 2);
      canvas.rotate(ang);
      canvas.translate(-size.width / 2, -size.height / 2);
    }

    // Dynamic params for some animations
    final spdDyn = (!asset.animSpeed.isFinite ? 1.0 : asset.animSpeed).clamp(0.2, 2.0);
    double effGlowRadius = !asset.glowRadius.isFinite ? 0.0 : asset.glowRadius;
    if (asset.animType == 'glow_pulse') {
      final double base = !asset.glowRadius.isFinite ? 0.0 : asset.glowRadius;
      effGlowRadius = base * (0.5 + 0.5 * (1.0 + math.sin(time * spdDyn)));
    }
    effGlowRadius = effGlowRadius.clamp(0.0, 40.0);
    double effBorderW = !asset.borderw.isFinite ? 0.0 : asset.borderw;
    if (asset.animType == 'outline_pulse') {
      effBorderW = asset.borderw * (0.5 + 0.5 * (1.0 + math.sin(time * spdDyn)));
    }
    effBorderW = effBorderW.clamp(0.0, 20.0);
    double sx = asset.shadowx, sy = asset.shadowy;
    if (asset.animType == 'shadow_swing') {
      final A = math.max(1.0, asset.animAmplitude);
      sx = A * math.sin(time * spdDyn);
      sy = A * math.cos(time * spdDyn);
    }
    final double shBlur = (!asset.shadowBlur.isFinite ? 0.0 : asset.shadowBlur).clamp(0.0, 40.0);

    final hasEffect = shader != null && asset.effectType != 'none' && asset.effectType != 'inner_glow' && asset.effectType != 'inner_shadow';
    if (!hasEffect) {
      // Draw background/outline/shadow + colored text directly (animation-only scenario)
      // Box background
      if (asset.box) {
        final double maxRad = 0.5 * math.min(contentSize.width, contentSize.height);
        final double effBoxRadius = (!asset.boxRadius.isFinite ? 0.0 : asset.boxRadius).clamp(0.0, maxRad);
        final rrect = RRect.fromRectAndRadius(
            Offset.zero & contentSize, Radius.circular(effBoxRadius));
        final bg = Paint()..color = _mulOpacity(Color(asset.boxcolor), gAlpha);
        canvas.drawRRect(rrect, bg);
        final double effBoxBorderW = (!asset.boxborderw.isFinite ? 0.0 : asset.boxborderw).clamp(0.0, 20.0);
        if (effBoxBorderW > 0) {
          final bdr = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = effBoxBorderW
            ..color = _mulOpacity(Color(asset.bordercolor), gAlpha);
          canvas.drawRRect(rrect, bdr);
        }
      }
      // Glow (outer) or inner glow via dstIn compositing (safer than inner blur)
      if (asset.effectType == 'inner_glow') {
        final r = effGlowRadius > 0 ? effGlowRadius : asset.glowRadius;
        if (r > 0) {
          // Save sublayer
          canvas.saveLayer(Offset.zero & size, Paint());
          // Destination: blurred glow
          final double sigma = ui.Shadow.convertRadiusToSigma(r);
          final glowPaint = Paint()
            ..color = _mulOpacity(Color(asset.glowColor), gAlpha)
            ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, sigma);
          paintTextWithStyle(textStyle.copyWith(color: null, foreground: glowPaint), offset: baseOff);
          // Source mask: glyphs, keep intersection
          final maskPaint = Paint()
            ..blendMode = BlendMode.dstIn
            ..color = const Color(0xFFFFFFFF);
          paintTextWithStyle(textStyle.copyWith(color: null, foreground: maskPaint), offset: baseOff);
          canvas.restore();
        }
      } else if (effGlowRadius > 0) {
        final double sigma = ui.Shadow.convertRadiusToSigma(effGlowRadius);
        final glowPaint = Paint()
          ..color = _mulOpacity(Color(asset.glowColor), gAlpha)
          ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, sigma);
        paintTextWithStyle(textStyle.copyWith(color: null, foreground: glowPaint), offset: baseOff);
      }
      // Shadow
      if (asset.effectType == 'inner_shadow') {
        final r = shBlur > 0 ? shBlur : asset.shadowBlur;
        if (r > 0) {
          canvas.saveLayer(Offset.zero & size, Paint());
          // Destination: blurred shadow (offset)
          final double sigma = ui.Shadow.convertRadiusToSigma(r);
          final sh = Paint()
            ..color = _mulOpacity(Color(asset.shadowcolor), gAlpha)
            ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, sigma);
          paintTextWithStyle(textStyle.copyWith(color: null, foreground: sh), offset: baseOff + Offset(sx, sy));
          // Mask with glyphs to keep only inside
          final maskPaint = Paint()
            ..blendMode = BlendMode.dstIn
            ..color = const Color(0xFFFFFFFF);
          paintTextWithStyle(textStyle.copyWith(color: null, foreground: maskPaint), offset: baseOff);
          canvas.restore();
        }
      } else if (shBlur > 0 || sx != 0 || sy != 0) {
        if (shBlur > 0) {
          final double sigma = ui.Shadow.convertRadiusToSigma(shBlur);
          final sh = Paint()
            ..color = _mulOpacity(Color(asset.shadowcolor), gAlpha)
            ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, sigma);
          paintTextWithStyle(textStyle.copyWith(color: null, foreground: sh), offset: baseOff + Offset(sx, sy));
        } else {
          paintTextWithStyle(
            textStyle.copyWith(color: _mulOpacity(Color(asset.shadowcolor), gAlpha)),
            offset: baseOff + Offset(sx, sy),
          );
        }
      }
      // Outline
      if (effBorderW > 0) {
        final strokePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = effBorderW
          ..color = _mulOpacity(Color(asset.bordercolor), gAlpha);
        paintTextWithStyle(textStyle.copyWith(color: null, foreground: strokePaint), offset: baseOff);
      }
      // Fill (support global blink and blur_in)
      TextStyle fillStyle = textStyle;
      if (asset.animType == 'blink') {
        final f = 0.5 + 0.5 * math.sin(time * spdDyn * 6.0 + asset.animPhase);
        final base = (fillStyle.color ?? const Color(0xFFFFFFFF));
        fillStyle = fillStyle.copyWith(color: _mulOpacity(base, f));
      } else if (asset.animType == 'blur_in') {
        final spd = asset.animSpeed.clamp(0.2, 2.0);
        final p = (time * spd) % 1.0;
        final br = (1.0 - p) * 12.0;
        final double sigma = ui.Shadow.convertRadiusToSigma(br);
        final blurPaint = Paint()
          ..color = _mulOpacity(Color(asset.fontColor), gAlpha)
          ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, sigma);
        fillStyle = fillStyle.copyWith(color: null, foreground: blurPaint);
      }
      paintTextWithStyle(fillStyle, offset: baseOff);
      canvas.restore(); // extra transforms
      canvas.restore(); // jitter
      canvas.restore(); // bounce
      canvas.restore(); // typing clip
      return;
    }

    // Offscreen layer for mask+shader composite (expanded with bleed to avoid clipping)
    final layerPaint = Paint();
    double bleed = 0.0;
    bleed = math.max(bleed, effGlowRadius * 2.0);
    bleed = math.max(bleed, shBlur * 2.0 + (sx.abs() + sy.abs()));
    bleed = math.max(bleed, effBorderW);
    bleed = bleed.clamp(0.0, 80.0);
    final Rect layerRect = Rect.fromLTWH(-bleed, -bleed, contentSize.width + 2 * bleed, contentSize.height + 2 * bleed);
    canvas.saveLayer(layerRect, layerPaint);

    // Draw decorations behind mask when using effect
    if (asset.box) {
      final double maxRad = 0.5 * math.min(contentSize.width, contentSize.height);
      final double effBoxRadius = (!asset.boxRadius.isFinite ? 0.0 : asset.boxRadius).clamp(0.0, maxRad);
      final rrect = RRect.fromRectAndRadius(
          Offset.zero & contentSize, Radius.circular(effBoxRadius));
      final bg = Paint()..color = _mulOpacity(Color(asset.boxcolor), gAlpha);
      canvas.drawRRect(rrect, bg);
      final double effBoxBorderW = (!asset.boxborderw.isFinite ? 0.0 : asset.boxborderw).clamp(0.0, 20.0);
      if (effBoxBorderW > 0) {
        final bdr = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = effBoxBorderW
          ..color = _mulOpacity(Color(asset.bordercolor), gAlpha);
        canvas.drawRRect(rrect, bdr);
      }
    }
    // Glow
    if (effGlowRadius > 0) {
      final double sigma = ui.Shadow.convertRadiusToSigma(effGlowRadius);
      final glowPaint = Paint()
        ..color = _mulOpacity(Color(asset.glowColor), gAlpha)
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, sigma);
      paintTextWithStyle(textStyle.copyWith(color: null, foreground: glowPaint), offset: baseOff);
    }
    if (shBlur > 0 || sx != 0 || sy != 0) {
      if (shBlur > 0) {
        final double sigma = ui.Shadow.convertRadiusToSigma(shBlur);
        final sh = Paint()
          ..color = _mulOpacity(Color(asset.shadowcolor), gAlpha)
          ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, sigma);
        paintTextWithStyle(textStyle.copyWith(color: null, foreground: sh), offset: baseOff + Offset(sx, sy));
      } else {
        paintTextWithStyle(
          textStyle.copyWith(color: _mulOpacity(Color(asset.shadowcolor), gAlpha)),
          offset: baseOff + Offset(sx, sy),
        );
      }
    }
    if (effBorderW > 0) {
      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = effBorderW
        ..color = _mulOpacity(Color(asset.bordercolor), gAlpha);
      paintTextWithStyle(textStyle.copyWith(color: null, foreground: strokePaint), offset: baseOff);
    }

    // Source: effect shader masked atop text
    final sh = shader;
    if (sh == null) {
      canvas.restore(); // layer
      canvas.restore(); // extra transforms
      canvas.restore(); // jitter
      canvas.restore(); // bounce
      canvas.restore(); // typing clip
      return;
    }
    // Create a sublayer so that shader is applied ONLY to glyph mask, not to decorations
    canvas.saveLayer(layerRect, Paint());
    // Destination: white glyphs as mask; if blur_in is active, blur the mask instead of shader paint
    if (asset.animType == 'blur_in') {
      final spdB = asset.animSpeed.clamp(0.2, 2.0);
      final pB = (time * spdB) % 1.0;
      final br = (1.0 - pB) * 12.0;
      final double sigma = ui.Shadow.convertRadiusToSigma(br);
      final blurPaint = Paint()
        ..color = const Color(0xFFFFFFFF)
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, sigma);
      paintTextWithStyle(textStyle.copyWith(color: null, foreground: blurPaint, backgroundColor: Colors.transparent), offset: baseOff);
    } else {
      paintTextWithStyle(textStyle.copyWith(color: const Color(0xFFFFFFFF), backgroundColor: Colors.transparent), offset: baseOff);
    }
    double w = size.width.isFinite ? size.width : 0.0;
    double h = size.height.isFinite ? size.height : 0.0;
    if (w <= 0) w = 1.0;
    if (h <= 0) h = 1.0;
    try {
      int idx = 0;
      sh.setFloat(idx++, w); // uResolution.x
      sh.setFloat(idx++, h); // uResolution.y
      sh.setFloat(idx++, time); // uTime
      // Flicker: animate intensity when animType is 'flicker'
      double eInt = !asset.effectIntensity.isFinite ? 0.7 : asset.effectIntensity;
      eInt = eInt.clamp(0.0, 1.0);
      double intensity = eInt;
      if (asset.animType == 'flicker') {
        final spd2 = asset.animSpeed.clamp(0.2, 2.0);
        final ph2 = (!asset.animPhase.isFinite ? 0.0 : asset.animPhase);
        final f = (0.7 + 0.3 * (0.5 * (1 + math.sin(time * spd2 * 10.0 + ph2))));
        intensity = (intensity * f).clamp(0.0, 1.0);
      }
      double eSpeed = !asset.effectSpeed.isFinite ? 1.0 : asset.effectSpeed;
      eSpeed = eSpeed.clamp(0.01, 5.0);
      double eAngle = !asset.effectAngle.isFinite ? 0.0 : asset.effectAngle;
      eAngle = eAngle.clamp(-3600.0, 3600.0);
      double eThick = !asset.effectThickness.isFinite ? 1.0 : asset.effectThickness;
      eThick = eThick.clamp(0.0, 5.0);
      sh.setFloat(idx++, intensity); // uIntensity
      sh.setFloat(idx++, eSpeed); // uSpeed
      sh.setFloat(idx++, eAngle); // uAngle
      sh.setFloat(idx++, eThick); // uThickness
      // Colors (A then B), normalized 0..1
      Color ca = Color(asset.effectColorA);
      Color cb = Color(asset.effectColorB);
      sh.setFloat(idx++, ca.red / 255.0);
      sh.setFloat(idx++, ca.green / 255.0);
      sh.setFloat(idx++, ca.blue / 255.0);
      sh.setFloat(idx++, cb.red / 255.0);
      sh.setFloat(idx++, cb.green / 255.0);
      sh.setFloat(idx++, cb.blue / 255.0);
    } catch (e) {
      // Shader params mismatch or driver error: fallback to simple fill to avoid crash
      paintTextWithStyle(textStyle.copyWith(color: textStyle.color ?? const Color(0xFFFFFFFF)), offset: baseOff);
      canvas.restore(); // mask sublayer
      canvas.restore(); // layer
      canvas.restore(); // extra transforms
      canvas.restore(); // jitter
      canvas.restore(); // bounce
      canvas.restore(); // typing clip
      return;
    }

    final effectPaint = Paint()
      ..blendMode = BlendMode.srcIn
      ..shader = sh
      ..color = Colors.white.withOpacity(gAlpha);
    canvas.drawRect(Offset.zero & contentSize, effectPaint);
    canvas.restore(); // mask sublayer
    canvas.restore(); // layer
    canvas.restore(); // extra transforms
    canvas.restore(); // jitter
    canvas.restore(); // bounce
    canvas.restore(); // typing clip
    } finally {
      if (ep > 0.0) {
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant TextEffectPainter oldDelegate) {
    return oldDelegate.asset != asset ||
        oldDelegate.shader != shader ||
        oldDelegate.time != time ||
        oldDelegate.textStyle != textStyle ||
        oldDelegate.title != title ||
        oldDelegate.extraPad != extraPad;
  }
}
