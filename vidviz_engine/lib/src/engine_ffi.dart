/// FFI bindings for VidViz Native Engine
/// 
/// SADECE FFI signature - iş mantığı yok!
/// Flutter ↔ Engine iletişimi minimal primitive tipler ve JSON string ile.

library;

import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

/// Native library loader
DynamicLibrary _loadLibrary() {
  if (Platform.isAndroid) {
    return DynamicLibrary.open('libvidviz_engine.so');
  } else if (Platform.isIOS) {
    return DynamicLibrary.process();
  }
  throw UnsupportedError('Platform not supported: ${Platform.operatingSystem}');
}

DynamicLibrary? _nativeLibInstance;

DynamicLibrary _nativeLib() {
  return _nativeLibInstance ??= _loadLibrary();
}

// =============================================================================
// FFI Type Definitions
// =============================================================================

/// Engine handle (opaque pointer)
typedef EngineHandle = Pointer<Void>;

/// Progress callback: (progress: double, frame: int, totalFrames: int)
typedef NativeProgressCallback = Void Function(Double, Int32, Int32);
typedef DartProgressCallback = void Function(double, int, int);

/// Completion callback: (success: bool, outputPath: Pointer<Utf8>, errorMsg: Pointer<Utf8>)
typedef NativeCompletionCallback = Void Function(Bool, Pointer<Utf8>, Pointer<Utf8>);
typedef DartCompletionCallback = void Function(bool, Pointer<Utf8>, Pointer<Utf8>);

// =============================================================================
// Native Function Signatures
// =============================================================================

/// Initialize engine - returns handle
typedef NativeEngineInit = EngineHandle Function();
typedef DartEngineInit = EngineHandle Function();

/// Destroy engine
typedef NativeEngineDestroy = Void Function(EngineHandle);
typedef DartEngineDestroy = void Function(EngineHandle);

/// Submit export job (JSON string)
typedef NativeSubmitJob = Int32 Function(EngineHandle, Pointer<Utf8>);
typedef DartSubmitJob = int Function(EngineHandle, Pointer<Utf8>);

/// Cancel current job
typedef NativeCancelJob = Void Function(EngineHandle);
typedef DartCancelJob = void Function(EngineHandle);

/// Get engine status (returns JSON string)
typedef NativeGetStatus = Pointer<Utf8> Function(EngineHandle);
typedef DartGetStatus = Pointer<Utf8> Function(EngineHandle);

/// Set progress callback
typedef NativeSetProgressCallback = Void Function(
  EngineHandle,
  Pointer<NativeFunction<NativeProgressCallback>>,
);
typedef DartSetProgressCallback = void Function(
  EngineHandle,
  Pointer<NativeFunction<NativeProgressCallback>>,
);

/// Set completion callback
typedef NativeSetCompletionCallback = Void Function(
  EngineHandle,
  Pointer<NativeFunction<NativeCompletionCallback>>,
);
typedef DartSetCompletionCallback = void Function(
  EngineHandle,
  Pointer<NativeFunction<NativeCompletionCallback>>,
);

/// Free string allocated by native
typedef NativeFreeString = Void Function(Pointer<Utf8>);
typedef DartFreeString = void Function(Pointer<Utf8>);

/// Get last initialization error message (returns UTF8 string, caller frees)
typedef NativeGetLastInitError = Pointer<Utf8> Function();
typedef DartGetLastInitError = Pointer<Utf8> Function();

// =============================================================================
// Bound Native Functions
// =============================================================================

class VidvizEngineFFI {
  VidvizEngineFFI._();
  
  static final VidvizEngineFFI instance = VidvizEngineFFI._();

  /// Engine initialization
  late final DartEngineInit engineInit = _nativeLib()
      .lookup<NativeFunction<NativeEngineInit>>('vidviz_engine_init')
      .asFunction();

  /// Engine destruction
  late final DartEngineDestroy engineDestroy = _nativeLib()
      .lookup<NativeFunction<NativeEngineDestroy>>('vidviz_engine_destroy')
      .asFunction();

  /// Submit export job
  late final DartSubmitJob submitJob = _nativeLib()
      .lookup<NativeFunction<NativeSubmitJob>>('vidviz_submit_job')
      .asFunction();

  /// Cancel current job
  late final DartCancelJob cancelJob = _nativeLib()
      .lookup<NativeFunction<NativeCancelJob>>('vidviz_cancel_job')
      .asFunction();

  /// Get engine status
  late final DartGetStatus getStatus = _nativeLib()
      .lookup<NativeFunction<NativeGetStatus>>('vidviz_get_status')
      .asFunction();

  /// Set progress callback
  late final DartSetProgressCallback setProgressCallback = _nativeLib()
      .lookup<NativeFunction<NativeSetProgressCallback>>('vidviz_set_progress_callback')
      .asFunction();

  /// Set completion callback  
  late final DartSetCompletionCallback setCompletionCallback = _nativeLib()
      .lookup<NativeFunction<NativeSetCompletionCallback>>('vidviz_set_completion_callback')
      .asFunction();

  /// Free native string
  late final DartFreeString freeString = _nativeLib()
      .lookup<NativeFunction<NativeFreeString>>('vidviz_free_string')
      .asFunction();

  /// Get last init error
  late final DartGetLastInitError getLastInitError = _nativeLib()
      .lookup<NativeFunction<NativeGetLastInitError>>('vidviz_get_last_init_error')
      .asFunction();
}
