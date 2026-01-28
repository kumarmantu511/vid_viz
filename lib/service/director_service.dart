import 'dart:io';
import 'dart:math' as math;
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:rxdart/rxdart.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/layer_player.dart';
import 'package:vidviz/service/export/native_generator.dart';
import 'package:vidviz/service/export/native_pipeline.dart';
import 'package:vidviz/service/export/native_export.dart';
import 'package:vidviz/service/audio_analysis_service.dart';
import 'package:vidviz/service/project_service.dart';
import 'package:vidviz/service/media_probe.dart';
import 'package:vidviz/service/visualizer_service.dart';
import 'package:vidviz/service/shader_effect_service.dart';
import 'package:vidviz/service/media_overlay_service.dart';
import 'package:vidviz/service/audio_reactive_service.dart';
import 'package:vidviz/model/layer.dart';
import 'package:vidviz/model/project.dart';
import 'package:vidviz/model/generated.dart';
import 'package:vidviz/dao/project_dao.dart';
import 'package:vidviz/model/text_asset.dart';
import 'package:vidviz/model/visualizer.dart';
import 'package:vidviz/model/media_overlay.dart';
import 'package:vidviz/model/audio_reactive.dart';
import 'package:vidviz/model/video_settings.dart';

part 'package:vidviz/functions/asset_function.dart';
part 'package:vidviz/functions/playback_function.dart';
part 'package:vidviz/functions/timeline_function.dart';
part 'package:vidviz/functions/thumbnail_function.dart';
part 'package:vidviz/functions/export_function.dart';
part 'package:vidviz/functions/history_function.dart';
part 'package:vidviz/functions/project_function.dart';
part 'package:vidviz/functions/save_function.dart';
part 'package:vidviz/functions/edit_function.dart';
part 'package:vidviz/functions/add_function.dart';
part 'package:vidviz/functions/set_function.dart';


class DirectorService {
  Project? project;
  String? exportPreviewThumbnailPath;
  final logger = locator.get<Logger>();
  final projectService = locator.get<ProjectService>();
  final generator = locator.get<Generator>();
  final mediaProbe = locator.get<MediaProbe>();
  final projectDao = locator.get<ProjectDao>();
  // Cache for media durations to avoid repeated ffprobe calls
  final Map<String, int> _mediaDurationCache = {};

  List<Layer>? layers;
  List<LayerPlayer?> layerPlayers = [];

  // RepaintBoundary key to capture the video/image stage for shader sampling
  GlobalKey shaderCaptureKey = GlobalKey(debugLabel: 'shaderCapture');
  // RepaintBoundary key to capture the FULL composite (video/image + shader + text + visualizer)
  GlobalKey exportCaptureKey = GlobalKey(debugLabel: 'exportCapture');


  // Flags for concurrency
  bool isEntering = false;
  bool isExiting = false;
  bool isPlaying = false;
  bool isPreviewing = false;
  int mainLayerIndexForConcurrency = -1;
  bool isDragging = false;
  bool isSizerDragging = false;
  bool isCutting = false;
  bool isScaling = false;
  bool isAdding = false;
  bool isDeleting = false;
  bool isGenerating = false;
  // While cancelling, allow UI to operate by ignoring isGenerating when _exportCancelled is true
  bool get isOperating => (isEntering || isExiting || isPlaying || isPreviewing || isDragging || isSizerDragging || isCutting || isScaling || isAdding || isDeleting || (isGenerating && !_exportCancelled));
  bool _exportCancelled = false;
  double _pixelsPerSecondOnInitScale = 0.0;
  double _scrollOffsetOnInitScale = 0.0;
  double dxSizerDrag = 0;
  bool isSizerDraggingEnd = false;
  Timer? _previewDebounce;

  // Stream subscriptions for proper disposal
  late StreamSubscription<bool> _layersChangedSubscription;

  BehaviorSubject<bool> _filesNotExist = BehaviorSubject.seeded(false);
  Stream<bool> get filesNotExist$ => _filesNotExist.stream;
  bool get filesNotExist => _filesNotExist.value;

  ScrollController scrollController = ScrollController();

  BehaviorSubject<bool> _layersChanged = BehaviorSubject.seeded(false);
  Stream<bool> get layersChanged$ => _layersChanged.stream;
  bool get layersChanged => _layersChanged.value;

  BehaviorSubject<Selected> _selected = BehaviorSubject.seeded(Selected(-1, -1),);

  Stream<Selected> get selected$ => _selected.stream;
  Selected get selected => _selected.value;
  Asset? get assetSelected {
    if (layers == null || selected.layerIndex == -1 || selected.assetIndex == -1)
    return null;
    return layers![selected.layerIndex].assets[selected.assetIndex];
  }

  static const double DEFAULT_PIXELS_PER_SECONDS = 100.0 / 5.0;
  BehaviorSubject<double> _pixelsPerSecond = BehaviorSubject.seeded(DEFAULT_PIXELS_PER_SECONDS,);
  Stream<double> get pixelsPerSecond$ => _pixelsPerSecond.stream;
  double get pixelsPerSecond => _pixelsPerSecond.value;

  BehaviorSubject<bool> _appBar = BehaviorSubject.seeded(false);
  Stream<bool> get appBar$ => _appBar.stream;

  BehaviorSubject<int> _position = BehaviorSubject.seeded(0);
  // Throttled position stream - 16ms (~60fps) to prevent excessive rebuilds
  Stream<int>? _throttledPosition$;
  Stream<int> get position$ {
    _throttledPosition$ ??= _position.stream.throttleTime(
      const Duration(milliseconds: 16),
      trailing: true,
      leading: true,
    );
    return _throttledPosition$!;
  }
  int get position => _position.value;

  // Audio-only play setting (allow playback when no raster is present at position)
  final BehaviorSubject<bool> _audioOnlyPlay = BehaviorSubject.seeded(false);
  Stream<bool> get audioOnlyPlay$ => _audioOnlyPlay.stream;
  bool get audioOnlyPlay => _audioOnlyPlay.value;


  // Export progress (capture + encode) aggregator
  final BehaviorSubject<FFmpegStat> _exportStat = BehaviorSubject.seeded(FFmpegStat(),);
  // Blend capture and encode into a single 0..duration scale so the bar doesn't restart.
  // Dynamic weighting: UI pipeline (capture active) -> 50/50, FFmpeg-only -> 0/100
  Stream<FFmpegStat>
  get progress$ => Rx.combineLatest2<FFmpegStat, FFmpegStat, FFmpegStat>(
    _exportStat.stream,
    generator.ffmepegStat$,
    (cap, enc) {
      final dur = duration == 0 ? 1 : duration; // avoid div by zero
      final capT = (cap.time ?? 0).clamp(0, dur);
      final encT = (enc.time ?? 0).clamp(0, dur);

      final bool captureActive =
          ((cap.videoFrameNumber ?? 0) > 0) ||
          ((cap.size ?? 0) > 0) ||
          ((cap.timeElapsed ?? 0) > 0) ||
          (cap.finished == true) ||
          (cap.error == true) ||
          (cap.outputPath != null);

      final bool encodeActive =
          ((enc.videoFrameNumber ?? 0) > 0) ||
          ((enc.size ?? 0) > 0) ||
          ((enc.timeElapsed ?? 0) > 0) ||
          ((enc.time ?? 0) > 0) ||
          (enc.finished == true) ||
          (enc.error == true) ||
          (enc.outputPath != null);

      if (!encodeActive) {
        final out = FFmpegStat(
          time: capT,
          timeElapsed: cap.timeElapsed,
          size: cap.size,
          bitrate: cap.bitrate,
          speed: cap.speed,
          videoFrameNumber: cap.videoFrameNumber,
          videoQuality: cap.videoQuality,
          videoFps: cap.videoFps,
          outputPath: cap.outputPath,
          message: cap.message,
          fileNum: cap.fileNum,
          totalFiles: cap.totalFiles,
        );
        out.finished = cap.finished ?? false;
        out.error = cap.error ?? false;
        return out;
      }

      if (!captureActive) {
        final out = FFmpegStat(
          time: encT,
          timeElapsed: enc.timeElapsed,
          size: enc.size,
          bitrate: enc.bitrate,
          speed: enc.speed,
          videoFrameNumber: enc.videoFrameNumber,
          videoQuality: enc.videoQuality,
          videoFps: enc.videoFps,
          outputPath: enc.outputPath,
          message: enc.message,
          fileNum: enc.fileNum,
          totalFiles: enc.totalFiles,
        );
        out.finished = enc.finished ?? false;
        out.error = enc.error ?? false;
        return out;
      }

      final capFrac = capT / dur;
      final encFrac = encT / dur;
      final combinedFrac = math.max(capFrac, encFrac).clamp(0.0, 1.0);
      final combinedTime = (combinedFrac * dur).round();

      final out = FFmpegStat(
        time: combinedTime,
        timeElapsed: enc.timeElapsed ?? cap.timeElapsed,
        size: enc.size,
        bitrate: enc.bitrate,
        speed: enc.speed,
        videoFrameNumber: enc.videoFrameNumber,
        videoQuality: enc.videoQuality,
        videoFps: enc.videoFps,
        outputPath: enc.outputPath,
        message: enc.message ?? cap.message,
        fileNum: enc.fileNum,
        totalFiles: enc.totalFiles,
      );
      out.finished = enc.finished ?? false;
      out.error = enc.error ?? false;
      return out;
    },
  );
  void reportExportProgress(FFmpegStat stat) => _exportStat.add(stat);
  void resetExportProgress() => _exportStat.add(FFmpegStat());

  BehaviorSubject<TextAsset?> _editingTextAsset = BehaviorSubject.seeded(null);
  Stream<TextAsset?> get editingTextAsset$ => _editingTextAsset.stream;
  TextAsset? get editingTextAsset => _editingTextAsset.value;
  set editingTextAsset(TextAsset? value) {
    _editingTextAsset.add(value);
    _appBar.add(true);
  }

  BehaviorSubject<String?> _editingColor = BehaviorSubject.seeded(null);
  Stream<String?> get editingColor$ => _editingColor.stream;
  String? get editingColor => _editingColor.value;
  set editingColor(String? value) {
    _editingColor.add(value);
    _appBar.add(true);
  }

  BehaviorSubject<VideoSettings?> _editingVideoSettings = BehaviorSubject.seeded(null);
  Stream<VideoSettings?> get editingVideoSettings$ => _editingVideoSettings.stream;
  VideoSettings? get editingVideoSettings => _editingVideoSettings.value;
  set editingVideoSettings(VideoSettings? value) {
    _editingVideoSettings.add(value);
    _appBar.add(true);
  }

  /// Aggregated editor open state for all detailed editors (Text, Visualizer,
  /// Shader Effect, Media Overlay, Audio Reactive, Video Settings).
  ///
  /// This is the single source of truth that UI widgets like EditorAction
  /// should use to decide whether to show the global action buttons.
  VisualizerService get _visualizerService => locator.get<VisualizerService>();
  ShaderEffectService get _shaderEffectService => locator.get<ShaderEffectService>();
  MediaOverlayService get _mediaOverlayService => locator.get<MediaOverlayService>();
  AudioReactiveService get _audioReactiveService => locator.get<AudioReactiveService>();

  bool get isAnyEditorOpen => editingTextAsset != null || _visualizerService.editingVisualizerAsset != null || _shaderEffectService.editingShaderEffectAsset != null || _mediaOverlayService.editingMediaOverlay != null || _audioReactiveService.editingAudioReactive != null || editingVideoSettings != null;

  /// Emits whenever any of the editor states or appBar state changes, and
  /// carries the aggregated `isAnyEditorOpen` value for convenience.
  Stream<bool> get isAnyEditorOpen$ => Rx.merge([
    appBar$,
    editingTextAsset$,
    _visualizerService.editingVisualizerAsset$,
    _shaderEffectService.editingShaderEffectAsset$,
    _mediaOverlayService.editingMediaOverlay$,
    _audioReactiveService.editingAudioReactive$,
    editingVideoSettings$,
  ]).map((_) => isAnyEditorOpen).startWith(isAnyEditorOpen);

  // Undo/Redo history stack
  final List<String> _historyStack = []; // JSON snapshots of layers
  int _historyIndex = -1; // Current position in history
  bool _isUndoRedoOperation = false; // Flag to prevent recursive saves
  static const int MAX_HISTORY_SIZE = 50; // Limit stack size
  BehaviorSubject<bool> _historyChanged = BehaviorSubject.seeded(false);
  Stream<bool> get historyChanged$ => _historyChanged.stream;
  bool get canUndo => _historyIndex > 0;
  bool get canRedo => _historyIndex < _historyStack.length - 1;

  String get positionMinutes {
    int minutes = (position / 1000 / 60).floor();
    return (minutes < 10) ? '0' + minutes.toString() : minutes.toString();
  }

  String get positionSeconds {
    int minutes = (position / 1000 / 60).floor();
    double seconds = (((position / 1000 - minutes * 60) * 10).floor() / 10);
    return (seconds < 10) ? '0' + seconds.toString() : seconds.toString();
  }

  int get duration {
    if (layers == null) return 0;
    int maxDuration = 0;
    // Dynamic overlay architecture: scan all assets across all layers
    for (final l in layers!) {
      for (final a in l.assets) {
        if (a.deleted) continue;
        // Skip placeholder empty text assets so they don't extend duration
        if (a.type == AssetType.text && a.title == '') continue;
        final int end = a.begin + a.duration;
        if (end > maxDuration) maxDuration = end;
      }
    }
    return maxDuration;
  }

  DirectorService() {
    logger.i('DirectorService constructor: isOperating: $isOperating',); // Log satırı durumu
    scrollController.addListener(_listenerScrollController);
    _layersChangedSubscription = _layersChanged.listen(
      (bool onData) => _saveProject(),
    );
  }

}
