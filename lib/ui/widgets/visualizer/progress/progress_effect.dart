import 'package:flutter/material.dart';
import 'package:vidviz/model/visualizer.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/director_service.dart';
import 'package:vidviz/ui/widgets/visualizer/shaders/shader_effect.dart';

class ProgressEffect extends StatelessWidget {
  final int position;
  final VisualizerAsset asset;
  final double width;
  final double height;

  final directorService = locator.get<DirectorService>();

  ProgressEffect({
    Key? key,
    required this.position,
    required this.asset,
    required this.width,
    required this.height,
  }) : super(key: key);

  double _styleIndex(String style) {
    switch (style) {
      case 'segments':
        return 1.0;
      case 'steps':
        return 2.0;
      case 'centered':
        return 3.0;
      case 'outline':
        return 4.0;
      case 'thin':
        return 5.0;
      case 'capsule':
      default:
        return 0.0;
    }
  }

  double _headStyleIndex(Map<String, dynamic>? params) {
    final dynamic raw = params != null ? params['progressHeadStyle'] : null;
    final String key = raw is String ? raw : 'pulse';
    switch (key) {
      case 'none':
      case 'static':
        return 0.0;
      case 'spark':
        return 2.0;
      case 'pulse':
      default:
        return 1.0;
    }
  }

  double _themeIndex(Map<String, dynamic>? params) {
    final dynamic raw = params != null ? params['progressTheme'] : null;
    final String key = raw is String ? raw : 'classic';
    switch (key) {
      case 'fire':
        return 1.0;
      case 'electric':
        return 2.0;
      case 'neon':
        return 3.0;
      case 'rainbow':
        return 4.0;
      case 'glitch':
        return 5.0;
      case 'soft':
        return 6.0;
      case 'sunset':
        return 7.0;
      case 'ice':
        return 8.0;
      case 'matrix':
        return 9.0;
      case 'classic':
      default:
        return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Global project duration: progress bar her zaman proje süresine göre çalışsın
    final int projectDuration = directorService.duration;
    final int totalDuration = projectDuration > 0 ? projectDuration : asset.duration;
    final int clampedPos = position.clamp(0, totalDuration);
    final double progress = totalDuration > 0 ? clampedPos / totalDuration : 0.0;
    final Color baseColor = Color(asset.color == 0xFF00FF00 ? 0xFFFFFFFF : asset.color);
    final Color? gradColor = asset.gradientColor != null ? Color(asset.gradientColor!) : null;
    final double style = _styleIndex(asset.effectStyle.isEmpty ? 'capsule' : asset.effectStyle);
    final double baseThickness = asset.strokeWidth.clamp(6.0, 24.0);
    final double thickness = height > 0.0 ? (baseThickness / 24.0) * height : baseThickness;
    final double glow = asset.glowIntensity.clamp(0.0, 1.0);

    final Map<String, dynamic>? params = asset.shaderParams;

    double trackOpacity = 0.35;
    if (params != null && params['progressTrackAlpha'] is num) {
      trackOpacity = (params['progressTrackAlpha'] as num).toDouble().clamp(0.0, 1.0);
    }

    double corner = 0.7;
    if (params != null && params['progressCorner'] is num) {
      corner = (params['progressCorner'] as num).toDouble().clamp(0.0, 1.0);
    }

    double gap = 0.25;
    if (params != null && params['progressGap'] is num) {
      gap = (params['progressGap'] as num).toDouble().clamp(0.0, 1.0);
    }

    double effectAmount = 0.3;
    if (params != null && params['progressEffectAmount'] is num) {
      effectAmount = (params['progressEffectAmount'] as num).toDouble().clamp(0.0, 1.0);
    }

    int? trackColorInt;
    if (params != null && params['progressTrackColor'] is int) {
      trackColorInt = params['progressTrackColor'] as int;
    }

    double headAmount = 0.0;
    if (params != null && params['progressHeadAmount'] is num) {
      headAmount = (params['progressHeadAmount'] as num).toDouble().clamp(0.0, 1.0);
    }

    double headSize = 0.5;
    if (params != null && params['progressHeadSize'] is num) {
      headSize = (params['progressHeadSize'] as num).toDouble().clamp(0.0, 1.0);
    }

    final double headStyleIndex = _headStyleIndex(params);

    final double theme = _themeIndex(params);
    return SizedBox(
      width: width,
      height: height,
      child: ShaderEffect(
        frequencies: const [0.0],
        shaderPath: 'progress',
        color: baseColor,
        gradientColor: gradColor,
        intensity: glow,
        speed: asset.speed.clamp(0.5, 2.0),
        width: width,
        height: height,
        barCount: 1,
        mirror: false,
        rotation: 0.0,
        progress: progress,
        style: style,
        thickness: thickness,
        trackOpacity: trackOpacity,
        corner: corner,
        gap: gap,
        theme: theme,
        effectAmount: effectAmount,
        trackColor: trackColorInt != null ? Color(trackColorInt) : null,
        headAmount: headAmount,
        headSize: headSize,
        headStyle: headStyleIndex,
      ),
    );
  }
}
