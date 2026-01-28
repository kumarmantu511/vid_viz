import 'dart:core';
import 'package:rxdart/rxdart.dart';
import 'package:vidviz/model/layer.dart';
import 'package:flutter/material.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/model/visualizer.dart';
import 'package:vidviz/service/director_service.dart';
import 'package:vidviz/service/visualizer_service.dart';
import 'package:vidviz/l10n/generated/app_localizations.dart';
import 'package:vidviz/ui/widgets/timeline/player_metrics.dart';
import 'package:vidviz/ui/widgets/visualizer/shaders/shader_effect.dart';
import 'package:vidviz/ui/widgets/visualizer/progress/progress_effect.dart';
import 'package:vidviz/ui/widgets/visualizer/counter/counter_effect.dart';
import 'package:vidviz/ui/widgets/visualizer/visualizer_shader_registry.dart';
import 'package:vidviz/ui/widgets/visualizer/shaders/visual_stage_effect.dart';


/// VisualizerPlayer - Video player üzerinde visualizer gösterimi
/// TextPlayer'ın TAM kopyası
class VisualizerPlayer extends StatelessWidget {
  final directorService = locator.get<DirectorService>();
  final visualizerService = locator.get<VisualizerService>();

  // Cached merged stream to avoid recreation on every build
  static Stream<dynamic>? _cachedRebuildStream;

  VisualizerPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: visualizerService.editingVisualizerAsset$,
        initialData: null,
        builder: (BuildContext context, AsyncSnapshot<VisualizerAsset?> editingVisualizerAsset) {
          final editing = editingVisualizerAsset.data;
          if (editing != null) {
            // Editing modunda da güvenli alan (player) dışına taşmayı engelle
            final double playerW = PlayerLayout.width(context);
            final double playerH = PlayerLayout.height(context);
            // Editing sırasında, kullanıcı yeni bir progress/counter eklerken mevcut overlay'leri de referans olarak görebilsin.
            // (Örn: progress varken counter hizalama)
            String? editingId;
            final int? li = visualizerService.editingLayerIndex;
            final int? ai = visualizerService.editingAssetIndex;
            final layers = directorService.layers;
            if (li != null && ai != null && layers != null) {
              if (li >= 0 && li < layers.length) {
                final la = layers[li].assets;
                if (ai >= 0 && ai < la.length) {
                  editingId = la[ai].id;
                }
              }
            }

            final assets = directorService
                .getActiveAssetsOfType(AssetType.visualizer)
                .where((a) => editingId == null || a.id != editingId)
                .map((a) => VisualizerAsset.fromAsset(a))
                .where((va) => va.fullScreen != true)
                .toList();
            for (final va in assets) {
              visualizerService.prefetchFFT(va.srcPath, asset: va);
            }

            final bgChildren = <Widget>[];
            final int position = directorService.position;
            for (final va in assets) {
              final double safeScale =
                  (va.scale.isFinite ? va.scale : 1.0).clamp(0.1, 4.0);
              final double safeX = (va.x.isFinite ? va.x : 0.5).clamp(-1.0, 2.0);
              final double safeY = (va.y.isFinite ? va.y : 0.5).clamp(-1.0, 2.0);
              final double visualizerWidth = playerW * safeScale;
              final double visualizerHeight = playerH * safeScale;
              final double leftBg = safeX * playerW - (visualizerWidth / 2);
              final double topBg = safeY * playerH - (visualizerHeight / 2);
              bgChildren.add(
                Positioned(
                  left: leftBg,
                  top: topBg,
                  child: IgnorePointer(
                    child: _buildVisualizerEffect(context, va, position),
                  ),
                ),
              );
            }
            // Overlay base size: match player size so visualizer sits directly on video
            final double baseWidth = playerW;
            final double baseHeight = playerH;
            final double safeScale =
                (editing.scale.isFinite ? editing.scale : 1.0).clamp(0.1, 4.0);
            final double safeX =
                (editing.x.isFinite ? editing.x : 0.5).clamp(-1.0, 2.0);
            final double safeY =
                (editing.y.isFinite ? editing.y : 0.5).clamp(-1.0, 2.0);
            final double visualizerWidth = baseWidth * safeScale;
            final double visualizerHeight = baseHeight * safeScale;
            final double left = safeX * playerW - (visualizerWidth / 2);
            final double top = safeY * playerH - (visualizerHeight / 2);

            return SizedBox(
              width: playerW,
              height: playerH,
              child: ClipRect(
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    ...bgChildren,
                    Positioned(
                      left: left,
                      top: top,
                      child: _buildEditingVisualizer(context, editing),
                    ),
                  ],
                ),
              ),
            );
          }

          // Not editing: render ALL active visualizers across layers
          final assets = directorService
              .getActiveAssetsOfType(AssetType.visualizer)
              .map((a) => VisualizerAsset.fromAsset(a))
              .where((va) => va.fullScreen != true)
              .toList();
          if (assets.isEmpty) return Container();

          // Ensure FFT prefetch for all (with asset params)
          for (final va in assets) {
            visualizerService.prefetchFFT(va.srcPath, asset: va);
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
              final position = directorService.position;
              // Performance: Skip unnecessary rebuilds during export
              if (directorService.isGenerating) {
                // During export, only rebuild when position actually changes
                // This prevents redundant FFT lookups and canvas repaints
              }
              final double playerW = PlayerLayout.width(context);
              final double playerH = PlayerLayout.height(context);
              // Overlay base size: exactly match player so effects align with video area
              final double baseWidth = playerW;
              final double baseHeight = playerH;
              final children = <Widget>[];
              for (final va in assets) {
                // Overlay visualizer: position by x/y and scale
                final double safeScale =
                    (va.scale.isFinite ? va.scale : 1.0).clamp(0.1, 4.0);
                final double safeX = (va.x.isFinite ? va.x : 0.5).clamp(-1.0, 2.0);
                final double safeY = (va.y.isFinite ? va.y : 0.5).clamp(-1.0, 2.0);
                final double visualizerWidth = baseWidth * safeScale;
                final double visualizerHeight = baseHeight * safeScale;
                final double halfW = visualizerWidth / 2;
                final double halfH = visualizerHeight / 2;
                double cx = safeX * playerW;
                double cy = safeY * playerH;
                double left = cx - halfW;
                double top = cy - halfH;
                children.add(Positioned(
                  left: left,
                  top: top,
                  child: _buildVisualizerEffect(context, va, position),
                ));
              }
              // Player güvenli alanı dışına taşmayı engelle
              return SizedBox(
                width: playerW,
                height: playerH,
                child: ClipRect(
                  child: Stack(clipBehavior: Clip.hardEdge, children: children),
                ),
              );
            },
          );
        });
  }

  /// Editing mode'da visualizer göster (sürüklenebilir) - TextPlayerEditor benzeri
  Widget _buildEditingVisualizer(BuildContext context, VisualizerAsset _asset) {
    // Ensure FFT starts processing for this source (with asset params)
    visualizerService.prefetchFFT(_asset.srcPath, asset: _asset);
    final bool allowOuterDrag = _asset.renderMode != 'counter';
    final child = StreamBuilder(
      stream: Rx.merge([
        visualizerService.fftReady$,
        directorService.position$,
      ]),
      initialData: 0,
      builder: (context, _) {
        final int pos = directorService.position;
        return _buildVisualizerEffect(context, _asset, pos);
      },
    );

    if (!allowOuterDrag) return child;

    return GestureDetector(
      onPanUpdate: (details) {
        // Text'teki gibi - direkt asset'i değiştir (performans için clone yok)
        final double playerW = PlayerLayout.width(context);
        final double playerH = PlayerLayout.height(context);
        final double dx = details.delta.dx / playerW;
        final double dy = details.delta.dy / playerH;
        final double nextX = _asset.x + (dx.isFinite ? dx : 0.0);
        final double nextY = _asset.y + (dy.isFinite ? dy : 0.0);
        if (nextX.isFinite) {
          _asset.x = nextX.clamp(-1.0, 2.0);
        }
        if (nextY.isFinite) {
          _asset.y = nextY.clamp(-1.0, 2.0);
        }
        // Overflow serbest: sürüklemede sınır kısıtlamaları kaldırıldı

        // Stream'i güncelle
        visualizerService.editingVisualizerAsset = _asset;
      },
      child: child,
    );
  }

  /// Timeline'dan visualizer göster (statik)
  Widget buildStaticVisualizer(BuildContext context, VisualizerAsset _asset) {
    // FFT'yi önceden başlat ve hazır olduğunda yeniden çiz (with asset params)
    visualizerService.prefetchFFT(_asset.srcPath, asset: _asset);
    final rebuild$ = Rx.merge([
      directorService.position$,
      visualizerService.fftReady$, // herhangi bir FFT tamamlandığında tetikler
    ]);
    return StreamBuilder(
      stream: rebuild$,
      initialData: 0,
      builder: (context, _) {
        // Pozisyonu doğrudan servisten al (fftReady event'i int değildir)
        final int position = directorService.position;
        // Performance: Cache FFT lookups during export
        return _buildVisualizerEffect(context, _asset, position);
      },
    );
  }

  /// Visualizer efektini oluştur
  Widget _buildVisualizerEffect(BuildContext context, VisualizerAsset asset, int position) {
    final loc = AppLocalizations.of(context);
    // Ses kaynağı yoksa boş göster
    if (asset.srcPath.isEmpty) {
      return Container(
        width: 300,
        height: 150,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          border: Border.all(color: Colors.orange, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            loc.visualizerNoAudioSource,
            style: TextStyle(color: Colors.orange, fontSize: 14),
          ),
        ),
      );
    }

    // Asset'in kendi timeline pozisyonunu hesapla ve sınırla
    int relativePosition = position - asset.begin;
    if (relativePosition < 0) relativePosition = 0;
    if (relativePosition > asset.duration) relativePosition = asset.duration;

    // VisualizerAsset'e map et (merkezi model)
    final va = asset;
    // Render mode'a göre widget seç
    String renderMode = va.renderMode;
    double scale = (va.scale.isFinite ? va.scale : 1.0).clamp(0.1, 4.0);
    // Normalize legacy default green to white
    int col = va.color == 0xFF00FF00 ? 0xFFFFFFFF : va.color;
    Color effectColor = Color(col);
    Color? gradientColor = va.gradientColor != null ? Color(va.gradientColor!) : null;
    final double opacity =
        (va.alpha.isFinite ? va.alpha : 1.0).clamp(0.0, 1.0);

    // Debug prints removed for performance

    // Base overlay size: exactly match player so visualizer fills video area by default
    final double playerW = PlayerLayout.width(context);
    final double playerH = PlayerLayout.height(context);
    final double baseWidth = playerW;
    final double baseHeight = playerH;

    Widget effectWidget;

    if (renderMode == 'progress') {
      // Time-based progress bar: use global timeline position for full project sync
      effectWidget = ProgressEffect(
        position: position,
        asset: va,
        width: baseWidth,
        height: baseHeight * 0.10,
      );
    } else if (renderMode == 'counter') {
      // Counter-only mode: start/end timers as standalone overlay
      effectWidget = Opacity(
        opacity: opacity,
        child: CounterEffect(
          position: position,
          asset: va,
          width: baseWidth,
          height: baseHeight,
        ),
      );
    } else {
      // FFT verilerini al (canvas/shader/visual için)
      List<double>? fftData = visualizerService.getFFTDataAtTime(
        asset.srcPath,
        relativePosition,
        asset: asset,
      );

      if (fftData == null || fftData.isEmpty) {
        // Demo kapalı: FFT hazır olana kadar sessiz başlangıç (çubuklar görünmez)
        // Boyut asset'in fftBands parametresine göre
        fftData = List.filled(asset.fftBands, 0.0);
      } else {
        // Gelişmiş dinamikler: smoothness + reactivity uygula
        fftData = visualizerService.applyDynamics(fftData, asset);
      }

      final bool isVisualMode = renderMode == 'visual';
      final String shaderPath = isVisualMode
          ? normalizeVisualShaderId(va.shaderType ?? 'pro_nation')
          : normalizeVisualizerShaderId(va.shaderType ?? 'bar');

      final String st = normalizeVisualizerShaderId(va.shaderType ?? 'bar');

      final double intensity = va.amplitude.clamp(0.5, 2.0);
      final double speed = va.speed.clamp(0.5, 2.0);
      final double rotation =
          (va.rotation.isFinite ? va.rotation : 0.0).clamp(0.0, 360.0);
      double? barFill;
      double? glow = va.glowIntensity.clamp(0.0, 1.0);
      double? strokeWidth;

      if (st == 'bar' || st == 'bar_normal' || st == 'bar_colors' || st == 'claude' || st == 'bar_circle'|| st == 'circle') {
        barFill = va.barSpacing.clamp(0.35, 0.92);
      } else if (st == 'smooth') {
        // smooth.frag declares uGlow BEFORE uStroke. If we only set strokeWidth, uniforms shift.
        strokeWidth = va.strokeWidth.clamp(0.5, 8.0);
      } else if (st == 'line' || st == 'wave' || st == 'curves' || st == 'wav' || st == 'sinus') {
        strokeWidth = va.strokeWidth.clamp(0.5, 8.0);
      }

      // Visual mode uses stage-sampling shader, Shader mode uses visualizer shader.
      // Legacy/unknown renderMode (including removed 'canvas') falls back to shader mode.
      if (isVisualMode) {
        effectWidget = Opacity(
          opacity: opacity,
          child: VisualStageEffect(
            frequencies: fftData,
            shaderPath: shaderPath,
            color: effectColor,
            gradientColor: gradientColor,
            intensity: intensity,
            speed: speed,
            width: baseWidth,
            height: baseHeight,
            barCount: va.barCount,
            mirror: va.mirror,
            rotation: rotation,
            // Overlay ayarlari (pro_nation shader icin)
            centerImagePath: va.centerImagePath,
            ringColor: va.ringColor != null ? Color(va.ringColor!) : null,
            backgroundImagePath: va.backgroundImagePath,
          ),
        );
      } else {
        effectWidget = Opacity(
          opacity: opacity,
          child: ShaderEffect(
            frequencies: fftData,
            shaderPath: shaderPath,
            color: effectColor,
            gradientColor: gradientColor,
            intensity: intensity,
            speed: speed,
            barFill: barFill,
            glow: glow,
            strokeWidth: strokeWidth,
            width: baseWidth,
            height: baseHeight,
            barCount: va.barCount,
            mirror: va.mirror,
            rotation: rotation,
          ),
        );
      }
    }

    // Ölçeklemeyi OverflowBox + Transform.scale ile yap: taşma kesilmesin
    return SizedBox(
      width: baseWidth * scale,
      height: baseHeight * scale,
      child: OverflowBox(
        alignment: Alignment.center,
        minWidth: 0,
        minHeight: 0,
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.center,
          child: SizedBox(
            width: baseWidth,
            height: baseHeight,
            child: effectWidget,
          ),
        ),
      ),
    );
  }
}
