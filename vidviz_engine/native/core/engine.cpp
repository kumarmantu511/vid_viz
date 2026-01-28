/**
 * VidViz Engine - Core Engine Implementation
 */

#include "engine.h"
#include "timeline/timeline.h"
#include "effects/shader_manager.h"
#include "parser/job_parser.h"
#include "platform/renderer_interface.h"
#include "platform/encoder_interface.h"
#include "common/log.h"

#if defined(__ANDROID__)
#include "platform/android/vulkan_renderer.h"
#include "platform/android/gles_surface_renderer.h"
#include "platform/android/mediacodec_encoder.h"
#endif

#if defined(__APPLE__)
#include <TargetConditionals.h>
#if TARGET_OS_IPHONE
#include "platform/ios/metal_renderer.h"
#include "platform/ios/avfoundation_encoder.h"
#endif
#endif

#include <memory>
#include <mutex>
#include <thread>
#include <chrono>
#include <string>
#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <cmath>
#include <atomic>
#include <utility>
#include <unordered_map>

#if defined(__ANDROID__)
#include <sys/sysinfo.h>
#endif

#include "common/minijson.h"

namespace vidviz {

namespace {

#if defined(__ANDROID__)
static int64_t vvGetTotalRamMb() {
    struct sysinfo info;
    if (sysinfo(&info) != 0) {
        return -1;
    }
    const int64_t bytes = static_cast<int64_t>(info.totalram) * static_cast<int64_t>(info.mem_unit);
    return bytes / (1024LL * 1024LL);
}

static void vvApplyAndroidCapabilityPreflight(VideoSettings& s) {
    const int64_t px = static_cast<int64_t>(s.width) * static_cast<int64_t>(s.height);
    const bool isUhd = px >= 8'000'000;
    const bool isHighFps = s.fps >= 50;
    if (!isUhd || !isHighFps) {
        return;
    }

    const int64_t ramMb = vvGetTotalRamMb();
    if (ramMb > 0 && ramMb <= 4096) {
        if (s.fps != 30) {
            LOGW("Capability preflight: low RAM (%lldMB). Downgrading UHD/%dfps -> UHD/30fps", (long long)ramMb, s.fps);
            s.fps = 30;
        }
    }

    // Very-low RAM devices often struggle even at 4K/30. Use 1/2 scale (e.g. 3840x2160 -> 1920x1080).
    if (ramMb > 0 && ramMb <= 3072) {
        const int w2 = std::max(2, (s.width / 2) & ~1);
        const int h2 = std::max(2, (s.height / 2) & ~1);
        if (w2 != s.width || h2 != s.height) {
            LOGW("Capability preflight: very low RAM (%lldMB). Downgrading %dx%d -> %dx%d @ %dfps", (long long)ramMb, s.width, s.height, w2, h2, s.fps);
            s.width = w2;
            s.height = h2;
        }
        if (s.fps != 30) {
            s.fps = 30;
        }
    }
}
#endif

struct AudioReactiveParams {
    std::string targetOverlayId;
    std::string audioSourceId;
    std::string audioPath;
    std::string reactiveType = "scale";
    std::string frequencyRange = "all";
    float sensitivity = 1.0f;
    float smoothing = 0.3f;
    float minValue = 0.1f;
    float maxValue = 2.0f;
    bool invertReaction = false;
    int64_t offsetMs = 0;
};

static inline float vvClamp(float v, float lo, float hi) {
    if (!std::isfinite(v)) return lo;
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

static inline float vvClamp01(float v) {
    return vvClamp(v, 0.0f, 1.0f);
}

static bool vvParseOverlayType(const std::string& dataJson, std::string& outType) {
    outType.clear();
    if (dataJson.empty()) return false;
    const auto parsed = minijson::parse(dataJson);
    if (!parsed.ok()) return false;
    const auto* root = parsed.value.asObject();
    if (!root) return false;
    minijson::getString(*root, "overlayType", &outType);
    return !outType.empty();
}

static bool vvParseAudioReactiveParams(const std::string& dataJson, AudioReactiveParams& out) {
    out = AudioReactiveParams{};
    if (dataJson.empty()) return false;

    const auto parsed = minijson::parse(dataJson);
    if (!parsed.ok()) return false;
    const auto* root = parsed.value.asObject();
    if (!root) return false;

    std::string overlayType;
    minijson::getString(*root, "overlayType", &overlayType);
    if (overlayType != "audio_reactive") return false;

    minijson::getString(*root, "targetOverlayId", &out.targetOverlayId);
    minijson::getString(*root, "audioSourceId", &out.audioSourceId);
    minijson::getString(*root, "audioPath", &out.audioPath);
    minijson::getString(*root, "reactiveType", &out.reactiveType);
    if (out.reactiveType.empty()) out.reactiveType = "scale";
    minijson::getString(*root, "frequencyRange", &out.frequencyRange);
    if (out.frequencyRange.empty()) out.frequencyRange = "all";

    double d = 0.0;
    if (minijson::getDouble(*root, "sensitivity", &d)) out.sensitivity = static_cast<float>(d);
    if (minijson::getDouble(*root, "smoothing", &d)) out.smoothing = static_cast<float>(d);
    if (minijson::getDouble(*root, "minValue", &d)) out.minValue = static_cast<float>(d);
    if (minijson::getDouble(*root, "maxValue", &d)) out.maxValue = static_cast<float>(d);
    bool b = false;
    if (minijson::getBool(*root, "invertReaction", &b)) out.invertReaction = b;
    int64_t i64 = 0;
    if (minijson::getInt64(*root, "offsetMs", &i64)) out.offsetMs = i64;

    return true;
}

static const FFTData* vvFindFftByAudioPath(const std::vector<FFTData>& fftData, const std::string& audioPath) {
    if (audioPath.empty()) return nullptr;
    for (const auto& f : fftData) {
        if (f.audioPath == audioPath) return &f;
    }
    return nullptr;
}

static float vvAverageRange(const std::vector<float>& values, int start, int end) {
    if (values.empty()) return 0.0f;
    if (start < 0) start = 0;
    if (end > static_cast<int>(values.size())) end = static_cast<int>(values.size());
    if (end <= start) return 0.0f;
    float sum = 0.0f;
    int cnt = 0;
    for (int i = start; i < end; i++) {
        float v = values[static_cast<size_t>(i)];
        if (!std::isfinite(v)) v = 0.0f;
        if (v < 0.0f) v = 0.0f;
        if (v > 1.0f) v = 1.0f;
        sum += v;
        cnt++;
    }
    return (cnt > 0) ? (sum / static_cast<float>(cnt)) : 0.0f;
}

static bool vvGetAudioReactiveLevel(
    const std::vector<FFTData>& fftData,
    const std::string& audioPath,
    int64_t localMs,
    const std::string& frequencyRange,
    float& outLevel
) {
    outLevel = 0.0f;
    const FFTData* fft = vvFindFftByAudioPath(fftData, audioPath);
    if (!fft || fft->frames.empty() || fft->hopSize <= 0 || fft->sampleRate <= 0) return false;

    const double seconds = static_cast<double>(std::max<int64_t>(0, localMs)) / 1000.0;
    const double frameIndexD = (seconds * static_cast<double>(fft->sampleRate)) / static_cast<double>(fft->hopSize);
    int64_t frameIndex = static_cast<int64_t>(frameIndexD);
    if (frameIndex < 0) frameIndex = 0;
    if (frameIndex >= static_cast<int64_t>(fft->frames.size())) {
        frameIndex = static_cast<int64_t>(fft->frames.size()) - 1;
    }
    if (frameIndex < 0 || frameIndex >= static_cast<int64_t>(fft->frames.size())) return false;

    const auto& frame = fft->frames[static_cast<size_t>(frameIndex)];
    if (frame.empty()) return false;

    if (frame.size() == 4) {
        if (frequencyRange == "bass") outLevel = frame[0];
        else if (frequencyRange == "mid") outLevel = frame[1];
        else if (frequencyRange == "treble") outLevel = frame[2];
        else outLevel = frame[3];
        outLevel = vvClamp01(outLevel);
        return true;
    }

    const int n = static_cast<int>(frame.size());
    const int bassEnd = std::max(1, n / 4);
    const int midEnd = std::max(bassEnd + 1, (n * 3) / 4);
    if (frequencyRange == "bass") {
        outLevel = vvAverageRange(frame, 0, bassEnd);
    } else if (frequencyRange == "mid") {
        outLevel = vvAverageRange(frame, bassEnd, midEnd);
    } else if (frequencyRange == "treble") {
        outLevel = vvAverageRange(frame, midEnd, n);
    } else {
        outLevel = vvAverageRange(frame, 0, n);
    }
    outLevel = vvClamp01(outLevel);
    return true;
}

static minijson::Value::Object* vvEnsureObject(minijson::Value& v) {
    auto* obj = std::get_if<minijson::Value::Object>(&v.v);
    if (obj) return obj;
    v = minijson::Value(minijson::Value::Object{});
    return std::get_if<minijson::Value::Object>(&v.v);
}

static void vvSetNumber(minijson::Value::Object& obj, const std::string& key, double value) {
    obj[key] = minijson::Value(value);
}

static bool vvUpdateTargetAssetData(
    Asset& target,
    const std::string& reactiveType,
    float value,
    std::unordered_map<std::string, float>& baseTextSizes
) {
    if (target.dataJson.empty()) return false;
    auto parsed = minijson::parse(target.dataJson);
    if (!parsed.ok()) return false;
    auto* rootObj = std::get_if<minijson::Value::Object>(&parsed.value.v);
    if (!rootObj) return false;

    std::string overlayType;
    minijson::getString(*rootObj, "overlayType", &overlayType);

    // Defensive clamps: keep values finite even if upstream sends NaN/Inf.
    float safe01 = vvClamp01(value);
    float safeScale = vvClamp(value, 0.05f, 4.0f);

    if (overlayType == "media") {
        if (reactiveType == "scale") vvSetNumber(*rootObj, "scale", safeScale);
        else if (reactiveType == "rotation") vvSetNumber(*rootObj, "rotation", safe01 * 360.0f);
        else if (reactiveType == "opacity") vvSetNumber(*rootObj, "opacity", safe01);
        else if (reactiveType == "x") vvSetNumber(*rootObj, "x", safe01);
        else if (reactiveType == "y") vvSetNumber(*rootObj, "y", safe01);
        target.dataJson = minijson::stringify(parsed.value);
        return true;
    }

    auto itText = rootObj->find("text");
    if (itText != rootObj->end()) {
        auto* textObj = vvEnsureObject(itText->second);
        if (!textObj) return false;
        if (reactiveType == "scale") {
            const std::string key = target.id;
            float baseSize = baseTextSizes.count(key) ? baseTextSizes[key] : 0.0f;
            if (baseSize <= 0.0f) {
                double fs = 0.0;
                if (minijson::getDouble(*textObj, "fontSize", &fs)) {
                    baseSize = static_cast<float>(fs);
                }
                if (baseSize <= 0.0f) baseSize = 0.1f;
                baseTextSizes[key] = baseSize;
            }
            float scaled = baseSize * value;
            scaled = vvClamp(scaled, 0.03f, 1.0f);
            vvSetNumber(*textObj, "fontSize", scaled);
        } else if (reactiveType == "opacity") {
            vvSetNumber(*textObj, "alpha", value);
        } else if (reactiveType == "x") {
            vvSetNumber(*textObj, "x", value);
        } else if (reactiveType == "y") {
            vvSetNumber(*textObj, "y", value);
        }
        target.dataJson = minijson::stringify(parsed.value);
        return true;
    }

    auto itVis = rootObj->find("visualizer");
    if (itVis != rootObj->end()) {
        auto* visObj = vvEnsureObject(itVis->second);
        if (!visObj) return false;
        if (reactiveType == "scale") vvSetNumber(*visObj, "scale", safeScale);
        else if (reactiveType == "opacity") vvSetNumber(*visObj, "alpha", safe01);
        else if (reactiveType == "x") vvSetNumber(*visObj, "x", safe01);
        else if (reactiveType == "y") vvSetNumber(*visObj, "y", safe01);
        target.dataJson = minijson::stringify(parsed.value);
        return true;
    }

    auto itShader = rootObj->find("shader");
    if (itShader != rootObj->end()) {
        auto* shaderObj = vvEnsureObject(itShader->second);
        if (!shaderObj) return false;
        if (reactiveType == "scale") vvSetNumber(*shaderObj, "scale", safeScale);
        else if (reactiveType == "opacity") vvSetNumber(*shaderObj, "alpha", safe01);
        else if (reactiveType == "x") vvSetNumber(*shaderObj, "x", safe01);
        else if (reactiveType == "y") vvSetNumber(*shaderObj, "y", safe01);
        target.dataJson = minijson::stringify(parsed.value);
        return true;
    }

    return false;
}

} // namespace

Engine::Engine() {
    LOGI("Engine created");
}

Engine::~Engine() {
    shutdown();
    LOGI("Engine destroyed");
}

Result Engine::initialize(
    std::unique_ptr<RendererInterface> renderer,
    std::unique_ptr<EncoderInterface> encoder
) {
    std::lock_guard<std::mutex> lock(m_mutex);

    m_lastInitError.clear();

    if (m_state != EngineState::Idle) {
        LOGW("Engine already initialized");
        return Result::ErrorEngineBusy;
    }

    m_state = EngineState::Initializing;

    // Store platform components
    m_renderer = std::move(renderer);
    m_encoder = std::move(encoder);

    // Create core components
    m_timeline = std::make_unique<Timeline>();
    m_shaderManager = std::make_unique<ShaderManager>();

    // Initialize renderer
    if (m_renderer) {
        if (!m_renderer->initialize()) {
            LOGE("Failed to initialize renderer");
            m_lastInitError = "Failed to initialize renderer";
            m_state = EngineState::Error;
            return Result::ErrorUnknown;
        }
    }

    // Initialize encoder
    if (m_encoder) {
        if (!m_encoder->initialize()) {
            LOGE("Failed to initialize encoder");
            m_lastInitError = "Failed to initialize encoder";
            m_state = EngineState::Error;
            return Result::ErrorEncodeFailed;
        }
    }

    m_state = EngineState::Ready;
    LOGI("Engine initialized successfully");
    return Result::Success;
}

void Engine::registerAudioTracksForCurrentJob() {
    if (!m_encoder || !m_currentJob) {
        return;
    }

    int audioCount = 0;
    const TimeMs totalDur = m_currentJob->totalDuration;
    auto clampDuration = [totalDur](TimeMs begin, TimeMs duration) -> TimeMs {
        if (duration <= 0) return 0;
        if (totalDur <= 0) return duration;
        if (begin < 0) begin = 0;
        if (begin >= totalDur) return 0;
        const TimeMs maxDur = totalDur - begin;
        return (duration > maxDur) ? maxDur : duration;
    };

    for (const auto& layer : m_currentJob->layers) {
        if (layer.type != LayerType::Audio) continue;
        const float baseVol = layer.mute ? 0.0f : layer.volume;
        if (baseVol <= 0.0001f) {
            continue;
        }
        for (const auto& asset : layer.assets) {
            if (asset.type != AssetType::Audio) continue;
            if (asset.srcPath.empty()) continue;
            const TimeMs dur = clampDuration(asset.begin, asset.duration);
            if (dur <= 0) continue;

            float gain = 1.0f;
            if (!asset.dataJson.empty()) {
                const auto parsed = minijson::parse(asset.dataJson);
                if (parsed.ok()) {
                    const auto* root = parsed.value.asObject();
                    if (root) {
                        double gv = 1.0;
                        if (minijson::getDouble(*root, "volume", &gv)) {
                            if (gv < 0.0) gv = 0.0;
                            if (gv > 1.0) gv = 1.0;
                            gain = static_cast<float>(gv);
                        }
                    }
                }
            }
            const float effVol = baseVol * gain;
            if (effVol <= 0.0001f) {
                continue;
            }
            m_encoder->addAudioTrack(asset.srcPath, asset.begin, dur, asset.cutFrom, effVol);
            audioCount++;
        }
    }

    for (const auto& layer : m_currentJob->layers) {
        if (layer.type != LayerType::Raster) continue;
        if (!layer.useVideoAudio) continue;
        const float baseVol = layer.mute ? 0.0f : layer.volume;
        if (baseVol <= 0.0001f) {
            continue;
        }
        for (const auto& asset : layer.assets) {
            if (asset.type != AssetType::Video) continue;
            if (asset.srcPath.empty()) continue;
            const TimeMs dur = clampDuration(asset.begin, asset.duration);
            if (dur <= 0) continue;

            float gain = 1.0f;
            if (!asset.dataJson.empty()) {
                const auto parsed = minijson::parse(asset.dataJson);
                if (parsed.ok()) {
                    const auto* root = parsed.value.asObject();
                    if (root) {
                        double gv = 1.0;
                        if (minijson::getDouble(*root, "volume", &gv)) {
                            if (gv < 0.0) gv = 0.0;
                            if (gv > 1.0) gv = 1.0;
                            gain = static_cast<float>(gv);
                        }
                    }
                }
            }
            const float effVol = baseVol * gain;
            if (effVol <= 0.0001f) {
                continue;
            }
            m_encoder->addAudioTrack(asset.srcPath, asset.begin, dur, asset.cutFrom, effVol);
            audioCount++;
        }
    }

    if (audioCount > 0) {
        LOGI("Registered audio assets: %d", audioCount);
    }
}

std::string Engine::getLastInitError() const {
    std::lock_guard<std::mutex> lock(m_mutex);
    return m_lastInitError;
}

void Engine::shutdown() {
    // Cancel any running job
    cancelJob();

    // Wait for render thread to finish
    if (m_renderThread && m_renderThread->joinable()) {
        m_renderThread->join();
    }

    std::lock_guard<std::mutex> lock(m_mutex);

    // Cleanup
    m_shaderManager.reset();
    m_timeline.reset();
    m_encoder.reset();
    m_renderer.reset();
    m_currentJob.reset();

    m_state = EngineState::Idle;
    LOGI("Engine shutdown complete");
}

Result Engine::submitJob(const std::string& jobJson) {
    // Zombi Savar v2: decide under lock, but do cancel/join outside lock.
    bool needCancel = false;
    bool needJoin = false;
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        if (m_state != EngineState::Ready) {
            if (m_renderThread && m_renderThread->joinable()) {
                needCancel = true;
            }
        } else {
            if (m_renderThread && m_renderThread->joinable()) {
                needJoin = true;
            }
        }
    }

    if (needCancel) {
        LOGW("submitJob: cancelling previous job before starting a new one");
        cancelJob();
    } else if (needJoin) {
        std::unique_ptr<std::thread> joinThread;
        {
            std::lock_guard<std::mutex> lock(m_mutex);
            joinThread = std::move(m_renderThread);
        }
        if (joinThread && joinThread->joinable()) {
            joinThread->join();
        }
    }

    std::lock_guard<std::mutex> lock(m_mutex);
    if (m_state != EngineState::Ready) {
        LOGE("Engine not ready, state: %d", static_cast<int>(m_state.load()));
        return Result::ErrorEngineBusy;
    }

    // Parse job
    Result parseResult = parseJob(jobJson);
    if (parseResult != Result::Success) {
        return parseResult;
    }

#if defined(__ANDROID__)
    if (m_currentJob) {
        vvApplyAndroidCapabilityPreflight(m_currentJob->settings);
    }
#endif

    // Reset audio reactive runtime state for a new job
    m_audioReactiveLastLevels.clear();
    m_audioReactiveBaseTextSizes.clear();

    // Setup shaders
    Result shaderResult = setupShaders();
    if (shaderResult != Result::Success) {
        return shaderResult;
    }

    // Calculate total frames
    const auto& settings = m_currentJob->settings;

    if (m_timeline) {
        m_timeline->setDuration(m_currentJob->totalDuration);
    }

    if (m_renderer) {
        m_renderer->setOutputSize(settings.width, settings.height);
        m_renderer->setVideoSettings(settings);
    }

    // Defensive: totalDuration may be missing/0 for some jobs (e.g., shader/effect-only changes).
    // Compute a fallback from assets so render loop doesn't terminate immediately.
    TimeMs totalDurationMs = m_currentJob->totalDuration;
    if (totalDurationMs <= 0 && m_currentJob) {
        TimeMs maxEnd = 0;
        for (const auto& layer : m_currentJob->layers) {
            for (const auto& asset : layer.assets) {
                if (asset.duration <= 0) continue;
                const TimeMs end = asset.begin + asset.duration;
                if (end > maxEnd) maxEnd = end;
            }
        }
        if (maxEnd > 0) {
            totalDurationMs = maxEnd;
            m_currentJob->totalDuration = maxEnd;
            if (m_timeline) {
                m_timeline->setDuration(maxEnd);
            }
            LOGW("VIDVIZ_ERROR: Job totalDuration was 0; computed fallback duration: %lldms", (long long)maxEnd);
        }
    }

    FrameNum frames = 0;
    if (totalDurationMs > 0 && settings.fps > 0) {
        const double exact = (static_cast<double>(totalDurationMs) / 1000.0) * static_cast<double>(settings.fps);
        frames = static_cast<FrameNum>(std::ceil(exact));
        if (frames < 1) frames = 1;
    }
    m_totalFrames.store(frames);
    m_currentFrame.store(0);

    // Configure encoder
    if (m_encoder) {
        if (!m_encoder->configure(
            settings.width,
            settings.height,
            settings.fps,
            settings.quality,
            settings.outputPath
        )) {
            {
                std::lock_guard<std::mutex> sLock(m_statusMutex);
                m_lastSuccess = false;
                m_lastOutputPath.clear();
                m_lastErrorMsg = "Encoder configure failed";
                m_lastJobId = m_currentJob ? m_currentJob->jobId : std::string();
                m_activeJobId.clear();
            }
            m_state = EngineState::Ready;
            return Result::ErrorEncodeFailed;
        }
    }

    registerAudioTracksForCurrentJob();

    // Start render thread
    m_cancelRequested = false;

    {
        std::lock_guard<std::mutex> sLock(m_statusMutex);
        m_activeJobId = m_currentJob ? m_currentJob->jobId : std::string();
    }

    m_state = EngineState::Exporting;
    m_renderThread = std::make_unique<std::thread>(&Engine::renderLoop, this);

    LOGI("Job submitted: %s, duration: %lldms, frames: %d",
         m_currentJob->jobId.c_str(),
         m_currentJob->totalDuration,
         m_totalFrames.load());

    return Result::Success;
}

void Engine::cancelJob() {
    std::string activeJobId;
    {
        std::lock_guard<std::mutex> lock(m_statusMutex);
        activeJobId = m_activeJobId;
    }

    // If there is no active job, do not overwrite last-job status and do not
    // delete any output file. Just ensure thread is joined.
    if (activeJobId.empty()) {
        std::unique_ptr<std::thread> joinThread;
        {
            std::lock_guard<std::mutex> lock(m_mutex);
            joinThread = std::move(m_renderThread);
        }
        if (joinThread && joinThread->joinable()) {
            joinThread->join();
        }
        return;
    }

    m_cancelRequested = true;

    // Wait for render thread
    std::unique_ptr<std::thread> joinThread;
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        joinThread = std::move(m_renderThread);
    }
    if (joinThread && joinThread->joinable()) {
        joinThread->join();
    }

    std::string cancelledJobId;
    std::string cancelledOutPath;
    if (m_currentJob) {
        cancelledJobId = m_currentJob->jobId;
        cancelledOutPath = m_currentJob->settings.outputPath;
    }

    cleanupJob();

    if (!cancelledOutPath.empty()) {
        const int rc = std::remove(cancelledOutPath.c_str());
        if (rc == 0) {
            LOGI("Cancelled output removed: %s", cancelledOutPath.c_str());
        } else {
            LOGW("Failed to remove cancelled output: %s", cancelledOutPath.c_str());
        }
    }

    {
        std::lock_guard<std::mutex> lock(m_statusMutex);
        m_lastSuccess = false;
        m_lastOutputPath.clear();
        m_lastErrorMsg = "Cancelled";

        m_lastJobId = std::move(cancelledJobId);
        m_activeJobId.clear();
    }

    m_state = EngineState::Ready;
    LOGI("Job cancelled");
}

void Engine::setProgressCallback(ProgressCallback callback) {
    std::lock_guard<std::mutex> lock(m_mutex);
    m_progressCallback = std::move(callback);
}

void Engine::setCompletionCallback(CompletionCallback callback) {
    std::lock_guard<std::mutex> lock(m_mutex);
    m_completionCallback = std::move(callback);
}

std::string Engine::getStatusJson() const {
    const int state = static_cast<int>(m_state.load());
    const int cur = static_cast<int>(m_currentFrame.load());
    const int tot = static_cast<int>(m_totalFrames.load());
    const double progress = (tot > 0) ? (static_cast<double>(cur) / static_cast<double>(tot)) : 0.0;

    int64_t elapsedMs = 0;
    double fps = 0.0;
    int64_t estimatedMs = 0;
    if (state == static_cast<int>(EngineState::Exporting)) {
        const int64_t startNs = m_startTimeNs.load();
        if (startNs > 0) {
            const int64_t nowNs = std::chrono::duration_cast<std::chrono::nanoseconds>(
                std::chrono::steady_clock::now().time_since_epoch()
            ).count();
            const int64_t diffNs = nowNs - startNs;
            if (diffNs > 0) {
                elapsedMs = diffNs / 1000000;
                if (elapsedMs > 0) {
                    fps = (cur * 1000.0) / static_cast<double>(elapsedMs);
                    if (progress > 0.0) {
                        const double remaining = (static_cast<double>(elapsedMs) / progress) - static_cast<double>(elapsedMs);
                        if (remaining > 0.0) {
                            estimatedMs = static_cast<int64_t>(remaining);
                        }
                    }
                }
            }
        }
    }

    bool success;
    std::string outPath;
    std::string err;
    std::string activeJobId;
    std::string lastJobId;

    std::string videoDecodePath;
    std::string videoDecodeError;

    bool setEncoderSurfaceOk = false;
    int64_t presentOkCount = 0;
    int64_t presentFailCount = 0;
    uint32_t lastEglError = 0;
    std::string lastPresentError;
#if defined(__ANDROID__)
    if (m_renderer) {
        auto* gles = dynamic_cast<vidviz::android::GlesSurfaceRenderer*>(m_renderer.get());
        if (gles) {
            videoDecodePath = gles->getVideoDecodePath();
            videoDecodeError = gles->getVideoDecodeError();

            setEncoderSurfaceOk = gles->getLastSetEncoderSurfaceOk();
            presentOkCount = gles->getPresentOkCount();
            presentFailCount = gles->getPresentFailCount();
            lastEglError = gles->getLastEglError();
            lastPresentError = gles->getLastPresentError();
        }
    }
#endif
    {
        std::lock_guard<std::mutex> lock(m_statusMutex);
        success = m_lastSuccess;
        outPath = m_lastOutputPath;
        err = m_lastErrorMsg;
        activeJobId = m_activeJobId;
        lastJobId = m_lastJobId;
    }

    auto escapeJson = [](const std::string& s) -> std::string {
        std::string out;
        out.reserve(s.size());
        for (const char c : s) {
            switch (c) {
                case '\\':
                    out += "\\\\";
                    break;
                case '"':
                    out += "\\\"";
                    break;
                case '\n':
                    out += "\\n";
                    break;
                case '\r':
                    out += "\\r";
                    break;
                case '\t':
                    out += "\\t";
                    break;
                default:
                    out += c;
                    break;
            }
        }
        return out;
    };

    const std::string outPathEsc = escapeJson(outPath);
    const std::string errEsc = escapeJson(err);
    const std::string activeJobEsc = escapeJson(activeJobId);
    const std::string lastJobEsc = escapeJson(lastJobId);
    const std::string vPathEsc = escapeJson(videoDecodePath);
    const std::string vErrEsc = escapeJson(videoDecodeError);
    const std::string lastPresentErrEsc = escapeJson(lastPresentError);

    // Simple JSON without external library for now
    char buffer[4096];
    snprintf(
        buffer,
        sizeof(buffer),
        R"({"state":%d,"currentFrame":%d,"totalFrames":%d,"progress":%.6f,"fps":%.3f,"elapsedMs":%lld,"estimatedMs":%lld,"activeJobId":"%s","lastJobId":"%s","lastSuccess":%s,"lastOutputPath":"%s","lastErrorMsg":"%s","videoDecodePath":"%s","videoDecodeError":"%s","setEncoderSurfaceOk":%s,"presentOkCount":%lld,"presentFailCount":%lld,"lastEglError":%u,"lastPresentError":"%s"})",
        state,
        cur,
        tot,
        progress,
        fps,
        static_cast<long long>(elapsedMs),
        static_cast<long long>(estimatedMs),
        activeJobEsc.c_str(),
        lastJobEsc.c_str(),
        success ? "true" : "false",
        outPathEsc.c_str(),
        errEsc.c_str(),
        vPathEsc.c_str(),
        vErrEsc.c_str(),
        setEncoderSurfaceOk ? "true" : "false",
        static_cast<long long>(presentOkCount),
        static_cast<long long>(presentFailCount),
        static_cast<unsigned int>(lastEglError),
        lastPresentErrEsc.c_str()
    );
    return std::string(buffer);
}

#if defined(__APPLE__) && TARGET_OS_IPHONE
void Engine::setMetalLayer(void* metalLayer) {
    std::lock_guard<std::mutex> lock(m_mutex);
    if (!m_renderer) return;

    auto* mr = dynamic_cast<vidviz::ios::MetalRenderer*>(m_renderer.get());
    if (!mr) return;

    mr->setMetalLayer(metalLayer);
}
#endif

Result Engine::parseJob(const std::string& jobJson) {
    JobParser parser;
    auto job = parser.parse(jobJson);

    if (!job) {
        LOGE("Failed to parse job JSON");
        return Result::ErrorInvalidJob;
    }

    m_currentJob = std::move(job);
    return Result::Success;
}

Result Engine::setupShaders() {
    if (!m_currentJob || !m_shaderManager) {
        return Result::ErrorInvalidJob;
    }

    for (const auto& shader : m_currentJob->shaders) {
        if (!m_shaderManager->compileShader(shader)) {
            LOGE("Failed to compile shader: %s", shader.name.c_str());
            return Result::ErrorShaderCompile;
        }
    }

    return Result::Success;
}

void Engine::renderLoop() {
    LOGI("Render loop started");

    auto startTime = std::chrono::steady_clock::now();
    m_startTimeNs = std::chrono::duration_cast<std::chrono::nanoseconds>(
        startTime.time_since_epoch()
    ).count();

    int downgradeStage = 0;
    bool success = false;
    std::string errorMsg;

    for (int attempt = 0; attempt < 3; ++attempt) {
        const auto attemptStartTime = std::chrono::steady_clock::now();
        const int fps = m_currentJob ? m_currentJob->settings.fps : 0;
        const double frameStepMs = (fps > 0) ? (1000.0 / static_cast<double>(fps)) : 0.0;

        success = true;
        errorMsg.clear();

        if (m_encoder) {
            if (!m_encoder->start()) {
                success = false;
                errorMsg = "Encoder start failed";
            }
        }

        if (success && m_renderer && m_encoder) {
            if (!m_renderer->setEncoderSurface(m_encoder->getInputSurface())) {
                success = false;
                errorMsg = "Renderer setEncoderSurface failed";
            }
        }

        if (success && m_renderer && m_currentJob) {
            for (const auto& shader : m_currentJob->shaders) {
                if (!m_renderer->compileShader(shader.id, shader.vertexSource, shader.fragmentSource)) {
                    success = false;
                    errorMsg = "Platform shader compile failed: " + shader.id;
#if defined(__ANDROID__)
                    {
                        auto* gles = dynamic_cast<vidviz::android::GlesSurfaceRenderer*>(m_renderer.get());
                        if (gles) {
                            const std::string& det = gles->getLastShaderCompileError();
                            if (!det.empty()) {
                                errorMsg += " | ";
                                errorMsg += det;
                            }
                        }
                    }
#endif
                    break;
                }
            }
        }

        const int64_t timeoutMs = (m_currentJob && m_currentJob->totalDuration > 0)
            ? (static_cast<int64_t>(m_currentJob->totalDuration) * 10LL + 60'000LL)
            : (10LL * 60'000LL);

        for (FrameNum f = 0; f < m_totalFrames.load(); ++f) {
            m_currentFrame.store(f);
            if (m_cancelRequested) {
                success = false;
                errorMsg = "Cancelled";
                break;
            }

            const auto nowTime = std::chrono::steady_clock::now();
            const int64_t elapsedMs = std::chrono::duration_cast<std::chrono::milliseconds>(nowTime - startTime).count();
            if (elapsedMs > timeoutMs) {
                success = false;
                errorMsg = "Timeout";
                LOGE("Render loop watchdog timeout (elapsedMs=%lld, timeoutMs=%lld)", (long long)elapsedMs, (long long)timeoutMs);
                break;
            }

            if (!success) {
                break;
            }

            TimeMs frameTimeMs = 0;
            if (frameStepMs > 0.0) {
                frameTimeMs = static_cast<TimeMs>(
                    std::llround(static_cast<double>(m_currentFrame.load()) * frameStepMs)
                );
            }

            Result result = renderFrame(frameTimeMs);
            if (result != Result::Success) {
                success = false;
                if (result == Result::ErrorCancelled) {
                    errorMsg = "Cancelled";
                } else if (result == Result::ErrorEncodeFailed) {
                    std::string encErr;
                    if (m_encoder) {
                        encErr = m_encoder->getLastErrorMessage();
                    }
                    errorMsg = encErr.empty() ? "Encode failed" : encErr;
                } else {
                    errorMsg = "Render failed";
                }
                break;
            }

            ProgressCallback progressCb;
            {
                std::lock_guard<std::mutex> cbLock(m_mutex);
                progressCb = m_progressCallback;
            }
            if (progressCb) {
                const FrameNum cur = m_currentFrame.load();
                const FrameNum tot = m_totalFrames.load();
                float p = (tot > 0) ? (static_cast<float>(cur + 1) / static_cast<float>(tot)) : 0.0f;
                progressCb(p, cur + 1, tot);
            }
        }

        const bool cancelled = (!success && errorMsg == "Cancelled") || m_cancelRequested;
        if (m_encoder) {
            if (cancelled || !success) {
                m_encoder->cancel();
            } else {
                if (!m_encoder->finish()) {
                    success = false;
                    if (errorMsg.empty()) {
                        const std::string encErr = m_encoder->getLastErrorMessage();
                        if (!encErr.empty()) {
                            errorMsg = encErr;
                        } else {
                            errorMsg = "Encoder finish failed";
                        }
                    }
                }
            }
        }

        if (success || cancelled) {
            break;
        }

        if (m_currentJob) {
            const int64_t px = static_cast<int64_t>(m_currentJob->settings.width) * static_cast<int64_t>(m_currentJob->settings.height);
            const bool isUhd = px >= 8'000'000;
            const bool isHighFps = m_currentJob->settings.fps >= 50;
            const int64_t attemptElapsedMs = std::chrono::duration_cast<std::chrono::milliseconds>(
                std::chrono::steady_clock::now() - attemptStartTime
            ).count();
            const bool failedEarly = attemptElapsedMs >= 0 && attemptElapsedMs < 2000;

            const bool canRetry = !m_cancelRequested;
            if (canRetry && isUhd && isHighFps && failedEarly && downgradeStage == 0) {
                downgradeStage = 1;
                LOGW("Encoder failed early at UHD/high-fps; retrying with 30fps for device stability (attemptElapsedMs=%lld)", (long long)attemptElapsedMs);
                m_currentJob->settings.fps = 30;
            } else if (canRetry && isUhd && failedEarly && downgradeStage == 1) {
                downgradeStage = 2;
                const int oldW = m_currentJob->settings.width;
                const int oldH = m_currentJob->settings.height;
                const int w2 = std::max(2, (oldW / 2) & ~1);
                const int h2 = std::max(2, (oldH / 2) & ~1);
                LOGW("Encoder still failing early; retrying with half-res for device stability (%dx%d -> %dx%d @ 30fps, attemptElapsedMs=%lld)", oldW, oldH, w2, h2, (long long)attemptElapsedMs);
                m_currentJob->settings.width = w2;
                m_currentJob->settings.height = h2;
                m_currentJob->settings.fps = 30;
            } else {
                break;
            }

            if (m_renderer) {
                m_renderer->setOutputSize(m_currentJob->settings.width, m_currentJob->settings.height);
                m_renderer->setVideoSettings(m_currentJob->settings);
            }

            FrameNum frames = 0;
            if (m_currentJob->totalDuration > 0) {
                const double exact = (static_cast<double>(m_currentJob->totalDuration) / 1000.0) * static_cast<double>(m_currentJob->settings.fps);
                frames = static_cast<FrameNum>(std::ceil(exact));
                if (frames < 1) frames = 1;
            }
            m_totalFrames.store(frames);
            m_currentFrame.store(0);

            if (m_encoder) {
                if (!m_encoder->configure(
                    m_currentJob->settings.width,
                    m_currentJob->settings.height,
                    m_currentJob->settings.fps,
                    m_currentJob->settings.quality,
                    m_currentJob->settings.outputPath
                )) {
                    success = false;
                    errorMsg = "Encoder configure failed";
                    break;
                }
            }

            registerAudioTracksForCurrentJob();

            continue;
        }
    }

    std::string finishedJobId;
    std::string finishedOut;
    if (m_currentJob) {
        finishedJobId = m_currentJob->jobId;
        if (success) {
            finishedOut = m_currentJob->settings.outputPath;
        }
    }

    {
        std::lock_guard<std::mutex> lock(m_statusMutex);
        m_lastSuccess = success;
        m_lastOutputPath = finishedOut;
        m_lastErrorMsg = errorMsg;
        m_lastJobId = finishedJobId;
        m_activeJobId.clear();
    }

    // Report completion
    CompletionCallback completionCb;
    {
        std::lock_guard<std::mutex> cbLock(m_mutex);
        completionCb = m_completionCallback;
    }
    if (completionCb) {
        completionCb(
            success,
            finishedOut,
            errorMsg
        );
    }

    auto endTime = std::chrono::steady_clock::now();
    auto durationMs = std::chrono::duration_cast<std::chrono::milliseconds>(
        endTime - startTime
    ).count();

    LOGI(
        "Render loop finished. Frames: %d, Duration: %lldms, FPS: %.1f",
        success ? m_totalFrames.load() : m_currentFrame.load(),
        durationMs,
        durationMs > 0
            ? ((success ? m_totalFrames.load() : m_currentFrame.load()) * 1000.0f / durationMs)
            : 0.0f
    );

    m_state = EngineState::Ready;
}

Result Engine::renderFrame(TimeMs timeMs) {
    if (!m_renderer || !m_encoder) {
        return Result::ErrorUnknown;
    }

    const FrameNum frameNo = m_currentFrame.load();
    const bool logThisFrame = (frameNo % 10) == 0;

    // Begin frame
    m_renderer->beginFrame();

    // Update timeline to this time
    m_timeline->seek(timeMs);

    // Get active layers at this time
    const auto& layers = m_currentJob->layers;

    // Build audio reactive overrides for this frame (do not mutate original assets)
    std::unordered_map<std::string, const Asset*> assetIndex;
    for (const auto& layer : layers) {
        for (const auto& asset : layer.assets) {
            if (!asset.id.empty()) {
                assetIndex[asset.id] = &asset;
            }
        }
    }

    std::unordered_map<std::string, Asset> overrides;
    for (const auto& layer : layers) {
        for (const auto& asset : layer.assets) {
            if (asset.type != AssetType::Image) continue;

            AudioReactiveParams reactive;
            if (!vvParseAudioReactiveParams(asset.dataJson, reactive)) continue;

            if (logThisFrame) {
                LOGI(
                    "[AR_NATIVE] frame=%d id=%s target=%s type=%s freq=%s sens=%.3f smooth=%.3f min=%.3f max=%.3f invert=%d offsetMs=%lld",
                    static_cast<int>(frameNo),
                    asset.id.c_str(),
                    reactive.targetOverlayId.c_str(),
                    reactive.reactiveType.c_str(),
                    reactive.frequencyRange.c_str(),
                    reactive.sensitivity,
                    reactive.smoothing,
                    reactive.minValue,
                    reactive.maxValue,
                    reactive.invertReaction ? 1 : 0,
                    static_cast<long long>(reactive.offsetMs)
                );
            }

            TimeMs dur = asset.duration;
            if (dur <= 0) {
                dur = m_currentJob ? m_currentJob->totalDuration : 0;
            }
            if (dur <= 0) {
                dur = std::numeric_limits<TimeMs>::max() / 4;
            }
            if (timeMs < asset.begin || timeMs >= asset.begin + dur) {
                continue;
            }

            std::string audioPath = reactive.audioPath;
            if (audioPath.empty() && !reactive.audioSourceId.empty()) {
                const auto it = assetIndex.find(reactive.audioSourceId);
                if (it != assetIndex.end() && it->second) {
                    audioPath = it->second->srcPath;
                }
            }
            if (audioPath.empty()) {
                if (logThisFrame) {
                    LOGW(
                        "[AR_NATIVE] missing audioPath frame=%d id=%s audioSourceId=%s",
                        static_cast<int>(frameNo),
                        asset.id.c_str(),
                        reactive.audioSourceId.c_str()
                    );
                }
                continue;
            }

            TimeMs localMs = Timeline::getLocalTime(asset, timeMs);
            localMs += reactive.offsetMs;
            if (localMs < 0) localMs = 0;

            float audioLevel = 0.0f;
            if (!vvGetAudioReactiveLevel(m_currentJob->fftData, audioPath, localMs, reactive.frequencyRange, audioLevel)) {
                if (logThisFrame) {
                    const FFTData* fft = vvFindFftByAudioPath(m_currentJob->fftData, audioPath);
                    if (!fft) {
                        LOGW(
                            "[AR_NATIVE] FFT not found frame=%d id=%s path=%s",
                            static_cast<int>(frameNo),
                            asset.id.c_str(),
                            audioPath.c_str()
                        );
                    } else {
                        LOGW(
                            "[AR_NATIVE] FFT invalid frame=%d id=%s path=%s frames=%zu hop=%d sr=%d",
                            static_cast<int>(frameNo),
                            asset.id.c_str(),
                            audioPath.c_str(),
                            fft->frames.size(),
                            fft->hopSize,
                            fft->sampleRate
                        );
                    }
                }
                continue;
            }

            float targetLevel = vvClamp01(audioLevel * reactive.sensitivity);
            float smoothing = vvClamp(reactive.smoothing, 0.0f, 0.95f);
            float prevLevel = targetLevel;
            if (smoothing > 0.0f) {
                const float prev = m_audioReactiveLastLevels.count(asset.id)
                    ? m_audioReactiveLastLevels[asset.id]
                    : targetLevel;
                const float alpha = 1.0f - smoothing;
                targetLevel = prev * (1.0f - alpha) + targetLevel * alpha;
                prevLevel = prev;
            }
            m_audioReactiveLastLevels[asset.id] = targetLevel;

            if (reactive.invertReaction) {
                targetLevel = 1.0f - targetLevel;
            }

            float minValue = reactive.minValue;
            float maxValue = reactive.maxValue;
            if (std::fabs(maxValue - minValue) < 0.0001f) {
                maxValue = minValue + 0.1f;
            }
            float value = minValue + (maxValue - minValue) * targetLevel;
            if (reactive.reactiveType == "opacity") {
                value = vvClamp01(value);
            } else if (reactive.reactiveType == "x" || reactive.reactiveType == "y") {
                value = vvClamp01(value);
            }

            if (logThisFrame) {
                LOGI(
                    "[AR_NATIVE] apply frame=%d id=%s audio=%.3f prev=%.3f smooth=%.3f level=%.3f value=%.3f path=%s localMs=%lld",
                    static_cast<int>(frameNo),
                    asset.id.c_str(),
                    audioLevel,
                    prevLevel,
                    smoothing,
                    targetLevel,
                    value,
                    audioPath.c_str(),
                    static_cast<long long>(localMs)
                );
            }

            if (reactive.targetOverlayId.empty()) continue;
            const auto it = assetIndex.find(reactive.targetOverlayId);
            if (it == assetIndex.end() || !it->second) {
                if (logThisFrame) {
                    LOGW(
                        "[AR_NATIVE] target overlay not found frame=%d id=%s target=%s",
                        static_cast<int>(frameNo),
                        asset.id.c_str(),
                        reactive.targetOverlayId.c_str()
                    );
                }
                continue;
            }

            auto ovIt = overrides.find(reactive.targetOverlayId);
            if (ovIt == overrides.end()) {
                ovIt = overrides.emplace(reactive.targetOverlayId, *it->second).first;
            }
            const bool updated = vvUpdateTargetAssetData(
                ovIt->second,
                reactive.reactiveType,
                value,
                m_audioReactiveBaseTextSizes
            );
            if (logThisFrame && !updated) {
                LOGW(
                    "[AR_NATIVE] failed to update target frame=%d id=%s target=%s type=%s",
                    static_cast<int>(frameNo),
                    asset.id.c_str(),
                    reactive.targetOverlayId.c_str(),
                    reactive.reactiveType.c_str()
                );
            }
        }
    }

    // Pass 1: render all non-shader assets
    for (const auto& layer : layers) {
        for (const auto& asset : layer.assets) {
            TimeMs dur = asset.duration;
            if (dur <= 0) {
                dur = m_currentJob ? m_currentJob->totalDuration : 0;
            }
            if (dur <= 0) {
                dur = std::numeric_limits<TimeMs>::max() / 4;
            }
            if (timeMs < asset.begin || timeMs >= asset.begin + dur) {
                continue;
            }

            if (asset.type == AssetType::Shader) {
                continue;
            }

            std::string overlayType;
            if (vvParseOverlayType(asset.dataJson, overlayType) && overlayType == "audio_reactive") {
                continue;
            }

            const auto itOverride = overrides.find(asset.id);
            const Asset& renderAsset = (itOverride != overrides.end()) ? itOverride->second : asset;
            TimeMs localTime = Timeline::getLocalTime(renderAsset, timeMs);

            switch (renderAsset.type) {
                case AssetType::Video:
                case AssetType::Image:
                    m_renderer->renderMedia(renderAsset, localTime);
                    break;
                case AssetType::Text:
                    m_renderer->renderText(renderAsset, localTime);
                    break;
                case AssetType::Visualizer:
                    m_renderer->renderVisualizer(renderAsset, m_currentJob->fftData, localTime);
                    break;
                default:
                    break;
            }
        }
    }

    // Pass 2: apply shader assets as post-process (in layer/z order)
    for (const auto& layer : layers) {
        for (const auto& asset : layer.assets) {
            if (asset.type != AssetType::Shader) {
                continue;
            }
            std::string overlayType;
            if (vvParseOverlayType(asset.dataJson, overlayType) && overlayType == "audio_reactive") {
                continue;
            }
            TimeMs dur = asset.duration;
            if (dur <= 0) {
                dur = m_currentJob ? m_currentJob->totalDuration : 0;
            }
            if (dur <= 0) {
                dur = std::numeric_limits<TimeMs>::max() / 4;
            }
            if (timeMs < asset.begin || timeMs >= asset.begin + dur) {
                continue;
            }
            const auto itOverride = overrides.find(asset.id);
            const Asset& renderAsset = (itOverride != overrides.end()) ? itOverride->second : asset;
            TimeMs localTime = Timeline::getLocalTime(renderAsset, timeMs);
            m_renderer->renderShader(renderAsset, m_shaderManager.get(), localTime);
        }
    }

    m_renderer->endFrame();

    if (m_cancelRequested) {
        return Result::ErrorCancelled;
    }

    const int64_t ptsUs = static_cast<int64_t>(timeMs) * 1000;
    if (!m_renderer->presentFrame(ptsUs)) {
        return Result::ErrorEncodeFailed;
    }

    if (m_cancelRequested) {
        return Result::ErrorCancelled;
    }

    if (!m_encoder->drain()) {
        return Result::ErrorEncodeFailed;
    }

    return Result::Success;
}

void Engine::cleanupJob() {
    m_currentJob.reset();
    m_currentFrame.store(0);
    m_totalFrames.store(0);

    if (m_shaderManager) {
        m_shaderManager->clearAll();
    }
}

} // namespace vidviz

// =============================================================================
// FFI Implementation
// =============================================================================

static std::unique_ptr<vidviz::Engine> g_engine;
static std::string g_last_init_error;

VIDVIZ_EXTERN_C {

VIDVIZ_API void* vidviz_engine_init() {
    g_last_init_error.clear();
    if (g_engine) {
        return g_engine.get();
    }

    g_engine = std::make_unique<vidviz::Engine>();

    vidviz::Result initRes = vidviz::Result::Success;

#if defined(__ANDROID__)
    auto rendererA = std::make_unique<vidviz::android::GlesSurfaceRenderer>();
    auto encoderA = std::make_unique<vidviz::android::MediaCodecEncoder>();
    initRes = g_engine->initialize(std::move(rendererA), std::move(encoderA));
#endif

#if defined(__APPLE__)
#if TARGET_OS_IPHONE
    auto rendererI = std::make_unique<vidviz::ios::MetalRenderer>();
    auto encoderI = std::make_unique<vidviz::ios::AVFoundationEncoder>();
    initRes = g_engine->initialize(std::move(rendererI), std::move(encoderI));
#endif
#endif

    if (initRes != vidviz::Result::Success) {
        g_last_init_error = g_engine ? g_engine->getLastInitError() : std::string("Engine init failed");
        if (g_last_init_error.empty()) {
            g_last_init_error = "Engine init failed";
        }
        LOGE("vidviz_engine_init failed (code=%d): %s", (int)initRes, g_last_init_error.c_str());
        g_engine.reset();
        return nullptr;
    }

    return g_engine.get();
}

VIDVIZ_API void vidviz_engine_destroy(void* handle) {
    if (g_engine.get() == handle) {
        g_engine.reset();
    }
}

VIDVIZ_API int32_t vidviz_submit_job(void* handle, const char* jobJson) {
    auto* engine = static_cast<vidviz::Engine*>(handle);
    if (!engine || !jobJson) {
        return static_cast<int32_t>(vidviz::Result::ErrorInvalidHandle);
    }
    return static_cast<int32_t>(engine->submitJob(std::string(jobJson)));
}

VIDVIZ_API void vidviz_cancel_job(void* handle) {
    auto* engine = static_cast<vidviz::Engine*>(handle);
    if (engine) {
        engine->cancelJob();
    }
}

VIDVIZ_API const char* vidviz_get_status(void* handle) {
    auto* engine = static_cast<vidviz::Engine*>(handle);
    if (!engine) {
        return nullptr;
    }
    
    std::string status = engine->getStatusJson();
    char* result = static_cast<char*>(malloc(status.size() + 1));
    if (result) {
        strcpy(result, status.c_str());
    }
    return result;
}

VIDVIZ_API void vidviz_set_progress_callback(
    void* handle,
    void (*callback)(double, int32_t, int32_t)
) {
    auto* engine = static_cast<vidviz::Engine*>(handle);
    if (!engine) return;
    
    if (callback) {
        engine->setProgressCallback([callback](float p, int32_t f, int32_t t) {
            callback(static_cast<double>(p), f, t);
        });
    } else {
        engine->setProgressCallback(nullptr);
    }
}

VIDVIZ_API void vidviz_set_completion_callback(
    void* handle,
    void (*callback)(bool, const char*, const char*)
) {
    auto* engine = static_cast<vidviz::Engine*>(handle);
    if (!engine) return;
    
    if (callback) {
        engine->setCompletionCallback([callback](bool s, const std::string& path, const std::string& err) {
            callback(s, path.c_str(), err.c_str());
        });
    } else {
        engine->setCompletionCallback(nullptr);
    }
}

VIDVIZ_API void vidviz_free_string(const char* str) {
    if (str) {
        free(const_cast<char*>(str));
    }
}

VIDVIZ_API const char* vidviz_get_last_init_error() {
    if (g_last_init_error.empty()) {
        return nullptr;
    }
    char* result = static_cast<char*>(malloc(g_last_init_error.size() + 1));
    if (!result) return nullptr;
    strcpy(result, g_last_init_error.c_str());
    return result;
}

} // extern "C"
