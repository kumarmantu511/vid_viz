#pragma once

#include <cstdint>
#include <string>
#include <vector>

namespace vidviz {
namespace android {
namespace gles {

struct ParsedTextParams {
    // Layout/placement
    std::string title;
    float x = 0.1f;
    float y = 0.1f;

    float padPx = -1.0f;

    bool decorAlreadyScaled = false;

    // Typography
    std::string font;
    float fontSizeN = 0.1f;
    int64_t fontColor = 0xFFFFFFFF;
    bool fakeBold = false;
    float alpha = 1.0f;

    // Decorations
    float borderW = 0.0f;
    int64_t borderColor = 0xFFFFFFFF;
    int64_t shadowColor = 0xFFFFFFFF;
    float shadowX = 0.0f;
    float shadowY = 0.0f;
    float shadowBlur = 0.0f;
    bool box = false;
    float boxBorderW = 0.0f;
    int64_t boxColor = 0x88000000;
    float boxPad = 0.0f;
    float boxRadius = 4.0f;
    float glowRadius = 0.0f;
    int64_t glowColor = 0xFFFFFFFF;

    // Shader effect (glyph fill)
    std::string effectType;
    float effectIntensity = 0.7f;
    int64_t effectColorA = 0xFF00FFFF;
    int64_t effectColorB = 0xFFFF00FF;
    float effectSpeed = 1.0f;
    float effectThickness = 1.0f;
    float effectAngle = 0.0f;

    // Animations
    std::string animType;
    float animSpeed = 1.0f;
    float animAmplitude = 0.0f;
    float animPhase = 0.0f;
};

bool rasterizeTextBitmap(
    const ParsedTextParams& p,
    float fontPx,
    float timeSec,
    bool maskOnly,
    bool decorOnly,
    std::vector<uint8_t>& outRgba,
    int32_t& outW,
    int32_t& outH,
    float* outInkCenterDxPx = nullptr,
    float* outInkCenterDyPx = nullptr
);

void shutdownTextRasterizer();

} // namespace gles
} // namespace android
} // namespace vidviz
