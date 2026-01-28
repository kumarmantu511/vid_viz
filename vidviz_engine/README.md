# VidViz Engine

High-performance GPU-accelerated video export engine for Flutter.

## Architecture

```
Flutter (UI) ──FFI──▶ C++ Core Engine ──GPU──▶ Video Encoder
```

### Key Principles

- **Flutter = Control Panel**: Only sends commands, receives progress
- **C++ Core = Brain**: All render logic, timeline, shaders (~90% of code)
- **Platform Bridge = Thin Layer**: Android (Vulkan/MediaCodec), iOS (Metal/AVFoundation)

## Building

### Prerequisites

**Android:**
- Android NDK r25+
- Vulkan SDK (for shader compilation)

**iOS:**
- Xcode 14+
- SPIRV-Cross (`brew install spirv-cross`)

### Shader Compilation

```bash
cd tools
python build_shaders.py --platform all
```

### Flutter Integration

```yaml
# In your pubspec.yaml
dependencies:
  vidviz_engine:
    path: ./vidviz_engine
```

## Usage

```dart
import 'package:vidviz_engine/vidviz_engine.dart';

// Initialize
final engine = EngineClient.instance;
await engine.initialize();

// Listen to progress
engine.progress$.listen((progress) {
  print('Progress: ${progress.percentage}%');
});

// Submit export job
final result = await engine.submitJob(ExportJob(
  jobId: 'export_001',
  settings: ExportSettings(
    width: 1920,
    height: 1080,
    fps: 30,
    outputPath: '/path/to/output.mp4',
  ),
  layers: [...],
  totalDuration: 60000, // 1 minute
));

// Cleanup
engine.dispose();
```

## Performance

| Metric | Before (Flutter UI) | After (Native) |
|--------|---------------------|----------------|
| 1080p 30fps | ~100ms/frame | ~5ms/frame |
| 2min video export | ~20 min | ~2 min |
| GPU utilization | ~10% | ~80% |
