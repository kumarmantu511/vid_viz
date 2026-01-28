/// VidViz Engine Client
/// 
/// Flutter tarafından engine'i kontrol eden ana sınıf.
/// Start / Stop / Job submit
library;

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'engine_ffi.dart';
import 'models/export_job.dart';
import 'models/export_progress.dart';

/// Engine state
enum EngineState {
  idle,
  initializing,
  ready,
  exporting,
  cancelled,
  error,
}

/// VidViz Native Engine Client
/// 
/// Flutter = kontrol paneli
/// Bu sınıf sadece "Ne yapılacağını" söyler (JSON Job)
class EngineClient {
  EngineClient._();
  static final EngineClient instance = EngineClient._();

  /// Native FFI bindings
  final _ffi = VidvizEngineFFI.instance;

  /// Engine handle
  Pointer<Void>? _handle;

  /// Current state
  EngineState _state = EngineState.idle;
  EngineState get state => _state;

  /// Progress stream controller
  final _progressController = StreamController<ExportProgress>.broadcast();
  Stream<ExportProgress> get progress$ => _progressController.stream;

  /// Completion completer
  Completer<ExportResult>? _completionCompleter;

  Timer? _pollTimer;
  int _lastProgressFrame = -1;
  int _lastProgressTotal = -1;

  int _lastStatusEmitMs = 0;
  String? _lastVideoDecodePath;
  String? _lastVideoDecodeError;

  String? _currentJobId;

  String? _lastInitError;
  String? get lastInitError => _lastInitError;

  /// Native callbacks (must keep references to prevent GC)
  Pointer<NativeFunction<NativeProgressCallback>>? _progressCallbackPtr;
  Pointer<NativeFunction<NativeCompletionCallback>>? _completionCallbackPtr;

  void _resetNativeHandle({String? reason}) {
    _stopPolling();

    final completer = _completionCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(
        ExportResult(
          success: false,
          outputPath: null,
          errorMessage: reason ?? 'Engine reset',
        ),
      );
    }
    _completionCompleter = null;
    _currentJobId = null;

    if (_handle != null && _handle != nullptr) {
      try {
        _ffi.engineDestroy(_handle!);
      } catch (_) {
        // ignore
      }
    }
    _handle = null;
  }

  /// Initialize engine
  Future<bool> initialize() async {
    // Self-heal: if previous run ended in error, restart the native engine.
    if (_state == EngineState.error) {
      try {
        _resetNativeHandle(reason: 'Engine recovered from error');
      } catch (_) {
        // ignore
      }
      _state = EngineState.idle;
    }

    if (_state != EngineState.idle) {
      return _state == EngineState.ready;
    }

    _state = EngineState.initializing;
    _lastInitError = null;

    try {
      _handle = _ffi.engineInit();
      
      if (_handle == null || _handle == nullptr) {
        String? initError;
        try {
          final errPtr = _ffi.getLastInitError();
          if (errPtr != nullptr) {
            final msg = errPtr.toDartString();
            _ffi.freeString(errPtr);
            initError = msg.isNotEmpty ? msg : null;
          }
        } catch (e) {
          // ignore: avoid_print
          print('🔴 Engine initialization error lookup failed: $e');
        }

        if (initError != null) {
          // ignore: avoid_print
          print('🔴 Engine initialization error: $initError');
        }

        _lastInitError = initError;
        _state = EngineState.error;
        return false;
      }

      _setupCallbacks();

      _state = EngineState.ready;
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('🔴 Engine initialization exception: $e');
      _lastInitError = e.toString();
      _state = EngineState.error;
      return false;
    }
  }

  /// Setup native callbacks
  void _setupCallbacks() {
    if (_handle == null) return;

    // Note: In production, callbacks need proper isolate handling
    // For POC, we use simple function pointers

    // Keep legacy fields referenced to avoid unused warnings.
    // Polling-based status is the authoritative mechanism.
    if (_progressCallbackPtr != null || _completionCallbackPtr != null) {
      return;
    }
  }

  /// Submit export job
  /// 
  /// [job] - Export job containing layers, shaders, settings
  /// Returns Future that completes when export finishes
  Future<ExportResult> submitJob(ExportJob job) async {
    if (_state == EngineState.idle || _state == EngineState.error) {
      final ok = await initialize();
      if (!ok) {
        throw StateError('Engine not ready (initialize failed). Current state: $_state');
      }
    }

    if (_state != EngineState.ready) {
      throw StateError('Engine not ready. Current state: $_state');
    }

    if (_handle == null) {
      throw StateError('Engine handle is null');
    }

    _state = EngineState.exporting;
    _completionCompleter = Completer<ExportResult>();
    _currentJobId = job.jobId;

    _stopPolling();
    _lastProgressFrame = -1;
    _lastProgressTotal = -1;
    _lastStatusEmitMs = 0;
    _lastVideoDecodePath = null;
    _lastVideoDecodeError = null;

    try {
      // Convert job to JSON and send to native
      final jobJson = jsonEncode(job.toJson());
      final jobPtr = jobJson.toNativeUtf8();

      final result = _ffi.submitJob(_handle!, jobPtr);
      
      // Free the string
      malloc.free(jobPtr);

      if (result != 0) {
        _state = EngineState.error;
        _completionCompleter = null;
        _currentJobId = null;
        throw Exception('Failed to submit job. Error code: $result');
      }

      _startPolling();
      return await _completionCompleter!.future;
    } catch (e) {
      _state = EngineState.error;
      _stopPolling();
      _completionCompleter = null;
      _currentJobId = null;
      rethrow;
    }
  }

  /// Cancel current export
  void cancel() {
    if (_state != EngineState.exporting) return;
    if (_handle == null) return;

    _ffi.cancelJob(_handle!);
    _state = EngineState.cancelled;

    // Deterministic: complete current job immediately as cancelled.
    // Native thread may still be shutting down, but Flutter must not receive
    // a later "success" completion for the same job.
    _stopPolling();
    final completer = _completionCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(
        ExportResult(
          success: false,
          outputPath: null,
          errorMessage: 'Cancelled',
        ),
      );
    }
    _completionCompleter = null;
    _currentJobId = null;

    // Allow subsequent exports after cancel.
    _state = EngineState.ready;
  }

  /// Get engine status (JSON)
  Map<String, dynamic>? getStatus() {
    if (_handle == null) return null;

    final statusPtr = _ffi.getStatus(_handle!);
    if (statusPtr == nullptr) return null;

    final statusJson = statusPtr.toDartString();
    _ffi.freeString(statusPtr);

    return jsonDecode(statusJson) as Map<String, dynamic>;
  }

  /// Destroy engine and cleanup
  void dispose() {
    _stopPolling();
    _currentJobId = null;
    if (_handle != null) {
      _ffi.engineDestroy(_handle!);
      _handle = null;
    }

    _progressController.close();
    _state = EngineState.idle;
  }

  void _startPolling() {
    if (_pollTimer != null) return;
    _pollTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _pollOnce(),
    );
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _pollOnce() {
    if (_handle == null) return;
    final completer = _completionCompleter;
    if (completer == null) return;

    Map<String, dynamic>? status;
    try {
      status = getStatus();
    } catch (_) {
      return;
    }
    if (status == null) return;

    final int cur = (status['currentFrame'] as num?)?.toInt() ?? 0;
    final int tot = (status['totalFrames'] as num?)?.toInt() ?? 0;
    final double p = (status['progress'] as num?)?.toDouble() ??
        ((tot > 0) ? (cur / tot) : 0.0);

    final String? videoDecodePath = status['videoDecodePath'] as String?;
    final String? videoDecodeError = status['videoDecodeError'] as String?;

    final bool? setEncoderSurfaceOk = status['setEncoderSurfaceOk'] as bool?;
    final int? presentOkCount = (status['presentOkCount'] as num?)?.toInt();
    final int? presentFailCount = (status['presentFailCount'] as num?)?.toInt();
    final int? lastEglError = (status['lastEglError'] as num?)?.toInt();
    final String? lastPresentError = status['lastPresentError'] as String?;

    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final bool frameChanged = (cur != _lastProgressFrame || tot != _lastProgressTotal);
    final bool decodeChanged = (videoDecodePath != _lastVideoDecodePath || videoDecodeError != _lastVideoDecodeError);
    final bool timeTick = (_lastStatusEmitMs == 0) || (nowMs - _lastStatusEmitMs >= 1000);

    if (frameChanged || decodeChanged || timeTick) {
      _lastProgressFrame = cur;
      _lastProgressTotal = tot;
      _lastStatusEmitMs = nowMs;
      _lastVideoDecodePath = videoDecodePath;
      _lastVideoDecodeError = videoDecodeError;
      final double clampedProgress = p < 0.0 ? 0.0 : (p > 1.0 ? 1.0 : p);
      _onProgress(
        ExportProgress(
          progress: clampedProgress,
          currentFrame: cur,
          totalFrames: tot,
          fps: (status['fps'] as num?)?.toInt(),
          elapsedMs: (status['elapsedMs'] as num?)?.toInt(),
          estimatedMs: (status['estimatedMs'] as num?)?.toInt(),
          videoDecodePath: videoDecodePath,
          videoDecodeError: videoDecodeError,
          setEncoderSurfaceOk: setEncoderSurfaceOk,
          presentOkCount: presentOkCount,
          presentFailCount: presentFailCount,
          lastEglError: lastEglError,
          lastPresentError: lastPresentError,
        ),
      );
    }

    final int nativeState = (status['state'] as num?)?.toInt() ?? -1;
    if (nativeState == 3) return;

    final String? lastJobId = status['lastJobId'] as String?;
    final String? currentJobId = _currentJobId;
    if (currentJobId != null && currentJobId.isNotEmpty) {
      if (lastJobId == null || lastJobId.isEmpty) {
        return;
      }
      if (lastJobId != currentJobId) {
        return;
      }
    }

    final bool lastSuccess = status['lastSuccess'] == true;
    final String? outPath = status['lastOutputPath'] as String?;
    final String? err = status['lastErrorMsg'] as String?;

    _stopPolling();
    _onCompletion(
      ExportResult(
        success: lastSuccess,
        outputPath: (outPath != null && outPath.isNotEmpty) ? outPath : null,
        errorMessage: (err != null && err.isNotEmpty) ? err : null,
      ),
    );
  }

  /// Handle progress from native
  void _onProgress(ExportProgress progress) {
    _progressController.add(progress);
  }

  /// Handle completion from native
  void _onCompletion(ExportResult result) {
    if (result.success) {
      _state = EngineState.ready;
    } else {
      _state = (result.errorMessage == 'Cancelled')
          ? EngineState.ready
          : EngineState.error;
    }

    _completionCompleter?.complete(result);
    _completionCompleter = null;
    _currentJobId = null;
  }
}

/// Export result
class ExportResult {
  final bool success;
  final String? outputPath;
  final String? errorMessage;

  ExportResult({
    required this.success,
    this.outputPath,
    this.errorMessage,
  });
}
