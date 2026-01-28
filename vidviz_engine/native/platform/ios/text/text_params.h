#pragma once

#include <cstdint>
#include <string>

namespace vidviz {
namespace ios {
namespace text {

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

struct TextAnimTransform {
    float dxPx = 0.0f;
    float dyPx = 0.0f;
    float scaleX = 1.0f;
    float scaleY = 1.0f;
    float rotationDeg = 0.0f;
};

} // namespace text
} // namespace ios
} // namespace vidviz
