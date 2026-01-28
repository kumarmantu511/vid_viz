#pragma once

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <string>

namespace vidviz {
namespace render {

struct QuadVertex {
    float pos[2];
    float uv[2];
};

static inline float clampf(float v, float lo, float hi) {
    if (!std::isfinite(v)) return lo;
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

static inline int32_t parseCropMode(const std::string& s) {
    if (s == "fill" || s == "cover") return 1;
    if (s == "stretch") return 2;
    return 0;
}

static inline void computeBaseMediaQuad(
    int32_t dstW,
    int32_t dstH,
    int32_t srcW,
    int32_t srcH,
    int32_t cropMode,
    float rotationDeg,
    bool flipH,
    bool flipV,
    QuadVertex outVerts[4]
) {
    if (!outVerts) return;

    const float dW = std::max(1.0f, static_cast<float>(dstW));
    const float dH = std::max(1.0f, static_cast<float>(dstH));
    float sW = std::max(1.0f, static_cast<float>(srcW));
    float sH = std::max(1.0f, static_cast<float>(srcH));

    float u0 = 0.0f, v0 = 0.0f, u1 = 1.0f, v1 = 1.0f;
    float quadW = dW;
    float quadH = dH;

    const float dstAspect = dW / dH;
    const float srcAspect = sW / sH;

    if (cropMode == 2) {
        quadW = dW;
        quadH = dH;
    } else if (cropMode == 1) {
        quadW = dW;
        quadH = dH;
        if (srcAspect > dstAspect) {
            const float keep = (srcAspect > 0.0f) ? (dstAspect / srcAspect) : 1.0f;
            const float m = (1.0f - keep) * 0.5f;
            u0 = m;
            u1 = 1.0f - m;
        } else {
            const float keep = (dstAspect > 0.0f) ? (srcAspect / dstAspect) : 1.0f;
            const float m = (1.0f - keep) * 0.5f;
            v0 = m;
            v1 = 1.0f - m;
        }
    } else {
        if (srcAspect > dstAspect) {
            quadW = dW;
            quadH = (srcAspect > 0.0f) ? (dW / srcAspect) : dH;
        } else {
            quadH = dH;
            quadW = dH * srcAspect;
        }
    }

    if (flipH) std::swap(u0, u1);
    if (flipV) std::swap(v0, v1);

    const float cxPx = 0.5f * dW;
    const float cyPx = 0.5f * dH;
    const float hxPx = 0.5f * quadW;
    const float hyPx = 0.5f * quadH;

    const float rad = rotationDeg * 3.1415926535f / 180.0f;
    const float cs = std::cos(rad);
    const float sn = std::sin(rad);

    auto rotPx = [&](float x, float y, float& ox, float& oy) {
        ox = x * cs - y * sn;
        oy = x * sn + y * cs;
    };

    auto pxToNdcX = [&](float xPx) -> float {
        return (xPx / dW) * 2.0f - 1.0f;
    };
    auto pxToNdcY = [&](float yPx) -> float {
        return 1.0f - (yPx / dH) * 2.0f;
    };

    float x0p, y0p, x1p, y1p, x2p, y2p, x3p, y3p;
    rotPx(-hxPx, -hyPx, x0p, y0p);
    rotPx( hxPx, -hyPx, x1p, y1p);
    rotPx(-hxPx,  hyPx, x2p, y2p);
    rotPx( hxPx,  hyPx, x3p, y3p);

    const float x0 = pxToNdcX(cxPx + x0p);
    const float y0 = pxToNdcY(cyPx + y0p);
    const float x1 = pxToNdcX(cxPx + x1p);
    const float y1 = pxToNdcY(cyPx + y1p);
    const float x2 = pxToNdcX(cxPx + x2p);
    const float y2 = pxToNdcY(cyPx + y2p);
    const float x3 = pxToNdcX(cxPx + x3p);
    const float y3 = pxToNdcY(cyPx + y3p);

    outVerts[0] = QuadVertex{{x0, y0}, {u0, v1}};
    outVerts[1] = QuadVertex{{x1, y1}, {u1, v1}};
    outVerts[2] = QuadVertex{{x2, y2}, {u0, v0}};
    outVerts[3] = QuadVertex{{x3, y3}, {u1, v0}};
}

static inline float normalizeDeg(float deg) {
    if (!std::isfinite(deg)) return 0.0f;
    while (deg > 180.0f) deg -= 360.0f;
    while (deg < -180.0f) deg += 360.0f;
    return deg;
}

} // namespace render
} // namespace vidviz
