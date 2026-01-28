#pragma once

#import "platform/ios/metal_renderer.h"
#import "platform/ios/text/text_parser_ios.h"
#import "platform/ios/text/text_rasterizer_ios.h"
#import "platform/ios/text/text_anim_ios.h"

#import <Metal/Metal.h>

#include <unordered_map>
#include <vector>
#include <string>
#include <cmath>
#include <algorithm>

namespace vidviz {
namespace ios {
namespace text {

struct VVTextTexInfo {
    void* tex = nullptr; // id<MTLTexture>
    int32_t w = 0;
    int32_t h = 0;
};

struct VVTextQuadV {
    float pos[2];
    float uv[2];
};

static inline float vvTextClamp(float v, float lo, float hi) {
    if (!std::isfinite(v)) return lo;
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

static inline float vvTextClamp01(float v) {
    if (!std::isfinite(v)) return 0.0f;
    if (v < 0.0f) return 0.0f;
    if (v > 1.0f) return 1.0f;
    return v;
}

static inline void vvTextArgbToRgb01(int64_t argb, float& r, float& g, float& b) {
    const uint32_t cc = static_cast<uint32_t>(argb);
    r = ((cc >> 16) & 0xFF) / 255.0f;
    g = ((cc >> 8) & 0xFF) / 255.0f;
    b = (cc & 0xFF) / 255.0f;
}

class TextRendererIOSImpl {
public:
    explicit TextRendererIOSImpl(MetalRenderer* owner) : owner(owner) {}

    MetalRenderer* owner = nullptr;

    std::unordered_map<std::string, VVTextTexInfo> baked;
    std::unordered_map<std::string, VVTextTexInfo> masks;

    void* quadPipeline = nullptr; // id<MTLRenderPipelineState>
    void* maskCompositePipeline = nullptr; // id<MTLRenderPipelineState>

    VVTextTexInfo effectRT;

    void releaseTexInfo(VVTextTexInfo& t);
    void cleanup();

    bool ensureQuadPipeline();
    bool ensureMaskCompositePipeline();

    id<MTLTexture> makeTextureBgra(const std::vector<uint8_t>& bgra, int32_t w, int32_t h);

    bool ensureEffectRT(int32_t w, int32_t h);
    void renderToEffectRT(
        const std::string& shaderId,
        int32_t w,
        int32_t h,
        float timeSec,
        float intensity,
        float speed,
        float angle,
        float thickness,
        int64_t colorA,
        int64_t colorB
    );

    void restoreSceneEncoderWithLoad();

    void drawTexturedQuad(
        void* pipelinePtr,
        id<MTLTexture> tex0,
        id<MTLTexture> tex1,
        float xPx,
        float yPx,
        float quadW,
        float quadH,
        float rotDeg,
        float sx,
        float sy,
        float alpha,
        float uMax
    );
};

} // namespace text
} // namespace ios
} // namespace vidviz
