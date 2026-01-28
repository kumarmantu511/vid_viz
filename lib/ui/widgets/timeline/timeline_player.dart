import 'dart:ui';
import 'dart:core';
import 'dart:io';
import 'dart:math' as math;
import 'package:rxdart/rxdart.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/model/layer.dart';
import 'package:vidviz/model/shader_effect.dart';
import 'package:vidviz/model/text_asset.dart';
import 'package:vidviz/core/params.dart';
import 'package:vidviz/core/aspect_ratio.dart';
import 'package:vidviz/service/director_service.dart';
import 'package:vidviz/service/shader_effect_service.dart';
import 'package:vidviz/ui/widgets/text/text_player_editor.dart';
import 'package:vidviz/ui/widgets/text/text_effect_player.dart';
import 'package:vidviz/ui/widgets/visualizer/visualizer_player.dart';
import 'package:vidviz/ui/widgets/visualizer/background_visualizer_player.dart';
import 'package:vidviz/ui/widgets/shader/shader_effect_player.dart';
import 'package:vidviz/ui/widgets/media_overlay/media_overlay_player.dart';
import 'package:vidviz/ui/widgets/audio_reactive/audio_reactive_player.dart';
import 'package:vidviz/core/constants.dart';
import 'package:vidviz/ui/widgets/timeline/player_metrics.dart';

class TimelinePlayer extends StatelessWidget {
  final directorService = locator.get<DirectorService>();

  TimelinePlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Rx.merge([
        directorService.position$,
        directorService.editingVideoSettings$,
      ]),
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        // Etkin video ayarlarını al (edit sırasında editingVideoSettings, aksi halde project ayarları)
        final vs = directorService.editingVideoSettings ?? directorService.getProjectVideoSettings();

        final double targetAspect = parseAspectRatioString(vs.aspectRatio);

        // Get main raster layer dynamically
        final mainIdx = directorService.getMainRasterLayerIndex();

        // Helper to build content stack
        Widget buildContent() {
          if (mainIdx < 0 ||
              directorService.layerPlayers.length == 0 ||
              mainIdx >= directorService.layerPlayers.length ||
              directorService.layerPlayers[mainIdx] == null) {
            return Container(color: Color(vs.backgroundColor));
          }

          int assetIndex = directorService.layerPlayers[mainIdx]!.currentAssetIndex;

          if (assetIndex == -1 ||
              directorService.layers == null ||
              directorService.layers!.isEmpty ||
              mainIdx >= directorService.layers!.length ||
              assetIndex >= directorService.layers![mainIdx].assets.length) {
            return Container(color: Color(vs.backgroundColor));
          }

          AssetType type = directorService.layers![mainIdx].assets[assetIndex].type;

          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // Base stage (background + video/image)
              RepaintBoundary(
                key: directorService.shaderCaptureKey,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Container(color: Color(vs.backgroundColor)),

                    /// Video/Image layer
                    Builder(
                      builder: (_) {
                        final vc = directorService.layerPlayers[mainIdx]!.videoController;
                        final Asset asset = directorService.layers![mainIdx].assets[assetIndex];
                        bool canRenderVideo = false;
                        if (type == AssetType.video && vc != null) {
                          try {
                            final v = vc.value;
                            canRenderVideo = v.isInitialized && !v.hasError;
                          } catch (_) {
                            canRenderVideo = false;
                          }
                        }

                        Widget media;
                        if (type == AssetType.video) {
                          final String? thumb = asset.thumbnailMedPath ?? asset.thumbnailPath;
                          final bool hasThumb = (thumb != null && File(thumb).existsSync());
                          media = Stack(
                            fit: StackFit.expand,
                            children: [
                              if (hasThumb)
                                Image.file(
                                  File(thumb!),
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                ),
                              if (canRenderVideo) VideoPlayer(vc!),
                            ],
                          );
                        } else {
                          media = _ImagePlayer(directorService.layers![mainIdx].assets[assetIndex], mainIdx,);
                        }

                        // Flip ve Rotation
                        Widget transformed = Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..scale(vs.flipHorizontal ? -1.0 : 1.0, vs.flipVertical ? -1.0 : 1.0)
                            ..rotateZ((vs.rotation).toDouble() * math.pi / 180.0),
                          child: media,
                        );

                        // İçeriğin orijinal oranını bul
                        final double srcAspect = (canRenderVideo && vc != null && vc.value.aspectRatio > 0) ? vc.value.aspectRatio : 16 / 9; // Image için varsayılan veya metadata'dan alınmalı (şimdilik 16:9 varsayılıyor, ImagePlayer kendi içinde fit edebilir)

                        // 4. BoxFit Modunu Belirle (DÜZELTİLEN KISIM)
                        BoxFit fitMode;
                        switch (vs.cropMode) {
                          case 'fill':
                          // Ekranı doldur (Kenarlardan taşarak/crop yaparak)
                            fitMode = BoxFit.cover;
                            break;
                          case 'fit':
                          // Ekrana sığdır (Kenarlarda boşluk/black bars kalabilir)
                            fitMode = BoxFit.contain;
                            break;
                          case 'stretch':
                          // Ekrana zorla sığdır (Görüntü uzar/basıklaşır)
                            fitMode = BoxFit.fill;
                            break;
                          default:
                            fitMode = BoxFit.contain; // Varsayılan: Sığdır
                        }

                        // FittedBox içine girecek child boyutunu belirle
                        double childWidth;
                        double childHeight;
                        if (canRenderVideo && vc != null && vc.value.size.width > 0 && vc.value.size.height > 0) {
                          childWidth = vc.value.size.width;
                          childHeight = vc.value.size.height;
                        } else {
                          childWidth = 1000;
                          childHeight = 1000 / srcAspect;
                        }

                        // Crop moduna göre yerleşim
                        return SizedBox.expand(
                          child: ClipRect(
                            child: FittedBox(
                              fit: fitMode,
                              alignment: Alignment.center,
                              child: SizedBox(
                                width: childWidth,
                                height: childHeight,
                                child: transformed,
                              ),
                            ),
                          ),
                        );

                      },
                    ),
                  ],
                ),
              ),

              /// Layers
              _ShaderEffectPlayerWrapper(),
              BackgroundVisualizerPlayer(),
              MediaOverlayPlayer(),
              VisualizerPlayer(),
              AudioReactivePlayer(),
              _TextPlayer(),
            ],
          );
        }

        return Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double maxW = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : MediaQuery.of(context).size.width;
              final double maxH = constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : MediaQuery.of(context).size.height;

              double w = maxW;
              double h = (targetAspect > 0) ? (w / targetAspect) : maxH;
              if (h > maxH) {
                h = maxH;
                w = (targetAspect > 0) ? (h * targetAspect) : maxW;
              }
              if (!w.isFinite || w <= 0) w = maxW;
              if (!h.isFinite || h <= 0) h = maxH;

              final double dpr = PlayerLayout.devicePixelRatio(context);

              return SizedBox(
                width: w,
                height: h,
                child: PlayerMetrics(
                  size: Size(w, h),
                  devicePixelRatio: dpr,
                  child: IgnorePointer(
                    ignoring: directorService.editingVideoSettings != null,
                    child: RepaintBoundary(
                      key: directorService.exportCaptureKey,
                      child: buildContent(),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ImagePlayer extends StatelessWidget {
  final directorService = locator.get<DirectorService>();
  final Asset asset;
  final int layerIndex;

  _ImagePlayer(this.asset, this.layerIndex) : super();

  @override
  Widget build(BuildContext context) {
    if (asset.deleted) return Container();
    return StreamBuilder(
      stream: directorService.position$,
      initialData: 0,
      builder: (BuildContext context, AsyncSnapshot<int> position) {
        int assetIndex = directorService.layerPlayers[layerIndex]!.currentAssetIndex;
        double ratio = (directorService.position -
        directorService.layers![layerIndex].assets[assetIndex].begin) /
        directorService.layers![layerIndex].assets[assetIndex].duration;
        if (ratio < 0) ratio = 0;
        if (ratio > 1) ratio = 1;

        // DÜZELTME BURADA:
        // Resmi tüm alana yaymak (expand) ve orantılı doldurmak (cover) için güncellendi.
        return SizedBox.expand(
          child: Image.file(
            File(asset.thumbnailMedPath ?? asset.srcPath),
            fit: BoxFit.cover, // Resmin en-boy oranını bozmadan alanı doldurur
            gaplessPlayback: true, // Titremeyi önler
          ),
        );

        /// geçiçici kernbun devre dışı
        /* sonra kulanılacak return KenBurnEffect(
            asset.thumbnailMedPath ?? asset.srcPath,
            ratio,
            zSign: asset.kenBurnZSign,
            xTarget: asset.kenBurnXTarget,
            yTarget: asset.kenBurnYTarget,
          );*/
      },
    );
  }
}

class _TextPlayer extends StatelessWidget {
  final directorService = locator.get<DirectorService>();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Rx.merge([
        directorService.editingTextAsset$,
        directorService.position$,
      ]),
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        Widget textWidget;
        final playerW = PlayerLayout.width(context);
        final playerH = PlayerLayout.height(context);

        // If editing, draw only the editor overlay (like before)
        if (directorService.editingTextAsset != null) {
          return Positioned(
            left: directorService.editingTextAsset!.x * playerW,
            top:  directorService.editingTextAsset!.y * playerH,
            child: TextPlayerEditor(directorService.editingTextAsset!),
          );
        }

        // Otherwise, render ALL active text overlays across layers
        final active = directorService.getActiveAssetsOfType(AssetType.text);
        if (active.isEmpty) return Container();
        final List<Widget> items = [];
        for (final a in active) {
          final t = TextAsset.fromAsset(a);
          final font = Font.getByPath(t.font);
          final hasEffect = (t.effectType != 'none' && t.effectType.isNotEmpty);
          final hasAnim = (t.animType != 'none' && t.animType.isNotEmpty);
          final hasDecor = (t.box == true) || (t.boxborderw > 0) || (t.borderw > 0) || (t.shadowx != 0) || (t.shadowy != 0);
          final useEffect = hasEffect || hasAnim || hasDecor;

          if (useEffect) {
            final nowMs = directorService.position;
            final timeSec = ((nowMs - t.begin) / 1000.0).clamp(0.0, 1e9);
            textWidget = TextEffectPlayer(
              t,
              playerWidth: playerW,
              timeSecOverride: timeSec,
            );
          } else {
            textWidget = Text(
              t.title,
              style: TextStyle(
                height: 1,
                fontSize: t.fontSize * playerW / MediaQuery.of(context).textScaleFactor,
                fontStyle: font.style,
                fontFamily: font.family,
                fontWeight: font.weight,
                color: Color(t.fontColor),
                backgroundColor: t.box == true ? Color(t.boxcolor) : Colors.transparent,
              ),
            );
          }
          items.add(
            Positioned(
              left: t.x * playerW,
              top: t.y * playerH,
              child: textWidget,
            ),
          );
        }
        return Stack(children: items);
      },
    );
  }
}

/// ShaderEffectPlayer Wrapper - VisualizerPlayer gibi
class _ShaderEffectPlayerWrapper extends StatelessWidget {
  final directorService = locator.get<DirectorService>();
  final shaderEffectService = locator.get<ShaderEffectService>();

  @override
  Widget build(BuildContext context) {
    // Editing mode stream'ini dinle
    return StreamBuilder(
      stream: shaderEffectService.editingShaderEffectAsset$,
      initialData: null,
      builder: (BuildContext context, AsyncSnapshot<ShaderEffectAsset?> editingSnapshot,) {

        ShaderEffectAsset? editingAsset = editingSnapshot.data;

        // Editing mode'daysa veya timeline'da shader varsa göster
        if (editingAsset != null) {
          // Editing mode - ShaderEffectPlayer'a asset geç
          return ShaderEffectPlayer(asset: editingAsset);
        }

        // Timeline'dan kontrol et (first active shader across layers)
        Asset? timelineAsset = directorService.getFirstActiveAssetOfType(AssetType.shader,);
        if (timelineAsset != null) {
          ShaderEffectAsset shaderAsset = shaderEffectService.assetToShaderEffect(timelineAsset);
          return ShaderEffectPlayer(asset: shaderAsset);
        }

        // Shader yoksa boş döndür
        return Container();
      },
    );
  }
}



/*
class KenBurnEffect extends StatelessWidget {
  final String path;
  final double ratio;
  // Effect configuration
  final int zSign;
  final double xTarget;
  final double yTarget;

  KenBurnEffect(
      this.path,
      this.ratio, {
        this.zSign = 0, // Options: {-1, 0, +1}
        this.xTarget = 0, // Options: {0, 0.5, 1}
        this.yTarget = 0, // Options; {0, 0.5, 1}
      }) : super();

  @override
  Widget build(BuildContext context) {
    // Start and end positions
    double xStart = (zSign == 1) ? 0 : (0.5 - xTarget);
    double xEnd = (zSign == 1)
        ? (0.5 - xTarget)
        : ((zSign == -1) ? 0 : (xTarget - 0.5));
    double yStart = (zSign == 1) ? 0 : (0.5 - yTarget);
    double yEnd = (zSign == 1)
        ? (0.5 - yTarget)
        : ((zSign == -1) ? 0 : (yTarget - 0.5));
    double zStart = (zSign == 1) ? 0 : 1;
    double zEnd = (zSign == -1) ? 0 : 1;

    // Interpolation
    double x = xStart * (1 - ratio) + xEnd * ratio;
    double y = yStart * (1 - ratio) + yEnd * ratio;
    double z = zStart * (1 - ratio) + zEnd * ratio;

    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRect(
          child: Transform.translate(
            offset: Offset(
              x * 0.2 * Params.getPlayerWidth(context),
              y * 0.2 * Params.getPlayerHeight(context),
            ),
            child: Transform.scale(
              scale: 1 + z * 0.2,
              child: Stack(
                fit: StackFit.expand,
                children: [Image.file(File(path))],
              ),
            ),
          ),
        );
      },
    );
  }
}*/
