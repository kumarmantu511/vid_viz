import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vidviz/model/visualizer.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/visualizer_service.dart';
import 'package:vidviz/service/director_service.dart';
import 'counter_param_utils.dart';

class CounterEffect extends StatelessWidget {
  final int position;
  final VisualizerAsset asset;
  final double width;
  final double height;

  final directorService = locator.get<DirectorService>();
  final visualizerService = locator.get<VisualizerService>();

  CounterEffect({
    Key? key,
    required this.position,
    required this.asset,
    required this.width,
    required this.height,
  }) : super(key: key);

  String _formatMs(int ms) {
    if (ms < 0) ms = 0;
    final totalSeconds = ms ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final m = minutes.toString().padLeft(2, '0');
    final s = seconds.toString().padLeft(2, '0');
    return '$m:$s';
  }

  FontWeight _labelFontWeight(Map<String, dynamic>? params, String id) {
    final String key = id == 'start' ? 'counterStartWeight' : 'counterEndWeight';
    final dynamic raw = params != null ? params[key] : null;
    final String w = raw is String ? raw : 'normal';
    switch (w) {
      case 'bold':
        return FontWeight.w700;
      case 'normal':
        return FontWeight.w400;
      case 'semibold':
      default:
        return FontWeight.w500;
    }
  }

  List<Shadow> _labelShadows(Map<String, dynamic>? params, String id, Color baseColor) {
    final String shadowOpacityKey =
        id == 'start' ? 'counterStartShadowOpacity' : 'counterEndShadowOpacity';
    final String shadowBlurKey =
        id == 'start' ? 'counterStartShadowBlur' : 'counterEndShadowBlur';
    final String shadowOffsetXKey =
        id == 'start' ? 'counterStartShadowOffsetX' : 'counterEndShadowOffsetX';
    final String shadowOffsetYKey =
        id == 'start' ? 'counterStartShadowOffsetY' : 'counterEndShadowOffsetY';

    final String glowRadiusKey =
        id == 'start' ? 'counterStartGlowRadius' : 'counterEndGlowRadius';
    final String glowOpacityKey =
        id == 'start' ? 'counterStartGlowOpacity' : 'counterEndGlowOpacity';

    final double shadowOpacity = (params != null && params[shadowOpacityKey] is num)
        ? (params[shadowOpacityKey] as num).toDouble().clamp(0.0, 1.0)
        : 0.75;
    final double shadowBlur = (params != null && params[shadowBlurKey] is num)
        ? (params[shadowBlurKey] as num).toDouble().clamp(0.0, 30.0)
        : 2.0;
    final double shadowOffsetX = (params != null && params[shadowOffsetXKey] is num)
        ? (params[shadowOffsetXKey] as num).toDouble().clamp(-30.0, 30.0)
        : 0.0;
    final double shadowOffsetY = (params != null && params[shadowOffsetYKey] is num)
        ? (params[shadowOffsetYKey] as num).toDouble().clamp(-30.0, 30.0)
        : 1.0;

    final double glowRadius = (params != null && params[glowRadiusKey] is num)
        ? (params[glowRadiusKey] as num).toDouble().clamp(0.0, 60.0)
        : 0.0;
    final double glowOpacity = (params != null && params[glowOpacityKey] is num)
        ? (params[glowOpacityKey] as num).toDouble().clamp(0.0, 1.0)
        : 0.0;

    final List<Shadow> out = [];
    if (glowOpacity > 0.0 && glowRadius > 0.0) {
      out.add(
        Shadow(
          color: baseColor.withOpacity(glowOpacity),
          offset: Offset.zero,
          blurRadius: glowRadius,
        ),
      );
    }
    if (shadowOpacity > 0.0 && (shadowBlur > 0.0 || shadowOffsetX != 0.0 || shadowOffsetY != 0.0)) {
      out.add(
        Shadow(
          color: Colors.black.withOpacity(shadowOpacity),
          offset: Offset(shadowOffsetX, shadowOffsetY),
          blurRadius: shadowBlur,
        ),
      );
    }
    return out;
  }

  double _labelFontSize(Map<String, dynamic>? params) {
    final dynamic raw = params != null ? params['counterLabelSize'] : null;
    final String key = raw is String ? raw : 'normal';
    switch (key) {
      case 'small':
        return 10.0;
      case 'large':
        return 14.0;
      case 'normal':
      default:
        return 12.0;
    }
  }

  Widget _buildTimeLabel({
    required String id,
    required String text,
    required bool isEditing,
    required bool isSelected,
    required double fontSize,
    required Color color,
    required FontWeight fontWeight,
    required List<Shadow> shadows,
    required double scaleX,
    required double scaleY,
    required double extraOffsetY,
    required double rotationZ,
    required double flipY,
    required double posX01,
    required double posY01,
  }) {
    final border = isEditing && isSelected
        ? Border.all(color: Colors.white.withOpacity(0.9), width: 1.5)
        : null;

    final decorated = Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: border != null
          ? BoxDecoration(
              color: Colors.black.withOpacity(0.10),
              borderRadius: BorderRadius.circular(6),
              border: border,
            )
          : null,
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          shadows: shadows,
        ),
      ),
    );

    Widget child = Transform.translate(
      offset: Offset(0, extraOffsetY),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateY(flipY)
          ..rotateZ(rotationZ)
          ..scale(scaleX, scaleY, 1.0),
        child: decorated,
      ),
    );

    if (isEditing) {
      child = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          updateCounterAsset(visualizerService, asset, (_, params) {
            params['counterSelected'] = id;
          });
        },
        onPanStart: (_) {
          updateCounterAsset(visualizerService, asset, (_, params) {
            params['counterSelected'] = id;
          });
        },
        onPanUpdate: (details) {
          if (width <= 0 || height <= 0) return;
          final dx01 = details.delta.dx / width;
          final dy01 = details.delta.dy / height;

          updateCounterAsset(visualizerService, asset, (_, params) {
            params['counterSelected'] = id;

            final xKey = id == 'start' ? 'counterStartPosX' : 'counterEndPosX';
            final yKey = id == 'start' ? 'counterStartPosY' : 'counterEndPosY';
            final double curX = readCounterPos01(asset, xKey, posX01);
            final double curY = readCounterPos01(asset, yKey, posY01);
            params[xKey] = (curX + dx01).clamp(0.0, 1.0);
            params[yKey] = (curY + dy01).clamp(0.0, 1.0);
          });
        },
        child: child,
      );
    }

    // Place at absolute normalized position (center anchored)
    final leftPx = (posX01.clamp(0.0, 1.0)) * width;
    final topPx = (posY01.clamp(0.0, 1.0)) * height;

    return Positioned(
      left: leftPx,
      top: topPx,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: child,
      ),
    );
  }

  String _modeLabel(String mode, int elapsedMs, int totalMs) {
    switch (mode) {
      case 'remaining':
        return _formatMs(totalMs - elapsedMs);
      case 'total':
        return _formatMs(totalMs);
      case 'elapsed':
      default:
        return _formatMs(elapsedMs);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? params = asset.shaderParams;

    final bool isEditing = identical(visualizerService.editingVisualizerAsset, asset);
    final String selected = readCounterSelected(asset);

    final int projectDuration = directorService.duration;
    final int totalDuration = projectDuration > 0 ? projectDuration : asset.duration;
    final int clampedPos = position.clamp(0, totalDuration);

    final startEnabledV = params?['counterStartEnabled'];
    final bool startEnabled = startEnabledV is bool ? startEnabledV : true;
    final endEnabledV = params?['counterEndEnabled'];
    final bool endEnabled = endEnabledV is bool ? endEnabledV : true;

    String effectiveSelected = selected;
    if (effectiveSelected == 'start' && !startEnabled && endEnabled) effectiveSelected = 'end';
    if (effectiveSelected == 'end' && !endEnabled && startEnabled) effectiveSelected = 'start';

    String startMode = 'elapsed';
    if (params != null && params['counterStartMode'] is String) {
      startMode = params['counterStartMode'] as String;
    }

    String endMode = 'remaining';
    if (params != null && params['counterEndMode'] is String) {
      endMode = params['counterEndMode'] as String;
    }

    // Legacy placement mapping (backward compatibility)
    String legacyPos = 'side';
    if (params != null && params['counterPos'] is String) {
      legacyPos = params['counterPos'] as String;
    }

    double legacyOffsetYpx = 0.0;
    if (params != null && params['counterOffsetY'] is num) {
      legacyOffsetYpx = (params['counterOffsetY'] as num).toDouble().clamp(-120.0, 120.0);
    }

    String anim = ' ';
    if (params != null && params['counterAnim'] is String) {
      anim = params['counterAnim'] as String;
    }

    final double seconds = clampedPos / 1000.0;
    final double speed = asset.speed.clamp(0.5, 2.0);

    double labelScale = 1.0;
    double labelOffsetY = 0.0;
    double rotZ = 0.0;
    double flipY = 0.0;
    double scaleX = 1.0;
    double scaleY = 1.0;
    if (anim == 'pulse') {
      final double baseFreq = 1.0 + 0.4 * speed;
      final double phase = seconds * baseFreq * 2.0 * math.pi;
      labelScale = 1.0 + 0.06 * math.sin(phase);
    } else if (anim == 'flip') {
      final double baseFreq = 0.8 + 0.7 * speed;
      final double phase = seconds * baseFreq * 2.0 * math.pi;
      // full 3D-ish flip on Y axis
      flipY = 0.9 * math.sin(phase);
      // keep readable: minor scale modulation
      labelScale = 1.0 + 0.03 * math.cos(phase);
    } else if (anim == 'leaf') {
      final double baseFreq = 1.0 + 0.6 * speed;
      final double phase = seconds * baseFreq * 2.0 * math.pi;
      final double wave = math.sin(phase);
      // leaf: sway + gentle float
      rotZ = 0.18 * wave;
      labelOffsetY = -(wave.abs()) * 10.0;
      labelScale = 1.0 + 0.03 * (math.sin(phase + 1.2));
    } else if (anim == 'bounce') {
      final double baseFreq = 1.2 + 0.7 * speed;
      final double phase = seconds * baseFreq * 2.0 * math.pi;
      final double wave = (math.sin(phase) + 1.0) * 0.5;
      // sharper feel: ease-in curve
      final double eased = wave * wave;
      // squash & stretch via rotationZ/flipY stays 0, but scale+offset creates punch
      labelScale = 1.0 + 0.12 * eased;
      labelOffsetY = -eased * 18.0;
      scaleX = 1.0 + 0.16 * eased;
      scaleY = 1.0 - 0.10 * eased;
    }

    if (anim != 'bounce') {
      scaleX = labelScale;
      scaleY = labelScale;
    }

    final double fontSize = _labelFontSize(params);

    final int col = asset.color == 0xFF00FF00 ? 0xFFFFFFFF : asset.color;
    final Color baseColor = Color(col);
    final Color defaultLabelColor = baseColor.computeLuminance() < 0.5 ? Colors.black : Colors.white;

    Color labelColorFor(String id) {
      final key = id == 'start' ? 'counterStartColor' : 'counterEndColor';
      final v = params != null ? params[key] : null;
      if (v is int) return Color(v);
      return defaultLabelColor;
    }

    FontWeight labelWeightFor(String id) => _labelFontWeight(params, id);

    List<Shadow> labelShadowsFor(String id) =>
        _labelShadows(params, id, labelColorFor(id));

    final String startLabel = _modeLabel(startMode, clampedPos, totalDuration);
    final String endLabel = _modeLabel(endMode, clampedPos, totalDuration);

    // Resolve positions: use explicit params if present, else derive from legacyPos + legacyOffsetY.
    double defaultY;
    if (legacyPos == 'top') {
      defaultY = 0.08;
    } else if (legacyPos == 'bottom') {
      defaultY = 0.92;
    } else {
      defaultY = 0.50;
    }
    final legacyDy01 = height > 0 ? (legacyOffsetYpx / height) : 0.0;
    defaultY = (defaultY + legacyDy01).clamp(0.0, 1.0);

    final startX = readCounterPos01(asset, 'counterStartPosX', 0.10);
    final startY = readCounterPos01(asset, 'counterStartPosY', defaultY);
    final endX = readCounterPos01(asset, 'counterEndPosX', 0.90);
    final endY = readCounterPos01(asset, 'counterEndPosY', defaultY);

    final children = <Widget>[];
    if (startEnabled) {
      children.add(
        _buildTimeLabel(
          id: 'start',
          text: startLabel,
          isEditing: isEditing,
          isSelected: effectiveSelected == 'start',
          fontSize: fontSize,
          color: labelColorFor('start'),
          fontWeight: labelWeightFor('start'),
          shadows: labelShadowsFor('start'),
          scaleX: scaleX,
          scaleY: scaleY,
          extraOffsetY: labelOffsetY,
          rotationZ: rotZ,
          flipY: flipY,
          posX01: startX,
          posY01: startY,
        ),
      );
    }
    if (endEnabled) {
      children.add(
        _buildTimeLabel(
          id: 'end',
          text: endLabel,
          isEditing: isEditing,
          isSelected: effectiveSelected == 'end',
          fontSize: fontSize,
          color: labelColorFor('end'),
          fontWeight: labelWeightFor('end'),
          shadows: labelShadowsFor('end'),
          scaleX: scaleX,
          scaleY: scaleY,
          extraOffsetY: labelOffsetY,
          rotationZ: rotZ,
          flipY: flipY,
          posX01: endX,
          posY01: endY,
        ),
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: children,
      ),
    );
  }
}
