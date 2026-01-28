/**
 * VidViz Engine - Job Parser Implementation
 * 
 * Uses nlohmann/json (header-only, included in common/)
 */

#include "job_parser.h"
#include "common/log.h"

#include "common/minijson.h"

// Simple JSON parsing without external dependency for now
// In production, use nlohmann/json or rapidjson

#include <cstdint>
#include <algorithm>
#include <limits>

namespace vidviz {

JobParser::JobParser() = default;
JobParser::~JobParser() = default;

std::unique_ptr<ExportJob> JobParser::parse(const std::string& json) {
    if (json.empty()) {
        LOGE("Empty JSON");
        return nullptr;
    }

    auto job = std::make_unique<ExportJob>();

    try {
        const auto parsed = minijson::parse(json);
        if (!parsed.ok()) {
            LOGE("JSON parse error: %s", parsed.error.c_str());
            return nullptr;
        }

        const auto* rootObj = parsed.value.asObject();
        if (!rootObj) {
            LOGE("Job JSON root is not an object");
            return nullptr;
        }

        if (!minijson::getString(*rootObj, "jobId", &job->jobId) || job->jobId.empty()) {
            LOGE("Job JSON missing jobId");
            return nullptr;
        }
        int64_t totalDurationMs = 0;
        if (minijson::getInt64(*rootObj, "totalDuration", &totalDurationMs)) {
            job->totalDuration = totalDurationMs;
        }

        const minijson::Value::Object* settingsObj = nullptr;
        if (const minijson::Value* settingsV = minijson::get(*rootObj, "settings")) {
            settingsObj = settingsV->asObject();
        }
        const minijson::Value::Object& s = settingsObj ? *settingsObj : *rootObj;

        int64_t i64 = 0;
        if (minijson::getInt64(s, "width", &i64)) job->settings.width = static_cast<int32_t>(i64);
        if (minijson::getInt64(s, "height", &i64)) job->settings.height = static_cast<int32_t>(i64);
        if (minijson::getInt64(s, "fps", &i64)) job->settings.fps = static_cast<int32_t>(i64);
        if (minijson::getInt64(s, "quality", &i64)) job->settings.quality = static_cast<int32_t>(i64);
        minijson::getString(s, "aspectRatio", &job->settings.aspectRatio);
        minijson::getString(s, "cropMode", &job->settings.cropMode);
        if (minijson::getInt64(s, "rotation", &i64)) job->settings.rotation = static_cast<int32_t>(i64);
        bool bSettings = false;
        if (minijson::getBool(s, "flipHorizontal", &bSettings)) job->settings.flipHorizontal = bSettings;
        if (minijson::getBool(s, "flipVertical", &bSettings)) job->settings.flipVertical = bSettings;
        if (minijson::getInt64(s, "backgroundColor", &i64)) job->settings.backgroundColor = i64;
        minijson::getString(s, "outputFormat", &job->settings.outputFormat);
        minijson::getString(s, "outputPath", &job->settings.outputPath);

        // Optional UI preview metrics for parity (Flutter logical-pixel space).
        // These fields may be absent for older jobs.
        double uiD = 0.0;
        if (minijson::getDouble(s, "uiPlayerWidth", &uiD)) job->settings.uiPlayerWidth = static_cast<float>(uiD);
        if (minijson::getDouble(s, "uiPlayerHeight", &uiD)) job->settings.uiPlayerHeight = static_cast<float>(uiD);
        if (minijson::getDouble(s, "uiDevicePixelRatio", &uiD)) job->settings.uiDevicePixelRatio = static_cast<float>(uiD);

        if (job->settings.width <= 0) job->settings.width = 1920;
        if (job->settings.height <= 0) job->settings.height = 1080;
        if (job->settings.fps <= 0) job->settings.fps = 30;

        if (const minijson::Value* layersV = minijson::get(*rootObj, "layers")) {
            if (const auto* layersA = layersV->asArray()) {
                job->layers.reserve(layersA->size());
                for (const auto& layerV : *layersA) {
                    const auto* layerO = layerV.asObject();
                    if (!layerO) continue;

                    Layer layer;
                    minijson::getString(*layerO, "id", &layer.id);
                    minijson::getString(*layerO, "name", &layer.name);

                    std::string layerType;
                    minijson::getString(*layerO, "type", &layerType);
                    layer.type = parseLayerType(layerType);

                    double d = 0.0;
                    if (minijson::getDouble(*layerO, "zIndex", &d)) layer.zIndex = static_cast<int32_t>(d);
                    if (minijson::getDouble(*layerO, "volume", &d)) layer.volume = static_cast<float>(d);
                    bool b = false;
                    if (minijson::getBool(*layerO, "mute", &b)) layer.mute = b;

                    bool useVideoAudio = (layer.type == LayerType::Raster);
                    if (minijson::getBool(*layerO, "useVideoAudio", &b)) useVideoAudio = b;
                    layer.useVideoAudio = useVideoAudio;

                    if (const minijson::Value* assetsV = minijson::get(*layerO, "assets")) {
                        if (const auto* assetsA = assetsV->asArray()) {
                            layer.assets.reserve(assetsA->size());
                            for (const auto& assetV : *assetsA) {
                                const auto* assetO = assetV.asObject();
                                if (!assetO) continue;

                                Asset asset;
                                minijson::getString(*assetO, "id", &asset.id);
                                minijson::getString(*assetO, "srcPath", &asset.srcPath);

                                std::string assetType;
                                minijson::getString(*assetO, "type", &assetType);
                                asset.type = parseAssetType(assetType);

                                int64_t t = 0;
                                if (minijson::getInt64(*assetO, "begin", &t)) asset.begin = t;
                                if (minijson::getInt64(*assetO, "duration", &t)) asset.duration = t;
                                if (minijson::getInt64(*assetO, "cutFrom", &t)) asset.cutFrom = t;

                                double spd = 1.0;
                                if (minijson::getDouble(*assetO, "playbackSpeed", &spd)) {
                                    asset.playbackSpeed = static_cast<float>(spd);
                                }

                                if (const minijson::Value* dataV = minijson::get(*assetO, "data")) {
                                    if (!dataV->isNull()) {
                                        asset.dataJson = minijson::stringify(*dataV);
                                    }
                                }

                                layer.assets.push_back(std::move(asset));
                            }
                        }
                    }

                    job->layers.push_back(std::move(layer));
                }
            }
        }

        std::sort(
            job->layers.begin(),
            job->layers.end(),
            [](const Layer& a, const Layer& b) { return a.zIndex < b.zIndex; }
        );

        if (const minijson::Value* shadersV = minijson::get(*rootObj, "shaders")) {
            if (const auto* shadersA = shadersV->asArray()) {
                job->shaders.reserve(shadersA->size());
                for (const auto& shaderV : *shadersA) {
                    const auto* shaderO = shaderV.asObject();
                    if (!shaderO) continue;

                    ShaderProgram shader;
                    minijson::getString(*shaderO, "id", &shader.id);
                    minijson::getString(*shaderO, "name", &shader.name);

                    std::string src;
                    minijson::getString(*shaderO, "source", &src);
                    shader.fragmentSource = std::move(src);
                    shader.vertexSource.clear();

                    if (const minijson::Value* uniformsV = minijson::get(*shaderO, "uniforms")) {
                        if (const auto* uniformsO = uniformsV->asObject()) {
                            shader.uniforms.reserve(uniformsO->size());
                            for (const auto& kv : *uniformsO) {
                                ShaderUniform u;
                                u.name = kv.first;

                                if (const double* n = kv.second.asNumber()) {
                                    u.type = ShaderUniform::Type::Float;
                                    u.values = {static_cast<float>(*n)};
                                } else if (const bool* bb = kv.second.asBool()) {
                                    u.type = ShaderUniform::Type::Int;
                                    u.values = {static_cast<float>(*bb ? 1 : 0)};
                                } else if (const auto* arr = kv.second.asArray()) {
                                    if (arr->size() == 2) u.type = ShaderUniform::Type::Vec2;
                                    else if (arr->size() == 3) u.type = ShaderUniform::Type::Vec3;
                                    else if (arr->size() == 4) u.type = ShaderUniform::Type::Vec4;
                                    else u.type = ShaderUniform::Type::Float;

                                    u.values.clear();
                                    u.values.reserve(arr->size());
                                    for (const auto& item : *arr) {
                                        if (const double* n = item.asNumber()) {
                                            u.values.push_back(static_cast<float>(*n));
                                        }
                                    }
                                } else {
                                    u.type = ShaderUniform::Type::Float;
                                    u.values = {0.0f};
                                }

                                shader.uniforms.push_back(std::move(u));
                            }
                        }
                    }

                    job->shaders.push_back(std::move(shader));
                }
            }
        }

        if (const minijson::Value* fftV = minijson::get(*rootObj, "fftData")) {
            if (const auto* fftA = fftV->asArray()) {
                job->fftData.reserve(fftA->size());

                constexpr size_t kMaxFrames = 20000;
                constexpr size_t kMaxBands = 4096;

                for (const auto& itemV : *fftA) {
                    const auto* itemO = itemV.asObject();
                    if (!itemO) continue;

                    FFTData fft;
                    minijson::getString(*itemO, "audioPath", &fft.audioPath);
                    if (minijson::getInt64(*itemO, "sampleRate", &i64)) fft.sampleRate = static_cast<int32_t>(i64);
                    if (minijson::getInt64(*itemO, "hopSize", &i64)) fft.hopSize = static_cast<int32_t>(i64);

                    if (const minijson::Value* framesV = minijson::get(*itemO, "frames")) {
                        if (const auto* framesA = framesV->asArray()) {
                            if (framesA->size() > kMaxFrames) {
                                LOGE("FFT frames too large: %zu", framesA->size());
                                return nullptr;
                            }
                            fft.frames.reserve(framesA->size());
                            for (const auto& frameV : *framesA) {
                                const auto* bandsA = frameV.asArray();
                                if (!bandsA) continue;
                                if (bandsA->size() > kMaxBands) {
                                    LOGE("FFT band count too large: %zu", bandsA->size());
                                    return nullptr;
                                }
                                std::vector<float> bands;
                                bands.reserve(bandsA->size());
                                for (const auto& bandV : *bandsA) {
                                    if (const double* n = bandV.asNumber()) {
                                        bands.push_back(static_cast<float>(*n));
                                    } else {
                                        bands.push_back(0.0f);
                                    }
                                }
                                fft.frames.push_back(std::move(bands));
                            }
                        }
                    }

                    job->fftData.push_back(std::move(fft));
                }
            }
        }

        LOGI("Parsed job: %s, %dx%d @ %dfps, duration: %lldms",
             job->jobId.c_str(),
             job->settings.width,
             job->settings.height,
             job->settings.fps,
             job->totalDuration);

    } catch (const std::exception& e) {
        LOGE("JSON parse error: %s", e.what());
        return nullptr;
    }

    return job;
}

AssetType JobParser::parseAssetType(const std::string& typeStr) {
    if (typeStr == "video" || typeStr == "AssetType.video") return AssetType::Video;
    if (typeStr == "image" || typeStr == "AssetType.image") return AssetType::Image;
    if (typeStr == "audio" || typeStr == "AssetType.audio") return AssetType::Audio;
    if (typeStr == "text" || typeStr == "AssetType.text") return AssetType::Text;
    if (typeStr == "shader" || typeStr == "AssetType.shader") return AssetType::Shader;
    if (typeStr == "visualizer" || typeStr == "AssetType.visualizer") return AssetType::Visualizer;
    return AssetType::Image; // default
}

LayerType JobParser::parseLayerType(const std::string& typeStr) {
    if (typeStr == "raster" || typeStr == "LayerType.raster") return LayerType::Raster;
    if (typeStr == "audio" || typeStr == "LayerType.audio") return LayerType::Audio;
    if (typeStr == "text" || typeStr == "LayerType.text") return LayerType::Text;
    if (typeStr == "shader" || typeStr == "LayerType.shader") return LayerType::Shader;
    if (typeStr == "visualizer" || typeStr == "LayerType.visualizer") return LayerType::Visualizer;
    return LayerType::Raster; // default
}

} // namespace vidviz
