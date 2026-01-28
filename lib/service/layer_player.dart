import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'package:video_player/video_player.dart';
import 'package:vidviz/model/layer.dart';


/// Modern LayerPlayer implementation for video layer management
/// Handles video playback, asset transitions, and media source management
class LayerPlayer {
  final Layer layer;
  int currentAssetIndex = -1;

  int _currentPosition = 0;
  VideoPlayerController? _videoController;
  // Preloaded next controller to reduce transition delay for different files
  VideoPlayerController? _preloadedController;
  int _preloadedIndex = -1;
  // Suppress one onMove/position push right after preemptive boundary jump
  bool _suppressOnMoveOnce = false;
  
  // Throttle listener to ~60fps to reduce CPU usage
  int _lastListenerCallMs = 0;
  static const int _listenerThrottleMs = 16; // ~60fps

  // Callback functions for position updates and playback events
  Function(int position)? _onMove;
  Function()? _onJump;
  Function()? _onEnd;

  // Stream controllers for reactive updates
  final StreamController<bool> _isPlayingController = StreamController<bool>.broadcast();
  final StreamController<int> _positionController = StreamController<int>.broadcast();

  // Public streams
  Stream<bool> get isPlaying$ => _isPlayingController.stream;
  Stream<int> get position$ => _positionController.stream;

  // Getters
  VideoPlayerController? get videoController => _videoController;
  bool get isInitialized => _videoController?.value.isInitialized ?? false;
  bool get isPlaying => _videoController?.value.isPlaying ?? false;
  int get currentPosition => _currentPosition;

  LayerPlayer(this.layer);

  double _assetSpeed(Asset a) {
    if (a.type != AssetType.video) return 1.0;
    final s = a.playbackSpeed;
    return (s > 0) ? s : 1.0;
  }

  int _assetEndFileTimeMs(Asset a) {
    final spd = _assetSpeed(a);
    return a.cutFrom + (a.duration * spd).round();
  }

  int _timelineToFileSeekMs(Asset a, int timelinePositionMs) {
    final int offsetInAsset = (timelinePositionMs - a.begin).clamp(0, a.duration);
    final spd = _assetSpeed(a);
    return a.cutFrom + (offsetInAsset * spd).round();
  }

  void _disposeControllerLater(VideoPlayerController? controller) {
    if (controller == null) return;
    Future.delayed(const Duration(milliseconds: 250), () async {
      try {
        await controller.dispose();
      } catch (_) {}
    });
  }

  /// Initialize the layer player with the first available asset
  Future<void> initialize() async {
    try {
      if (layer.assets.isEmpty) {
        print('🔍 [LayerPlayer] No assets to initialize');
        return;
      }

      // Find first non-deleted asset
      final firstAsset = _findFirstValidAsset();
      if (firstAsset != null) {
        await _initializeWithAsset(firstAsset.index, firstAsset.asset);
        print(
          '✅ [LayerPlayer] Initialized with asset: ${firstAsset.asset.title}',
        );
      } else {
        print('⚠️ [LayerPlayer] No valid assets found for initialization');
      }
    } catch (e, stackTrace) {
      print('🚨 [LayerPlayer] Initialize error: $e');
      print(stackTrace);
    }
  }

  /// Find the first valid (non-deleted) asset
  ({int index, Asset asset})? _findFirstValidAsset() {
    for (int i = 0; i < layer.assets.length; i++) {
      final asset = layer.assets[i];
      if (!asset.deleted) {
        return (index: i, asset: asset);
      }
    }
    return null;
  }

  /// Preview video at specific position without sound
  Future<void> preview(int position) async {
    try {
      final prevController = _videoController;
      final assetInfo = _getAssetAtPosition(position);
      if (assetInfo == null) {
        print('🔍 [LayerPlayer] No asset found at position $position');
        return;
      }

      // If we have a preloaded controller for this exact asset, swap it in
      if (_preloadedController != null && _preloadedIndex == assetInfo.index) {
        final old = _videoController;
        old?.removeListener(_videoListener);
        _videoController = _preloadedController;
        _preloadedController = null;
        _preloadedIndex = -1;
        currentAssetIndex = assetInfo.index;
        _disposeControllerLater(old);
        // Preload next for subsequent scrubs
        await _preloadNextIfNeeded();
      } else {
        await _prepareAssetForPlayback(assetInfo.index, assetInfo.asset);
      }
      if (!isInitialized) return;
      final Asset a = assetInfo.asset;
      int fileSeek = _timelineToFileSeekMs(a, position);
      // Clamp to media duration
      try {
        final int fileDur = _videoController!.value.duration.inMilliseconds;
        fileSeek = fileSeek.clamp(0, fileDur);
      } catch (_) {}
      await _videoController?.setVolume(0.0);
      try {
        if (a.type == AssetType.video) {
          await _videoController?.setPlaybackSpeed(_assetSpeed(a));
        }
      } catch (_) {}
      await _seekToPosition(fileSeek);

      // Ensure preview is always paused. Some platforms keep the last rendered frame
      // until the next decode tick; pausing here prevents runaway playback.
      try {
        await _videoController?.pause();
      } catch (_) {}

      // If we switched underlying controller (e.g., scrubbing across different files),
      // force one decode tick so the displayed frame matches the seek position.
      final bool switchedController = prevController != null && prevController != _videoController;
      if (switchedController) {
        try {
          await _videoController?.play();
          await Future.delayed(const Duration(milliseconds: 16));
          await _videoController?.pause();
        } catch (_) {}
      }
      // Prime a frame to avoid black screen during scrubbing
      ///DAHA ÇOK TAKILAM SEBEBİ OLUYORDU
      ///try {
      ///  await _videoController?.play();
      ///  await Future.delayed(Duration(milliseconds: 16)); // ~1 frame
      ///  await _videoController?.pause();
      ///} catch (_) {}

      print('👁️ [LayerPlayer] Preview at position $position (fileSeek: $fileSeek)',);
    } catch (e) {
      print('🚨 [LayerPlayer] Preview error: $e');
    }
  }

  /// Start playback at specific position with callbacks
  Future<void> play(
    int position, {
    Function(int position)? onMove,
    Function()? onJump,
    Function()? onEnd,
  }) async {
    try {
      _onMove = onMove;
      _onJump = onJump;
      _onEnd = onEnd;

      final assetInfo = _getAssetAtPosition(position);
      if (assetInfo == null) {
        print('🔍 [LayerPlayer] No asset found at position $position');
        return;
      }

      await _prepareAssetForPlayback(assetInfo.index, assetInfo.asset);
      if (!isInitialized) return;
      // Asynchronously ensure next asset is preloaded for cross-file seamless transition
      scheduleMicrotask(() => _preloadNextIfNeeded());

      final Asset a = assetInfo.asset;
      final double spd = _assetSpeed(a);
      int fileSeek = _timelineToFileSeekMs(a, position);
      try {
        final int fileDur = _videoController!.value.duration.inMilliseconds;
        fileSeek = fileSeek.clamp(0, fileDur);
      } catch (_) {}
      // Initialize current timeline position for fade/effective volume calculations
      _currentPosition = position;
      await _videoController?.setVolume(_effectiveVolume());
      await _seekToPosition(fileSeek);
      // Apply playback speed for runtime (video only)
      try {
        if (a.type == AssetType.video)
          await _videoController?.setPlaybackSpeed(spd);
      } catch (_) {}

      // Idempotent listener attach (prevents duplicate listeners on repeated play calls)
      _videoController?.removeListener(_videoListener);
      _videoController?.addListener(_videoListener);
      await _videoController?.play();
      _isPlayingController.add(true);

      print('▶️ [LayerPlayer] Playing from position $position (fileSeek: $fileSeek)',);
    } catch (e) {
      print('🚨 [LayerPlayer] Play error: $e');
    }
  }

  /// Stop playback and clean up listeners
  Future<void> stop() async {
    try {
      _videoController?.removeListener(_videoListener);

      final ctrl = _videoController;
      if (ctrl == null) {
        _isPlayingController.add(false);
        return;
      }

      try {
        if (ctrl.value.isInitialized) {
          await ctrl.pause();
        }
      } catch (_) {}

      _isPlayingController.add(false);
      if (ctrl.value.isInitialized) {
        print("⏸️ [LayerPlayer] Playback stopped");
      }
    } catch (e) {
      print('🚨 [LayerPlayer] Stop error: $e');
    }
  }

  /// Get asset information at specific position
  ({int index, Asset asset})? _getAssetAtPosition(int position) {
    for (int i = 0; i < layer.assets.length; i++) {
      final asset = layer.assets[i];
      if (asset.deleted) continue;
      final assetEnd = asset.begin + asset.duration;
      if (position >= asset.begin && position < assetEnd) {
        return (index: i, asset: asset);
      }
    }
    return null;
  }

  /// Prepare asset for playback by initializing controller if needed
  Future<void> _prepareAssetForPlayback(int assetIndex, Asset asset) async {
    // If controller not ready, initialize
    if (!isInitialized || currentAssetIndex == -1) {
      await _initializeWithAsset(assetIndex, asset);
      return;
    }
    // If switching to a different asset index
    if (currentAssetIndex != assetIndex) {
      // If same source file and media type, keep controller and just update index
      final cur = layer.assets[currentAssetIndex];
      final sameFile = (cur.type == asset.type) && (cur.type == AssetType.video || cur.type == AssetType.audio) && (cur.srcPath == asset.srcPath);
      if (sameFile) {
        currentAssetIndex = assetIndex;
        return;
      }
      // Otherwise initialize and swap controller without dropping to black
      await _initializeAndSwapController(assetIndex, asset);
    }
  }

  /// Initialize a new controller for target asset and swap it in without stopping first
  Future<void> _initializeAndSwapController(int assetIndex, Asset asset) async {
    final old = _videoController;
    try {
      final newCtrl = await _createControllerForAsset(asset);
      if (newCtrl != null) {
        try {
          await newCtrl.initialize();
        } catch (e) {
          try {
            await newCtrl.dispose();
          } catch (_) {}
          final fallback = VideoPlayerController.asset('assets/blank-1h.mp4');
          try {
            await fallback.initialize();
          } catch (_) {}
          old?.removeListener(_videoListener);
          _videoController = fallback;
          currentAssetIndex = assetIndex;
          await _videoController?.setVolume(_effectiveVolume());
          await _preloadNextIfNeeded();
          return;
        }
        await newCtrl.setLooping(false);
        // swap
        old?.removeListener(_videoListener);
        _videoController = newCtrl;
        currentAssetIndex = assetIndex;
        await _videoController?.setVolume(_effectiveVolume());
        // Do NOT add listener here; callers (play/transition) manage it
        // Preload upcoming
        await _preloadNextIfNeeded();
      } else {
        // Non-media types
        await _disposeController();
        currentAssetIndex = assetIndex;
      }
    } catch (e) {
      // Fallback to standard path
      await _initializeWithAsset(assetIndex, asset);
    } finally {
      if (old != null && old != _videoController) {
        _disposeControllerLater(old);
      }
    }
  }

  /// Seek to position with error handling
  Future<void> _seekToPosition(int milliseconds) async {
    if (!isInitialized) return;

    final duration = _videoController!.value.duration;
    final seekPosition = Duration(
      milliseconds: milliseconds.clamp(0, duration.inMilliseconds),
    );

    await _videoController?.seekTo(seekPosition);
    // Do not emit position here. This value is FILE time, not absolute timeline time.
    // Absolute timeline updates are handled by _videoListener (during playback)
    // and by higher-level callers (e.g., DirectorService.previewAt) when scrubbing.
  }

  /// Initialize video controller with specific asset
  Future<void> _initializeWithAsset(int assetIndex, Asset asset) async {
    if (assetIndex < 0 || assetIndex >= layer.assets.length) {
      print('🚨 [LayerPlayer] Invalid asset index: $assetIndex');
      return;
    }

    try {
      // Dispose previous controller
      await _disposeController();

      // Create appropriate controller based on asset type and state
      _videoController = await _createControllerForAsset(asset);

      if (_videoController != null) {
        try {
          await _videoController!.initialize();
        } catch (e) {
          print('🚨 [LayerPlayer] Failed to initialize controller: $e');
          await _disposeController();
          _videoController = VideoPlayerController.asset('assets/blank-1h.mp4');
          try {
            await _videoController!.initialize();
          } catch (_) {}
        }
        await _videoController!.setLooping(false);

        currentAssetIndex = assetIndex;
        print('✅ [LayerPlayer] Controller initialized for: ${asset.title}');
        // Preload upcoming media if needed
        await _preloadNextIfNeeded();
      }
    } catch (e) {
      print('🚨 [LayerPlayer] Failed to initialize controller: $e');
      await _disposeController();
    }
  }

  /// Create video controller based on asset type
  Future<VideoPlayerController?> _createControllerForAsset(Asset asset) async {
    try {
      if (asset.deleted) {
        return VideoPlayerController.asset('assets/blank-1h.mp4');
      }

      switch (asset.type) {
        case AssetType.video:
        case AssetType.audio:
          final file = File(asset.srcPath);
          if (await file.exists()) {
            return VideoPlayerController.file(
              file,
              videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
            );
          } else {
            print('⚠️ [LayerPlayer] File not found: ${asset.srcPath}');
            return VideoPlayerController.asset('assets/blank-1h.mp4');
          }
        case AssetType.image:
          // Use blank video for images (Ken Burns effect handled in UI)
          return VideoPlayerController.asset('assets/blank-1h.mp4');
        case AssetType.text:
          // Text assets don't need video controller
          return null;
        case AssetType.visualizer:
          // Visualizer assets don't need video controller
          return null;
        case AssetType.shader:
          // Shader effect assets don't need video controller
          return null;
      }
    } catch (e) {
      print('🚨 [LayerPlayer] Error creating controller: $e');
      return VideoPlayerController.asset('assets/blank-1h.mp4');
    }
  }

  /// Safely dispose video controller
  Future<void> _disposeController() async {
    if (_videoController != null) {
      try {
        _videoController!.removeListener(_videoListener);
        await _videoController!.dispose();
        print('🧹 [LayerPlayer] Controller disposed');
      } catch (e) {
        print('⚠️ [LayerPlayer] Error disposing controller: $e');
      } finally {
        _videoController = null;
        currentAssetIndex = -1;
      }
    }
  }

  /// Preload next media controller for seamless transition if next asset is a different file
  Future<void> _preloadNextIfNeeded() async {
    try {
      final nextIndex = _findNextValidAsset(currentAssetIndex + 1);
      if (nextIndex == -1) {
        await _disposePreloaded();
        return;
      }
      if (_preloadedIndex == nextIndex && _preloadedController != null)
        return; // already prepared
      final nextAsset = layer.assets[nextIndex];
      // If same file as current, seamless path uses same controller -> no preload
      if (currentAssetIndex >= 0 && currentAssetIndex < layer.assets.length) {
        final curAsset = layer.assets[currentAssetIndex];
        if (curAsset.srcPath == nextAsset.srcPath &&
            curAsset.type == nextAsset.type) {
          // Same file: preload only if non-contiguous to avoid seek stutter
          final int curEnd = _assetEndFileTimeMs(curAsset);
          final bool contiguous = (nextAsset.cutFrom - curEnd).abs() <= 33;
          if (contiguous) {
            await _disposePreloaded();
            return;
          }
        }
      }
      await _disposePreloaded();
      final ctrl = await _createControllerForAsset(nextAsset);
      if (ctrl != null) {
        try {
          await ctrl.initialize();
        } catch (e) {
          try {
            await ctrl.dispose();
          } catch (_) {}
          return;
        }
        await ctrl.setLooping(false);
        await ctrl.seekTo(Duration(milliseconds: nextAsset.cutFrom));
        try {
          if (nextAsset.type == AssetType.video) {
            await ctrl.setPlaybackSpeed(_assetSpeed(nextAsset));
          }
        } catch (_) {}
        await ctrl.setVolume(_effectiveVolume());
        _preloadedController = ctrl;
        _preloadedIndex = nextIndex;
        print('🧰 [LayerPlayer] Preloaded next media at index $nextIndex');
      }
    } catch (e) {
      print('⚠️ [LayerPlayer] Preload failed: $e');
      await _disposePreloaded();
    }
  }

  Future<void> _disposePreloaded() async {
    if (_preloadedController != null) {
      try {
        await _preloadedController!.dispose();
      } catch (_) {}
      _preloadedController = null;
      _preloadedIndex = -1;
    }
  }

  /// Get asset index by position (legacy method for compatibility)
  int getAssetByPosition(int? position) {
    if (position == null) return -1;

    final assetInfo = _getAssetAtPosition(position);
    return assetInfo?.index ?? -1;
  }

  /// Video position listener for playback monitoring (throttled to ~60fps)
  void _videoListener() async {
    if (!isInitialized || currentAssetIndex == -1) return;
    
    // Throttle to ~60fps to reduce CPU usage
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastListenerCallMs < _listenerThrottleMs) return;
    _lastListenerCallMs = now;

    try {
      final currentAsset = layer.assets[currentAssetIndex];
      final int videoPosition = _videoController!.value.position.inMilliseconds; // file position

      // Calculate absolute position in timeline using speed mapping
      final double spd = (currentAsset.type == AssetType.video && currentAsset.playbackSpeed > 0) ? currentAsset.playbackSpeed : 1.0;
      final int relFromCutFile = (videoPosition - currentAsset.cutFrom).clamp(0, (currentAsset.duration * spd).round(),);
      final int relFromCutTimeline = (relFromCutFile / spd).round().clamp(0, currentAsset.duration,);

      _currentPosition = currentAsset.begin + relFromCutTimeline;
      // Push position updates unless we just performed a preemptive jump
      if (_suppressOnMoveOnce) {
        _suppressOnMoveOnce = false;
      } else {
        _positionController.add(_currentPosition);
        _onMove?.call(_currentPosition);
      }

      // Check if current asset has ended at cutFrom + duration*speed (tight tolerance)
      int assetEndTime = currentAsset.cutFrom + (currentAsset.duration * spd).round();
      try {
        final int fileDur = _videoController!.value.duration.inMilliseconds;
        assetEndTime = math.min(assetEndTime, fileDur);
      } catch (_) {}
      final int tolerance = 33; // ~2 frames at 60fps
      // Auxiliary audio layers (driven by DirectorService timeline) should NOT
      // perform internal seamless same-file jumps or auto-chain segments.
      // We detect them as audio layers without an onMove callback.
      final bool isAuxAudioLayer = layer.type == 'audio' && (_onMove == null);

      // Preemptive seamless jump a few ms before boundary for same-file segments.
      // Disabled for auxiliary audio layers so that they respect timeline gaps
      // and are driven explicitly from DirectorService.play().
      if (!isAuxAudioLayer) {
        final int earlyThreshold = 33; // ~2 frames
        final int toEnd = assetEndTime - videoPosition;
        if (toEnd <= earlyThreshold) {
          final nextIndex = _findNextValidAsset(currentAssetIndex + 1);
          if (nextIndex != -1) {
            final nextAsset = layer.assets[nextIndex];
            final bool sameFile =
                (nextAsset.type == currentAsset.type) &&
                (nextAsset.type == AssetType.video ||
                 nextAsset.type == AssetType.audio) &&
                (nextAsset.srcPath == currentAsset.srcPath);
            if (sameFile) {
              currentAssetIndex = nextIndex;
              // If we have preloaded controller for this asset, swap now to avoid seek stutter
              if (_preloadedController != null &&
                  _preloadedIndex == nextIndex) {
                final old = _videoController;
                old?.removeListener(_videoListener);
                _videoController = _preloadedController;
                _preloadedController = null;
                _preloadedIndex = -1;
                // Attach listener and ensure playback continues seamlessly
                _videoController?.addListener(_videoListener);
                // Update speed for next asset
                try {
                  await _videoController?.setPlaybackSpeed(
                    nextAsset.playbackSpeed > 0 ? nextAsset.playbackSpeed : 1.0,
                  );
                } catch (_) {}
                if (!(_videoController?.value.isPlaying ?? false)) {
                  await _videoController?.play();
                  _isPlayingController.add(true);
                }
                _onJump?.call();
                _disposeControllerLater(old);
                // Preload following asset
                await _preloadNextIfNeeded();
              } else {
                // If contiguous, let playback continue without seeking to avoid hitch
                final bool contiguous = (nextAsset.cutFrom - assetEndTime).abs() <= 33;
                if (!contiguous) {
                  // Non-blocking seek; keep playback continuous
                  _videoController!.seekTo(
                    Duration(milliseconds: nextAsset.cutFrom),
                  );
                }
              }
              // Reset timeline position to the beginning of the new asset for fades
              _currentPosition = nextAsset.begin;
              // Apply per-asset effective volume for the new segment
              try {
                await _videoController?.setVolume(_effectiveVolume());
              } catch (_) {}
              _suppressOnMoveOnce = true; // skip one UI update to avoid visible hitch
              return; // Skip normal transition path
            }
          }
        }
      }
      final bool hasAssetEnded = videoPosition >= assetEndTime - tolerance;

      if (hasAssetEnded) {
        // Run transition asynchronously to avoid blocking listener
        scheduleMicrotask(() async {
          if (isAuxAudioLayer) {
            // For auxiliary audio layers, simply stop at the end of the
            // current segment and let DirectorService drive subsequent
            // playback based on global timeline position.
            await stop();
            currentAssetIndex = -1;
          } else {
            await _handleAssetTransition();
          }
        });
      }
    } catch (e) {
      print('🚨 [LayerPlayer] Video listener error: $e');
    }
  }

  /// Handle transition between assets
  Future<void> _handleAssetTransition() async {
    final nextAssetIndex = _findNextValidAsset(currentAssetIndex + 1);
    if (nextAssetIndex == -1) {
      // No more assets, end playback
      currentAssetIndex = -1;
      _isPlayingController.add(false);
      _onJump?.call();
      _onEnd?.call();
      print('🏁 [LayerPlayer] Playback completed');
      return;
    }

    final currentAsset = layer.assets[currentAssetIndex];
    final nextAsset = layer.assets[nextAssetIndex];

    // Seamless path: same source file -> prefer preloaded swap, else seek/jump
    if ((currentAsset.type == AssetType.video ||
         currentAsset.type == AssetType.audio) &&
        (nextAsset.type == currentAsset.type) &&
        currentAsset.srcPath == nextAsset.srcPath &&
        isInitialized &&
        _videoController != null) {
      // If we have preloaded controller for next asset, swap to it
      if (_preloadedController != null && _preloadedIndex == nextAssetIndex) {
        final old = _videoController;
        old?.removeListener(_videoListener);
        _videoController = _preloadedController;
        _preloadedController = null;
        _preloadedIndex = -1;
        currentAssetIndex = nextAssetIndex;
        _videoController?.addListener(_videoListener);
        // Ensure volume matches new asset gain
        // Reset timeline position to the beginning of the new asset for fades
        _currentPosition = nextAsset.begin;
        try {
          await _videoController?.setVolume(_effectiveVolume());
        } catch (_) {}
        if (!(_videoController?.value.isPlaying ?? false)) {
          await _videoController?.play();
          _isPlayingController.add(true);
        }
        _onJump?.call();
        _disposeControllerLater(old);
        print('⏭️ [LayerPlayer] Seamless swap to preloaded same-file segment');
        // Preload upcoming after swap
        await _preloadNextIfNeeded();
        return;
      }
      // Otherwise seek within same controller
      currentAssetIndex = nextAssetIndex;
      final double curSpd = (currentAsset.type == AssetType.video && currentAsset.playbackSpeed > 0)? currentAsset.playbackSpeed: 1.0;
      final int assetEndTime = currentAsset.cutFrom + (currentAsset.duration * curSpd).round();
      final bool contiguous = (nextAsset.cutFrom - assetEndTime).abs() <= 33;
      if (!contiguous) {
        _videoController!.seekTo(Duration(milliseconds: nextAsset.cutFrom));
      }
      // Ensure playback speed matches next segment
      try {
        if (nextAsset.type == AssetType.video) {
          final double spd = nextAsset.playbackSpeed > 0
              ? nextAsset.playbackSpeed
              : 1.0;
          await _videoController?.setPlaybackSpeed(spd);
        }
      } catch (_) {}
      // Ensure volume matches new asset gain
      try {
        // Reset timeline position to the beginning of the new asset for fades
        _currentPosition = nextAsset.begin;
        await _videoController?.setVolume(_effectiveVolume());
      } catch (_) {}
      // Ensure playing only if paused
      if (!(_videoController?.value.isPlaying ?? false)) {
        await _videoController!.play();
        _isPlayingController.add(true);
      }
      _onJump?.call();
      print(
        '⏭️ [LayerPlayer] Seamless jump within same file to cutFrom=${nextAsset.cutFrom}',
      );
      return;
    } else {
      final old = _videoController;
      old?.removeListener(_videoListener);

      if (_preloadedController != null && _preloadedIndex == nextAssetIndex) {
        _videoController = _preloadedController;
        _preloadedController = null;
        _preloadedIndex = -1;
        currentAssetIndex = nextAssetIndex;
      } else {
        final newCtrl = await _createControllerForAsset(nextAsset);
        if (newCtrl == null) {
          currentAssetIndex = -1;
          _isPlayingController.add(false);
          _onEnd?.call();
          return;
        }
        try {
          await newCtrl.initialize();
          await newCtrl.setLooping(false);
        } catch (_) {}
        _videoController = newCtrl;
        currentAssetIndex = nextAssetIndex;
      }

      if (!isInitialized) return;
      _currentPosition = nextAsset.begin;
      try {
        await _videoController?.setVolume(_effectiveVolume());
      } catch (_) {}
      try {
        await _seekToPosition(nextAsset.cutFrom);
      } catch (_) {}
      try {
        if (nextAsset.type == AssetType.video) {
          await _videoController?.setPlaybackSpeed(_assetSpeed(nextAsset));
        }
      } catch (_) {}

      _videoController?.removeListener(_videoListener);
      _videoController?.addListener(_videoListener);
      try {
        await _videoController?.play();
      } catch (_) {}
      _isPlayingController.add(true);
      _onJump?.call();
      _disposeControllerLater(old);
      await _preloadNextIfNeeded();
      print('⏭️ [LayerPlayer] Switched to next file: ${nextAsset.title}');
    }
  }

  /// Find next valid (non-deleted) asset starting from given index
  int _findNextValidAsset(int startIndex) {
    for (int i = startIndex; i < layer.assets.length; i++) {
      final asset = layer.assets[i];
      // Consider video, image and audio for timeline sequencing
      if (!asset.deleted &&
          (asset.type == AssetType.video ||
           asset.type == AssetType.image ||
           asset.type == AssetType.audio)) {
        return i;
      }
    }
    return -1;
  }

  /// Add or update media source for specific asset
  Future<Duration?> addMediaSource(int index, Asset asset) async {
    try {
      print("➕ [LayerPlayer] Adding media source for asset $index: ${asset.title}",);

      await stop();
      await _initializeWithAsset(index, asset);

      if (isInitialized) {
        final duration = _videoController!.value.duration;
        print('ℹ️ [LayerPlayer] Media source added - Duration: $duration');
        return duration;
      }

      return null;
    } catch (e, stackTrace) {
      print('🚨 [LayerPlayer] Error adding media source: $e');
      print(stackTrace);
      return null;
    }
  }

  /// Remove media source at specific index
  Future<void> removeMediaSource(int index) async {
    try {
      print("➖ [LayerPlayer] Removing media source at index $index");

      // Keep preloaded controller index consistent with list mutations
      if (_preloadedIndex == index) {
        await _disposePreloaded();
      } else if (_preloadedIndex > index) {
        _preloadedIndex--;
      }

      // If this was the currently playing asset, stop and reset
      if (index == currentAssetIndex) {
        await stop();
        await _disposeController();
      } else if (index < currentAssetIndex) {
        // Adjust current asset index if an earlier asset was removed
        currentAssetIndex--;
      }

      print('✅ [LayerPlayer] Media source removed');
    } catch (e) {
      print('🚨 [LayerPlayer] Error removing media source: $e');
    }
  }

  /// Notify player that an asset was inserted into [layer.assets] at [index].
  /// This keeps internal indices (current/preloaded) consistent.
  Future<void> onAssetInserted(int index) async {
    try {
      if (index <= currentAssetIndex) {
        currentAssetIndex++;
      }
      if (_preloadedIndex >= index) {
        await _disposePreloaded();
      }
    } catch (_) {}
  }

  /// Dispose all resources and clean up
  Future<void> dispose() async {
    try {
      await stop();
      await _disposeController();
      await _disposePreloaded();

      // Close stream controllers
      await _isPlayingController.close();
      await _positionController.close();

      print('🧹 [LayerPlayer] Disposed successfully');
    } catch (e) {
      print('🚨 [LayerPlayer] Error during dispose: $e');
    }
  }

  /// Update runtime volume for this layer's active and preloaded controllers
  Future<void> setVolume(double volume) async {
    final double v = volume.clamp(0.0, 1.0);
    try {
      if (_videoController != null) {
        await _videoController!.setVolume(v);
      }
      if (_preloadedController != null) {
        await _preloadedController!.setVolume(v);
      }
    } catch (e) {
      print('⚠️ [LayerPlayer] setVolume error: $e');
    }
  }

  /// Compute effective volume for playback respecting mute and useVideoAudio
  double _effectiveVolume() {
    // Mute supersedes everything
    if (layer.mute == true) return 0.0;
    // If this is a raster layer and user disabled embedded video audio, silence it
    if (layer.type == 'raster' && (layer.useVideoAudio == false)) return 0.0;
    double base = layer.volume.clamp(0.0, 1.0);
    double assetGain = 1.0;
    double fadeGain = 1.0;
    try {
      if (currentAssetIndex >= 0 && currentAssetIndex < layer.assets.length) {
        final a = layer.assets[currentAssetIndex];
        final v = a.data?['volume'];
        if (v is num) {
          assetGain = v.clamp(0.0, 1.0).toDouble();
        }
        // Optional per-asset fade in/out based on timeline position within the asset
        final fi = a.data?['fadeInMs'];
        final fo = a.data?['fadeOutMs'];
        if ((fi is num && fi > 0) || (fo is num && fo > 0)) {
          final int dur = a.duration;
          if (dur > 0) {
            final int localPos = (_currentPosition - a.begin).clamp(0, dur);
            double fIn = 1.0;
            double fOut = 1.0;
            if (fi is num && fi > 0) {
              final double dIn = fi.toDouble().clamp(0.0, dur.toDouble());
              if (dIn > 0) {
                fIn = (localPos / dIn).clamp(0.0, 1.0);
              }
            }
            if (fo is num && fo > 0) {
              final double dOut = fo.toDouble().clamp(0.0, dur.toDouble());
              if (dOut > 0) {
                final double fromEnd = (dur - localPos).toDouble();
                fOut = (fromEnd / dOut).clamp(0.0, 1.0);
              }
            }
            fadeGain = (fIn * fOut).clamp(0.0, 1.0);
          }
        }
      }
    } catch (_) {}
    final num combined = (base * assetGain * fadeGain).clamp(0.0, 1.0);
    return combined.toDouble();
  }
}
