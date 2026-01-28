/**
 * VidViz Engine - Core Engine Header
 * 
 * Ana render engine - platform bağımsız.
 * "Nasıl yapılacağını" hesaplar (Math/Timeline/Shaders).
 */

#pragma once

#include "common/types.h"
#include <memory>
#include <atomic>
#include <thread>
#include <mutex>
#include <string>
#include <unordered_map>

#if defined(__APPLE__)
#include <TargetConditionals.h>
#endif

namespace vidviz {

// Forward declarations
class Timeline;
class ShaderManager;
class RendererInterface;
class EncoderInterface;

/**
 * VidViz Core Engine
 * 
 * Platform bağımsız ana motor.
 * Render loop bu sınıfın içinde çalışır.
 * Flutter lifecycle'a bağlı DEĞİL.
 */
class Engine {
public:
    Engine();
    ~Engine();

    // Non-copyable
    Engine(const Engine&) = delete;
    Engine& operator=(const Engine&) = delete;

    /// Initialize engine with platform-specific renderer and encoder
    Result initialize(
        std::unique_ptr<RendererInterface> renderer,
        std::unique_ptr<EncoderInterface> encoder
    );

    /// If initialize() fails, returns a human-readable reason.
    std::string getLastInitError() const;

    /// Shutdown engine
    void shutdown();

    /// Get current state
    EngineState getState() const { return m_state.load(); }

    /// Submit export job (JSON string)
    Result submitJob(const std::string& jobJson);

    /// Cancel current job
    void cancelJob();

    /// Set progress callback
    void setProgressCallback(ProgressCallback callback);

    /// Set completion callback  
    void setCompletionCallback(CompletionCallback callback);

    /// Get status as JSON
    std::string getStatusJson() const;

#if defined(__APPLE__) && TARGET_OS_IPHONE
    void setMetalLayer(void* metalLayer);
#endif

private:
    /// Parse job from JSON
    Result parseJob(const std::string& jobJson);

    /// Main render loop (runs in separate thread)
    void renderLoop();

    /// Render single frame at given time
    Result renderFrame(TimeMs timeMs);

    /// Setup shaders from job
    Result setupShaders();

    /// Cleanup after job
    void cleanupJob();

    void registerAudioTracksForCurrentJob();

private:
    // State
    std::atomic<EngineState> m_state{EngineState::Idle};
    std::atomic<bool> m_cancelRequested{false};

    // Current job
    std::unique_ptr<ExportJob> m_currentJob;

    // Core components
    std::unique_ptr<Timeline> m_timeline;
    std::unique_ptr<ShaderManager> m_shaderManager;

    // Platform components (injected)
    std::unique_ptr<RendererInterface> m_renderer;
    std::unique_ptr<EncoderInterface> m_encoder;

    // Render thread
    std::unique_ptr<std::thread> m_renderThread;
    mutable std::mutex m_mutex;

    // Init diagnostics
    std::string m_lastInitError;

    // Callbacks
    ProgressCallback m_progressCallback;
    CompletionCallback m_completionCallback;

    std::atomic<FrameNum> m_currentFrame{0};
    std::atomic<FrameNum> m_totalFrames{0};
    std::atomic<int64_t> m_startTimeNs{0};

    // Audio reactive runtime state (per-job)
    std::unordered_map<std::string, float> m_audioReactiveLastLevels;
    std::unordered_map<std::string, float> m_audioReactiveBaseTextSizes;

    mutable std::mutex m_statusMutex;
    bool m_lastSuccess{false};
    std::string m_lastOutputPath;
    std::string m_lastErrorMsg;

    std::string m_activeJobId;
    std::string m_lastJobId;
};

} // namespace vidviz

// =============================================================================
// FFI Exports (C interface for Flutter)
// =============================================================================

VIDVIZ_EXTERN_C {

/// Initialize engine, returns handle
VIDVIZ_API void* vidviz_engine_init();

/// Destroy engine
VIDVIZ_API void vidviz_engine_destroy(void* handle);

/// Submit export job (JSON string)
VIDVIZ_API int32_t vidviz_submit_job(void* handle, const char* jobJson);

/// Cancel current job
VIDVIZ_API void vidviz_cancel_job(void* handle);

/// Get engine status (returns JSON, caller must free with vidviz_free_string)
VIDVIZ_API const char* vidviz_get_status(void* handle);

/// Set progress callback
VIDVIZ_API void vidviz_set_progress_callback(
    void* handle,
    void (*callback)(double progress, int32_t frame, int32_t totalFrames)
);

/// Set completion callback
VIDVIZ_API void vidviz_set_completion_callback(
    void* handle,
    void (*callback)(bool success, const char* outputPath, const char* errorMsg)
);

/// Get last engine initialization error (returns UTF8, caller must free with vidviz_free_string)
VIDVIZ_API const char* vidviz_get_last_init_error();

/// Free string allocated by engine
VIDVIZ_API void vidviz_free_string(const char* str);

} // extern "C"
