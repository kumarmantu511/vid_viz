/**
 * VidViz Engine - Metal Renderer Implementation (iOS)
 * 
 * POC implementation - basic Metal setup
 */

#import "metal_renderer.h"
#import "common/log.h"
#import "platform/ios/ios_encoder_surface.h"

#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <CoreVideo/CVMetalTextureCache.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <UIKit/UIKit.h>
#import <CoreText/CoreText.h>
#import <CoreGraphics/CoreGraphics.h>

#include <vector>
#include <cstdio>
#include <unordered_map>
#include <cstring>
#include <algorithm>
#include <cmath>
 
#include "common/minijson.h"
#include "common/render_math.h"
#include "common/media_overlay.h"
#include "platform/ios/text/text_renderer_ios.h"

namespace vidviz {
namespace ios {

static inline float vvClamp(float v, float lo, float hi) {
    if (!std::isfinite(v)) return lo;
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

bool MetalRenderer::ensureOverlayPipeline() {
    if (m_overlayPipeline && m_videoSampler) {
        return true;
    }
    if (!m_videoSampler) {
        if (!ensureVideoPipeline()) {
            return false;
        }
    }

    id<MTLDevice> device = (__bridge id<MTLDevice>)m_device;
    if (!device) return false;

    static NSString* const src =
        @"#include <metal_stdlib>\n"
        @"using namespace metal;\n"
        @"struct VOut { float4 position [[position]]; float2 uv; };\n"
        @"vertex VOut vmain(uint vid [[vertex_id]], const device float4* vb [[buffer(0)]]) {\n"
        @"  float4 v = vb[vid]; VOut o; o.position = float4(v.xy, 0.0, 1.0); o.uv = v.zw; return o;\n"
        @"}\n"
        @"struct U { float4 p0; float4 uvRect; float4 p1; };\n"
        @"fragment float4 fmain(VOut in [[stage_in]], texture2d<float> tex [[texture(0)]], sampler samp [[sampler(0)]], constant U& u [[buffer(0)]]) {\n"
        @"  float2 uv = u.uvRect.xy + in.uv * u.uvRect.zw;\n"
        @"  float4 c = tex.sample(samp, uv);\n"
        @"  float a = c.a * clamp(u.p0.w, 0.0, 1.0);\n"
        @"  float radiusPx = max(0.0, u.p1.x);\n"
        @"  if (radiusPx > 0.5) {\n"
        @"    float2 sizePx = max(float2(1.0, 1.0), u.p1.yz);\n"
        @"    float2 p = in.uv * sizePx;\n"
        @"    float2 q = abs(p - 0.5 * sizePx) - (0.5 * sizePx - float2(radiusPx));\n"
        @"    float d = length(max(q, float2(0.0))) + min(max(q.x, q.y), 0.0);\n"
        @"    float edge = smoothstep(1.0, 0.0, d);\n"
        @"    a *= edge;\n"
        @"  }\n"
        @"  return float4(c.rgb * clamp(u.p0.w, 0.0, 1.0), a);\n"
        @"}\n";

    NSError* err = nil;
    id<MTLLibrary> lib = [device newLibraryWithSource:src options:nil error:&err];
    if (err || !lib) {
        if (err) {
            LOGE("VIDVIZ_ERROR: Metal overlay library compile failed: %s", [[err localizedDescription] UTF8String]);
        }
        return false;
    }

    id<MTLFunction> vf = [lib newFunctionWithName:@"vmain"];
    id<MTLFunction> ff = [lib newFunctionWithName:@"fmain"];
    if (!vf || !ff) {
        return false;
    }

    MTLRenderPipelineDescriptor* desc = [[MTLRenderPipelineDescriptor alloc] init];
    desc.vertexFunction = vf;
    desc.fragmentFunction = ff;
    desc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    desc.colorAttachments[0].blendingEnabled = YES;
    desc.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
    desc.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
    desc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorOne;
    desc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
    desc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    desc.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;

    id<MTLRenderPipelineState> pso = [device newRenderPipelineStateWithDescriptor:desc error:&err];
    if (err || !pso) {
        if (err) {
            LOGE("VIDVIZ_ERROR: Metal overlay pipeline create failed: %s", [[err localizedDescription] UTF8String]);
        }
        return false;
    }

    m_overlayPipeline = (__bridge_retained void*)pso;
    return true;
}

static const FFTData* vvFindFftByAudioPath(const std::vector<FFTData>& fftData, const std::string& audioPath) {
    if (audioPath.empty()) return nullptr;
    for (const auto& f : fftData) {
        if (f.audioPath == audioPath) return &f;
    }
    return nullptr;
}

static void vvFillFftN(const std::vector<float>* frame, std::vector<float>& out, int bins) {
    out.assign((size_t)std::max(1, bins), 0.0f);
    if (!frame || frame->empty() || bins <= 0) return;
    const int n = (int)frame->size();
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
        out[(size_t)b] = (cnt > 0) ? (sum / (float)cnt) : 0.0f;
    }
}

void MetalRenderer::setVideoSettings(const VideoSettings& settings) {
    m_uiPlayerWidth = settings.uiPlayerWidth;
    m_uiPlayerHeight = settings.uiPlayerHeight;
    m_uiDevicePixelRatio = settings.uiDevicePixelRatio;

    m_cropMode = vidviz::render::parseCropMode(settings.cropMode);
    m_rotationDeg = vidviz::render::normalizeDeg(static_cast<float>(settings.rotation));
    m_flipH = settings.flipHorizontal;
    m_flipV = settings.flipVertical;

    const uint32_t cc = static_cast<uint32_t>(settings.backgroundColor);
    m_bgA = ((cc >> 24) & 0xFF) / 255.0f;
    m_bgR = ((cc >> 16) & 0xFF) / 255.0f;
    m_bgG = ((cc >> 8) & 0xFF) / 255.0f;
    m_bgB = (cc & 0xFF) / 255.0f;
}

static const std::vector<float>* vvApplyDynamics(
    const std::vector<float>* frame,
    float smoothness,
    float reactivity,
    std::vector<float>& scratch
) {
    if (!frame || frame->empty()) return frame;

    float smooth = smoothness;
    if (std::fabs(smooth - 0.6f) < 0.001f) smooth = 0.0f;
    if (smooth < 0.0f) smooth = 0.0f;
    if (smooth > 1.0f) smooth = 1.0f;

    float react = reactivity;
    if (react < 0.5f) react = 0.5f;
    if (react > 2.0f) react = 2.0f;

    if (smooth == 0.0f && std::fabs(react - 1.0f) < 0.001f) {
        return frame;
    }

    scratch = *frame;
    const int n = (int)scratch.size();
    std::vector<float> smoothed((size_t)n, 0.0f);

    if (smooth > 0.0f) {
        for (int i = 0; i < n; i++) {
            float self = scratch[(size_t)i];
            if (!std::isfinite(self)) self = 0.0f;
            if (self < 0.0f) self = 0.0f;
            if (self > 1.0f) self = 1.0f;
            float prev = (i > 0) ? scratch[(size_t)(i - 1)] : self;
            float next = (i < n - 1) ? scratch[(size_t)(i + 1)] : self;
            if (!std::isfinite(prev)) prev = 0.0f;
            if (!std::isfinite(next)) next = 0.0f;
            if (prev < 0.0f) prev = 0.0f;
            if (prev > 1.0f) prev = 1.0f;
            if (next < 0.0f) next = 0.0f;
            if (next > 1.0f) next = 1.0f;
            const float avg = (prev + self + next) / 3.0f;
            smoothed[(size_t)i] = self * (1.0f - smooth) + avg * smooth;
        }
    } else {
        for (int i = 0; i < n; i++) {
            float v = scratch[(size_t)i];
            if (!std::isfinite(v)) v = 0.0f;
            if (v < 0.0f) v = 0.0f;
            if (v > 1.0f) v = 1.0f;
            smoothed[(size_t)i] = v;
        }
    }

    if (std::fabs(react - 1.0f) < 0.001f) {
        scratch.swap(smoothed);
        return &scratch;
    }

    const float exp = 1.0f / react;
    for (int i = 0; i < n; i++) {
        float v = smoothed[(size_t)i];
        if (!std::isfinite(v)) v = 0.0f;
        if (v < 0.0f) v = 0.0f;
        if (v > 1.0f) v = 1.0f;
        scratch[(size_t)i] = std::pow(v, exp);
    }
    return &scratch;
}

struct VVVisualizerExtraParams {
    float amplitude = 1.0f;
    float barFill = 0.75f;
    float glow = 0.0f;
    float strokeWidth = 2.5f;
    bool mirror = false;

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
    std::string counterAnim = "none";
    float counterOffsetY = 0.0f;

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

static inline float vvClamp01(float v) {
    if (v < 0.0f) return 0.0f;
    if (v > 1.0f) return 1.0f;
    return v;
}

static float vvProgressThemeIndex(const std::string& theme) {
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

static float vvProgressHeadStyleIndex(const std::string& style) {
    if (style == "none") return 0.0f;
    if (style == "static") return 0.0f;
    if (style == "spark") return 2.0f;
    return 1.0f; // pulse
}

static std::string vvPickVisualizerShaderId(const std::string& renderMode, const std::string& shaderType, const std::string& type) {
    if (renderMode == "progress") {
        return "progress";
    }
    if (renderMode == "shader" || renderMode == "visual") {
        return shaderType.empty() ? "bar" : shaderType;
    }
    if (type == "bars") return "bar";
    if (type == "wave") return "wav";
    if (type == "circle") return "circle";
    if (type == "spectrum") return "bar_circle";
    if (type == "particle") return "fractal";
    return "bar";
}

static bool vvParseVisualizerParams(
    const std::string& dataJson,
    std::string& outRenderMode,
    std::string& outShaderType,
    std::string& outType,
    std::string& outAudioPath,
    bool& outFullScreen,
    float& outAlpha,
    float& outSensitivity,
    float& outSpeed,
    float& outSmoothness,
    float& outReactivity,
    float& outX,
    float& outY,
    float& outScale,
    float& outRotation,
    int32_t& outBarCount,
    int64_t& outColor,
    int64_t& outGradientColor,
    int64_t& outProjectDurationMs,
    std::string& outEffectStyle,
    VVVisualizerExtraParams& outExtra
) {
    outRenderMode = "canvas";
    outShaderType.clear();
    outType = "bars";
    outAudioPath.clear();
    outFullScreen = false;
    outAlpha = 1.0f;
    outSensitivity = 1.0f;
    outSpeed = 1.0f;
    outSmoothness = 0.6f;
    outReactivity = 1.0f;
    outX = 0.5f;
    outY = 0.5f;
    outScale = 1.0f;
    outRotation = 0.0f;
    outBarCount = 32;
    outColor = 0xFFFFFFFF;
    outGradientColor = 0;
    outProjectDurationMs = 0;
    outEffectStyle = "default";
    outExtra = VVVisualizerExtraParams{};

    if (dataJson.empty()) return false;
    const auto parsed = minijson::parse(dataJson);
    if (!parsed.ok()) return false;
    const auto* root = parsed.value.asObject();
    if (!root) return false;
    const minijson::Value* visV = minijson::get(*root, "visualizer");
    const auto* visO = visV ? visV->asObject() : nullptr;
    if (!visO) return false;

    minijson::getString(*visO, "renderMode", &outRenderMode);
    minijson::getString(*visO, "shaderType", &outShaderType);
    minijson::getString(*visO, "type", &outType);
    minijson::getString(*visO, "audioPath", &outAudioPath);
    minijson::getString(*visO, "effectStyle", &outEffectStyle);

    bool bb = false;
    if (minijson::getBool(*visO, "fullScreen", &bb)) outFullScreen = bb;

    double d = 0.0;
    if (minijson::getDouble(*visO, "alpha", &d)) outAlpha = (float)d;
    if (minijson::getDouble(*visO, "sensitivity", &d)) outSensitivity = (float)d;
    if (minijson::getDouble(*visO, "speed", &d)) outSpeed = (float)d;
    if (minijson::getDouble(*visO, "smoothness", &d)) outSmoothness = (float)d;
    if (minijson::getDouble(*visO, "reactivity", &d)) outReactivity = (float)d;
    if (minijson::getDouble(*visO, "x", &d)) outX = (float)d;
    if (minijson::getDouble(*visO, "y", &d)) outY = (float)d;
    if (minijson::getDouble(*visO, "scale", &d)) outScale = (float)d;
    if (minijson::getDouble(*visO, "rotation", &d)) outRotation = (float)d;

    if (minijson::getDouble(*visO, "amplitude", &d)) outExtra.amplitude = (float)d;
    if (minijson::getDouble(*visO, "barSpacing", &d)) outExtra.barFill = (float)d;
    if (minijson::getDouble(*visO, "glowIntensity", &d)) outExtra.glow = (float)d;
    if (minijson::getDouble(*visO, "strokeWidth", &d)) outExtra.strokeWidth = (float)d;

    bool bm = false;
    if (minijson::getBool(*visO, "mirror", &bm)) outExtra.mirror = bm;

    int64_t i64 = 0;
    if (minijson::getInt64(*visO, "projectDuration", &i64)) outProjectDurationMs = i64;
    if (minijson::getInt64(*visO, "barCount", &i64)) outBarCount = (int32_t)i64;
    if (minijson::getInt64(*visO, "color", &i64)) outColor = i64;
    if (minijson::getInt64(*visO, "gradientColor", &i64)) outGradientColor = i64;

    // shaderParams for progress-bar extras (optional)
    const minijson::Value* paramsV = minijson::get(*visO, "shaderParams");
    const auto* paramsO = paramsV ? paramsV->asObject() : nullptr;
    if (paramsO) {
        if (minijson::getDouble(*paramsO, "progressTrackAlpha", &d)) outExtra.progressTrackAlpha = (float)d;
        if (minijson::getDouble(*paramsO, "progressCorner", &d)) outExtra.progressCorner = (float)d;
        if (minijson::getDouble(*paramsO, "progressGap", &d)) outExtra.progressGap = (float)d;
        if (minijson::getDouble(*paramsO, "progressEffectAmount", &d)) outExtra.progressEffectAmount = (float)d;
        if (minijson::getDouble(*paramsO, "progressHeadAmount", &d)) outExtra.progressHeadAmount = (float)d;
        if (minijson::getDouble(*paramsO, "progressHeadSize", &d)) outExtra.progressHeadSize = (float)d;

        std::string theme;
        if (minijson::getString(*paramsO, "progressTheme", &theme)) {
            outExtra.progressThemeIdx = vvProgressThemeIndex(theme);
        }
        std::string headStyle;
        if (minijson::getString(*paramsO, "progressHeadStyle", &headStyle)) {
            outExtra.progressHeadStyleIdx = vvProgressHeadStyleIndex(headStyle);
        }

        if (minijson::getInt64(*paramsO, "progressTrackColor", &i64)) {
            outExtra.hasProgressTrackColor = true;
            outExtra.progressTrackColor = i64;
        }

        bool bb2 = false;
        if (minijson::getBool(*paramsO, "counterStartEnabled", &bb2)) outExtra.counterStartEnabled = bb2;
        if (minijson::getBool(*paramsO, "counterEndEnabled", &bb2)) outExtra.counterEndEnabled = bb2;
        minijson::getString(*paramsO, "counterPos", &outExtra.counterPos);
        minijson::getString(*paramsO, "counterStartMode", &outExtra.counterStartMode);
        minijson::getString(*paramsO, "counterEndMode", &outExtra.counterEndMode);
        minijson::getString(*paramsO, "counterLabelSize", &outExtra.counterLabelSize);
        minijson::getString(*paramsO, "counterAnim", &outExtra.counterAnim);
        if (minijson::getDouble(*paramsO, "counterOffsetY", &d)) outExtra.counterOffsetY = (float)d;

        minijson::getString(*paramsO, "counterStartWeight", &outExtra.counterStartWeight);
        minijson::getString(*paramsO, "counterEndWeight", &outExtra.counterEndWeight);

        if (minijson::getDouble(*paramsO, "counterStartShadowOpacity", &d)) outExtra.counterStartShadowOpacity = (float)d;
        if (minijson::getDouble(*paramsO, "counterStartShadowBlur", &d)) outExtra.counterStartShadowBlur = (float)d;
        if (minijson::getDouble(*paramsO, "counterStartShadowOffsetX", &d)) outExtra.counterStartShadowOffsetX = (float)d;
        if (minijson::getDouble(*paramsO, "counterStartShadowOffsetY", &d)) outExtra.counterStartShadowOffsetY = (float)d;
        if (minijson::getDouble(*paramsO, "counterEndShadowOpacity", &d)) outExtra.counterEndShadowOpacity = (float)d;
        if (minijson::getDouble(*paramsO, "counterEndShadowBlur", &d)) outExtra.counterEndShadowBlur = (float)d;
        if (minijson::getDouble(*paramsO, "counterEndShadowOffsetX", &d)) outExtra.counterEndShadowOffsetX = (float)d;
        if (minijson::getDouble(*paramsO, "counterEndShadowOffsetY", &d)) outExtra.counterEndShadowOffsetY = (float)d;

        if (minijson::getDouble(*paramsO, "counterStartGlowRadius", &d)) outExtra.counterStartGlowRadius = (float)d;
        if (minijson::getDouble(*paramsO, "counterStartGlowOpacity", &d)) outExtra.counterStartGlowOpacity = (float)d;
        if (minijson::getDouble(*paramsO, "counterEndGlowRadius", &d)) outExtra.counterEndGlowRadius = (float)d;
        if (minijson::getDouble(*paramsO, "counterEndGlowOpacity", &d)) outExtra.counterEndGlowOpacity = (float)d;

        if (minijson::getDouble(*paramsO, "counterStartPosX", &d)) outExtra.counterStartPosX = (float)d;
        if (minijson::getDouble(*paramsO, "counterStartPosY", &d)) outExtra.counterStartPosY = (float)d;
        if (minijson::getDouble(*paramsO, "counterEndPosX", &d)) outExtra.counterEndPosX = (float)d;
        if (minijson::getDouble(*paramsO, "counterEndPosY", &d)) outExtra.counterEndPosY = (float)d;

        if (minijson::getInt64(*paramsO, "counterStartColor", &i64)) {
            outExtra.hasCounterStartColor = true;
            outExtra.counterStartColor = i64;
        }
        if (minijson::getInt64(*paramsO, "counterEndColor", &i64)) {
            outExtra.hasCounterEndColor = true;
            outExtra.counterEndColor = i64;
        }
    }

    // Clamp progress params
    outExtra.progressTrackAlpha = vvClamp01(outExtra.progressTrackAlpha);
    outExtra.progressCorner = vvClamp01(outExtra.progressCorner);
    outExtra.progressGap = vvClamp01(outExtra.progressGap);
    outExtra.progressEffectAmount = vvClamp01(outExtra.progressEffectAmount);
    outExtra.progressHeadAmount = vvClamp01(outExtra.progressHeadAmount);
    outExtra.progressHeadSize = vvClamp01(outExtra.progressHeadSize);

    outAlpha = vvClamp01(outAlpha);

    if (!std::isfinite(outExtra.counterOffsetY)) outExtra.counterOffsetY = 0.0f;
    if (outExtra.counterOffsetY < -120.0f) outExtra.counterOffsetY = -120.0f;
    if (outExtra.counterOffsetY > 120.0f) outExtra.counterOffsetY = 120.0f;

    if (outExtra.counterStartWeight != "normal" && outExtra.counterStartWeight != "semibold" && outExtra.counterStartWeight != "bold") {
        outExtra.counterStartWeight = "semibold";
    }
    if (outExtra.counterEndWeight != "normal" && outExtra.counterEndWeight != "semibold" && outExtra.counterEndWeight != "bold") {
        outExtra.counterEndWeight = "semibold";
    }

    outExtra.counterStartShadowOpacity = vvClamp01(outExtra.counterStartShadowOpacity);
    outExtra.counterEndShadowOpacity = vvClamp01(outExtra.counterEndShadowOpacity);
    outExtra.counterStartShadowBlur = vvClamp(outExtra.counterStartShadowBlur, 0.0f, 30.0f);
    outExtra.counterEndShadowBlur = vvClamp(outExtra.counterEndShadowBlur, 0.0f, 30.0f);
    outExtra.counterStartShadowOffsetX = vvClamp(outExtra.counterStartShadowOffsetX, -30.0f, 30.0f);
    outExtra.counterStartShadowOffsetY = vvClamp(outExtra.counterStartShadowOffsetY, -30.0f, 30.0f);
    outExtra.counterEndShadowOffsetX = vvClamp(outExtra.counterEndShadowOffsetX, -30.0f, 30.0f);
    outExtra.counterEndShadowOffsetY = vvClamp(outExtra.counterEndShadowOffsetY, -30.0f, 30.0f);

    outExtra.counterStartGlowRadius = vvClamp(outExtra.counterStartGlowRadius, 0.0f, 60.0f);
    outExtra.counterEndGlowRadius = vvClamp(outExtra.counterEndGlowRadius, 0.0f, 60.0f);
    outExtra.counterStartGlowOpacity = vvClamp01(outExtra.counterStartGlowOpacity);
    outExtra.counterEndGlowOpacity = vvClamp01(outExtra.counterEndGlowOpacity);

    if (!std::isfinite(outExtra.counterStartPosX)) outExtra.counterStartPosX = -1.0f;
    if (!std::isfinite(outExtra.counterStartPosY)) outExtra.counterStartPosY = -1.0f;
    if (!std::isfinite(outExtra.counterEndPosX)) outExtra.counterEndPosX = -1.0f;
    if (!std::isfinite(outExtra.counterEndPosY)) outExtra.counterEndPosY = -1.0f;
    if (outExtra.counterStartPosX >= 0.0f) outExtra.counterStartPosX = vvClamp01(outExtra.counterStartPosX);
    if (outExtra.counterStartPosY >= 0.0f) outExtra.counterStartPosY = vvClamp01(outExtra.counterStartPosY);
    if (outExtra.counterEndPosX >= 0.0f) outExtra.counterEndPosX = vvClamp01(outExtra.counterEndPosX);
    if (outExtra.counterEndPosY >= 0.0f) outExtra.counterEndPosY = vvClamp01(outExtra.counterEndPosY);

    return true;
}

static inline void vvWriteToStaging(std::vector<uint8_t>& buf, uint32_t off, const void* src, size_t len) {
    if (buf.empty()) return;
    if ((size_t)off + len > buf.size()) return;
    std::memcpy(buf.data() + off, src, len);
}

static bool vvParseShaderTypeAndParams(
    const std::string& json,
    std::string& shaderType,
    float& intensity,
    float& speed,
    float& angle,
    float& frequency,
    float& amplitude,
    float& size,
    float& density,
    float& blurRadius,
    float& vignetteSize,
    int64_t& color
) {
    shaderType.clear();
    if (json.empty()) return false;

    const auto parsed = minijson::parse(json);
    if (!parsed.ok()) return false;
    const auto* root = parsed.value.asObject();
    if (!root) return false;

    const minijson::Value* shaderV = minijson::get(*root, "shader");
    const auto* shaderO = shaderV ? shaderV->asObject() : nullptr;
    if (!shaderO) return false;

    minijson::getString(*shaderO, "type", &shaderType);
    if (shaderType.empty()) return false;

    double d = 0.0;
    if (minijson::getDouble(*shaderO, "intensity", &d)) intensity = (float)d;
    if (minijson::getDouble(*shaderO, "speed", &d)) speed = (float)d;
    if (minijson::getDouble(*shaderO, "angle", &d)) angle = (float)d;
    if (minijson::getDouble(*shaderO, "frequency", &d)) frequency = (float)d;
    if (minijson::getDouble(*shaderO, "amplitude", &d)) amplitude = (float)d;
    if (minijson::getDouble(*shaderO, "size", &d)) size = (float)d;
    if (minijson::getDouble(*shaderO, "density", &d)) density = (float)d;
    if (minijson::getDouble(*shaderO, "blurRadius", &d)) blurRadius = (float)d;
    if (minijson::getDouble(*shaderO, "vignetteSize", &d)) vignetteSize = (float)d;

    int64_t c = 0;
    if (minijson::getInt64(*shaderO, "color", &c)) color = c;

    // Defensive clamps to avoid invalid uniforms (NaN/Inf) reaching Metal.
    intensity = vvClamp01(intensity);
    speed = vvClamp(speed, 0.0f, 5.0f);
    angle = vvClamp(angle, -180.0f, 180.0f);
    frequency = vvClamp(frequency, 0.0f, 50.0f);
    amplitude = vvClamp(amplitude, 0.0f, 10.0f);
    size = vvClamp(size, 0.0f, 10.0f);
    density = vvClamp01(density);
    blurRadius = vvClamp(blurRadius, 0.0f, 100.0f);
    vignetteSize = vvClamp01(vignetteSize);
    return true;
}

static inline void vvArgbToRgb01(int64_t argb, float& r, float& g, float& b) {
    const uint32_t cc = static_cast<uint32_t>(argb);
    r = ((cc >> 16) & 0xFF) / 255.0f;
    g = ((cc >> 8) & 0xFF) / 255.0f;
    b = (cc & 0xFF) / 255.0f;
}

static inline float vvEaseOut(float t) {
    if (!std::isfinite(t)) return 0.0f;
    if (t < 0.0f) t = 0.0f;
    if (t > 1.0f) t = 1.0f;
    const float inv = 1.0f - t;
    return 1.0f - inv * inv;
}

MetalRenderer::MetalRenderer() {
    LOGI("MetalRenderer created");
}

bool MetalRenderer::ensurePostProcessTextures() {
    id<MTLDevice> device = (__bridge id<MTLDevice>)m_device;
    if (!device) return false;
    if (m_width <= 0 || m_height <= 0) return false;

    auto needsRecreate = [&](void* texPtr) -> bool {
        if (!texPtr) return true;
        id<MTLTexture> t = (__bridge id<MTLTexture>)texPtr;
        if (!t) return true;
        return (t.width != (NSUInteger)m_width) || (t.height != (NSUInteger)m_height);
    };

    if (needsRecreate(m_ppTexA)) {
        if (m_ppTexA) {
            id<MTLTexture> t = (__bridge_transfer id<MTLTexture>)m_ppTexA;
            (void)t;
            m_ppTexA = nullptr;
        }
        MTLTextureDescriptor* d = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:(NSUInteger)m_width height:(NSUInteger)m_height mipmapped:NO];
        d.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
        d.storageMode = MTLStorageModePrivate;
        id<MTLTexture> t = [device newTextureWithDescriptor:d];
        if (!t) return false;
        m_ppTexA = (__bridge_retained void*)t;
    }
    if (needsRecreate(m_ppTexB)) {
        if (m_ppTexB) {
            id<MTLTexture> t = (__bridge_transfer id<MTLTexture>)m_ppTexB;
            (void)t;
            m_ppTexB = nullptr;
        }
        MTLTextureDescriptor* d = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:(NSUInteger)m_width height:(NSUInteger)m_height mipmapped:NO];
        d.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
        d.storageMode = MTLStorageModePrivate;
        id<MTLTexture> t = [device newTextureWithDescriptor:d];
        if (!t) return false;
        m_ppTexB = (__bridge_retained void*)t;
    }
    return m_ppTexA && m_ppTexB;
}

void* MetalRenderer::currentPostProcessSrcTexture() const {
    return m_ppUseAAsSrc ? m_ppTexA : m_ppTexB;
}

void* MetalRenderer::currentPostProcessDstTexture() const {
    return m_ppUseAAsSrc ? m_ppTexB : m_ppTexA;
}

void MetalRenderer::swapPostProcessTextures() {
    m_ppUseAAsSrc = !m_ppUseAAsSrc;
}

MetalRenderer::~MetalRenderer() {
    shutdown();
    LOGI("MetalRenderer destroyed");
}

bool MetalRenderer::initialize() {
    LOGI("Initializing Metal renderer...");
    
    if (!createDevice()) return false;
    if (!createCommandQueue()) return false;
    if (!createTextureCache()) return false;
    
    if (!m_textRenderer) {
        m_textRenderer = new vidviz::ios::text::TextRendererIOS(this);
    }
    
    LOGI("Metal renderer initialized");
    return true;
}

void MetalRenderer::shutdown() {
    cleanup();
    LOGI("Metal renderer shutdown");
}

void MetalRenderer::setOutputSize(int32_t width, int32_t height) {
    m_width = width;
    m_height = height;
    LOGI("Output size set: %dx%d", width, height);
    
    // Update metal layer drawable size
    if (m_metalLayer) {
        CAMetalLayer* layer = (__bridge CAMetalLayer*)m_metalLayer;
        layer.drawableSize = CGSizeMake(width, height);
    }
}

void MetalRenderer::beginFrame() {
    if (!m_commandQueue) return;

    if (m_hasEncoderSurface) {
        if (!m_exportSession.beginFrame()) {
            LOGE("Export beginFrame failed");
            return;
        }
        m_commandBuffer = m_exportSession.currentCommandBuffer();
        if (!m_commandBuffer) {
            return;
        }

        if (!ensurePostProcessTextures()) {
            return;
        }
        m_ppUseAAsSrc = true;

        m_boundShaderId.clear();
        m_uniformStaging.clear();
        m_boundTextures.clear();

        id<MTLCommandBuffer> cb = (__bridge id<MTLCommandBuffer>)m_commandBuffer;
        id<MTLTexture> dst = (__bridge id<MTLTexture>)m_ppTexA;
        if (!cb || !dst) {
            return;
        }

        MTLRenderPassDescriptor* passDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
        passDescriptor.colorAttachments[0].texture = dst;
        passDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
        passDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
        passDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(m_bgR, m_bgG, m_bgB, m_bgA);

        id<MTLRenderCommandEncoder> encoder = [cb renderCommandEncoderWithDescriptor:passDescriptor];
        if (!encoder) {
            return;
        }
        m_renderEncoder = (__bridge void*)encoder;
        m_exportSession.setCurrentEncoder(m_renderEncoder);
        m_currentDrawable = nullptr;
        return;
    }

    if (!m_metalLayer) return;

    CAMetalLayer* layer = (__bridge CAMetalLayer*)m_metalLayer;
    id<CAMetalDrawable> drawable = [layer nextDrawable];
    if (!drawable) {
        LOGW("Failed to get next drawable");
        return;
    }

    m_currentDrawable = (__bridge void*)drawable;

    id<MTLCommandQueue> queue = (__bridge id<MTLCommandQueue>)m_commandQueue;
    id<MTLCommandBuffer> commandBuffer = [queue commandBuffer];
    m_commandBuffer = (__bridge void*)commandBuffer;

    // Create render pass descriptor
    MTLRenderPassDescriptor* passDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    passDescriptor.colorAttachments[0].texture = drawable.texture;
    passDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    passDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    passDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(m_bgR, m_bgG, m_bgB, m_bgA);

    id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:passDescriptor];
    m_renderEncoder = (__bridge void*)encoder;

    m_boundShaderId.clear();
    m_uniformStaging.clear();
    m_boundTextures.clear();
}

GPUTexture MetalRenderer::endFrame() {
    GPUTexture result;
    result.width = m_width;
    result.height = m_height;

    if (m_hasEncoderSurface) {
        if (!m_commandBuffer) {
            return result;
        }

        if (m_renderEncoder) {
            id<MTLRenderCommandEncoder> enc = (__bridge id<MTLRenderCommandEncoder>)m_renderEncoder;
            [enc endEncoding];
            m_renderEncoder = nullptr;
            m_exportSession.setCurrentEncoder(nullptr);
        }

        void* srcPtr = currentPostProcessSrcTexture();
        void* dstPtr = m_exportSession.targetTexture();
        id<MTLCommandBuffer> cb = (__bridge id<MTLCommandBuffer>)m_commandBuffer;
        id<MTLTexture> src = (__bridge id<MTLTexture>)srcPtr;
        id<MTLTexture> dst = (__bridge id<MTLTexture>)dstPtr;

        if (cb && src && dst) {
            if (!ensureVideoPipeline()) {
                return result;
            }

            auto quantizeRightAngle = [](float deg) -> int {
                const float q = std::round(deg / 90.0f) * 90.0f;
                int r = static_cast<int>(q);
                r = ((r % 360) + 360) % 360;
                if (r != 0 && r != 90 && r != 180 && r != 270) {
                    r = 0;
                }
                return r;
            };

            auto transformUvMetal = [&](float u, float v, float& outU, float& outV) {
                float ug = u;
                float vg = 1.0f - v;

                if (m_flipH) ug = 1.0f - ug;
                if (m_flipV) vg = 1.0f - vg;

                const int r = quantizeRightAngle(m_rotationDeg);
                switch (r) {
                    case 90: {
                        const float nu = vg;
                        const float nv = 1.0f - ug;
                        ug = nu;
                        vg = nv;
                        break;
                    }
                    case 180:
                        ug = 1.0f - ug;
                        vg = 1.0f - vg;
                        break;
                    case 270: {
                        const float nu = 1.0f - vg;
                        const float nv = ug;
                        ug = nu;
                        vg = nv;
                        break;
                    }
                    default:
                        break;
                }

                outU = ug;
                outV = 1.0f - vg;
            };

            struct V { float pos[2]; float uv[2]; };
            V verts[4] = {
                {{-1.0f, -1.0f}, {0.0f, 1.0f}},
                {{ 1.0f, -1.0f}, {1.0f, 1.0f}},
                {{-1.0f,  1.0f}, {0.0f, 0.0f}},
                {{ 1.0f,  1.0f}, {1.0f, 0.0f}},
            };
            for (int i = 0; i < 4; i++) {
                float uu = verts[i].uv[0];
                float vv = verts[i].uv[1];
                float tu = uu;
                float tv = vv;
                transformUvMetal(uu, vv, tu, tv);
                verts[i].uv[0] = tu;
                verts[i].uv[1] = tv;
            }

            id<MTLRenderPipelineState> pso = (__bridge id<MTLRenderPipelineState>)m_videoPipeline;
            id<MTLSamplerState> samp = (__bridge id<MTLSamplerState>)m_videoSampler;
            if (!pso || !samp) {
                return result;
            }

            MTLRenderPassDescriptor* pass = [MTLRenderPassDescriptor renderPassDescriptor];
            pass.colorAttachments[0].texture = dst;
            pass.colorAttachments[0].loadAction = MTLLoadActionClear;
            pass.colorAttachments[0].storeAction = MTLStoreActionStore;
            pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);

            id<MTLRenderCommandEncoder> enc = [cb renderCommandEncoderWithDescriptor:pass];
            if (!enc) {
                return result;
            }
            [enc setRenderPipelineState:pso];
            [enc setVertexBytes:verts length:sizeof(verts) atIndex:0];
            [enc setFragmentTexture:src atIndex:0];
            [enc setFragmentSamplerState:samp atIndex:0];
            [enc drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
            [enc endEncoding];
        }

        if (!m_exportSession.endFrame()) {
            LOGE("Export endFrame failed");
            return result;
        }

        result.handle = m_exportSession.targetTexture();
        m_renderEncoder = nullptr;
        m_commandBuffer = nullptr;
        m_currentDrawable = nullptr;

        m_boundShaderId.clear();
        m_uniformStaging.clear();
        m_boundTextures.clear();
        return result;
    }

    if (!m_renderEncoder || !m_commandBuffer || !m_currentDrawable) {
        return result;
    }
    
    id<MTLRenderCommandEncoder> encoder = (__bridge id<MTLRenderCommandEncoder>)m_renderEncoder;
    [encoder endEncoding];
    
    id<MTLCommandBuffer> commandBuffer = (__bridge id<MTLCommandBuffer>)m_commandBuffer;
    id<CAMetalDrawable> drawable = (__bridge id<CAMetalDrawable>)m_currentDrawable;
    
    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];
    
    // Return drawable texture as GPUTexture
    result.handle = (__bridge void*)drawable.texture;
    
    m_renderEncoder = nullptr;
    m_commandBuffer = nullptr;
    m_currentDrawable = nullptr;

    m_boundShaderId.clear();
    m_uniformStaging.clear();
    m_boundTextures.clear();
    
    return result;
}

bool MetalRenderer::setEncoderSurface(const NativeSurface& surface) {
    if (!surface.handle) {
        m_hasEncoderSurface = false;
        m_encoderSurface = nullptr;
        return false;
    }

    m_encoderSurface = static_cast<IosEncoderSurface*>(surface.handle);
    m_hasEncoderSurface = (m_encoderSurface != nullptr);
    if (!m_hasEncoderSurface) return false;

    id<MTLDevice> device = (__bridge id<MTLDevice>)m_device;
    id<MTLCommandQueue> queue = (__bridge id<MTLCommandQueue>)m_commandQueue;
    CVMetalTextureCacheRef cache = (CVMetalTextureCacheRef)m_textureCache;

    return m_exportSession.configure((__bridge void*)device, (__bridge void*)queue, (void*)cache, m_encoderSurface, surface.width, surface.height);
}

bool MetalRenderer::presentFrame(int64_t ptsUs) {
    if (!m_hasEncoderSurface) return true;
    return m_exportSession.presentFrame(ptsUs);
}

void MetalRenderer::clear(float r, float g, float b, float a) {
    // Clear is handled in beginFrame via MTLLoadActionClear
}

void MetalRenderer::renderMedia(const Asset& asset, TimeMs localTime) {
    LOGV("renderMedia: %s @ %lld", asset.srcPath.c_str(), localTime);
    if (!m_renderEncoder) return;
    if (asset.srcPath.empty()) return;
    if (!m_textureCache) return;

    if (!ensureVideoPipeline()) {
        return;
    }

    id<MTLRenderCommandEncoder> enc = (__bridge id<MTLRenderCommandEncoder>)m_renderEncoder;
    MTLViewport vp;
    vp.originX = 0;
    vp.originY = 0;
    vp.width = (double)m_width;
    vp.height = (double)m_height;
    vp.znear = 0.0;
    vp.zfar = 1.0;
    [enc setViewport:vp];

    const std::string path = asset.srcPath;

    auto isRot90 = [&](float deg) -> bool {
        const float a = std::fabs(vidviz::render::normalizeDeg(deg));
        return (std::fabs(a - 90.0f) < 0.01f);
    };

    if (asset.type == AssetType::Image) {
        vidviz::overlay::MediaOverlayParams overlay;
        (void)vidviz::overlay::parseMediaOverlayParams(asset.dataJson, overlay);

        if (overlay.isOverlay) {
            if (!ensureOverlayPipeline()) {
                return;
            }

            float animAlphaMul = 1.0f;
            float animDxN = 0.0f;
            float animDyN = 0.0f;
            float animScaleMul = 1.0f;

            const int64_t localMs = std::max<int64_t>(0, localTime);
            const int32_t animDurMs = std::max<int32_t>(1, overlay.animationDurationMs);
            const float tIn = std::min(1.0f, std::max(0.0f, static_cast<float>(localMs) / static_cast<float>(animDurMs)));
            const bool wantsAnim = (!overlay.animationType.empty() && overlay.animationType != "none" && overlay.animationDurationMs > 0);
            const bool wantsSlide = wantsAnim && (overlay.animationType.rfind("slide_", 0) == 0);

            if (wantsAnim) {
                if (overlay.animationType == "fade_in") {
                    animAlphaMul = tIn;
                } else if (overlay.animationType == "fade_out") {
                    const int64_t durMs = static_cast<int64_t>(asset.duration);
                    if (durMs > 0) {
                        const int64_t startFade = std::max<int64_t>(0, durMs - static_cast<int64_t>(animDurMs));
                        const float tOut = std::min(1.0f, std::max(0.0f, static_cast<float>(localMs - startFade) / static_cast<float>(animDurMs)));
                        animAlphaMul = 1.0f - tOut;
                    } else {
                        animAlphaMul = 1.0f - tIn;
                    }
                } else if (overlay.animationType == "zoom_in") {
                    animScaleMul = vvEaseOut(tIn);
                } else if (overlay.animationType == "zoom_out") {
                    animScaleMul = 2.0f - vvEaseOut(tIn);
                }
                if (animAlphaMul < 0.0f) animAlphaMul = 0.0f;
                if (animAlphaMul > 1.0f) animAlphaMul = 1.0f;
                if (animScaleMul < 0.0f) animScaleMul = 0.0f;
            }

            float basePx = 0.0f;
            vidviz::overlay::computeMediaOverlayBaseSize(m_width, m_height, basePx);

            float frameWpx = basePx;
            float frameHpx = basePx;
            if (overlay.frameMode == "fullscreen") {
                frameWpx = static_cast<float>(m_width);
                frameHpx = static_cast<float>(m_height);
            } else if (overlay.frameMode == "portrait") {
                frameWpx = basePx * (9.0f / 16.0f);
                frameHpx = basePx;
            } else if (overlay.frameMode == "landscape") {
                frameWpx = basePx;
                frameHpx = basePx * (9.0f / 16.0f);
            }

            float s = overlay.scale * animScaleMul;
            if (!std::isfinite(s)) s = 1.0f;
            if (s < 0.01f) s = 0.01f;
            frameWpx *= s;
            frameHpx *= s;

            if (wantsSlide) {
                if (overlay.animationType == "slide_left" || overlay.animationType == "slide_right") {
                    const float distPx = (1.0f - tIn) * frameWpx;
                    const float dxN = distPx / std::max(1.0f, static_cast<float>(m_width));
                    if (overlay.animationType == "slide_left") animDxN = dxN;
                    else animDxN = -dxN;
                } else if (overlay.animationType == "slide_up" || overlay.animationType == "slide_down") {
                    const float distPx = (1.0f - tIn) * frameHpx;
                    const float dyN = distPx / std::max(1.0f, static_cast<float>(m_height));
                    if (overlay.animationType == "slide_up") animDyN = dyN;
                    else animDyN = -dyN;
                }
            }

            float radiusPxDraw = 0.0f;
            {
                float brRatio = overlay.borderRadius / 100.0f;
                if (brRatio < 0.0f) brRatio = 0.0f;
                if (brRatio > 1.0f) brRatio = 1.0f;
                const float maxRadius = 0.5f * std::min(frameWpx, frameHpx);
                radiusPxDraw = brRatio * maxRadius;
            }

            float fitScaleX = 1.0f;
            float fitScaleY = 1.0f;
            float fitOffX = 0.0f;
            float fitOffY = 0.0f;
            float u0 = 0.0f, v0 = 0.0f, u1 = 1.0f, v1 = 1.0f;

            auto drawOverlayTexture = [&](id<MTLTexture> tex, int32_t srcW, int32_t srcH, float preferredRotationDeg) {
                if (!tex) return;
                if (srcW <= 0 || srcH <= 0) return;

                float drawWpx = frameWpx;
                float drawHpx = frameHpx;
                float fitU0 = 0.0f, fitV0 = 0.0f, fitU1 = 1.0f, fitV1 = 1.0f;

                const float visW = static_cast<float>(srcW);
                const float visH = static_cast<float>(srcH);
                const float srcAspect = (visH > 0.0f) ? (visW / visH) : 1.0f;
                const float dstAspect = (frameHpx > 0.0f) ? (frameWpx / frameHpx) : 1.0f;

                if (overlay.fitMode == "contain") {
                    if (srcAspect > dstAspect) {
                        drawWpx = frameWpx;
                        drawHpx = (srcAspect > 0.0f) ? (frameWpx / srcAspect) : frameHpx;
                    } else {
                        drawHpx = frameHpx;
                        drawWpx = frameHpx * srcAspect;
                    }
                } else if (overlay.fitMode == "cover") {
                    if (srcAspect > dstAspect) {
                        const float fracW = (srcAspect > 0.0f) ? (dstAspect / srcAspect) : 1.0f;
                        fitU0 = 0.5f - 0.5f * fracW;
                        fitU1 = 0.5f + 0.5f * fracW;
                    } else {
                        const float fracH = (dstAspect > 0.0f) ? (srcAspect / dstAspect) : 1.0f;
                        fitV0 = 0.5f - 0.5f * fracH;
                        fitV1 = 0.5f + 0.5f * fracH;
                    }
                }

                float cropU0 = 0.0f, cropV0 = 0.0f, cropU1 = 1.0f, cropV1 = 1.0f;
                vidviz::overlay::computeMediaOverlayCustomCrop(overlay, cropU0, cropV0, cropU1, cropV1);

                const float fu0 = fitU0 + cropU0 * (fitU1 - fitU0);
                const float fv0 = fitV0 + cropV0 * (fitV1 - fitV0);
                const float fu1 = fitU0 + cropU1 * (fitU1 - fitU0);
                const float fv1 = fitV0 + cropV1 * (fitV1 - fitV0);

                u0 = fu0;
                v0 = fv0;
                u1 = fu1;
                v1 = fv1;

                fitScaleX = (frameWpx > 0.0f) ? (drawWpx / frameWpx) : 1.0f;
                fitScaleY = (frameHpx > 0.0f) ? (drawHpx / frameHpx) : 1.0f;
                fitOffX = 0.5f * (1.0f - fitScaleX);
                fitOffY = 0.5f * (1.0f - fitScaleY);

                const float cxPx = (overlay.x + animDxN) * std::max(1.0f, static_cast<float>(m_width));
                const float cyPx = (overlay.y + animDyN) * std::max(1.0f, static_cast<float>(m_height));

                const float rotDeg = vidviz::render::normalizeDeg(overlay.rotation + preferredRotationDeg);

                const float hw = 0.5f * frameWpx;
                const float hh = 0.5f * frameHpx;
                const float rad = rotDeg * 3.1415926535f / 180.0f;
                const float cs = std::cos(rad);
                const float sn = std::sin(rad);

                auto xform = [&](float x0, float y0, float& ox, float& oy) {
                    const float x = x0;
                    const float y = y0;
                    const float rx = x * cs - y * sn;
                    const float ry = x * sn + y * cs;
                    ox = cxPx + rx;
                    oy = cyPx + ry;
                };

                float x0, y0p, x1p, y1p, x2p, y2p, x3p, y3p;
                xform(-hw, -hh, x0, y0p);
                xform(hw, -hh, x1p, y1p);
                xform(-hw, hh, x2p, y2p);
                xform(hw, hh, x3p, y3p);

                auto toNdcX = [&](float px) { return (px / std::max(1.0f, static_cast<float>(m_width))) * 2.0f - 1.0f; };
                auto toNdcY = [&](float py) { return 1.0f - (py / std::max(1.0f, static_cast<float>(m_height))) * 2.0f; };

                const float vx0 = toNdcX(x0);
                const float vy0 = toNdcY(y0p);
                const float vx1 = toNdcX(x1p);
                const float vy1 = toNdcY(y1p);
                const float vx2 = toNdcX(x2p);
                const float vy2 = toNdcY(y2p);
                const float vx3 = toNdcX(x3p);
                const float vy3 = toNdcY(y3p);
                float uu0 = u0;
                float uu1 = u1;
                float vv0 = v0;
                float vv1 = v1;

                const float du = (uu1 - uu0);
                const float dv = (vv1 - vv0);
                const float ru0 = uu0 + (fitOffX) * du;
                const float rv0 = vv0 + (fitOffY) * dv;
                const float ru1 = uu0 + (fitOffX + fitScaleX) * du;
                const float rv1 = vv0 + (fitOffY + fitScaleY) * dv;

                struct V { float pos[2]; float uv[2]; };
                const V verts[4] = {
                    {{vx0, vy0}, {ru0, rv1}},
                    {{vx1, vy1}, {ru1, rv1}},
                    {{vx2, vy2}, {ru0, rv0}},
                    {{vx3, vy3}, {ru1, rv0}},
                };

                id<MTLRenderCommandEncoder> enc = (__bridge id<MTLRenderCommandEncoder>)m_renderEncoder;
                id<MTLRenderPipelineState> pso = (__bridge id<MTLRenderPipelineState>)m_overlayPipeline;
                id<MTLSamplerState> samp = (__bridge id<MTLSamplerState>)m_videoSampler;
                if (!enc || !pso || !samp) return;

                struct U { float p0[4]; float uvRect[4]; float p1[4]; };
                U u;
                u.p0[0] = 0.0f;
                u.p0[1] = 0.0f;
                u.p0[2] = 0.0f;
                u.p0[3] = overlay.opacity * animAlphaMul;
                u.uvRect[0] = 0.0f;
                u.uvRect[1] = 0.0f;
                u.uvRect[2] = 1.0f;
                u.uvRect[3] = 1.0f;
                u.p1[0] = radiusPxDraw;
                u.p1[1] = frameWpx;
                u.p1[2] = frameHpx;
                u.p1[3] = 0.0f;

                [enc setRenderPipelineState:pso];
                [enc setVertexBytes:verts length:sizeof(verts) atIndex:0];
                [enc setFragmentTexture:tex atIndex:0];
                [enc setFragmentSamplerState:samp atIndex:0];
                [enc setFragmentBytes:&u length:sizeof(u) atIndex:0];
                [enc drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
            };

            if (overlay.mediaType == "video") {
                if (m_overlayVideoPath != path) {
                    resetOverlayVideoDecoder();
                    m_overlayVideoPath = path;

                    NSString* p = [NSString stringWithUTF8String:path.c_str()];
                    if (!p || p.length == 0) {
                        return;
                    }
                    NSURL* url = nil;
                    if ([p hasPrefix:@"file://"]) {
                        url = [NSURL URLWithString:p];
                    }
                    if (!url) {
                        url = [NSURL fileURLWithPath:p];
                    }
                    AVURLAsset* a = [AVURLAsset URLAssetWithURL:url options:nil];
                    if (!a) {
                        return;
                    }
                    m_overlayVideoAsset = (__bridge_retained void*)a;

                    NSError* err = nil;
                    AVAssetReader* reader = [[AVAssetReader alloc] initWithAsset:a error:&err];
                    if (err || !reader) {
                        resetOverlayVideoDecoder();
                        return;
                    }

                    NSArray<AVAssetTrack*>* tracks = [a tracksWithMediaType:AVMediaTypeVideo];
                    AVAssetTrack* track = (tracks.count > 0) ? tracks[0] : nil;
                    if (!track) {
                        resetOverlayVideoDecoder();
                        return;
                    }

                    {
                        CGAffineTransform t = track.preferredTransform;
                        const float angle = std::atan2((float)t.b, (float)t.a) * (180.0f / 3.1415926535f);
                        m_overlayVideoPreferredRotationDeg = vidviz::render::normalizeDeg(angle);
                    }

                    NSDictionary* outSettings = @{
                        (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
                        (id)kCVPixelBufferMetalCompatibilityKey: @YES,
                        (id)kCVPixelBufferIOSurfacePropertiesKey: @{},
                    };
                    AVAssetReaderTrackOutput* out = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:track outputSettings:outSettings];
                    out.alwaysCopiesSampleData = NO;
                    if (![reader canAddOutput:out]) {
                        resetOverlayVideoDecoder();
                        return;
                    }
                    [reader addOutput:out];

                    if (asset.duration > 0) {
                        const CMTime start = CMTimeMake(static_cast<int64_t>(asset.cutFrom), 1000);
                        const CMTime dur = CMTimeMake(static_cast<int64_t>(asset.duration), 1000);
                        reader.timeRange = CMTimeRangeMake(start, dur);
                    }

                    if (![reader startReading]) {
                        resetOverlayVideoDecoder();
                        return;
                    }

                    m_overlayVideoReader = (__bridge_retained void*)reader;
                    m_overlayVideoOutput = (__bridge_retained void*)out;
                    m_overlayVideoLastPtsUs = -1;
                }

                AVAssetReaderTrackOutput* out = (__bridge AVAssetReaderTrackOutput*)m_overlayVideoOutput;
                if (!out) {
                    return;
                }

                const double speed = (asset.playbackSpeed <= 0.0001f) ? 1.0 : asset.playbackSpeed;
                const int64_t desiredUs = static_cast<int64_t>((static_cast<double>(asset.cutFrom) + static_cast<double>(localTime) * speed) * 1000.0);
                while (m_overlayVideoLastPtsUs < desiredUs) {
                    CMSampleBufferRef sb = [out copyNextSampleBuffer];
                    if (!sb) {
                        break;
                    }
                    const CMTime pts = CMSampleBufferGetPresentationTimeStamp(sb);
                    const double sec = CMTimeGetSeconds(pts);
                    const int64_t ptsUs = (sec > 0.0) ? static_cast<int64_t>(sec * 1000000.0) : 0;
                    if (m_overlayVideoLastSample) {
                        CFRelease(m_overlayVideoLastSample);
                        m_overlayVideoLastSample = nullptr;
                    }
                    m_overlayVideoLastSample = (void*)sb;
                    m_overlayVideoLastPtsUs = ptsUs;
                }
                if (!m_overlayVideoLastSample) {
                    return;
                }

                CMSampleBufferRef sb = (CMSampleBufferRef)m_overlayVideoLastSample;
                CVImageBufferRef img = CMSampleBufferGetImageBuffer(sb);
                if (!img) {
                    return;
                }
                CVPixelBufferRef pb = (CVPixelBufferRef)img;
                const size_t w = CVPixelBufferGetWidth(pb);
                const size_t h = CVPixelBufferGetHeight(pb);
                if (w == 0 || h == 0) {
                    return;
                }

                CVMetalTextureCacheRef cache = (CVMetalTextureCacheRef)m_textureCache;
                CVMetalTextureRef cvTex = nullptr;
                const CVReturn trc = CVMetalTextureCacheCreateTextureFromImage(
                    kCFAllocatorDefault,
                    cache,
                    pb,
                    nil,
                    MTLPixelFormatBGRA8Unorm,
                    w,
                    h,
                    0,
                    &cvTex
                );
                if (trc != kCVReturnSuccess || !cvTex) {
                    return;
                }

                id<MTLTexture> tex = CVMetalTextureGetTexture(cvTex);
                if (!tex) {
                    CFRelease(cvTex);
                    return;
                }

                const float rot = m_overlayVideoPreferredRotationDeg;
                const bool rot90 = isRot90(rot);
                const int32_t srcW = rot90 ? (int32_t)h : (int32_t)w;
                const int32_t srcH = rot90 ? (int32_t)w : (int32_t)h;
                drawOverlayTexture(tex, srcW, srcH, rot);
                CFRelease(cvTex);
                return;
            }

            // default overlay mediaType = image
            GPUTexture t = loadTexture(asset.srcPath);
            id<MTLTexture> tex = (__bridge id<MTLTexture>)t.handle;
            if (!tex) {
                return;
            }
            drawOverlayTexture(tex, t.width, t.height, 0.0f);
            return;
        }

        if (m_imagePath != path || !m_imageTexture) {
            if (m_imageTexture) {
                id<MTLTexture> t = (__bridge_transfer id<MTLTexture>)m_imageTexture;
                (void)t;
                m_imageTexture = nullptr;
            }
            m_imagePath = path;

            id<MTLDevice> device = (__bridge id<MTLDevice>)m_device;
            if (!device) return;

            NSString* p = [NSString stringWithUTF8String:path.c_str()];
            if (!p || p.length == 0) return;
            NSURL* url = nil;
            if ([p hasPrefix:@"file://"]) {
                url = [NSURL URLWithString:p];
            }
            if (!url) {
                url = [NSURL fileURLWithPath:p];
            }

            MTKTextureLoader* loader = [[MTKTextureLoader alloc] initWithDevice:device];
            NSError* err = nil;
            NSDictionary* opts = @{ MTKTextureLoaderOptionSRGB: @NO };
            id<MTLTexture> tex = [loader newTextureWithContentsOfURL:url options:opts error:&err];
            if (err || !tex) {
                if (err) {
                    LOGE("VIDVIZ_ERROR: Failed to load image texture: %s", [[err localizedDescription] UTF8String]);
                }
                return;
            }
            m_imageTexture = (__bridge_retained void*)tex;
        }

        id<MTLRenderPipelineState> pso = (__bridge id<MTLRenderPipelineState>)m_videoPipeline;
        id<MTLSamplerState> samp = (__bridge id<MTLSamplerState>)m_videoSampler;
        id<MTLTexture> tex = (__bridge id<MTLTexture>)m_imageTexture;
        if (!pso || !samp || !tex) return;

        vidviz::render::QuadVertex qv[4];
        const float rot = m_rotationDeg;
        const bool rot90 = isRot90(rot);
        const int32_t srcW = rot90 ? (int32_t)tex.height : (int32_t)tex.width;
        const int32_t srcH = rot90 ? (int32_t)tex.width : (int32_t)tex.height;
        vidviz::render::computeBaseMediaQuad(m_width, m_height, srcW, srcH, m_cropMode, rot, m_flipH, m_flipV, qv);

        struct V { float pos[2]; float uv[2]; };
        V verts[4];
        for (int i = 0; i < 4; i++) {
            verts[i].pos[0] = qv[i].pos[0];
            verts[i].pos[1] = qv[i].pos[1];
            verts[i].uv[0] = qv[i].uv[0];
            verts[i].uv[1] = qv[i].uv[1];
        }
        [enc setRenderPipelineState:pso];
        [enc setVertexBytes:verts length:sizeof(verts) atIndex:0];
        [enc setFragmentTexture:tex atIndex:0];
        [enc setFragmentSamplerState:samp atIndex:0];
        [enc drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
        return;
    }
    if (m_videoPath != path) {
        resetVideoDecoder();
        m_videoPath = path;

        NSString* p = [NSString stringWithUTF8String:path.c_str()];
        if (!p || p.length == 0) {
            return;
        }
        NSURL* url = nil;
        if ([p hasPrefix:@"file://"]) {
            url = [NSURL URLWithString:p];
        }
        if (!url) {
            url = [NSURL fileURLWithPath:p];
        }
        AVURLAsset* a = [AVURLAsset URLAssetWithURL:url options:nil];
        if (!a) {
            return;
        }
        m_videoAsset = (__bridge_retained void*)a;

        NSError* err = nil;
        AVAssetReader* reader = [[AVAssetReader alloc] initWithAsset:a error:&err];
        if (err || !reader) {
            if (err) {
                LOGE("VIDVIZ_ERROR: Video reader create failed: %s", [[err localizedDescription] UTF8String]);
            }
            resetVideoDecoder();
            return;
        }

        NSArray<AVAssetTrack*>* tracks = [a tracksWithMediaType:AVMediaTypeVideo];
        AVAssetTrack* track = (tracks.count > 0) ? tracks[0] : nil;
        if (!track) {
            LOGE("VIDVIZ_ERROR: No video track");
            resetVideoDecoder();
            return;
        }

        {
            CGAffineTransform t = track.preferredTransform;
            const float angle = std::atan2((float)t.b, (float)t.a) * (180.0f / 3.1415926535f);
            m_videoPreferredRotationDeg = vidviz::render::normalizeDeg(angle);
        }

        NSDictionary* outSettings = @{
            (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
            (id)kCVPixelBufferMetalCompatibilityKey: @YES,
            (id)kCVPixelBufferIOSurfacePropertiesKey: @{},
        };
        AVAssetReaderTrackOutput* out = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:track outputSettings:outSettings];
        out.alwaysCopiesSampleData = NO;
        if (![reader canAddOutput:out]) {
            LOGE("VIDVIZ_ERROR: Cannot add video reader output");
            resetVideoDecoder();
            return;
        }
        [reader addOutput:out];

        if (asset.duration > 0) {
            const CMTime start = CMTimeMake(static_cast<int64_t>(asset.cutFrom), 1000);
            const CMTime dur = CMTimeMake(static_cast<int64_t>(asset.duration), 1000);
            reader.timeRange = CMTimeRangeMake(start, dur);
        }

        if (![reader startReading]) {
            LOGE("VIDVIZ_ERROR: Video reader startReading failed");
            resetVideoDecoder();
            return;
        }

        m_videoReader = (__bridge_retained void*)reader;
        m_videoOutput = (__bridge_retained void*)out;
        m_videoLastPtsUs = -1;
    }

    AVAssetReader* reader = (__bridge AVAssetReader*)m_videoReader;
    AVAssetReaderTrackOutput* out = (__bridge AVAssetReaderTrackOutput*)m_videoOutput;
    if (!reader || !out) {
        return;
    }

    const double speed = (asset.playbackSpeed <= 0.0001f) ? 1.0 : asset.playbackSpeed;
    const int64_t desiredUs = static_cast<int64_t>((static_cast<double>(asset.cutFrom) + static_cast<double>(localTime) * speed) * 1000.0);

    while (m_videoLastPtsUs < desiredUs) {
        CMSampleBufferRef sb = [out copyNextSampleBuffer];
        if (!sb) {
            break;
        }
        const CMTime pts = CMSampleBufferGetPresentationTimeStamp(sb);
        const double sec = CMTimeGetSeconds(pts);
        const int64_t ptsUs = (sec > 0.0) ? static_cast<int64_t>(sec * 1000000.0) : 0;

        if (m_videoLastSample) {
            CFRelease(m_videoLastSample);
            m_videoLastSample = nullptr;
        }
        m_videoLastSample = (void*)sb;
        m_videoLastPtsUs = ptsUs;
    }

    if (!m_videoLastSample) {
        return;
    }

    CMSampleBufferRef sb = (CMSampleBufferRef)m_videoLastSample;
    CVImageBufferRef img = CMSampleBufferGetImageBuffer(sb);
    if (!img) {
        return;
    }

    CVPixelBufferRef pb = (CVPixelBufferRef)img;
    const size_t w = CVPixelBufferGetWidth(pb);
    const size_t h = CVPixelBufferGetHeight(pb);
    if (w == 0 || h == 0) {
        return;
    }

    CVMetalTextureCacheRef cache = (CVMetalTextureCacheRef)m_textureCache;
    CVMetalTextureRef cvTex = nullptr;
    const CVReturn trc = CVMetalTextureCacheCreateTextureFromImage(
        kCFAllocatorDefault,
        cache,
        pb,
        nil,
        MTLPixelFormatBGRA8Unorm,
        w,
        h,
        0,
        &cvTex
    );
    if (trc != kCVReturnSuccess || !cvTex) {
        return;
    }

    id<MTLTexture> tex = CVMetalTextureGetTexture(cvTex);
    if (!tex) {
        CFRelease(cvTex);
        return;
    }

    id<MTLRenderPipelineState> pso = (__bridge id<MTLRenderPipelineState>)m_videoPipeline;
    id<MTLSamplerState> samp = (__bridge id<MTLSamplerState>)m_videoSampler;

    vidviz::render::QuadVertex qv[4];
    const float rot = vidviz::render::normalizeDeg(m_rotationDeg + m_videoPreferredRotationDeg);
    const bool rot90 = isRot90(rot);
    const int32_t srcW = rot90 ? (int32_t)h : (int32_t)w;
    const int32_t srcH = rot90 ? (int32_t)w : (int32_t)h;
    vidviz::render::computeBaseMediaQuad(m_width, m_height, srcW, srcH, m_cropMode, rot, m_flipH, m_flipV, qv);

    struct V { float pos[2]; float uv[2]; };
    V verts[4];
    for (int i = 0; i < 4; i++) {
        verts[i].pos[0] = qv[i].pos[0];
        verts[i].pos[1] = qv[i].pos[1];
        verts[i].uv[0] = qv[i].uv[0];
        verts[i].uv[1] = qv[i].uv[1];
    }

    [enc setRenderPipelineState:pso];
    [enc setVertexBytes:verts length:sizeof(verts) atIndex:0];
    [enc setFragmentTexture:tex atIndex:0];
    [enc setFragmentSamplerState:samp atIndex:0];
    [enc drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];

    CFRelease(cvTex);
}

void MetalRenderer::renderText(const Asset& asset, TimeMs localTime) {
    LOGV("renderText: %s @ %lld", asset.id.c_str(), localTime);
    if (m_textRenderer) {
        m_textRenderer->render(asset, localTime);
    }
}

void MetalRenderer::renderShader(const Asset& asset, ShaderManager* shaderManager, TimeMs localTime) {
    LOGV("renderShader: %s @ %lld", asset.id.c_str(), localTime);
    if (!m_hasEncoderSurface) {
        return;
    }
    if (!shaderManager) {
        return;
    }
    if (!m_commandBuffer) {
        return;
    }

    std::string shaderType;
    float intensity = 0.5f;
    float speed = 1.0f;
    float angle = 0.0f;
    float frequency = 1.0f;
    float amplitude = 0.5f;
    float size = 1.0f;
    float density = 0.5f;
    float blurRadius = 5.0f;
    float vignetteSize = 0.5f;
    int64_t color = 0xFFFFFFFF;
    if (!vvParseShaderTypeAndParams(asset.dataJson, shaderType, intensity, speed, angle, frequency, amplitude, size, density, blurRadius, vignetteSize, color)) {
        return;
    }

    const std::string shaderId = shaderType;
    if (m_shaderPipelines.find(shaderId) == m_shaderPipelines.end() || !m_shaderPipelines[shaderId]) {
        const auto* shader = shaderManager->getShader(shaderId);
        if (!shader) {
            return;
        }
        if (!compileShader(shaderId, shader->vertexSource, shader->fragmentSource)) {
            return;
        }
    }
    auto it = m_shaderPipelines.find(shaderId);
    if (it == m_shaderPipelines.end() || !it->second) {
        return;
    }

    if (!ensurePostProcessTextures()) {
        return;
    }

    if (!ensureVideoPipeline()) {
        return;
    }

    if (m_renderEncoder) {
        id<MTLRenderCommandEncoder> enc = (__bridge id<MTLRenderCommandEncoder>)m_renderEncoder;
        [enc endEncoding];
        m_renderEncoder = nullptr;
        m_exportSession.setCurrentEncoder(nullptr);
    }

    void* srcPtr = currentPostProcessSrcTexture();
    void* dstPtr = currentPostProcessDstTexture();
    id<MTLTexture> srcTex = (__bridge id<MTLTexture>)srcPtr;
    id<MTLTexture> dstTex = (__bridge id<MTLTexture>)dstPtr;
    if (!srcTex || !dstTex) {
        return;
    }

    id<MTLCommandBuffer> cb = (__bridge id<MTLCommandBuffer>)m_commandBuffer;
    MTLRenderPassDescriptor* passDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    passDescriptor.colorAttachments[0].texture = dstTex;
    passDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    passDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    passDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);
    id<MTLRenderCommandEncoder> enc = [cb renderCommandEncoderWithDescriptor:passDescriptor];
    if (!enc) {
        return;
    }
    m_renderEncoder = (__bridge void*)enc;
    m_exportSession.setCurrentEncoder(m_renderEncoder);

    bindShader(shaderId);

    const float tSec = static_cast<float>(localTime) / 1000.0f;
    setUniform("uResolution", static_cast<float>(m_width), static_cast<float>(m_height));
    setUniform("iResolution", static_cast<float>(m_width), static_cast<float>(m_height));
    setUniform("uTime", tSec);
    setUniform("iTime", tSec);
    setUniform("uIntensity", intensity);
    setUniform("uSpeed", speed);
    setUniform("uAngle", angle);
    setUniform("uFrequency", frequency);
    setUniform("uAmplitude", amplitude);
    setUniform("uDensity", density);
    setUniform("uDropSize", size);
    setUniform("uFlakeSize", size);
    setUniform("uBlurRadius", blurRadius);
    setUniform("uVignetteSize", vignetteSize);
    setUniform("uAspect", static_cast<float>(m_width) / std::max(1.0f, static_cast<float>(m_height)));
    {
        float r = 1.0f, g = 1.0f, b = 1.0f;
        vvArgbToRgb01(color, r, g, b);
        setUniform("uColor", r, g, b);
    }
    setTexture("uTexture", GPUTexture{(__bridge void*)srcTex, m_width, m_height, 0}, 0);
    setTexture("iChannel0", GPUTexture{(__bridge void*)srcTex, m_width, m_height, 0}, 0);

    struct V { float pos[2]; float uv[2]; };
    const V verts[4] = {
        {{-1.0f, -1.0f}, {0.0f, 1.0f}},
        {{ 1.0f, -1.0f}, {1.0f, 1.0f}},
        {{-1.0f,  1.0f}, {0.0f, 0.0f}},
        {{ 1.0f,  1.0f}, {1.0f, 0.0f}},
    };

    [enc setVertexBytes:verts length:sizeof(verts) atIndex:0];
    if (!m_uniformStaging.empty()) {
        [enc setFragmentBytes:m_uniformStaging.data() length:m_uniformStaging.size() atIndex:0];
    }
    id<MTLSamplerState> samp = (__bridge id<MTLSamplerState>)m_videoSampler;
    if (samp) {
        [enc setFragmentSamplerState:samp atIndex:0];
    }
    for (const auto& kv : m_boundTextures) {
        const int unit = kv.first;
        id<MTLTexture> t = (__bridge id<MTLTexture>)kv.second;
        if (t) {
            [enc setFragmentTexture:t atIndex:unit];
        }
    }
    [enc drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];

    [enc endEncoding];
    m_renderEncoder = nullptr;
    m_exportSession.setCurrentEncoder(nullptr);
    swapPostProcessTextures();
}

void MetalRenderer::renderVisualizer(const Asset& asset, const std::vector<FFTData>& fftData, TimeMs localTime) {
    LOGV("renderVisualizer: %s @ %lld", asset.id.c_str(), localTime);
    if (!m_renderEncoder) return;

    std::string renderMode;
    std::string shaderType;
    std::string type;
    std::string audioPath;
    std::string effectStyle;
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
    int64_t projectDurationMs = 0;
    VVVisualizerExtraParams extra;
    if (!vvParseVisualizerParams(asset.dataJson, renderMode, shaderType, type, audioPath, fullScreen, alpha, sensitivity, speed, smoothness, reactivity, x, y, scale, rotation, barCount, color, gradientColor, projectDurationMs, effectStyle, extra)) {
        return;
    }

    alpha = vvClamp01(alpha);

    if (barCount < 1) barCount = 1;
    if (barCount > 128) barCount = 128;
    if (sensitivity < 0.0f) sensitivity = 0.0f;
    if (sensitivity > 2.0f) sensitivity = 2.0f;

    if (speed < 0.0f) speed = 0.0f;
    if (speed > 3.0f) speed = 3.0f;
    if (scale < 0.05f) scale = 0.05f;
    if (scale > 4.0f) scale = 4.0f;

    if (extra.amplitude < 0.0f) extra.amplitude = 0.0f;
    if (extra.amplitude > 3.0f) extra.amplitude = 3.0f;
    if (extra.barFill < 0.0f) extra.barFill = 0.0f;
    if (extra.barFill > 1.0f) extra.barFill = 1.0f;
    if (extra.glow < 0.0f) extra.glow = 0.0f;
    if (extra.glow > 1.0f) extra.glow = 1.0f;
    if (extra.strokeWidth < 0.0f) extra.strokeWidth = 0.0f;
    if (extra.strokeWidth > 24.0f) extra.strokeWidth = 24.0f;

    if (renderMode == "progress") {
        if (extra.strokeWidth < 6.0f) extra.strokeWidth = 6.0f;
    }

    if (renderMode == "counter") {
        id<MTLDevice> device = (__bridge id<MTLDevice>)m_device;
        if (!device) return;

        auto ensureCounterTextPipeline = [&]() -> bool {
            if (m_counterTextPipeline) return true;
            static NSString* const src =
                @"#include <metal_stdlib>\n"
                @"using namespace metal;\n"
                @"struct VIn { float2 pos [[attribute(0)]]; float2 uv [[attribute(1)]]; };\n"
                @"struct VOut { float4 position [[position]]; float2 uv; };\n"
                @"vertex VOut vmain(uint vid [[vertex_id]], const device float4* vb [[buffer(0)]]) {\n"
                @"  float4 v = vb[vid];\n"
                @"  VOut o; o.position = float4(v.xy, 0.0, 1.0); o.uv = v.zw; return o;\n"
                @"}\n"
                @"struct U { float alpha; };\n"
                @"fragment float4 fmain(VOut in [[stage_in]], texture2d<float> tex [[texture(0)]], sampler samp [[sampler(0)]], constant U& u [[buffer(0)]]) {\n"
                @"  float4 c = tex.sample(samp, in.uv);\n"
                @"  float a = c.a * clamp(u.alpha, 0.0, 1.0);\n"
                @"  return float4(c.rgb * clamp(u.alpha, 0.0, 1.0), a);\n"
                @"}\n";

            NSError* err = nil;
            id<MTLLibrary> lib = [device newLibraryWithSource:src options:nil error:&err];
            if (err || !lib) {
                return false;
            }
            id<MTLFunction> vf = [lib newFunctionWithName:@"vmain"];
            id<MTLFunction> ff = [lib newFunctionWithName:@"fmain"];
            if (!vf || !ff) {
                return false;
            }

            MTLRenderPipelineDescriptor* desc = [[MTLRenderPipelineDescriptor alloc] init];
            desc.vertexFunction = vf;
            desc.fragmentFunction = ff;
            desc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
            desc.colorAttachments[0].blendingEnabled = YES;
            desc.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
            desc.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
            desc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorOne;
            desc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
            desc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
            desc.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;

            id<MTLRenderPipelineState> pso = [device newRenderPipelineStateWithDescriptor:desc error:&err];
            if (err || !pso) {
                return false;
            }
            m_counterTextPipeline = (__bridge_retained void*)pso;
            return true;
        };

        if (!ensureVideoPipeline()) return;
        if (!ensureCounterTextPipeline()) return;

        auto formatMs = [&](int64_t ms) -> std::string {
            if (ms < 0) ms = 0;
            const int64_t totalSeconds = ms / 1000;
            const int64_t minutes = totalSeconds / 60;
            const int64_t seconds = totalSeconds % 60;
            char buf[16];
            std::snprintf(buf, sizeof(buf), "%02lld:%02lld", (long long)minutes, (long long)seconds);
            return std::string(buf);
        };

        const int64_t denomMs = (projectDurationMs > 0) ? projectDurationMs : static_cast<int64_t>(asset.duration);
        const int64_t totalMs = (denomMs > 0) ? denomMs : 1;
        const int64_t globalMs = static_cast<int64_t>(asset.begin) + static_cast<int64_t>(localTime);
        const int64_t elapsedMs = std::min<int64_t>(std::max<int64_t>(0, globalMs), totalMs);

        auto modeLabel = [&](const std::string& mode) -> std::string {
            if (mode == "remaining") return formatMs(totalMs - elapsedMs);
            if (mode == "total") return formatMs(totalMs);
            return formatMs(elapsedMs);
        };

        float baseR = 1.0f, baseG = 1.0f, baseB = 1.0f;
        vvArgbToRgb01(color, baseR, baseG, baseB);
        const float lum = 0.2126f * baseR + 0.7152f * baseG + 0.0722f * baseB;
        const int64_t defaultLabelColor = (lum < 0.5f) ? 0xFF000000 : 0xFFFFFFFF;

        float labelSize = 12.0f;
        if (extra.counterLabelSize == "small") labelSize = 10.0f;
        else if (extra.counterLabelSize == "large") labelSize = 14.0f;
        float fontPx = 0.03f * (labelSize / 12.0f) * static_cast<float>(m_width);
        if (!std::isfinite(fontPx) || fontPx < 8.0f) fontPx = 16.0f;
        if (fontPx > 512.0f) fontPx = 512.0f;

        float left = -1.0f;
        float right = 1.0f;
        float bottom = -1.0f;
        float top = 1.0f;
        if (!fullScreen) {
            const float tx = (x * 2.0f) - 1.0f;
            const float ty = ((1.0f - y) * 2.0f) - 1.0f;
            const float sx = scale;
            const float sy = (renderMode == "progress") ? (scale * 0.10f) : scale;
            left = -sx + tx;
            right = sx + tx;
            bottom = -sy + ty;
            top = sy + ty;
        }

        const float leftPx = (left + 1.0f) * 0.5f * static_cast<float>(m_width);
        const float rightPx = (right + 1.0f) * 0.5f * static_cast<float>(m_width);
        const float topPx = (1.0f - top) * 0.5f * static_cast<float>(m_height);
        const float bottomPx = (1.0f - bottom) * 0.5f * static_cast<float>(m_height);
        const float regionW = std::max(1.0f, rightPx - leftPx);
        const float regionH = std::max(1.0f, bottomPx - topPx);
        const float boxH = std::max(1.0f, regionH * 0.10f);
        const float padPx = 12.0f;

        float legacyDefaultY = 0.50f;
        if (extra.counterPos == "top") legacyDefaultY = 0.08f;
        else if (extra.counterPos == "bottom") legacyDefaultY = 0.92f;
        const float heightPxF = std::max(1.0f, static_cast<float>(m_height));
        const float legacyDy01 = extra.counterOffsetY / heightPxF;
        legacyDefaultY = std::min(1.0f, std::max(0.0f, legacyDefaultY + legacyDy01));

        const bool hasStartPos = (extra.counterStartPosX >= 0.0f && extra.counterStartPosY >= 0.0f);
        const bool hasEndPos = (extra.counterEndPosX >= 0.0f && extra.counterEndPosY >= 0.0f);
        const float startX01 = (extra.counterStartPosX >= 0.0f) ? extra.counterStartPosX : 0.10f;
        const float startY01 = (extra.counterStartPosY >= 0.0f) ? extra.counterStartPosY : legacyDefaultY;
        const float endX01 = (extra.counterEndPosX >= 0.0f) ? extra.counterEndPosX : 0.90f;
        const float endY01 = (extra.counterEndPosY >= 0.0f) ? extra.counterEndPosY : legacyDefaultY;

        const int64_t startColor = extra.hasCounterStartColor ? extra.counterStartColor : defaultLabelColor;
        const int64_t endColor = extra.hasCounterEndColor ? extra.counterEndColor : defaultLabelColor;

        const float animSec = static_cast<float>(elapsedMs) / 1000.0f;
        float animSpeed = speed;
        if (!std::isfinite(animSpeed)) animSpeed = 1.0f;
        if (animSpeed < 0.5f) animSpeed = 0.5f;
        if (animSpeed > 2.0f) animSpeed = 2.0f;

        float rotationDeg = 0.0f;
        float scaleX = 1.0f;
        float scaleY = 1.0f;
        float extraOffsetYPx = 0.0f;
        if (extra.counterAnim == "pulse") {
            const float baseFreq = 1.0f + 0.4f * animSpeed;
            const float phase = animSec * baseFreq * 2.0f * 3.1415926535f;
            const float s = 1.0f + 0.06f * std::sin(phase);
            scaleX = s;
            scaleY = s;
        } else if (extra.counterAnim == "flip") {
            const float baseFreq = 0.8f + 0.7f * animSpeed;
            const float phase = animSec * baseFreq * 2.0f * 3.1415926535f;
            const float c = std::cos(phase);
            const float mag = 0.15f + 0.85f * std::fabs(c);
            const float sign = (c >= 0.0f) ? 1.0f : -1.0f;
            scaleX = sign * mag;
            scaleY = 1.0f + 0.03f * std::cos(phase);
        } else if (extra.counterAnim == "leaf") {
            const float baseFreq = 1.0f + 0.6f * animSpeed;
            const float phase = animSec * baseFreq * 2.0f * 3.1415926535f;
            const float wave = std::sin(phase);
            rotationDeg = (0.18f * wave) * (180.0f / 3.1415926535f);
            extraOffsetYPx = -(std::fabs(wave)) * 10.0f;
            const float s = 1.0f + 0.03f * std::sin(phase + 1.2f);
            scaleX = s;
            scaleY = s;
        } else if (extra.counterAnim == "bounce") {
            const float baseFreq = 1.2f + 0.7f * animSpeed;
            const float phase = animSec * baseFreq * 2.0f * 3.1415926535f;
            const float wave = (std::sin(phase) + 1.0f) * 0.5f;
            const float eased = wave * wave;
            extraOffsetYPx = -eased * 18.0f;
            scaleX = 1.0f + 0.16f * eased;
            scaleY = 1.0f - 0.10f * eased;
        }

        auto rasterize = [&](const std::string& text, float fontPxLocal, int64_t labelColor, const std::string& weight, float shadowOpacity, float shadowBlur, float shadowOffsetX, float shadowOffsetY, float glowRadius, float glowOpacity, std::vector<uint8_t>& outBgra, int32_t& outW, int32_t& outH) -> bool {
            outBgra.clear();
            outW = 0;
            outH = 0;
            if (text.empty()) return false;

            float rr = 1.0f, gg = 1.0f, bb = 1.0f;
            vvArgbToRgb01(labelColor, rr, gg, bb);
            const float aa = static_cast<float>((static_cast<uint64_t>(labelColor) >> 24) & 0xFFu) / 255.0f;

            UIFontWeight fw = UIFontWeightSemibold;
            if (weight == "bold") fw = UIFontWeightBold;
            else if (weight == "normal") fw = UIFontWeightRegular;

            UIFont* uiFont = [UIFont systemFontOfSize:std::max(1.0f, fontPxLocal) weight:fw];
            if (!uiFont) return false;
            CTFontRef ctFont = CTFontCreateWithName((__bridge CFStringRef)uiFont.fontName, uiFont.pointSize, nullptr);
            if (!ctFont) return false;

            const float sOp = vvClamp01(shadowOpacity);
            const float sBlur = vvClamp(shadowBlur, 0.0f, 30.0f);
            const float sOffX = vvClamp(shadowOffsetX, -30.0f, 30.0f);
            const float sOffY = vvClamp(shadowOffsetY, -30.0f, 30.0f);
            const float gOp = vvClamp01(glowOpacity);
            const float gRad = vvClamp(glowRadius, 0.0f, 60.0f);

            float bleed = 0.0f;
            bleed = std::max(bleed, gRad * 2.0f);
            bleed = std::max(bleed, sBlur * 2.0f + (std::fabs(sOffX) + std::fabs(sOffY)));
            bleed = vvClamp(bleed, 0.0f, 80.0f);
            const int pad = static_cast<int>(std::ceil(bleed)) + 6;

            NSDictionary* attrs = @{
                (__bridge id)kCTFontAttributeName: (__bridge id)ctFont,
                (__bridge id)kCTForegroundColorAttributeName: (id)[UIColor colorWithRed:rr green:gg blue:bb alpha:aa].CGColor,
            };
            CFAttributedStringRef astr = CFAttributedStringCreate(kCFAllocatorDefault, (__bridge CFStringRef)[NSString stringWithUTF8String:text.c_str()], (__bridge CFDictionaryRef)attrs);
            if (!astr) {
                CFRelease(ctFont);
                return false;
            }
            CTLineRef line = CTLineCreateWithAttributedString(astr);
            CFRelease(astr);
            if (!line) {
                CFRelease(ctFont);
                return false;
            }

            CGFloat ascent = 0.0, descent = 0.0, leading = 0.0;
            const double adv = CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
            (void)adv;
            const int textW = std::max(1, static_cast<int>(std::ceil(ascent + descent + 0.0)));
            (void)textW;
            const CGRect bounds = CTLineGetBoundsWithOptions(line, kCTLineBoundsUseOpticalBounds);
            const int bw = std::max(1, static_cast<int>(std::ceil(bounds.size.width)));
            const int bh = std::max(1, static_cast<int>(std::ceil(bounds.size.height)));
            const int w = std::min(4096, bw + pad * 2);
            const int h = std::min(4096, bh + pad * 2);

            if (w <= 0 || h <= 0) {
                CFRelease(line);
                CFRelease(ctFont);
                return false;
            }

            outW = w;
            outH = h;
            outBgra.assign(static_cast<size_t>(w) * static_cast<size_t>(h) * 4u, 0);

            CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
            CGContextRef ctx = CGBitmapContextCreate(outBgra.data(), w, h, 8, w * 4, cs, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
            CGColorSpaceRelease(cs);
            if (!ctx) {
                CFRelease(line);
                CFRelease(ctFont);
                outBgra.clear();
                outW = 0;
                outH = 0;
                return false;
            }

            CGContextClearRect(ctx, CGRectMake(0, 0, w, h));
            CGContextTranslateCTM(ctx, 0, h);
            CGContextScaleCTM(ctx, 1.0, -1.0);

            const CGPoint pos = CGPointMake(static_cast<CGFloat>(pad) - bounds.origin.x, static_cast<CGFloat>(pad) - bounds.origin.y);

            if (gOp > 0.0f && gRad > 0.0f) {
                CGColorRef glowC = [UIColor colorWithRed:rr green:gg blue:bb alpha:(aa * gOp)].CGColor;
                CGContextSetShadowWithColor(ctx, CGSizeMake(0.0, 0.0), gRad, glowC);
                CGContextSetTextPosition(ctx, pos.x, pos.y);
                CTLineDraw(line, ctx);
                CGContextSetShadowWithColor(ctx, CGSizeZero, 0.0, nullptr);
            }

            if (sOp > 0.0f && (sBlur > 0.0f || sOffX != 0.0f || sOffY != 0.0f)) {
                CGColorRef shC = [UIColor colorWithRed:0 green:0 blue:0 alpha:sOp].CGColor;
                CGContextSetShadowWithColor(ctx, CGSizeMake(sOffX, -sOffY), sBlur, shC);
                CGContextSetTextPosition(ctx, pos.x, pos.y);
                CTLineDraw(line, ctx);
                CGContextSetShadowWithColor(ctx, CGSizeZero, 0.0, nullptr);
            }

            CGContextSetTextPosition(ctx, pos.x, pos.y);
            CTLineDraw(line, ctx);

            CGContextFlush(ctx);
            CGContextRelease(ctx);
            CFRelease(line);
            CFRelease(ctFont);
            return (!outBgra.empty() && outW > 0 && outH > 0);
        };

        auto makeTexture = [&](const std::vector<uint8_t>& bgra, int32_t w, int32_t h) -> id<MTLTexture> {
            if (bgra.empty() || w <= 0 || h <= 0) return nil;
            MTLTextureDescriptor* td = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:(NSUInteger)w height:(NSUInteger)h mipmapped:NO];
            td.usage = MTLTextureUsageShaderRead;
            td.storageMode = MTLStorageModeShared;
            id<MTLTexture> tex = [device newTextureWithDescriptor:td];
            if (!tex) return nil;
            MTLRegion rgn = { {0, 0, 0}, {(NSUInteger)w, (NSUInteger)h, 1} };
            [tex replaceRegion:rgn mipmapLevel:0 withBytes:bgra.data() bytesPerRow:(NSUInteger)w * 4];
            return tex;
        };

        auto pushTexturedQuad = [&](id<MTLTexture> tex, int32_t tw, int32_t th, float cxPx, float cyPx, float rotDeg, float sx, float sy, float alpha) {
            if (!tex || tw <= 0 || th <= 0) return;
            const float w = static_cast<float>(tw);
            const float h = static_cast<float>(th);
            const float hw = w * 0.5f;
            const float hh = h * 0.5f;

            const float rad = rotDeg * (3.1415926535f / 180.0f);
            const float cs = std::cos(rad);
            const float sn = std::sin(rad);

            auto xform = [&](float x0, float y0, float& ox, float& oy) {
                const float x = x0 * sx;
                const float y = y0 * sy;
                const float rx = x * cs - y * sn;
                const float ry = x * sn + y * cs;
                ox = cxPx + rx;
                oy = cyPx + ry;
            };

            float x0, y0, x1, y1, x2, y2, x3, y3;
            xform(-hw, -hh, x0, y0);
            xform(hw, -hh, x1, y1);
            xform(-hw, hh, x2, y2);
            xform(hw, hh, x3, y3);

            auto toNdcX = [&](float px) { return (px / std::max(1.0f, static_cast<float>(m_width))) * 2.0f - 1.0f; };
            auto toNdcY = [&](float py) { return 1.0f - (py / std::max(1.0f, static_cast<float>(m_height))) * 2.0f; };

            const float vx0 = toNdcX(x0);
            const float vy0 = toNdcY(y0);
            const float vx1 = toNdcX(x1);
            const float vy1 = toNdcY(y1);
            const float vx2 = toNdcX(x2);
            const float vy2 = toNdcY(y2);
            const float vx3 = toNdcX(x3);
            const float vy3 = toNdcY(y3);

            struct V { float pos[2]; float uv[2]; };
            const V verts[4] = {
                {{vx0, vy0}, {0.0f, 1.0f}},
                {{vx1, vy1}, {1.0f, 1.0f}},
                {{vx2, vy2}, {0.0f, 0.0f}},
                {{vx3, vy3}, {1.0f, 0.0f}},
            };

            id<MTLRenderCommandEncoder> enc = (__bridge id<MTLRenderCommandEncoder>)m_renderEncoder;
            if (!enc) return;
            id<MTLRenderPipelineState> pso = (__bridge id<MTLRenderPipelineState>)m_counterTextPipeline;
            id<MTLSamplerState> samp = (__bridge id<MTLSamplerState>)m_videoSampler;
            if (!pso || !samp) return;

            struct U { float alpha; };
            U u{alpha};

            [enc setRenderPipelineState:pso];
            [enc setVertexBytes:verts length:sizeof(verts) atIndex:0];
            [enc setFragmentTexture:tex atIndex:0];
            [enc setFragmentSamplerState:samp atIndex:0];
            [enc setFragmentBytes:&u length:sizeof(u) atIndex:0];
            [enc drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
        };

        auto drawLabel = [&](const std::string& keySuffix, const std::string& text, float posX01, float posY01, bool useLegacyTopLeftPx, float legacyXpx, float legacyYpx, int64_t labelColor, const std::string& weight, float shadowOpacity, float shadowBlur, float shadowOffsetX, float shadowOffsetY, float glowRadius, float glowOpacity) {
            if (text.empty()) return;

            std::string key;
            key.reserve(asset.id.size() + text.size() + 128);
            key += asset.id;
            key += "|counter|";
            key += keySuffix;
            key += "|";
            key += std::to_string(m_width);
            key += "x";
            key += std::to_string(m_height);
            key += "|";
            key += text;
            key += "|";
            key += std::to_string(static_cast<int>(fontPx));
            key += "|";
            key += std::to_string(static_cast<int64_t>(labelColor));
            key += "|";
            key += weight;
            key += "|";
            key += std::to_string(shadowOpacity);
            key += "|";
            key += std::to_string(shadowBlur);
            key += "|";
            key += std::to_string(shadowOffsetX);
            key += "|";
            key += std::to_string(shadowOffsetY);
            key += "|";
            key += std::to_string(glowRadius);
            key += "|";
            key += std::to_string(glowOpacity);

            auto itT = m_counterTextTextures.find(key);
            if (itT == m_counterTextTextures.end() || !itT->second.tex) {
                std::vector<uint8_t> bgra;
                int32_t tw = 0;
                int32_t th = 0;
                if (!rasterize(text, fontPx, labelColor, weight, shadowOpacity, shadowBlur, shadowOffsetX, shadowOffsetY, glowRadius, glowOpacity, bgra, tw, th)) {
                    return;
                }
                id<MTLTexture> tex = makeTexture(bgra, tw, th);
                if (!tex) {
                    return;
                }
                CounterTextTextureInfo info;
                info.tex = (__bridge_retained void*)tex;
                info.width = tw;
                info.height = th;
                m_counterTextTextures[key] = info;
                itT = m_counterTextTextures.find(key);
            }
            if (itT == m_counterTextTextures.end()) return;
            const CounterTextTextureInfo& ti = itT->second;
            id<MTLTexture> tex = (__bridge id<MTLTexture>)ti.tex;
            if (!tex || ti.width <= 0 || ti.height <= 0) return;

            float cxPx = posX01 * std::max(1.0f, static_cast<float>(m_width));
            float cyPx = posY01 * std::max(1.0f, static_cast<float>(m_height));
            if (useLegacyTopLeftPx) {
                cxPx = legacyXpx + static_cast<float>(ti.width) * 0.5f;
                cyPx = legacyYpx + static_cast<float>(ti.height) * 0.5f + extraOffsetYPx;
            } else {
                cyPx = cyPx + extraOffsetYPx;
            }

            cxPx = vvClamp(cxPx, 0.0f, std::max(1.0f, static_cast<float>(m_width)));
            cyPx = vvClamp(cyPx, 0.0f, std::max(1.0f, static_cast<float>(m_height)));

            pushTexturedQuad(tex, ti.width, ti.height, cxPx, cyPx, rotationDeg, scaleX, scaleY, alpha);
        };

        if (extra.counterStartEnabled) {
            const std::string s = modeLabel(extra.counterStartMode);
            drawLabel(
                "start",
                s,
                startX01,
                startY01,
                false,
                leftPx + padPx,
                topPx + (boxH * 0.5f) - 20.0f + extra.counterOffsetY,
                startColor,
                extra.counterStartWeight,
                extra.counterStartShadowOpacity,
                extra.counterStartShadowBlur,
                extra.counterStartShadowOffsetX,
                extra.counterStartShadowOffsetY,
                extra.counterStartGlowRadius,
                extra.counterStartGlowOpacity
            );
        }
        if (extra.counterEndEnabled) {
            const std::string e = modeLabel(extra.counterEndMode);
            drawLabel(
                "end",
                e,
                endX01,
                endY01,
                false,
                (leftPx + regionW) - padPx - 120.0f,
                topPx + (boxH * 0.5f) - 20.0f + extra.counterOffsetY,
                endColor,
                extra.counterEndWeight,
                extra.counterEndShadowOpacity,
                extra.counterEndShadowBlur,
                extra.counterEndShadowOffsetX,
                extra.counterEndShadowOffsetY,
                extra.counterEndGlowRadius,
                extra.counterEndGlowOpacity
            );
        }
        return;
    }

    // Shader-based visualizers (shader/visual/progress) must render through the compiled shader pipeline.
    if (renderMode == "shader" || renderMode == "visual" || renderMode == "progress") {
        if (!m_hasEncoderSurface) {
            // Export parity is the primary goal; interactive Metal preview isn't used.
            return;
        }
        if (!m_commandBuffer) {
            return;
        }

        // Ensure we have a sampler available for shaders that use textures.
        if (!ensureVideoPipeline()) {
            return;
        }

        const std::string shaderId = vvPickVisualizerShaderId(renderMode, shaderType, type);
        auto it = m_shaderPipelines.find(shaderId);
        if (it == m_shaderPipelines.end() || !it->second) {
            return;
        }

        // Compute quad bounds (match Android GLES path)
        float left = -1.0f;
        float right = 1.0f;
        float bottom = -1.0f;
        float top = 1.0f;
        if (!fullScreen) {
            const float tx = (x * 2.0f) - 1.0f;
            const float ty = ((1.0f - y) * 2.0f) - 1.0f;
            const float sxy = scale;
            left = -sxy + tx;
            right = sxy + tx;
            bottom = -sxy + ty;
            top = sxy + ty;
        }

        const float tSec = static_cast<float>(localTime) / 1000.0f;

        // FFT -> 8 bands, apply smoothness/reactivity + mirror + sensitivity (Flutter-like)
        const std::string& fftKey = (!audioPath.empty()) ? audioPath : asset.srcPath;
        const FFTData* fft = vvFindFftByAudioPath(fftData, fftKey);
        const std::vector<float>* frame = nullptr;
        if (fft && !fft->frames.empty() && fft->hopSize > 0 && fft->sampleRate > 0) {
            const double seconds = static_cast<double>(std::max<int64_t>(0, localTime)) / 1000.0;
            const double frameIndexD = (seconds * static_cast<double>(fft->sampleRate)) / static_cast<double>(fft->hopSize);
            int64_t frameIndex = static_cast<int64_t>(frameIndexD);
            if (frameIndex < 0) frameIndex = 0;
            if (frameIndex >= (int64_t)fft->frames.size()) frameIndex = (int64_t)fft->frames.size() - 1;
            if (frameIndex >= 0 && frameIndex < (int64_t)fft->frames.size()) {
                frame = &fft->frames[(size_t)frameIndex];
            }
        }

        std::vector<float> dynScratch;
        const std::vector<float>* dynFrame = vvApplyDynamics(frame, smoothness, reactivity, dynScratch);
        std::vector<float> f8;
        vvFillFftN(dynFrame, f8, 8);
        for (auto& v : f8) {
            v *= sensitivity;
            if (v < 0.0f) v = 0.0f;
            if (v > 1.0f) v = 1.0f;
        }
        if (extra.mirror && f8.size() >= 8) {
            for (int i = 4; i < 8; i++) {
                f8[(size_t)i] = f8[(size_t)(7 - i)];
            }
        }

        float r = 1.0f, g = 1.0f, b = 1.0f;
        vvArgbToRgb01(color, r, g, b);
        float r2 = r, g2 = g, b2 = b;
        if (gradientColor != 0) {
            vvArgbToRgb01(gradientColor, r2, g2, b2);
        }

        // Visual mode: stage-sampling post-process.
        // IMPORTANT: avoid sampling from the same texture we render to (Metal hazard).
        if (renderMode == "visual") {
            if (!ensurePostProcessTextures()) {
                return;
            }
            if (!ensureVideoPipeline()) {
                return;
            }

            // Finish the current scene encoder (writes to currentPostProcessSrcTexture())
            if (m_renderEncoder) {
                id<MTLRenderCommandEncoder> enc0 = (__bridge id<MTLRenderCommandEncoder>)m_renderEncoder;
                [enc0 endEncoding];
                m_renderEncoder = nullptr;
                m_exportSession.setCurrentEncoder(nullptr);
            }

            void* srcPtr = currentPostProcessSrcTexture();
            void* dstPtr = currentPostProcessDstTexture();
            id<MTLTexture> srcTex = (__bridge id<MTLTexture>)srcPtr;
            id<MTLTexture> dstTex = (__bridge id<MTLTexture>)dstPtr;
            if (!srcTex || !dstTex) {
                return;
            }

            id<MTLCommandBuffer> cb = (__bridge id<MTLCommandBuffer>)m_commandBuffer;
            MTLRenderPassDescriptor* passDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
            passDescriptor.colorAttachments[0].texture = dstTex;
            passDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
            passDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
            passDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);
            id<MTLRenderCommandEncoder> enc = [cb renderCommandEncoderWithDescriptor:passDescriptor];
            if (!enc) {
                return;
            }
            m_renderEncoder = (__bridge void*)enc;
            m_exportSession.setCurrentEncoder(m_renderEncoder);

            // Preserve background by copying current scene into the visual pass target.
            {
                id<MTLRenderPipelineState> pso = (__bridge id<MTLRenderPipelineState>)m_videoPipeline;
                id<MTLSamplerState> samp = (__bridge id<MTLSamplerState>)m_videoSampler;
                if (pso && samp) {
                    [enc setRenderPipelineState:pso];
                    struct V { float pos[2]; float uv[2]; };
                    const V baseVerts[4] = {
                        {{-1.0f, -1.0f}, {0.0f, 1.0f}},
                        {{ 1.0f, -1.0f}, {1.0f, 1.0f}},
                        {{-1.0f,  1.0f}, {0.0f, 0.0f}},
                        {{ 1.0f,  1.0f}, {1.0f, 0.0f}},
                    };
                    [enc setVertexBytes:baseVerts length:sizeof(baseVerts) atIndex:0];
                    [enc setFragmentTexture:srcTex atIndex:0];
                    [enc setFragmentSamplerState:samp atIndex:0];
                    [enc drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
                }
            }

            bindShader(shaderId);
            setUniform("uResolution", static_cast<float>(m_width), static_cast<float>(m_height));
            setUniform("iResolution", static_cast<float>(m_width), static_cast<float>(m_height));
            setUniform("uTime", tSec);
            setUniform("iTime", tSec);
            setUniform("uAlpha", alpha);
            setUniform("iAlpha", alpha);
            setUniform("uIntensity", extra.amplitude);
            setUniform("uSpeed", speed);
            setUniform("uBars", static_cast<float>(barCount));
            setUniform("uAngle", rotation);
            setUniform("uAspect", static_cast<float>(m_width) / std::max(1.0f, static_cast<float>(m_height)));
            setUniform("uColor", r, g, b);
            setUniform("uColor2", r2, g2, b2);
            setUniform("uBarFill", extra.barFill);
            setUniform("uGlow", extra.glow);
            setUniform("uStroke", extra.strokeWidth);
            if (f8.size() >= 8) {
                setUniform("uFreq0", f8[0]);
                setUniform("uFreq1", f8[1]);
                setUniform("uFreq2", f8[2]);
                setUniform("uFreq3", f8[3]);
                setUniform("uFreq4", f8[4]);
                setUniform("uFreq5", f8[5]);
                setUniform("uFreq6", f8[6]);
                setUniform("uFreq7", f8[7]);
            }

            if (shaderId == "pro_nation") {
                const auto parsed = minijson::parse(asset.dataJson);
                const auto* root = parsed.ok() ? parsed.value.asObject() : nullptr;
                const minijson::Value* visV = root ? minijson::get(*root, "visualizer") : nullptr;
                const auto* visO = visV ? visV->asObject() : nullptr;
                if (visO) {
                    int64_t ringColorI64 = 0;
                    if (minijson::getInt64(*visO, "ringColor", &ringColorI64)) {
                        float rr = 1.0f, rg = 1.0f, rb = 1.0f;
                        vvArgbToRgb01(ringColorI64, rr, rg, rb);
                        setUniform("uRingColor", rr, rg, rb);
                        setUniform("uHasRingColor", 1.0f);
                    } else {
                        setUniform("uHasRingColor", 0.0f);
                    }

                    std::string centerPath;
                    std::string bgPath;
                    minijson::getString(*visO, "centerImagePath", &centerPath);
                    minijson::getString(*visO, "backgroundImagePath", &bgPath);

                    if (!centerPath.empty()) {
                        GPUTexture ct = loadTexture(centerPath);
                        if (ct.handle) {
                            setTexture("uCenterImg", ct, 1);
                            setUniform("uHasCenter", 1.0f);
                        } else {
                            setUniform("uHasCenter", 0.0f);
                        }
                    } else {
                        setUniform("uHasCenter", 0.0f);
                    }

                    if (!bgPath.empty()) {
                        GPUTexture bt = loadTexture(bgPath);
                        if (bt.handle) {
                            setTexture("uBgImg", bt, 2);
                            setUniform("uHasBg", 1.0f);
                        } else {
                            setUniform("uHasBg", 0.0f);
                        }
                    } else {
                        setUniform("uHasBg", 0.0f);
                    }
                }
            }

            setTexture("uTexture", GPUTexture{(__bridge void*)srcTex, m_width, m_height, 0}, 0);
            setTexture("iChannel0", GPUTexture{(__bridge void*)srcTex, m_width, m_height, 0}, 0);

            struct V { float pos[2]; float uv[2]; };
            const V verts[4] = {
                // Match renderShader() UV convention
                {{left,  bottom}, {0.0f, 1.0f}},
                {{right, bottom}, {1.0f, 1.0f}},
                {{left,  top},    {0.0f, 0.0f}},
                {{right, top},    {1.0f, 0.0f}},
            };

            [enc setVertexBytes:verts length:sizeof(verts) atIndex:0];
            if (!m_uniformStaging.empty()) {
                [enc setFragmentBytes:m_uniformStaging.data() length:m_uniformStaging.size() atIndex:0];
            }
            id<MTLSamplerState> samp = (__bridge id<MTLSamplerState>)m_videoSampler;
            if (samp) {
                [enc setFragmentSamplerState:samp atIndex:0];
            }
            for (const auto& kv : m_boundTextures) {
                const int unit = kv.first;
                id<MTLTexture> t = (__bridge id<MTLTexture>)kv.second;
                if (t) {
                    [enc setFragmentTexture:t atIndex:unit];
                }
            }
            [enc drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];

            [enc endEncoding];
            m_renderEncoder = nullptr;
            m_exportSession.setCurrentEncoder(nullptr);
            swapPostProcessTextures();

            // Resume drawing on the new post-processed scene.
            id<MTLTexture> newDst = (__bridge id<MTLTexture>)currentPostProcessSrcTexture();
            if (!newDst) {
                return;
            }
            MTLRenderPassDescriptor* resume = [MTLRenderPassDescriptor renderPassDescriptor];
            resume.colorAttachments[0].texture = newDst;
            resume.colorAttachments[0].loadAction = MTLLoadActionLoad;
            resume.colorAttachments[0].storeAction = MTLStoreActionStore;
            id<MTLRenderCommandEncoder> enc2 = [cb renderCommandEncoderWithDescriptor:resume];
            if (!enc2) {
                return;
            }
            m_renderEncoder = (__bridge void*)enc2;
            m_exportSession.setCurrentEncoder(m_renderEncoder);
            m_boundShaderId.clear();
            m_uniformStaging.clear();
            m_boundTextures.clear();
            return;
        }

        // Overlay modes (shader/progress): draw quad directly into the current encoder.
        // Do NOT bind scene texture (Metal cannot sample from render target).
        bindShader(shaderId);

        float resW = static_cast<float>(m_width);
        float resH = static_cast<float>(m_height);
        if (renderMode == "progress") {
            const float dpr = (m_uiDevicePixelRatio > 0.0f) ? m_uiDevicePixelRatio : 1.0f;
            const float uiW = (m_uiPlayerWidth > 0.0f) ? m_uiPlayerWidth : static_cast<float>(m_width);
            const float uiH = (m_uiPlayerHeight > 0.0f) ? m_uiPlayerHeight : static_cast<float>(m_height);
            // Flutter ShaderEffect sets uResolution in logical pixels (dp), then Transform.scale scales the output.
            // Keep shader space in dp for parity (avoids px-based constants drifting with DPR/export scale).
            resW = std::max(1.0f, uiW);
            resH = std::max(1.0f, uiH * 0.10f);
        }
        setUniform("uResolution", resW, resH);
        setUniform("iResolution", resW, resH);
        setUniform("uTime", tSec);
        setUniform("iTime", tSec);
        setUniform("uAlpha", alpha);
        setUniform("iAlpha", alpha);
        // Flutter parity: progress uses uIntensity = glowIntensity; other visualizers use amplitude.
        setUniform("uIntensity", (renderMode == "progress") ? extra.glow : extra.amplitude);
        setUniform("uSpeed", speed);
        setUniform("uBars", static_cast<float>(barCount));
        setUniform("uAngle", rotation);
        setUniform("uAspect", resW / std::max(1.0f, resH));
        setUniform("uColor", r, g, b);
        setUniform("uColor2", r2, g2, b2);
        setUniform("uBarFill", extra.barFill);
        setUniform("uGlow", extra.glow);
        setUniform("uStroke", extra.strokeWidth);
        if (f8.size() >= 8) {
            setUniform("uFreq0", f8[0]);
            setUniform("uFreq1", f8[1]);
            setUniform("uFreq2", f8[2]);
            setUniform("uFreq3", f8[3]);
            setUniform("uFreq4", f8[4]);
            setUniform("uFreq5", f8[5]);
            setUniform("uFreq6", f8[6]);
            setUniform("uFreq7", f8[7]);
        }

        if (shaderId == "pro_nation") {
            const auto parsed = minijson::parse(asset.dataJson);
            const auto* root = parsed.ok() ? parsed.value.asObject() : nullptr;
            const minijson::Value* visV = root ? minijson::get(*root, "visualizer") : nullptr;
            const auto* visO = visV ? visV->asObject() : nullptr;
            if (visO) {
                int64_t ringColorI64 = 0;
                if (minijson::getInt64(*visO, "ringColor", &ringColorI64)) {
                    float rr = 1.0f, rg = 1.0f, rb = 1.0f;
                    vvArgbToRgb01(ringColorI64, rr, rg, rb);
                    setUniform("uRingColor", rr, rg, rb);
                    setUniform("uHasRingColor", 1.0f);
                } else {
                    setUniform("uHasRingColor", 0.0f);
                }

                std::string centerPath;
                std::string bgPath;
                minijson::getString(*visO, "centerImagePath", &centerPath);
                minijson::getString(*visO, "backgroundImagePath", &bgPath);

                if (!centerPath.empty()) {
                    GPUTexture ct = loadTexture(centerPath);
                    if (ct.handle) {
                        setTexture("uCenterImg", ct, 1);
                        setUniform("uHasCenter", 1.0f);
                    } else {
                        setUniform("uHasCenter", 0.0f);
                    }
                } else {
                    setUniform("uHasCenter", 0.0f);
                }

                if (!bgPath.empty()) {
                    GPUTexture bt = loadTexture(bgPath);
                    if (bt.handle) {
                        setTexture("uBgImg", bt, 2);
                        setUniform("uHasBg", 1.0f);
                    } else {
                        setUniform("uHasBg", 0.0f);
                    }
                } else {
                    setUniform("uHasBg", 0.0f);
                }
            }
        }

        if (renderMode == "progress") {
            // Flutter parity: progress uses global timeline position / project duration.
            int64_t denomMs = projectDurationMs;
            if (denomMs <= 0) denomMs = static_cast<int64_t>(asset.duration);
            if (denomMs <= 0) denomMs = 1;

            const int64_t globalMs = static_cast<int64_t>(asset.begin) + static_cast<int64_t>(localTime);
            float p = static_cast<float>(globalMs) / static_cast<float>(denomMs);
            p = vvClamp01(p);
            setUniform("uProgress", p);

            // Style comes from effectStyle (Flutter ProgressEffect mapping)
            float styleIdx = 0.0f;
            if (effectStyle == "segments") styleIdx = 1.0f;
            else if (effectStyle == "steps") styleIdx = 2.0f;
            else if (effectStyle == "centered") styleIdx = 3.0f;
            else if (effectStyle == "outline") styleIdx = 4.0f;
            else if (effectStyle == "thin") styleIdx = 5.0f;
            else styleIdx = 0.0f;
            setUniform("uStyle", styleIdx);

            float th = extra.strokeWidth;
            if (th < 6.0f) th = 6.0f;
            if (th > 24.0f) th = 24.0f;
            // Flutter parity: scale thickness to bar height so max stroke fills the progress bar.
            float thicknessPx = (resH > 0.0f) ? ((th / 24.0f) * resH) : th;
            if (!std::isfinite(thicknessPx) || thicknessPx <= 0.0f) thicknessPx = th;
            setUniform("uThickness", thicknessPx);
            setUniform("uTrackAlpha", extra.progressTrackAlpha);
            setUniform("uCorner", extra.progressCorner);
            setUniform("uGap", extra.progressGap);
            setUniform("uTheme", extra.progressThemeIdx);
            setUniform("uEffectAmount", extra.progressEffectAmount);
            setUniform("uHeadAmount", extra.progressHeadAmount);
            setUniform("uHeadSize", extra.progressHeadSize);
            setUniform("uHeadStyle", extra.progressHeadStyleIdx);

            if (extra.hasProgressTrackColor) {
                float tr = 0.0f, tg = 0.0f, tb = 0.0f;
                vvArgbToRgb01(extra.progressTrackColor, tr, tg, tb);
                setUniform("uTrackColor", tr, tg, tb);
            } else {
                setUniform("uTrackColor", 0.0f, 0.0f, 0.0f);
            }
        }

        id<MTLRenderCommandEncoder> enc = (__bridge id<MTLRenderCommandEncoder>)m_renderEncoder;
        if (!enc) return;

        if (renderMode == "progress") {
            const float pxL = (left * 0.5f + 0.5f) * static_cast<float>(m_width);
            const float pxR = (right * 0.5f + 0.5f) * static_cast<float>(m_width);
            const float pyB = (bottom * 0.5f + 0.5f) * static_cast<float>(m_height);
            const float pyT = (top * 0.5f + 0.5f) * static_cast<float>(m_height);

            float wPx = pxR - pxL;
            float hPx = pyT - pyB;
            float cxPx = (pxL + pxR) * 0.5f;
            float cyPx = (pyB + pyT) * 0.5f;

            // Avoid snapping to integer pixels here; it can shift half-coverage to one edge.
            wPx = std::max(1.0f, wPx);
            hPx = std::max(1.0f, hPx);

            const float pxL2 = cxPx - (wPx * 0.5f);
            const float pxR2 = cxPx + (wPx * 0.5f);
            const float pyB2 = cyPx - (hPx * 0.5f);
            const float pyT2 = cyPx + (hPx * 0.5f);

            left = ((pxL2 / static_cast<float>(m_width)) - 0.5f) * 2.0f;
            right = ((pxR2 / static_cast<float>(m_width)) - 0.5f) * 2.0f;
            bottom = ((pyB2 / static_cast<float>(m_height)) - 0.5f) * 2.0f;
            top = ((pyT2 / static_cast<float>(m_height)) - 0.5f) * 2.0f;
        }

        struct V { float pos[2]; float uv[2]; };
        const V verts[4] = {
            // Match renderShader() UV convention
            {{left,  bottom}, {0.0f, 1.0f}},
            {{right, bottom}, {1.0f, 1.0f}},
            {{left,  top},    {0.0f, 0.0f}},
            {{right, top},    {1.0f, 0.0f}},
        };
        [enc setVertexBytes:verts length:sizeof(verts) atIndex:0];
        if (!m_uniformStaging.empty()) {
            [enc setFragmentBytes:m_uniformStaging.data() length:m_uniformStaging.size() atIndex:0];
        }

        id<MTLSamplerState> samp = (__bridge id<MTLSamplerState>)m_videoSampler;
        if (samp) {
            [enc setFragmentSamplerState:samp atIndex:0];
        }
        for (const auto& kv : m_boundTextures) {
            const int unit = kv.first;
            id<MTLTexture> t = (__bridge id<MTLTexture>)kv.second;
            if (t) {
                [enc setFragmentTexture:t atIndex:unit];
            }
        }
        [enc drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
        return;
    }

    if (!m_visualizerPipeline) {
        id<MTLDevice> device = (__bridge id<MTLDevice>)m_device;
        if (!device) return;

        static NSString* const src =
            @"#include <metal_stdlib>\n"
            @"using namespace metal;\n"
            @"struct VIn { float2 pos [[attribute(0)]]; };\n"
            @"struct VOut { float4 position [[position]]; };\n"
            @"vertex VOut vmain(VIn in [[stage_in]]) { VOut o; o.position = float4(in.pos, 0.0, 1.0); return o; }\n"
            @"struct U { float4 color; };\n"
            @"fragment float4 fmain(constant U& u [[buffer(0)]]) { return u.color; }\n";

        NSError* err = nil;
        id<MTLLibrary> lib = [device newLibraryWithSource:src options:nil error:&err];
        if (err || !lib) {
            if (err) {
                LOGE("VIDVIZ_ERROR: Visualizer library compile failed: %s", [[err localizedDescription] UTF8String]);
            }
            return;
        }
        id<MTLFunction> vf = [lib newFunctionWithName:@"vmain"];
        id<MTLFunction> ff = [lib newFunctionWithName:@"fmain"];
        if (!vf || !ff) return;

        MTLRenderPipelineDescriptor* desc = [[MTLRenderPipelineDescriptor alloc] init];
        desc.vertexFunction = vf;
        desc.fragmentFunction = ff;
        desc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
        desc.colorAttachments[0].blendingEnabled = YES;
        desc.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
        desc.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
        desc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
        desc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
        desc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        desc.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;

        MTLVertexDescriptor* vd = [[MTLVertexDescriptor alloc] init];
        vd.attributes[0].format = MTLVertexFormatFloat2;
        vd.attributes[0].offset = 0;
        vd.attributes[0].bufferIndex = 0;
        vd.layouts[0].stride = sizeof(float) * 2;
        vd.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;
        desc.vertexDescriptor = vd;

        id<MTLRenderPipelineState> pso = [device newRenderPipelineStateWithDescriptor:desc error:&err];
        if (err || !pso) {
            if (err) {
                LOGE("VIDVIZ_ERROR: Visualizer pipeline create failed: %s", [[err localizedDescription] UTF8String]);
            }
            return;
        }
        m_visualizerPipeline = (__bridge_retained void*)pso;
    }

    const std::string& fftKey = (!audioPath.empty()) ? audioPath : asset.srcPath;
    const FFTData* fft = vvFindFftByAudioPath(fftData, fftKey);
    const std::vector<float>* frame = nullptr;
    if (fft && !fft->frames.empty() && fft->hopSize > 0 && fft->sampleRate > 0) {
        const double seconds = static_cast<double>(std::max<int64_t>(0, localTime)) / 1000.0;
        const double frameIndexD = (seconds * static_cast<double>(fft->sampleRate)) / static_cast<double>(fft->hopSize);
        int64_t frameIndex = static_cast<int64_t>(frameIndexD);
        if (frameIndex < 0) frameIndex = 0;
        if (frameIndex >= (int64_t)fft->frames.size()) frameIndex = (int64_t)fft->frames.size() - 1;
        if (frameIndex >= 0 && frameIndex < (int64_t)fft->frames.size()) {
            frame = &fft->frames[(size_t)frameIndex];
        }
    }

    std::vector<float> amps;
    std::vector<float> dynScratch;
    const std::vector<float>* dynFrame = vvApplyDynamics(frame, smoothness, reactivity, dynScratch);
    vvFillFftN(dynFrame, amps, barCount);

    float r = 1.0f, g = 1.0f, b = 1.0f;
    vvArgbToRgb01(color, r, g, b);

    id<MTLRenderCommandEncoder> enc = (__bridge id<MTLRenderCommandEncoder>)m_renderEncoder;
    id<MTLRenderPipelineState> pso = (__bridge id<MTLRenderPipelineState>)m_visualizerPipeline;
    if (!enc || !pso) return;
    [enc setRenderPipelineState:pso];

    const float baseHeight = 0.18f;
    const float pad = 0.01f;

    float left = -1.0f;
    float right = 1.0f;
    float bottom = -1.0f;
    float top = 1.0f;
    if (!fullScreen) {
        const float tx = (x * 2.0f) - 1.0f;
        const float ty = ((1.0f - y) * 2.0f) - 1.0f;
        const float sxy = scale;
        left = -sxy + tx;
        right = sxy + tx;
        bottom = -sxy + ty;
        top = sxy + ty;
    }

    const float width = right - left;
    const float barW = width / (float)barCount;
    const float maxH = std::max(0.02f, (top - bottom) * baseHeight);
    const float y0 = bottom + pad;

    struct U { float color[4]; };
    U u;
    u.color[0] = r;
    u.color[1] = g;
    u.color[2] = b;
    u.color[3] = 0.85f * alpha;
    [enc setFragmentBytes:&u length:sizeof(u) atIndex:0];

    for (int i = 0; i < barCount; i++) {
        float a = (i >= 0 && i < (int)amps.size()) ? amps[(size_t)i] : 0.0f;
        a *= sensitivity;
        if (a < 0.0f) a = 0.0f;
        if (a > 1.0f) a = 1.0f;

        const float h = std::max(0.004f, maxH * a);
        const float x0 = left + barW * (float)i + pad;
        const float x1 = left + barW * (float)(i + 1) - pad;
        const float y1 = y0 + h;

        const float vx0 = x0;
        const float vx1 = x1;
        const float vy0 = y0;
        const float vy1 = y1;

        const float verts[8] = {
            vx0, vy0,
            vx1, vy0,
            vx0, vy1,
            vx1, vy1,
        };
        [enc setVertexBytes:verts length:sizeof(verts) atIndex:0];
        [enc drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
    }
}

bool MetalRenderer::compileShader(
    const std::string& shaderId,
    const std::string& vertexSource,
    const std::string& fragmentSource
) {
    (void)vertexSource;
    LOGI("Compiling shader: %s", shaderId.c_str());
    if (shaderId.empty()) return false;
    if (fragmentSource.empty()) return false;

    id<MTLDevice> device = (__bridge id<MTLDevice>)m_device;
    if (!device) return false;

    // Cache invalidation: if shaderId exists, release old pipeline before compiling new.
    {
        auto it = m_shaderPipelines.find(shaderId);
        if (it != m_shaderPipelines.end() && it->second) {
            id<MTLRenderPipelineState> oldPso = (__bridge_transfer id<MTLRenderPipelineState>)it->second;
            (void)oldPso;
            it->second = nullptr;
        }
        m_shaderPipelines.erase(shaderId);
    }

    NSString* src = [NSString stringWithUTF8String:fragmentSource.c_str()];
    if (!src || src.length == 0) return false;

    NSError* err = nil;
    id<MTLLibrary> lib = [device newLibraryWithSource:src options:nil error:&err];
    if (err || !lib) {
        if (err) {
            LOGE("VIDVIZ_ERROR: Metal shader library compile failed: %s", [[err localizedDescription] UTF8String]);
        }
        return false;
    }

    // Entrypoints are fixed by build_shaders.py: vmain / fmain
    id<MTLFunction> vf = [lib newFunctionWithName:@"vmain"];
    id<MTLFunction> ff = [lib newFunctionWithName:@"fmain"];
    if (!vf) {
        vf = [lib newFunctionWithName:@"main0"];
    }
    if (!ff) {
        ff = [lib newFunctionWithName:@"main0"];
    }
    if (!vf || !ff) {
        LOGE("VIDVIZ_ERROR: Metal shader missing required entrypoints vmain/fmain (id=%s)", shaderId.c_str());
        return false;
    }

    MTLRenderPipelineDescriptor* desc = [[MTLRenderPipelineDescriptor alloc] init];
    desc.vertexFunction = vf;
    desc.fragmentFunction = ff;
    desc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;

    MTLVertexDescriptor* vd = [[MTLVertexDescriptor alloc] init];
    vd.attributes[0].format = MTLVertexFormatFloat2;
    vd.attributes[0].offset = 0;
    vd.attributes[0].bufferIndex = 0;
    vd.attributes[1].format = MTLVertexFormatFloat2;
    vd.attributes[1].offset = sizeof(float) * 2;
    vd.attributes[1].bufferIndex = 0;
    vd.layouts[0].stride = sizeof(float) * 4;
    vd.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;
    desc.vertexDescriptor = vd;

    // Match Android behavior: shader overlays typically need alpha blending.
    desc.colorAttachments[0].blendingEnabled = YES;
    desc.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
    desc.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
    if (shaderId == "progress") {
        desc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorOne;
        desc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
    } else {
        desc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
        desc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
    }
    desc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    desc.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;

    err = nil;
    MTLRenderPipelineReflection* refl = nil;
    id<MTLRenderPipelineState> pso = [device newRenderPipelineStateWithDescriptor:desc options:MTLPipelineOptionArgumentInfo reflection:&refl error:&err];
    if (err || !pso) {
        if (err) {
            LOGE("VIDVIZ_ERROR: Metal shader pipeline create failed: %s", [[err localizedDescription] UTF8String]);
        }
        return false;
    }

    if (refl) {
        uint32_t bufSize = 0;
        std::unordered_map<std::string, uint32_t> offsets;
        std::unordered_map<std::string, uint32_t> texIndices;
        for (MTLArgument* a in refl.fragmentArguments) {
            if (a.type == MTLArgumentTypeBuffer && a.index == 0 && a.bufferStructType) {
                bufSize = (uint32_t)a.bufferDataSize;
                for (MTLStructMember* m in a.bufferStructType.members) {
                    if (!m.name) continue;
                    offsets[[m.name UTF8String]] = (uint32_t)m.offset;
                }
            }
            if (a.type == MTLArgumentTypeTexture && a.name) {
                texIndices[[a.name UTF8String]] = (uint32_t)a.index;
            }
        }
        m_shaderUniformBufferSizes[shaderId] = bufSize;
        m_shaderUniformOffsets[shaderId] = std::move(offsets);
        m_shaderTextureIndices[shaderId] = std::move(texIndices);
    }

    m_shaderPipelines[shaderId] = (__bridge_retained void*)pso;
    return true;
}

void MetalRenderer::bindShader(const std::string& shaderId) {
    if (!m_renderEncoder) return;
    if (shaderId.empty()) return;
    auto it = m_shaderPipelines.find(shaderId);
    if (it == m_shaderPipelines.end() || !it->second) return;
    id<MTLRenderCommandEncoder> enc = (__bridge id<MTLRenderCommandEncoder>)m_renderEncoder;
    id<MTLRenderPipelineState> pso = (__bridge id<MTLRenderPipelineState>)it->second;
    [enc setRenderPipelineState:pso];

    m_boundShaderId = shaderId;
    m_boundTextures.clear();
    m_uniformStaging.clear();
    auto szIt = m_shaderUniformBufferSizes.find(shaderId);
    if (szIt != m_shaderUniformBufferSizes.end() && szIt->second > 0) {
        m_uniformStaging.resize(szIt->second);
        std::fill(m_uniformStaging.begin(), m_uniformStaging.end(), 0);
    }
}

void MetalRenderer::setUniform(const std::string& name, float value) {
    if (m_boundShaderId.empty()) return;
    if (m_uniformStaging.empty()) return;
    auto it = m_shaderUniformOffsets.find(m_boundShaderId);
    if (it == m_shaderUniformOffsets.end()) return;
    auto mit = it->second.find(name);
    if (mit == it->second.end()) return;
    vvWriteToStaging(m_uniformStaging, mit->second, &value, sizeof(float));
}

void MetalRenderer::setUniform(const std::string& name, float x, float y) {
    if (m_boundShaderId.empty()) return;
    if (m_uniformStaging.empty()) return;
    auto it = m_shaderUniformOffsets.find(m_boundShaderId);
    if (it == m_shaderUniformOffsets.end()) return;
    auto mit = it->second.find(name);
    if (mit == it->second.end()) return;
    vvWriteToStaging(m_uniformStaging, mit->second, &x, sizeof(float));
    vvWriteToStaging(m_uniformStaging, mit->second + (uint32_t)sizeof(float), &y, sizeof(float));
}

void MetalRenderer::setUniform(const std::string& name, float x, float y, float z) {
    if (m_boundShaderId.empty()) return;
    if (m_uniformStaging.empty()) return;
    auto it = m_shaderUniformOffsets.find(m_boundShaderId);
    if (it == m_shaderUniformOffsets.end()) return;
    auto mit = it->second.find(name);
    if (mit == it->second.end()) return;
    vvWriteToStaging(m_uniformStaging, mit->second, &x, sizeof(float));
    vvWriteToStaging(m_uniformStaging, mit->second + (uint32_t)sizeof(float), &y, sizeof(float));
    vvWriteToStaging(m_uniformStaging, mit->second + (uint32_t)sizeof(float) * 2, &z, sizeof(float));
}

void MetalRenderer::setUniform(const std::string& name, float x, float y, float z, float w) {
    if (m_boundShaderId.empty()) return;
    if (m_uniformStaging.empty()) return;
    auto it = m_shaderUniformOffsets.find(m_boundShaderId);
    if (it == m_shaderUniformOffsets.end()) return;
    auto mit = it->second.find(name);
    if (mit == it->second.end()) return;
    vvWriteToStaging(m_uniformStaging, mit->second, &x, sizeof(float));
    vvWriteToStaging(m_uniformStaging, mit->second + (uint32_t)sizeof(float), &y, sizeof(float));
    vvWriteToStaging(m_uniformStaging, mit->second + (uint32_t)sizeof(float) * 2, &z, sizeof(float));
    vvWriteToStaging(m_uniformStaging, mit->second + (uint32_t)sizeof(float) * 3, &w, sizeof(float));
}

void MetalRenderer::setUniform(const std::string& name, int value) {
    if (m_boundShaderId.empty()) return;
    if (m_uniformStaging.empty()) return;
    auto it = m_shaderUniformOffsets.find(m_boundShaderId);
    if (it == m_shaderUniformOffsets.end()) return;
    auto mit = it->second.find(name);
    if (mit == it->second.end()) return;
    vvWriteToStaging(m_uniformStaging, mit->second, &value, sizeof(int));
}

void MetalRenderer::setTexture(const std::string& name, const GPUTexture& texture, int unit) {
    if (!m_renderEncoder) return;
    if (!texture.handle) return;

    int bindIndex = unit;
    if (!m_boundShaderId.empty()) {
        auto sit = m_shaderTextureIndices.find(m_boundShaderId);
        if (sit != m_shaderTextureIndices.end()) {
            auto mit = sit->second.find(name);
            if (mit != sit->second.end()) {
                bindIndex = (int)mit->second;
            }
        }
    }
    if (bindIndex < 0) return;
    m_boundTextures[bindIndex] = texture.handle;
}

GPUTexture MetalRenderer::loadTexture(const std::string& path) {
    LOGI("Loading texture: %s", path.c_str());
    GPUTexture tex;
    if (path.empty()) return tex;

    auto it = m_loadedTextures.find(path);
    if (it != m_loadedTextures.end() && it->second) {
        id<MTLTexture> t = (__bridge id<MTLTexture>)it->second;
        if (t) {
            tex.handle = it->second;
            tex.width = (int32_t)t.width;
            tex.height = (int32_t)t.height;
            tex.format = 0;
            return tex;
        }
        m_loadedTextures.erase(it);
    }

    id<MTLDevice> device = (__bridge id<MTLDevice>)m_device;
    if (!device) return tex;

    NSString* p = [NSString stringWithUTF8String:path.c_str()];
    if (!p || p.length == 0) return tex;

    NSURL* url = nil;
    if ([p hasPrefix:@"file://"]) {
        url = [NSURL URLWithString:p];
    }
    if (!url) {
        url = [NSURL fileURLWithPath:p];
    }
    if (!url) return tex;

    MTKTextureLoader* loader = [[MTKTextureLoader alloc] initWithDevice:device];
    NSError* err = nil;
    NSDictionary* opts = @{ MTKTextureLoaderOptionSRGB: @NO };
    id<MTLTexture> t = [loader newTextureWithContentsOfURL:url options:opts error:&err];
    if (err || !t) {
        if (err) {
            LOGE("VIDVIZ_ERROR: Failed to load texture: %s", [[err localizedDescription] UTF8String]);
        }
        return tex;
    }

    void* handle = (__bridge_retained void*)t;
    m_loadedTextures[path] = handle;
    tex.handle = handle;
    tex.width = (int32_t)t.width;
    tex.height = (int32_t)t.height;
    tex.format = 0;
    return tex;
}

void MetalRenderer::unloadTexture(GPUTexture& texture) {
    if (!texture.handle) return;
    void* h = texture.handle;

    for (auto it = m_loadedTextures.begin(); it != m_loadedTextures.end(); ++it) {
        if (it->second == h) {
            id<MTLTexture> t = (__bridge_transfer id<MTLTexture>)it->second;
            (void)t;
            m_loadedTextures.erase(it);
            break;
        }
    }

    texture.handle = nullptr;
    texture.width = 0;
    texture.height = 0;
    texture.format = 0;
}

NativeSurface MetalRenderer::getEncoderSurface() {
    NativeSurface surface;
    surface.handle = m_metalLayer;
    surface.width = m_width;
    surface.height = m_height;
    return surface;
}

void MetalRenderer::setMetalLayer(CAMetalLayer* layer) {
    m_metalLayer = (__bridge void*)layer;
    
    if (layer && m_device) {
        layer.device = (__bridge id<MTLDevice>)m_device;
        layer.pixelFormat = MTLPixelFormatBGRA8Unorm;
        layer.framebufferOnly = NO; // Allow reading for encoder
    }
    
    LOGI("Metal layer set");
}

void MetalRenderer::setMetalLayer(void* metalLayer) {
    if (!metalLayer) {
        setMetalLayer((CAMetalLayer*)nil);
        return;
    }
    CAMetalLayer* layer = (__bridge CAMetalLayer*)metalLayer;
    setMetalLayer(layer);
}

// =============================================================================
// Helper Methods
// =============================================================================

bool MetalRenderer::createDevice() {
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (!device) {
        LOGE("Failed to create Metal device");
        return false;
    }
    
    m_device = (__bridge_retained void*)device;
    LOGI("Metal device created: %s", [[device name] UTF8String]);
    return true;
}

bool MetalRenderer::createCommandQueue() {
    id<MTLDevice> device = (__bridge id<MTLDevice>)m_device;
    id<MTLCommandQueue> queue = [device newCommandQueue];
    if (!queue) {
        LOGE("Failed to create command queue");
        return false;
    }
    
    m_commandQueue = (__bridge_retained void*)queue;
    LOGI("Command queue created");
    return true;
}

bool MetalRenderer::createTextureCache() {
    id<MTLDevice> device = (__bridge id<MTLDevice>)m_device;
    
    CVMetalTextureCacheRef textureCache;
    CVReturn status = CVMetalTextureCacheCreate(
        kCFAllocatorDefault,
        nil,
        device,
        nil,
        &textureCache
    );
    
    if (status != kCVReturnSuccess) {
        LOGE("Failed to create texture cache: %d", status);
        return false;
    }
    
    m_textureCache = textureCache;
    LOGI("Texture cache created");
    return true;
}

void MetalRenderer::cleanup() {
    resetVideoDecoder();
    resetOverlayVideoDecoder();

    if (m_textRenderer) {
        m_textRenderer->cleanup();
        delete m_textRenderer;
        m_textRenderer = nullptr;
    }

    if (!m_shaderPipelines.empty()) {
        for (auto& kv : m_shaderPipelines) {
            if (kv.second) {
                id<MTLRenderPipelineState> p = (__bridge_transfer id<MTLRenderPipelineState>)kv.second;
                (void)p;
                kv.second = nullptr;
            }
        }
        m_shaderPipelines.clear();
    }

    m_shaderUniformOffsets.clear();
    m_shaderUniformBufferSizes.clear();
    m_shaderTextureIndices.clear();

    if (m_visualizerPipeline) {
        id<MTLRenderPipelineState> p = (__bridge_transfer id<MTLRenderPipelineState>)m_visualizerPipeline;
        (void)p;
        m_visualizerPipeline = nullptr;
    }

    if (m_ppTexA) {
        id<MTLTexture> t = (__bridge_transfer id<MTLTexture>)m_ppTexA;
        (void)t;
        m_ppTexA = nullptr;
    }
    if (m_ppTexB) {
        id<MTLTexture> t = (__bridge_transfer id<MTLTexture>)m_ppTexB;
        (void)t;
        m_ppTexB = nullptr;
    }

    if (m_imageTexture) {
        id<MTLTexture> t = (__bridge_transfer id<MTLTexture>)m_imageTexture;
        (void)t;
        m_imageTexture = nullptr;
    }
    m_imagePath.clear();

    if (!m_loadedTextures.empty()) {
        for (auto& kv : m_loadedTextures) {
            if (kv.second) {
                id<MTLTexture> t = (__bridge_transfer id<MTLTexture>)kv.second;
                (void)t;
                kv.second = nullptr;
            }
        }
        m_loadedTextures.clear();
    }

    if (m_videoSampler) {
        id<MTLSamplerState> s = (__bridge_transfer id<MTLSamplerState>)m_videoSampler;
        (void)s;
        m_videoSampler = nullptr;
    }

    if (m_videoPipeline) {
        id<MTLRenderPipelineState> p = (__bridge_transfer id<MTLRenderPipelineState>)m_videoPipeline;
        (void)p;
        m_videoPipeline = nullptr;
    }

    if (m_effectPipeline) {
        id<MTLRenderPipelineState> p = (__bridge_transfer id<MTLRenderPipelineState>)m_effectPipeline;
        (void)p;
        m_effectPipeline = nullptr;
    }

    if (!m_counterTextTextures.empty()) {
        for (auto& kv : m_counterTextTextures) {
            if (kv.second.tex) {
                id<MTLTexture> t = (__bridge_transfer id<MTLTexture>)kv.second.tex;
                (void)t;
                kv.second.tex = nullptr;
            }
        }
        m_counterTextTextures.clear();
    }

    if (m_counterTextPipeline) {
        id<MTLRenderPipelineState> p = (__bridge_transfer id<MTLRenderPipelineState>)m_counterTextPipeline;
        (void)p;
        m_counterTextPipeline = nullptr;
    }

    if (m_overlayPipeline) {
        id<MTLRenderPipelineState> p = (__bridge_transfer id<MTLRenderPipelineState>)m_overlayPipeline;
        (void)p;
        m_overlayPipeline = nullptr;
    }

    if (m_textureCache) {
        CFRelease(m_textureCache);
        m_textureCache = nullptr;
    }
     
    if (m_commandQueue) {
        id<MTLCommandQueue> queue = (__bridge_transfer id<MTLCommandQueue>)m_commandQueue;
        (void)queue;
        m_commandQueue = nullptr;
    }
     
    if (m_device) {
        id<MTLDevice> device = (__bridge_transfer id<MTLDevice>)m_device;
        (void)device;
        m_device = nullptr;
    }
}

bool MetalRenderer::ensureVideoPipeline() {
    if (m_videoPipeline && m_videoSampler) {
        return true;
    }

    id<MTLDevice> device = (__bridge id<MTLDevice>)m_device;
    if (!device) return false;

    static NSString* const src =
        @"#include <metal_stdlib>\n"
        @"using namespace metal;\n"
        @"struct VIn { float2 pos [[attribute(0)]]; float2 uv [[attribute(1)]]; };\n"
        @"struct VOut { float4 position [[position]]; float2 uv; };\n"
        @"vertex VOut vmain(uint vid [[vertex_id]], const device float4* vb [[buffer(0)]]) {\n"
        @"  float4 v = vb[vid];\n"
        @"  VOut o; o.position = float4(v.xy, 0.0, 1.0); o.uv = v.zw; return o;\n"
        @"}\n"
        @"fragment float4 fmain(VOut in [[stage_in]], texture2d<float> tex [[texture(0)]], sampler samp [[sampler(0)]]) {\n"
        @"  return tex.sample(samp, in.uv);\n"
        @"}\n";

    NSError* err = nil;
    id<MTLLibrary> lib = [device newLibraryWithSource:src options:nil error:&err];
    if (err || !lib) {
        if (err) {
            LOGE("VIDVIZ_ERROR: Metal library compile failed: %s", [[err localizedDescription] UTF8String]);
        }
        return false;
    }

    id<MTLFunction> vf = [lib newFunctionWithName:@"vmain"];
    id<MTLFunction> ff = [lib newFunctionWithName:@"fmain"];
    if (!vf || !ff) {
        return false;
    }

    MTLRenderPipelineDescriptor* desc = [[MTLRenderPipelineDescriptor alloc] init];
    desc.vertexFunction = vf;
    desc.fragmentFunction = ff;
    desc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;

    id<MTLRenderPipelineState> pso = [device newRenderPipelineStateWithDescriptor:desc error:&err];
    if (err || !pso) {
        if (err) {
            LOGE("VIDVIZ_ERROR: Metal pipeline create failed: %s", [[err localizedDescription] UTF8String]);
        }
        return false;
    }

    MTLSamplerDescriptor* sd = [[MTLSamplerDescriptor alloc] init];
    sd.minFilter = MTLSamplerMinMagFilterLinear;
    sd.magFilter = MTLSamplerMinMagFilterLinear;
    sd.sAddressMode = MTLSamplerAddressModeClampToEdge;
    sd.tAddressMode = MTLSamplerAddressModeClampToEdge;
    id<MTLSamplerState> samp = [device newSamplerStateWithDescriptor:sd];
    if (!samp) {
        return false;
    }

    m_videoPipeline = (__bridge_retained void*)pso;
    m_videoSampler = (__bridge_retained void*)samp;
    return true;
}

bool MetalRenderer::ensureEffectPipeline() {
    if (m_effectPipeline) {
        return true;
    }

    id<MTLDevice> device = (__bridge id<MTLDevice>)m_device;
    if (!device) return false;

    static NSString* const src =
        @"#include <metal_stdlib>\n"
        @"using namespace metal;\n"
        @"struct VOut { float4 position [[position]]; float2 uv; };\n"
        @"vertex VOut vmain(uint vid [[vertex_id]], const device float4* vb [[buffer(0)]]) {\n"
        @"  float4 v = vb[vid];\n"
        @"  VOut o; o.position = float4(v.xy, 0.0, 1.0); o.uv = v.zw; return o;\n"
        @"}\n"
        @"struct U { float4 p0; float4 color; };\n"
        @"fragment float4 fmain(VOut in [[stage_in]], constant U& u [[buffer(0)]]) {\n"
        @"  float2 p = in.uv - float2(0.5, 0.5);\n"
        @"  float d = length(p);\n"
        @"  float intensity = clamp(u.p0.x, 0.0, 1.0);\n"
        @"  float alpha = clamp(u.p0.y, 0.0, 1.0);\n"
        @"  float vignetteSize = clamp(u.p0.z, 0.0, 1.0);\n"
        @"  int mode = (int)u.p0.w;\n"
        @"  float vig = smoothstep(vignetteSize, vignetteSize + 0.35, d);\n"
        @"  float a = alpha * intensity;\n"
        @"  if (mode == 1) {\n"
        @"    return float4(u.color.rgb, a * vig);\n"
        @"  }\n"
        @"  return float4(u.color.rgb, a);\n"
        @"}\n";

    NSError* err = nil;
    id<MTLLibrary> lib = [device newLibraryWithSource:src options:nil error:&err];
    if (err || !lib) {
        if (err) {
            LOGE("VIDVIZ_ERROR: Metal effect library compile failed: %s", [[err localizedDescription] UTF8String]);
        }
        return false;
    }

    id<MTLFunction> vf = [lib newFunctionWithName:@"vmain"];
    id<MTLFunction> ff = [lib newFunctionWithName:@"fmain"];
    if (!vf || !ff) {
        return false;
    }

    MTLRenderPipelineDescriptor* desc = [[MTLRenderPipelineDescriptor alloc] init];
    desc.vertexFunction = vf;
    desc.fragmentFunction = ff;
    desc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    desc.colorAttachments[0].blendingEnabled = YES;
    desc.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
    desc.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
    desc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
    desc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
    desc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    desc.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;

    id<MTLRenderPipelineState> pso = [device newRenderPipelineStateWithDescriptor:desc error:&err];
    if (err || !pso) {
        if (err) {
            LOGE("VIDVIZ_ERROR: Metal effect pipeline create failed: %s", [[err localizedDescription] UTF8String]);
        }
        return false;
    }

    m_effectPipeline = (__bridge_retained void*)pso;
    return true;
}

void MetalRenderer::resetVideoDecoder() {
    if (m_videoLastSample) {
        CFRelease(m_videoLastSample);
        m_videoLastSample = nullptr;
    }
    m_videoLastPtsUs = -1;
    m_videoPreferredRotationDeg = 0.0f;

    if (m_videoReader) {
        AVAssetReader* r = (__bridge_transfer AVAssetReader*)m_videoReader;
        [r cancelReading];
        (void)r;
        m_videoReader = nullptr;
    }

    if (m_videoOutput) {
        AVAssetReaderTrackOutput* o = (__bridge_transfer AVAssetReaderTrackOutput*)m_videoOutput;
        (void)o;
        m_videoOutput = nullptr;
    }

    if (m_videoAsset) {
        AVAsset* a = (__bridge_transfer AVAsset*)m_videoAsset;
        (void)a;
        m_videoAsset = nullptr;
    }

    m_videoPath.clear();
}

void MetalRenderer::resetOverlayVideoDecoder() {
    if (m_overlayVideoLastSample) {
        CFRelease(m_overlayVideoLastSample);
        m_overlayVideoLastSample = nullptr;
    }
    m_overlayVideoLastPtsUs = -1;
    m_overlayVideoPreferredRotationDeg = 0.0f;

    if (m_overlayVideoReader) {
        AVAssetReader* r = (__bridge_transfer AVAssetReader*)m_overlayVideoReader;
        [r cancelReading];
        (void)r;
        m_overlayVideoReader = nullptr;
    }

    if (m_overlayVideoOutput) {
        AVAssetReaderTrackOutput* o = (__bridge_transfer AVAssetReaderTrackOutput*)m_overlayVideoOutput;
        (void)o;
        m_overlayVideoOutput = nullptr;
    }

    if (m_overlayVideoAsset) {
        AVAsset* a = (__bridge_transfer AVAsset*)m_overlayVideoAsset;
        (void)a;
        m_overlayVideoAsset = nullptr;
    }

    m_overlayVideoPath.clear();
}

} // namespace ios
} // namespace vidviz
