#pragma once

#include <cstdint>
#include <string>
#include <vector>

#include "common/types.h"

namespace vidviz {
namespace android {
namespace gles {

struct VisualizerParams {
    std::string renderMode;
    std::string shaderType;
    std::string type;
    std::string audioPath;
    int64_t beginMs = 0;
    int64_t durationMs = 0;
    int64_t projectDurationMs = 0;
    bool fullScreen = false;
    float alpha = 1.0f;
    float sensitivity = 1.0f;
    float speed = 1.0f;
    float smoothness = 0.6f;
    float reactivity = 1.0f;
    float x = 0.5f;
    float y = 0.5f;
    float scale = 1.0f;
    float rotation = 0.0f;
    int32_t barCount = 32;
    int64_t color = 0xFFFFFFFF;
    int64_t gradientColor = 0;

    // Flutter parity extras
    float amplitude = 1.0f;    // maps to uIntensity
    float barFill = 0.75f;     // maps to uBarFill
    float glow = 0.0f;         // maps to uGlow
    float strokeWidth = 2.5f;  // maps to uStroke / uThickness
    bool mirror = false;
    std::string effectStyle = "default";

    // Progress-bar specific (optional)
    float progressTrackAlpha = 0.35f;
    float progressCorner = 0.7f;
    float progressGap = 0.25f;
    float progressEffectAmount = 1.0f;
    float progressHeadAmount = 0.0f;
    float progressHeadSize = 0.5f;
    float progressThemeIdx = 0.0f;
    float progressHeadStyleIdx = 1.0f;
    bool hasProgressTrackColor = false;
    int64_t progressTrackColor = 0;

    // Counter (renderMode == "counter")
    bool counterStartEnabled = true;
    bool counterEndEnabled = true;
    std::string counterPos = "side";
    std::string counterStartMode = "elapsed";
    std::string counterEndMode = "remaining";
    std::string counterLabelSize = "normal";
    std::string counterAnim = "pulse";
    float counterOffsetY = 0.0f;

    // Counter text style (Flutter parity)
    std::string counterStartWeight = "semibold";
    std::string counterEndWeight = "semibold";
    float counterStartShadowOpacity = 0.75f;
    float counterStartShadowBlur = 2.0f;
    float counterStartShadowOffsetX = 0.0f;
    float counterStartShadowOffsetY = 1.0f;
    float counterEndShadowOpacity = 0.75f;
    float counterEndShadowBlur = 2.0f;
    float counterEndShadowOffsetX = 0.0f;
    float counterEndShadowOffsetY = 1.0f;
    float counterStartGlowRadius = 0.0f;
    float counterStartGlowOpacity = 0.0f;
    float counterEndGlowRadius = 0.0f;
    float counterEndGlowOpacity = 0.0f;

    // New counter params (Flutter parity)
    float counterStartPosX = -1.0f;
    float counterStartPosY = -1.0f;
    float counterEndPosX = -1.0f;
    float counterEndPosY = -1.0f;
    bool hasCounterStartColor = false;
    int64_t counterStartColor = 0;
    bool hasCounterEndColor = false;
    int64_t counterEndColor = 0;
};

bool parseVisualizerParams(const std::string& dataJson, VisualizerParams& out);

std::string pickVisualizerShaderId(const VisualizerParams& p);

const FFTData* findFftByAudioPath(const std::vector<FFTData>& fftData, const std::string& audioPath);

void fillFft8(const std::vector<float>* frame, float out8[8]);

} // namespace gles
} // namespace android
} // namespace vidviz
