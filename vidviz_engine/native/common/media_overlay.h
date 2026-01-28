#pragma once

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <string>

#include "common/minijson.h"

namespace vidviz {
namespace overlay {

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

static inline float clampf(float v, float lo, float hi) {
    if (!std::isfinite(v)) return lo;
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

static inline bool parseMediaOverlayParams(const std::string& dataJson, MediaOverlayParams& out) {
    out = MediaOverlayParams{};
    if (dataJson.empty()) return false;

    const auto parsed = minijson::parse(dataJson);
    if (!parsed.ok()) return false;
    const auto* root = parsed.value.asObject();
    if (!root) return false;

    std::string overlayType;
    minijson::getString(*root, "overlayType", &overlayType);
    if (overlayType != "media") return false;

    out.isOverlay = true;
    minijson::getString(*root, "mediaType", &out.mediaType);

    double d = 0.0;
    if (minijson::getDouble(*root, "x", &d)) out.x = static_cast<float>(d);
    if (minijson::getDouble(*root, "y", &d)) out.y = static_cast<float>(d);
    if (minijson::getDouble(*root, "scale", &d)) out.scale = static_cast<float>(d);
    if (minijson::getDouble(*root, "opacity", &d)) out.opacity = static_cast<float>(d);
    if (minijson::getDouble(*root, "rotation", &d)) out.rotation = static_cast<float>(d);
    if (minijson::getDouble(*root, "borderRadius", &d)) out.borderRadius = static_cast<float>(d);

    minijson::getString(*root, "cropMode", &out.cropMode);
    if (out.cropMode.empty()) out.cropMode = "none";
    if (minijson::getDouble(*root, "cropZoom", &d)) out.cropZoom = static_cast<float>(d);
    if (minijson::getDouble(*root, "cropPanX", &d)) out.cropPanX = static_cast<float>(d);
    if (minijson::getDouble(*root, "cropPanY", &d)) out.cropPanY = static_cast<float>(d);

    minijson::getString(*root, "frameMode", &out.frameMode);
    if (out.frameMode.empty()) out.frameMode = "square";
    minijson::getString(*root, "fitMode", &out.fitMode);
    if (out.fitMode.empty()) out.fitMode = "cover";

    minijson::getString(*root, "animationType", &out.animationType);
    int64_t i64 = 0;
    if (minijson::getInt64(*root, "animationDuration", &i64)) {
        out.animationDurationMs = static_cast<int32_t>(i64);
    }

    out.x = clampf(out.x, 0.0f, 1.0f);
    out.y = clampf(out.y, 0.0f, 1.0f);
    out.scale = clampf(out.scale, 0.01f, 10.0f);
    out.opacity = clampf(out.opacity, 0.0f, 1.0f);
    out.rotation = clampf(out.rotation, -3600.0f, 3600.0f);
    out.borderRadius = clampf(out.borderRadius, 0.0f, 100.0f);
    out.cropZoom = clampf(out.cropZoom, 1.0f, 4.0f);
    out.cropPanX = clampf(out.cropPanX, -1.0f, 1.0f);
    out.cropPanY = clampf(out.cropPanY, -1.0f, 1.0f);

    return true;
}

static inline void computeMediaOverlayBaseSize(
    int32_t outW,
    int32_t outH,
    float& outBasePx
) {
    const float minSide = static_cast<float>(std::min(outW, outH));
    float base = minSide * 0.25f;
    const float minBase = minSide * 0.10f;
    const float maxBase = minSide * 0.40f;
    if (base < minBase) base = minBase;
    if (base > maxBase) base = maxBase;
    outBasePx = base;
}

static inline void computeMediaOverlayQuad(
    int32_t outW,
    int32_t outH,
    float scale,
    float borderRadius,
    float& outBasePx,
    float& outQuadPx,
    float& outRadiusPx
) {
    computeMediaOverlayBaseSize(outW, outH, outBasePx);

    float s = scale;
    if (!std::isfinite(s)) s = 1.0f;
    if (s < 0.01f) s = 0.01f;
    if (s > 10.0f) s = 10.0f;
    outQuadPx = outBasePx * s;

    float br = borderRadius / 100.0f;
    if (!std::isfinite(br)) br = 0.0f;
    if (br < 0.0f) br = 0.0f;
    if (br > 1.0f) br = 1.0f;
    const float maxRadiusPx = 0.5f * outQuadPx;
    outRadiusPx = br * maxRadiusPx;
}

static inline void computeMediaOverlayCustomCrop(
    const MediaOverlayParams& overlay,
    float& cropU0,
    float& cropV0,
    float& cropU1,
    float& cropV1
) {
    cropU0 = 0.0f;
    cropV0 = 0.0f;
    cropU1 = 1.0f;
    cropV1 = 1.0f;

    if (overlay.cropMode != "custom") return;

    float z = overlay.cropZoom;
    if (!std::isfinite(z)) z = 1.0f;
    if (z < 1.0f) z = 1.0f;
    if (z > 4.0f) z = 4.0f;

    const float win = 1.0f / z;
    const float maxOff = (1.0f - win) * 0.5f;

    float px = overlay.cropPanX;
    float py = overlay.cropPanY;
    if (!std::isfinite(px)) px = 0.0f;
    if (!std::isfinite(py)) py = 0.0f;
    if (px < -1.0f) px = -1.0f;
    if (px > 1.0f) px = 1.0f;
    if (py < -1.0f) py = -1.0f;
    if (py > 1.0f) py = 1.0f;

    const float cx = 0.5f + px * maxOff;
    const float cy = 0.5f + py * maxOff;

    cropU0 = cx - win * 0.5f;
    cropV0 = cy - win * 0.5f;
    cropU1 = cx + win * 0.5f;
    cropV1 = cy + win * 0.5f;

    cropU0 = clampf(cropU0, 0.0f, 1.0f);
    cropV0 = clampf(cropV0, 0.0f, 1.0f);
    cropU1 = clampf(cropU1, 0.0f, 1.0f);
    cropV1 = clampf(cropV1, 0.0f, 1.0f);
}

} // namespace overlay
} // namespace vidviz
