import 'dart:core';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/director_service.dart';
import 'package:vidviz/service/visualizer_service.dart';
import 'package:vidviz/model/layer.dart';
import 'package:vidviz/model/visualizer.dart';
import 'package:vidviz/core/params.dart';
import 'package:vidviz/ui/widgets/timeline/player_metrics.dart';
import 'package:vidviz/ui/widgets/visualizer/shaders/shader_effect.dart';
import 'package:vidviz/ui/widgets/visualizer/shaders/visual_stage_effect.dart';
import 'package:vidviz/ui/widgets/visualizer/visualizer_shader_registry.dart';

/// BackgroundVisualizerPlayer - draws full-screen visualizer shaders as background
/// Only renders Visualizer assets where fullScreen == true
class BackgroundVisualizerPlayer extends StatelessWidget {
  final directorService = locator.get<DirectorService>();
  final visualizerService = locator.get<VisualizerService>();

  // Cached merged stream to avoid recreation on every build
  static Stream<dynamic>? _cachedRebuildStream;

  @override
  Widget build(BuildContext context) {
    // Collect active full-screen visualizers at current position
    final all = directorService
        .getActiveAssetsOfType(AssetType.visualizer)
        .map((a) => VisualizerAsset.fromAsset(a))
        .where((va) => va.fullScreen == true)
        .toList();

    if (all.isEmpty) return const SizedBox.shrink();

    // Ensure FFT prefetch for all
    for (final va in all) {
      if (va.srcPath.isNotEmpty) {
        visualizerService.prefetchFFT(va.srcPath, asset: va);
      }
    }

    // Use cached stream to avoid recreation on every build
    _cachedRebuildStream ??= Rx.merge([
      directorService.position$,
      visualizerService.fftReady$,
    ]).asBroadcastStream();

    return StreamBuilder(
      stream: _cachedRebuildStream,
      initialData: 0,
      builder: (context, _) {
        final int position = directorService.position;
        final double w = PlayerLayout.width(context);
        final double h = PlayerLayout.height(context);
        final children = <Widget>[];

        for (final va in all) {
          children.add(Positioned(
            left: 0,
            top: 0,
            child: _buildBackgroundEffect(context, va, position, w, h),
          ));
        }

        return SizedBox(
          width: w,
          height: h,
          child: Stack(clipBehavior: Clip.hardEdge, children: children),
        );
      },
    );
  }

  Widget _buildBackgroundEffect(BuildContext context, VisualizerAsset asset, int position, double width, double height) {
    // Timeline relative position
    int rel = position - asset.begin;
    if (rel < 0) rel = 0;
    if (rel > asset.duration) rel = asset.duration;

    // FFT
    List<double>? fftData = visualizerService.getFFTDataAtTime(
      asset.srcPath,
      rel,
      asset: asset,
    );
    if (fftData == null || fftData.isEmpty) {
      fftData = List.filled(asset.fftBands, 0.0);
    } else {
      fftData = visualizerService.applyDynamics(fftData, asset);
    }

    // Colors
    int _col = asset.color == 0xFF00FF00 ? 0xFFFFFFFF : asset.color;
    final Color color = Color(_col);
    final Color? gradientColor = asset.gradientColor != null ? Color(asset.gradientColor!) : null;

    final double opacity = (asset.alpha.isFinite ? asset.alpha : 1.0).clamp(0.0, 1.0);
    final String st = normalizeVisualizerShaderId(asset.shaderType ?? 'bar');

    double? barFill;
    double? glow = (asset.glowIntensity.isFinite ? asset.glowIntensity : 0.5).clamp(0.0, 1.0);
    double? strokeWidth;

    if (st == 'bar' || st == 'bar_normal' || st == 'bar_colors' || st == 'claude' || st == 'bar_circle') {
      barFill = (asset.barSpacing.isFinite ? asset.barSpacing : 0.75).clamp(0.35, 0.92);
    } else if (st == 'smooth') {
      strokeWidth = (asset.strokeWidth.isFinite ? asset.strokeWidth : 2.5).clamp(0.5, 8.0);
    } else if (st == 'line' || st == 'wave' || st == 'curves' || st == 'wav' || st == 'sinus') {
      strokeWidth = (asset.strokeWidth.isFinite ? asset.strokeWidth : 2.5).clamp(0.5, 8.0);
    }

    // Render mode
    final String renderMode = asset.renderMode;

    final bool isVisualMode = renderMode == 'visual';
    final String shaderPath = isVisualMode
        ? normalizeVisualShaderId(asset.shaderType ?? 'pro_nation')
        : normalizeVisualizerShaderId(asset.shaderType ?? 'bar');

    final double intensity = (asset.amplitude.isFinite ? asset.amplitude : 1.0).clamp(0.5, 2.0);
    final double speed = (asset.speed.isFinite ? asset.speed : 1.0).clamp(0.5, 2.0);
    final double rotation = (asset.rotation.isFinite ? asset.rotation : 0.0).clamp(0.0, 360.0);

    // Visual mode uses stage-sampling shader, Shader mode uses visualizer shader.
    // Legacy/unknown renderMode (including removed 'canvas') falls back to shader mode.
    if (isVisualMode) {
      return SizedBox(
        width: width,
        height: height,
        child: Opacity(
          opacity: opacity,
          child: VisualStageEffect(
            frequencies: fftData,
            shaderPath: shaderPath,
            color: color,
            gradientColor: gradientColor,
            intensity: intensity,
            speed: speed,
            width: width,
            height: height,
            barCount: asset.barCount.clamp(1, 256),
            mirror: asset.mirror,
            rotation: rotation,
            // Overlay ayarlari (pro_nation shader icin)
            centerImagePath: asset.centerImagePath,
            ringColor: asset.ringColor != null ? Color(asset.ringColor!) : null,
            backgroundImagePath: asset.backgroundImagePath,
          ),
        ),
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: Opacity(
        opacity: opacity,
        child: ShaderEffect(
          frequencies: fftData,
          shaderPath: shaderPath,
          color: color,
          gradientColor: gradientColor,
          intensity: intensity,
          speed: speed,
          barFill: barFill,
          glow: glow,
          strokeWidth: strokeWidth,
          width: width,
          height: height,
          barCount: asset.barCount.clamp(1, 256),
          mirror: asset.mirror,
          rotation: rotation,
        ),
      ),
    );
  }
}
