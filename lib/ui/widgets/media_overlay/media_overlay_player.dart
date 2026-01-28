import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/director_service.dart';
import 'package:vidviz/service/media_overlay_service.dart';
import 'package:vidviz/model/layer.dart';
import 'package:vidviz/model/media_overlay.dart';
import 'package:vidviz/core/params.dart';
import 'package:vidviz/ui/widgets/timeline/player_metrics.dart';

/// Media Overlay Player - Sahne üzerinde media overlay render
/// Text/Visualizer player pattern'ini takip eder
class MediaOverlayPlayer extends StatefulWidget {
  @override
  _MediaOverlayPlayerState createState() => _MediaOverlayPlayerState();
}

class _MediaOverlayPlayerState extends State<MediaOverlayPlayer>
    with TickerProviderStateMixin {
  final directorService = locator.get<DirectorService>();
  final mediaOverlayService = locator.get<MediaOverlayService>();

  // Video controllers cache
  final Map<String, VideoPlayerController> _videoControllers = {};

  StreamSubscription<int>? _positionSubscription;
  int _currentPositionMs = 0;

  @override
  void initState() {
    super.initState();
    _positionSubscription = directorService.position$.listen((pos) {
      if (!mounted) return;
      setState(() {
        _currentPositionMs = pos;
      });
    });
  }

  @override
  void dispose() {
    // Dispose all video controllers
    _videoControllers.values.forEach((controller) => controller.dispose());
    _videoControllers.clear();
    _positionSubscription?.cancel();
    super.dispose();
  }

  /// Get or create video controller
  VideoPlayerController _getVideoController(String srcPath) {
    if (!_videoControllers.containsKey(srcPath)) {
      final controller = VideoPlayerController.file(File(srcPath));
      controller.initialize().then((_) {
        controller.setLooping(true);
        controller.setVolume(
          0.0,
        ); // Overlay video SESSIZ (ana video + timeline audio çalmalı)
        // Don't auto-play, let _buildOverlay handle playback state
        if (mounted) setState(() {});
      });
      _videoControllers[srcPath] = controller;
    }
    return _videoControllers[srcPath]!;
  }

  double _computeBaseSize(BuildContext context) {
    final double playerW = PlayerLayout.width(context);
    final double playerH = PlayerLayout.height(context);
    final double minSide = math.min(playerW, playerH);
    double base = minSide * 0.25;
    final minBase = minSide * 0.10;
    final maxBase = minSide * 0.40;
    if (base < minBase) base = minBase;
    if (base > maxBase) base = maxBase;
    return base;
  }

  Size _computeFrameSize(BuildContext context, MediaOverlayAsset overlay) {
    final double playerW = PlayerLayout.width(context);
    final double playerH = PlayerLayout.height(context);
    final double base = _computeBaseSize(context);

    if (overlay.frameMode == 'fullscreen') {
      return Size(playerW, playerH);
    }

    if (overlay.frameMode == 'portrait') {
      return Size(base * (9.0 / 16.0), base);
    }

    if (overlay.frameMode == 'landscape') {
      return Size(base, base * (9.0 / 16.0));
    }

    return Size(base, base);
  }

  BoxFit _boxFitForMode(MediaOverlayAsset overlay) {
    if (overlay.fitMode == 'contain') return BoxFit.contain;
    if (overlay.fitMode == 'stretch') return BoxFit.fill;
    return BoxFit.cover;
  }

  Widget _applyCropToChild(MediaOverlayAsset overlay, Widget child, Size frameSize) {
    if (overlay.cropMode != 'custom') return child;

    double zoom = overlay.cropZoom;
    if (zoom < 1.0) zoom = 1.0;
    if (zoom > 4.0) zoom = 4.0;

    double panX = overlay.cropPanX;
    if (panX < -1.0) panX = -1.0;
    if (panX > 1.0) panX = 1.0;

    double panY = overlay.cropPanY;
    if (panY < -1.0) panY = -1.0;
    if (panY > 1.0) panY = 1.0;

    final double maxShiftXPx = ((zoom - 1.0) * frameSize.width) / 2.0;
    final double maxShiftYPx = ((zoom - 1.0) * frameSize.height) / 2.0;
    final double dxPx = -panX * maxShiftXPx;
    final double dyPx = -panY * maxShiftYPx;

    return ClipRect(
      child: Transform.translate(
        offset: Offset(dxPx, dyPx),
        child: Transform.scale(
          scale: zoom,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: mediaOverlayService.editingMediaOverlay$,
      initialData: null,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<MediaOverlayAsset?> editingSnapshot,
          ) {
            final editing = editingSnapshot.data;

            // Editing mode
            if (editing != null) {
              return _buildEditingOverlay(context, editing);
            }

            // Playback mode: render ALL active media overlays
            final activeOverlays = directorService
                .getActiveAssetsOfType(AssetType.image)
                .where((a) => MediaOverlayAsset.isMediaOverlay(a))
                .map((a) => MediaOverlayAsset.fromAsset(a))
                .toList();

            if (activeOverlays.isEmpty) return Container();

            return Stack(
              children: activeOverlays.map((overlay) {
                return _buildPlaybackOverlay(context, overlay);
              }).toList(),
            );
          },
    );
  }

  /// Playback mode overlay (positioned, not draggable)
  Widget _buildPlaybackOverlay(
    BuildContext context,
    MediaOverlayAsset overlay,
  ) {
    final frameSize = _computeFrameSize(context, overlay);
    final double playerW = PlayerLayout.width(context);
    final double playerH = PlayerLayout.height(context);

    return Positioned(
      // Center anchor: x,y = center point of overlay (scale merkezden uygulanacak)
      left: (overlay.x * playerW) - (frameSize.width / 2),
      top: (overlay.y * playerH) - (frameSize.height / 2),
      child: _buildOverlay(context, overlay, false, frameSize),
    );
  }

  /// Editing mode overlay (draggable)
  Widget _buildEditingOverlay(BuildContext context, MediaOverlayAsset overlay) {
    final frameSize = _computeFrameSize(context, overlay);
    final double playerW = PlayerLayout.width(context);
    final double playerH = PlayerLayout.height(context);

    return Positioned(
      // Center anchor: x,y = center point of overlay (scale merkezden uygulanacak)
      left: (overlay.x * playerW) - (frameSize.width / 2),
      top: (overlay.y * playerH) - (frameSize.height / 2),
      child: GestureDetector(
        onPanUpdate: (details) {
          if (overlay.cropMode == 'custom') {
            final double zoom = overlay.cropZoom.clamp(1.0, 4.0);
            final double maxShiftXPx = ((zoom - 1.0) * frameSize.width) / 2.0;
            final double maxShiftYPx = ((zoom - 1.0) * frameSize.height) / 2.0;

            if (maxShiftXPx > 0.5) {
              overlay.cropPanX =
                  (overlay.cropPanX - (details.delta.dx / maxShiftXPx)).clamp(-1.0, 1.0);
            }
            if (maxShiftYPx > 0.5) {
              overlay.cropPanY =
                  (overlay.cropPanY - (details.delta.dy / maxShiftYPx)).clamp(-1.0, 1.0);
            }
            mediaOverlayService.editingMediaOverlay = overlay;
            return;
          }

          overlay.x += details.delta.dx / playerW;
          overlay.y += details.delta.dy / playerH;

          // Bounds check with margin (keep overlay visible)
          final margin = 0.05; // 5% margin
          overlay.x = overlay.x.clamp(margin, 1.0 - margin);
          overlay.y = overlay.y.clamp(margin, 1.0 - margin);

          mediaOverlayService.editingMediaOverlay = overlay;
        },
        child: _buildOverlay(context, overlay, true, frameSize),
      ),
    );
  }

  /// Build overlay widget
  Widget _buildOverlay(
    BuildContext context,
    MediaOverlayAsset overlay,
    bool isEditing,
    Size frameSize,
  ) {
    Widget mediaWidget;

    final fit = _boxFitForMode(overlay);

    // Load HIGH QUALITY media (srcPath, not thumbnail!)
    if (overlay.mediaType == AssetType.video) {
      // VIDEO: Use VideoPlayer for playback (timeline-synced with cutFrom + begin)
      final controller = _getVideoController(overlay.srcPath);
      if (controller.value.isInitialized) {
        if (!isEditing) {
          final int position = _currentPositionMs;
          // Compute timeline-relative offset within overlay window
          int relMs = position - overlay.begin;
          if (relMs < 0) relMs = 0;
          if (relMs > overlay.duration) relMs = overlay.duration;
          int seekMs = overlay.cutFrom + relMs;
          // Clamp to file duration if known
          final int fileDurMs = controller.value.duration.inMilliseconds;
          if (fileDurMs > 0 && seekMs > fileDurMs) {
            seekMs = fileDurMs;
          }
          // Avoid excessive re-seek if already close
          final int currentMs = controller.value.position.inMilliseconds;
          if ((currentMs - seekMs).abs() > 40) {
            controller.seekTo(Duration(milliseconds: seekMs));
          }

          // For preview mode, keep play/pause in sync with director
          if (!directorService.isGenerating) {
            if (directorService.isPlaying && !controller.value.isPlaying) {
              controller.play();
            } else if (!directorService.isPlaying &&
                controller.value.isPlaying) {
              controller.pause();
            }
          } else {
            // During export, ensure video is paused; frames are driven by seek
            if (controller.value.isPlaying) {
              controller.pause();
            }
          }
        } else {
          // In editing mode, pause video
          if (controller.value.isPlaying) {
            controller.pause();
          }
        }
        final Size vSize = controller.value.size;
        if (vSize.width > 0 && vSize.height > 0) {
          mediaWidget = FittedBox(
            fit: fit,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: vSize.width,
              height: vSize.height,
              child: VideoPlayer(controller),
            ),
          );
        } else {
          mediaWidget = VideoPlayer(controller);
        }
      } else {
        // Loading placeholder
        mediaWidget = Container(
          color: Colors.black,
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        );
      }
    } else {
      // IMAGE: Use high-quality srcPath
      if (File(overlay.srcPath).existsSync()) {
        mediaWidget = Image.file(
          File(overlay.srcPath),
          fit: fit,
          filterQuality: FilterQuality.high, // High quality!
        );
      } else {
        mediaWidget = Container(
          color: Colors.grey,
          child: Icon(Icons.broken_image, color: Colors.white),
        );
      }
    }

    // Apply crop/pan/zoom inside the overlay box.
    mediaWidget = _applyCropToChild(overlay, mediaWidget, frameSize);

    final double minSide = math.min(frameSize.width, frameSize.height);
    final double radius = (overlay.borderRadius.clamp(0.0, 100.0) / 100.0) * (minSide * 0.5);

    // Apply transformations
    Widget transformed = Transform.rotate(
      angle: overlay.rotation * 3.14159 / 180,
      child: Transform.scale(
        scale: overlay.scale,
        child: Opacity(
          opacity: overlay.opacity,
          child: Container(
            width: frameSize.width,
            height: frameSize.height,
            decoration: BoxDecoration(
              border: isEditing
                  ? Border.all(color: Color(0xFF00DD34), width: 0.6)
                  : null,
              borderRadius: BorderRadius.circular(radius),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: mediaWidget,
            ),
          ),
        ),
      ),
    );

    // Apply animation if not editing
    if (!isEditing && overlay.animationType != 'none') {
      return _applyAnimation(overlay, transformed);
    }

    return transformed;
  }

  /// Apply animation based on type
  Widget _applyAnimation(MediaOverlayAsset overlay, Widget child) {
    if (overlay.animationDuration <= 0) return child;

    // Timeline-based progress inside overlay window [begin, begin+duration)
    final int overlayPos = (_currentPositionMs - overlay.begin).clamp(
      0,
      overlay.duration,
    );
    final int animDur = overlay.animationDuration;

    double t;
    Animation<double> animation;

    switch (overlay.animationType) {
      case 'fade_in':
        // Fade in from overlay start
        if (overlayPos <= 0) {
          t = 0.0;
        } else if (overlayPos >= animDur) {
          t = 1.0;
        } else {
          t = overlayPos / animDur;
        }
        animation = AlwaysStoppedAnimation<double>(t.clamp(0.0, 1.0));
        return FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(animation),
          child: child,
        );

      case 'fade_out':
        // Fade out over the last animationDuration before overlay end
        final int startFade = (overlay.duration - animDur).clamp(
          0,
          overlay.duration,
        );
        if (overlayPos <= startFade) {
          t = 0.0;
        } else if (overlayPos >= overlay.duration) {
          t = 1.0;
        } else {
          final int span = animDur == 0 ? 1 : animDur;
          t = (overlayPos - startFade) / span;
        }
        animation = AlwaysStoppedAnimation<double>(t.clamp(0.0, 1.0));
        return FadeTransition(
          opacity: Tween<double>(begin: 1.0, end: 0.0).animate(animation),
          child: child,
        );

      case 'slide_left':
        // Slide-in from right at overlay start
        if (overlayPos <= 0) {
          t = 0.0;
        } else if (overlayPos >= animDur) {
          t = 1.0;
        } else {
          t = overlayPos / animDur;
        }
        animation = AlwaysStoppedAnimation<double>(t.clamp(0.0, 1.0));
        return SlideTransition(
          position: Tween<Offset>(
            begin: Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        );

      case 'slide_right':
        // Slide-in from left at overlay start
        if (overlayPos <= 0) {
          t = 0.0;
        } else if (overlayPos >= animDur) {
          t = 1.0;
        } else {
          t = overlayPos / animDur;
        }
        animation = AlwaysStoppedAnimation<double>(t.clamp(0.0, 1.0));
        return SlideTransition(
          position: Tween<Offset>(
            begin: Offset(-1.0, 0.0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        );

      case 'slide_up':
        // Slide-in from bottom at overlay start
        if (overlayPos <= 0) {
          t = 0.0;
        } else if (overlayPos >= animDur) {
          t = 1.0;
        } else {
          t = overlayPos / animDur;
        }
        animation = AlwaysStoppedAnimation<double>(t.clamp(0.0, 1.0));
        return SlideTransition(
          position: Tween<Offset>(
            begin: Offset(0.0, 1.0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        );

      case 'slide_down':
        // Slide-in from top at overlay start
        if (overlayPos <= 0) {
          t = 0.0;
        } else if (overlayPos >= animDur) {
          t = 1.0;
        } else {
          t = overlayPos / animDur;
        }
        animation = AlwaysStoppedAnimation<double>(t.clamp(0.0, 1.0));
        return SlideTransition(
          position: Tween<Offset>(
            begin: Offset(0.0, -1.0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        );

      case 'zoom_in':
        // Zoom-in at overlay start
        if (overlayPos <= 0) {
          t = 0.0;
        } else if (overlayPos >= animDur) {
          t = 1.0;
        } else {
          t = overlayPos / animDur;
        }
        animation = AlwaysStoppedAnimation<double>(t.clamp(0.0, 1.0));
        return ScaleTransition(
          scale: Tween<double>(begin: 0.0, end: 1.0).animate(animation),
          child: child,
        );

      case 'zoom_out':
        // Zoom-out towards normal size at overlay start
        if (overlayPos <= 0) {
          t = 0.0;
        } else if (overlayPos >= animDur) {
          t = 1.0;
        } else {
          t = overlayPos / animDur;
        }
        animation = AlwaysStoppedAnimation<double>(t.clamp(0.0, 1.0));
        return ScaleTransition(
          scale: Tween<double>(begin: 2.0, end: 1.0).animate(animation),
          child: child,
        );

      default:
        return child;
    }
  }
}
