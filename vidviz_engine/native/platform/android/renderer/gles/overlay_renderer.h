#pragma once

#include <cstdint>
#include <string>

namespace vidviz {
namespace android {
namespace gles {

struct MediaOverlayParams {
    bool isOverlay = false;
    std::string mediaType;
    float x = 0.5f;
    float y = 0.5f;
    float scale = 1.0f;
    float opacity = 1.0f;
    float rotation = 0.0f;
    float borderRadius = 0.0f;
    std::string cropMode;
    float cropZoom = 1.0f;
    float cropPanX = 0.0f;
    float cropPanY = 0.0f;
    std::string frameMode;
    std::string fitMode;
    std::string animationType;
    int32_t animationDurationMs = 0;
};

bool parseMediaOverlayParams(const std::string& dataJson, MediaOverlayParams& out);

void computeMediaOverlayQuad(
    int32_t outW,
    int32_t outH,
    float scale,
    float borderRadius,
    float& outBasePx,
    float& outQuadPx,
    float& outRadiusPx
);

} // namespace gles
} // namespace android
} // namespace vidviz
