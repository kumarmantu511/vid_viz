#include "platform/android/renderer/gles/visualizer_renderer.h"

#include "common/minijson.h"

#include <algorithm>

namespace vidviz {
namespace android {
namespace gles {

static inline float clamp01(float v) {
    if (!std::isfinite(v)) return 0.0f;
    if (v < 0.0f) return 0.0f;
    if (v > 1.0f) return 1.0f;
    return v;
}

static float progressThemeIndex(const std::string& theme) {
    if (theme == "fire") return 1.0f;
    if (theme == "electric") return 2.0f;
    if (theme == "neon") return 3.0f;
    if (theme == "rainbow") return 4.0f;
    if (theme == "glitch") return 5.0f;
    if (theme == "soft") return 6.0f;
    if (theme == "sunset") return 7.0f;
    if (theme == "ice") return 8.0f;
    if (theme == "matrix") return 9.0f;
    return 0.0f;
}

static float progressHeadStyleIndex(const std::string& style) {
    if (style == "none") return 0.0f;
    if (style == "static") return 0.0f;
    if (style == "spark") return 2.0f;
    return 1.0f;
}

bool parseVisualizerParams(const std::string& dataJson, VisualizerParams& out) {
    out = VisualizerParams{};
 
    out.renderMode = "canvas";
    out.shaderType.clear();
    out.type = "bars";
    out.audioPath.clear();
    out.projectDurationMs = 0;
    out.fullScreen = false;
    out.alpha = 1.0f;
    out.sensitivity = 1.0f;
    out.speed = 1.0f;
    out.smoothness = 0.6f;
    out.reactivity = 1.0f;
    out.x = 0.5f;
    out.y = 0.5f;
    out.scale = 1.0f;
    out.rotation = 0.0f;
    out.barCount = 32;
    out.color = 0xFFFFFFFF;
    out.gradientColor = 0;

    out.amplitude = 1.0f;
    out.barFill = 0.75f;
    out.glow = 0.0f;
    out.strokeWidth = 2.5f;
    out.mirror = false;
    out.effectStyle = "default";

    out.progressTrackAlpha = 0.35f;
    out.progressCorner = 0.7f;
    out.progressGap = 0.25f;
    out.progressEffectAmount = 1.0f;
    out.progressHeadAmount = 0.0f;
    out.progressHeadSize = 0.5f;
    out.progressThemeIdx = 0.0f;
    out.progressHeadStyleIdx = 1.0f;
    out.hasProgressTrackColor = false;
    out.progressTrackColor = 0;

    out.counterStartEnabled = true;
    out.counterEndEnabled = true;
    out.counterPos = "side";
    out.counterStartMode = "elapsed";
    out.counterEndMode = "remaining";
    out.counterLabelSize = "normal";
    out.counterAnim = "none";
    out.counterOffsetY = 0.0f;

    out.counterStartWeight = "semibold";
    out.counterEndWeight = "semibold";
    out.counterStartShadowOpacity = 0.75f;
    out.counterStartShadowBlur = 2.0f;
    out.counterStartShadowOffsetX = 0.0f;
    out.counterStartShadowOffsetY = 1.0f;
    out.counterEndShadowOpacity = 0.75f;
    out.counterEndShadowBlur = 2.0f;
    out.counterEndShadowOffsetX = 0.0f;
    out.counterEndShadowOffsetY = 1.0f;
    out.counterStartGlowRadius = 0.0f;
    out.counterStartGlowOpacity = 0.0f;
    out.counterEndGlowRadius = 0.0f;
    out.counterEndGlowOpacity = 0.0f;

    out.counterStartPosX = -1.0f;
    out.counterStartPosY = -1.0f;
    out.counterEndPosX = -1.0f;
    out.counterEndPosY = -1.0f;
    out.hasCounterStartColor = false;
    out.counterStartColor = 0;
    out.hasCounterEndColor = false;
    out.counterEndColor = 0;

    if (dataJson.empty()) return false;
    const auto parsed = minijson::parse(dataJson);
    if (!parsed.ok()) return false;
    const auto* root = parsed.value.asObject();
    if (!root) return false;
    const minijson::Value* visV = minijson::get(*root, "visualizer");
    const auto* visO = visV ? visV->asObject() : nullptr;
    if (!visO) return false;

    minijson::getString(*visO, "renderMode", &out.renderMode);
    minijson::getString(*visO, "shaderType", &out.shaderType);
    minijson::getString(*visO, "type", &out.type);
    minijson::getString(*visO, "audioPath", &out.audioPath);
    minijson::getString(*visO, "effectStyle", &out.effectStyle);

    bool bb = false;
    if (minijson::getBool(*visO, "fullScreen", &bb)) out.fullScreen = bb;

    double d = 0.0;
    if (minijson::getDouble(*visO, "alpha", &d)) out.alpha = static_cast<float>(d);
    if (minijson::getDouble(*visO, "sensitivity", &d)) out.sensitivity = static_cast<float>(d);
    if (minijson::getDouble(*visO, "speed", &d)) out.speed = static_cast<float>(d);
    if (minijson::getDouble(*visO, "smoothness", &d)) out.smoothness = static_cast<float>(d);
    if (minijson::getDouble(*visO, "reactivity", &d)) out.reactivity = static_cast<float>(d);
    if (minijson::getDouble(*visO, "x", &d)) out.x = static_cast<float>(d);
    if (minijson::getDouble(*visO, "y", &d)) out.y = static_cast<float>(d);
    if (minijson::getDouble(*visO, "scale", &d)) out.scale = static_cast<float>(d);
    if (minijson::getDouble(*visO, "rotation", &d)) out.rotation = static_cast<float>(d);

    if (minijson::getDouble(*visO, "amplitude", &d)) out.amplitude = static_cast<float>(d);
    if (minijson::getDouble(*visO, "barSpacing", &d)) out.barFill = static_cast<float>(d);
    if (minijson::getDouble(*visO, "glowIntensity", &d)) out.glow = static_cast<float>(d);
    if (minijson::getDouble(*visO, "strokeWidth", &d)) out.strokeWidth = static_cast<float>(d);

    bool bm = false;
    if (minijson::getBool(*visO, "mirror", &bm)) out.mirror = bm;

    int64_t i64 = 0;
    if (minijson::getInt64(*visO, "projectDuration", &i64)) out.projectDurationMs = i64;
    if (minijson::getInt64(*visO, "barCount", &i64)) out.barCount = static_cast<int32_t>(i64);
    if (minijson::getInt64(*visO, "color", &i64)) out.color = i64;
    if (minijson::getInt64(*visO, "gradientColor", &i64)) out.gradientColor = i64;

    // shaderParams for progress-bar extras (optional)
    const minijson::Value* paramsV = minijson::get(*visO, "shaderParams");
    const auto* paramsO = paramsV ? paramsV->asObject() : nullptr;
    if (paramsO) {
        if (minijson::getDouble(*paramsO, "progressTrackAlpha", &d)) out.progressTrackAlpha = static_cast<float>(d);
        if (minijson::getDouble(*paramsO, "progressCorner", &d)) out.progressCorner = static_cast<float>(d);
        if (minijson::getDouble(*paramsO, "progressGap", &d)) out.progressGap = static_cast<float>(d);
        if (minijson::getDouble(*paramsO, "progressEffectAmount", &d)) out.progressEffectAmount = static_cast<float>(d);
        if (minijson::getDouble(*paramsO, "progressHeadAmount", &d)) out.progressHeadAmount = static_cast<float>(d);
        if (minijson::getDouble(*paramsO, "progressHeadSize", &d)) out.progressHeadSize = static_cast<float>(d);

        std::string theme;
        if (minijson::getString(*paramsO, "progressTheme", &theme)) {
            out.progressThemeIdx = progressThemeIndex(theme);
        }
        std::string headStyle;
        if (minijson::getString(*paramsO, "progressHeadStyle", &headStyle)) {
            out.progressHeadStyleIdx = progressHeadStyleIndex(headStyle);
        }

        if (minijson::getInt64(*paramsO, "progressTrackColor", &i64)) {
            out.hasProgressTrackColor = true;
            out.progressTrackColor = i64;
        }

        bool bb2 = false;
        if (minijson::getBool(*paramsO, "counterStartEnabled", &bb2)) out.counterStartEnabled = bb2;
        if (minijson::getBool(*paramsO, "counterEndEnabled", &bb2)) out.counterEndEnabled = bb2;
        minijson::getString(*paramsO, "counterPos", &out.counterPos);
        minijson::getString(*paramsO, "counterStartMode", &out.counterStartMode);
        minijson::getString(*paramsO, "counterEndMode", &out.counterEndMode);
        minijson::getString(*paramsO, "counterLabelSize", &out.counterLabelSize);
        minijson::getString(*paramsO, "counterAnim", &out.counterAnim);
        if (minijson::getDouble(*paramsO, "counterOffsetY", &d)) out.counterOffsetY = static_cast<float>(d);

        minijson::getString(*paramsO, "counterStartWeight", &out.counterStartWeight);
        minijson::getString(*paramsO, "counterEndWeight", &out.counterEndWeight);

        if (minijson::getDouble(*paramsO, "counterStartShadowOpacity", &d)) out.counterStartShadowOpacity = static_cast<float>(d);
        if (minijson::getDouble(*paramsO, "counterStartShadowBlur", &d)) out.counterStartShadowBlur = static_cast<float>(d);
        if (minijson::getDouble(*paramsO, "counterStartShadowOffsetX", &d)) out.counterStartShadowOffsetX = static_cast<float>(d);
        if (minijson::getDouble(*paramsO, "counterStartShadowOffsetY", &d)) out.counterStartShadowOffsetY = static_cast<float>(d);
        if (minijson::getDouble(*paramsO, "counterEndShadowOpacity", &d)) out.counterEndShadowOpacity = static_cast<float>(d);
        if (minijson::getDouble(*paramsO, "counterEndShadowBlur", &d)) out.counterEndShadowBlur = static_cast<float>(d);
        if (minijson::getDouble(*paramsO, "counterEndShadowOffsetX", &d)) out.counterEndShadowOffsetX = static_cast<float>(d);
        if (minijson::getDouble(*paramsO, "counterEndShadowOffsetY", &d)) out.counterEndShadowOffsetY = static_cast<float>(d);

        if (minijson::getDouble(*paramsO, "counterStartGlowRadius", &d)) out.counterStartGlowRadius = static_cast<float>(d);
        if (minijson::getDouble(*paramsO, "counterStartGlowOpacity", &d)) out.counterStartGlowOpacity = static_cast<float>(d);
        if (minijson::getDouble(*paramsO, "counterEndGlowRadius", &d)) out.counterEndGlowRadius = static_cast<float>(d);
        if (minijson::getDouble(*paramsO, "counterEndGlowOpacity", &d)) out.counterEndGlowOpacity = static_cast<float>(d);

        if (minijson::getDouble(*paramsO, "counterStartPosX", &d)) out.counterStartPosX = static_cast<float>(d);
        if (minijson::getDouble(*paramsO, "counterStartPosY", &d)) out.counterStartPosY = static_cast<float>(d);
        if (minijson::getDouble(*paramsO, "counterEndPosX", &d)) out.counterEndPosX = static_cast<float>(d);
        if (minijson::getDouble(*paramsO, "counterEndPosY", &d)) out.counterEndPosY = static_cast<float>(d);

        if (minijson::getInt64(*paramsO, "counterStartColor", &i64)) {
            out.hasCounterStartColor = true;
            out.counterStartColor = i64;
        }
        if (minijson::getInt64(*paramsO, "counterEndColor", &i64)) {
            out.hasCounterEndColor = true;
            out.counterEndColor = i64;
        }
    }

    // Clamp progress params
    out.progressTrackAlpha = clamp01(out.progressTrackAlpha);
    out.progressCorner = clamp01(out.progressCorner);
    out.progressGap = clamp01(out.progressGap);
    out.progressEffectAmount = clamp01(out.progressEffectAmount);
    out.progressHeadAmount = clamp01(out.progressHeadAmount);
    out.progressHeadSize = clamp01(out.progressHeadSize);

    out.alpha = clamp01(out.alpha);
    if (!std::isfinite(out.counterOffsetY)) out.counterOffsetY = 0.0f;
    if (out.counterOffsetY < -120.0f) out.counterOffsetY = -120.0f;
    if (out.counterOffsetY > 120.0f) out.counterOffsetY = 120.0f;

    if (out.counterStartWeight != "normal" && out.counterStartWeight != "semibold" && out.counterStartWeight != "bold") {
        out.counterStartWeight = "semibold";
    }
    if (out.counterEndWeight != "normal" && out.counterEndWeight != "semibold" && out.counterEndWeight != "bold") {
        out.counterEndWeight = "semibold";
    }

    out.counterStartShadowOpacity = clamp01(out.counterStartShadowOpacity);
    out.counterEndShadowOpacity = clamp01(out.counterEndShadowOpacity);
    if (!std::isfinite(out.counterStartShadowBlur)) out.counterStartShadowBlur = 0.0f;
    if (!std::isfinite(out.counterEndShadowBlur)) out.counterEndShadowBlur = 0.0f;
    if (out.counterStartShadowBlur < 0.0f) out.counterStartShadowBlur = 0.0f;
    if (out.counterStartShadowBlur > 30.0f) out.counterStartShadowBlur = 30.0f;
    if (out.counterEndShadowBlur < 0.0f) out.counterEndShadowBlur = 0.0f;
    if (out.counterEndShadowBlur > 30.0f) out.counterEndShadowBlur = 30.0f;

    if (!std::isfinite(out.counterStartShadowOffsetX)) out.counterStartShadowOffsetX = 0.0f;
    if (!std::isfinite(out.counterStartShadowOffsetY)) out.counterStartShadowOffsetY = 0.0f;
    if (!std::isfinite(out.counterEndShadowOffsetX)) out.counterEndShadowOffsetX = 0.0f;
    if (!std::isfinite(out.counterEndShadowOffsetY)) out.counterEndShadowOffsetY = 0.0f;
    if (out.counterStartShadowOffsetX < -30.0f) out.counterStartShadowOffsetX = -30.0f;
    if (out.counterStartShadowOffsetX > 30.0f) out.counterStartShadowOffsetX = 30.0f;
    if (out.counterStartShadowOffsetY < -30.0f) out.counterStartShadowOffsetY = -30.0f;
    if (out.counterStartShadowOffsetY > 30.0f) out.counterStartShadowOffsetY = 30.0f;
    if (out.counterEndShadowOffsetX < -30.0f) out.counterEndShadowOffsetX = -30.0f;
    if (out.counterEndShadowOffsetX > 30.0f) out.counterEndShadowOffsetX = 30.0f;
    if (out.counterEndShadowOffsetY < -30.0f) out.counterEndShadowOffsetY = -30.0f;
    if (out.counterEndShadowOffsetY > 30.0f) out.counterEndShadowOffsetY = 30.0f;

    if (!std::isfinite(out.counterStartGlowRadius)) out.counterStartGlowRadius = 0.0f;
    if (!std::isfinite(out.counterEndGlowRadius)) out.counterEndGlowRadius = 0.0f;
    if (out.counterStartGlowRadius < 0.0f) out.counterStartGlowRadius = 0.0f;
    if (out.counterStartGlowRadius > 60.0f) out.counterStartGlowRadius = 60.0f;
    if (out.counterEndGlowRadius < 0.0f) out.counterEndGlowRadius = 0.0f;
    if (out.counterEndGlowRadius > 60.0f) out.counterEndGlowRadius = 60.0f;
    out.counterStartGlowOpacity = clamp01(out.counterStartGlowOpacity);
    out.counterEndGlowOpacity = clamp01(out.counterEndGlowOpacity);

    if (!std::isfinite(out.counterStartPosX)) out.counterStartPosX = -1.0f;
    if (!std::isfinite(out.counterStartPosY)) out.counterStartPosY = -1.0f;
    if (!std::isfinite(out.counterEndPosX)) out.counterEndPosX = -1.0f;
    if (!std::isfinite(out.counterEndPosY)) out.counterEndPosY = -1.0f;

    if (out.counterStartPosX >= 0.0f) out.counterStartPosX = clamp01(out.counterStartPosX);
    if (out.counterStartPosY >= 0.0f) out.counterStartPosY = clamp01(out.counterStartPosY);
    if (out.counterEndPosX >= 0.0f) out.counterEndPosX = clamp01(out.counterEndPosX);
    if (out.counterEndPosY >= 0.0f) out.counterEndPosY = clamp01(out.counterEndPosY);

    return true;
}

std::string pickVisualizerShaderId(const VisualizerParams& p) {
    if (p.renderMode == "progress") {
        return "progress";
    }
    if (p.renderMode == "shader" || p.renderMode == "visual") {
        return p.shaderType.empty() ? "bar" : p.shaderType;
    }

    if (p.type == "bars") return "bar";
    if (p.type == "wave") return "wav";
    if (p.type == "circle") return "circle";
    if (p.type == "spectrum") return "bar_circle";
    if (p.type == "particle") return "fractal";
    return "bar";
}

const FFTData* findFftByAudioPath(const std::vector<FFTData>& fftData, const std::string& audioPath) {
    if (audioPath.empty()) return nullptr;
    for (const auto& f : fftData) {
        if (f.audioPath == audioPath) return &f;
    }
    return nullptr;
}

void fillFft8(const std::vector<float>* frame, float out8[8]) {
    for (int i = 0; i < 8; i++) out8[i] = 0.0f;
    if (!frame || frame->empty()) return;

    const int n = static_cast<int>(frame->size());
    const int bins = 8;
    for (int b = 0; b < bins; b++) {
        const int start = (b * n) / bins;
        const int end = ((b + 1) * n) / bins;
        if (end <= start) continue;
        float sum = 0.0f;
        int cnt = 0;
        for (int i = start; i < end; i++) {
            float v = (*frame)[i];
            if (!std::isfinite(v)) v = 0.0f;
            if (v < 0.0f) v = 0.0f;
            if (v > 1.0f) v = 1.0f;
            sum += v;
            cnt++;
        }
        out8[b] = (cnt > 0) ? (sum / static_cast<float>(cnt)) : 0.0f;
    }
}

} // namespace gles
} // namespace android
} // namespace vidviz
