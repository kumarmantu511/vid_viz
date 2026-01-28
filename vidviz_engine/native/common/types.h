/**
 * VidViz Engine - Common Types
 * 
 * Platform bağımsız tip tanımları.
 * Core kodları asla Vulkan/Metal kütüphanelerini include etmez.
 */

#pragma once

#include <cstdint>
#include <string>
#include <vector>
#include <memory>
#include <functional>

// =============================================================================
// Export Macro (FFI visibility)
// =============================================================================

#if defined(VIDVIZ_BUILDING_LIBRARY)
    #if defined(_WIN32)
        #define VIDVIZ_API __declspec(dllexport)
    #else
        #define VIDVIZ_API __attribute__((visibility("default"))) __attribute__((used))
    #endif
#else
    #if defined(_WIN32)
        #define VIDVIZ_API __declspec(dllimport)
    #else
        #define VIDVIZ_API
    #endif
#endif

// Extern C for FFI
#ifdef __cplusplus
    #define VIDVIZ_EXTERN_C extern "C"
#else
    #define VIDVIZ_EXTERN_C
#endif

// =============================================================================
// Basic Types
// =============================================================================

namespace vidviz {

/// Time in milliseconds
using TimeMs = int64_t;

/// Frame number
using FrameNum = int32_t;

/// Result codes
enum class Result : int32_t {
    Success = 0,
    ErrorInvalidHandle = -1,
    ErrorInvalidJob = -2,
    ErrorEngineBusy = -3,
    ErrorEncodeFailed = -4,
    ErrorShaderCompile = -5,
    ErrorFileNotFound = -6,
    ErrorOutOfMemory = -7,
    ErrorCancelled = -8,
    ErrorUnknown = -99,
};

/// Engine state
enum class EngineState : int32_t {
    Idle = 0,
    Initializing = 1,
    Ready = 2,
    Exporting = 3,
    Paused = 4,
    Cancelling = 5,
    Error = 6,
};

// =============================================================================
// Video Settings
// =============================================================================

struct VideoSettings {
    int32_t width = 1920;
    int32_t height = 1080;
    int32_t fps = 30;
    int32_t quality = 1;  // 0=low, 1=medium, 2=high
    std::string aspectRatio = "16:9";
    std::string cropMode = "fit";
    int32_t rotation = 0;
    bool flipHorizontal = false;
    bool flipVertical = false;
    int64_t backgroundColor = 0xFF000000;
    std::string outputFormat = "mp4";
    std::string outputPath;

    // Optional UI preview metrics (Flutter) for parity.
    // Used to convert UI logical-pixel values (e.g., progress strokeWidth) to export pixel space.
    // 0 means "unknown/not provided".
    float uiPlayerWidth = 0.0f;
    float uiPlayerHeight = 0.0f;
    float uiDevicePixelRatio = 0.0f;
};

// =============================================================================
// Timeline Types
// =============================================================================

/// Asset type
enum class AssetType : int32_t {
    Video = 0,
    Image = 1,
    Audio = 2,
    Text = 3,
    Shader = 4,
    Visualizer = 5,
};

/// Layer type  
enum class LayerType : int32_t {
    Raster = 0,      // Video/Image
    Audio = 1,       // Audio track
    Text = 2,        // Text overlay
    Shader = 3,      // GLSL effect
    Visualizer = 4,  // Audio visualizer
};

/// Asset in timeline
struct Asset {
    std::string id;
    AssetType type;
    std::string srcPath;
    TimeMs begin = 0;       // Start time on timeline
    TimeMs duration = 0;    // Duration on timeline
    TimeMs cutFrom = 0;     // Trim start in source
    float playbackSpeed = 1.0f;
    std::string dataJson;   // Type-specific data as JSON
};

/// Layer in timeline
struct Layer {
    std::string id;
    LayerType type;
    std::string name;
    int32_t zIndex = 0;
    float volume = 1.0f;
    bool mute = false;
    bool useVideoAudio = false;
    std::vector<Asset> assets;
};

// =============================================================================
// Shader Types
// =============================================================================

struct ShaderUniform {
    std::string name;
    enum class Type { Float, Vec2, Vec3, Vec4, Int, Sampler2D } type;
    std::vector<float> values;
};

struct ShaderProgram {
    std::string id;
    std::string name;
    std::string vertexSource;
    std::string fragmentSource;
    std::vector<ShaderUniform> uniforms;
};

// =============================================================================
// FFT Data (for visualizers)
// =============================================================================

struct FFTData {
    std::string audioPath;
    int32_t sampleRate = 44100;
    int32_t hopSize = 512;
    std::vector<std::vector<float>> frames;  // [frame][band] = amplitude
};

// =============================================================================
// Export Job
// =============================================================================

struct ExportJob {
    std::string jobId;
    VideoSettings settings;
    std::vector<Layer> layers;
    std::vector<ShaderProgram> shaders;
    std::vector<FFTData> fftData;
    TimeMs totalDuration = 0;
};

// =============================================================================
// Callbacks
// =============================================================================

/// Progress callback: (progress: 0.0-1.0, frame, totalFrames)
using ProgressCallback = std::function<void(float, int32_t, int32_t)>;

/// Completion callback: (success, outputPath, errorMsg)
using CompletionCallback = std::function<void(bool, const std::string&, const std::string&)>;

// =============================================================================
// Platform Abstraction
// =============================================================================

/// Opaque native surface handle
struct NativeSurface {
    void* handle = nullptr;
    int32_t width = 0;
    int32_t height = 0;
};

/// Opaque GPU texture handle
struct GPUTexture {
    void* handle = nullptr;
    int32_t width = 0;
    int32_t height = 0;
    int32_t format = 0;
};

} // namespace vidviz
