#import "platform/ios/text/text_renderer_ios.h"

#import "platform/ios/metal_renderer.h"
#import "platform/ios/text/text_parser_ios.h"
#import "platform/ios/text/text_rasterizer_ios.h"
#import "platform/ios/text/text_anim_ios.h"
#import "common/log.h"

#import <Metal/Metal.h>

#include <unordered_map>
#include <vector>
#include <string>
#include <cmath>
#include <algorithm>

namespace vidviz {
namespace ios {
namespace text {

struct TexInfo {
    void* tex = nullptr; // id<MTLTexture>
    int32_t w = 0;
    int32_t h = 0;
};

static inline float vvClamp(float v, float lo, float hi) {
    if (!std::isfinite(v)) return lo;
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

static inline float vvClamp01(float v) {
    if (!std::isfinite(v)) return 0.0f;
    if (v < 0.0f) return 0.0f;
    if (v > 1.0f) return 1.0f;
    return v;
}

static inline void vvArgbToRgb01(int64_t argb, float& r, float& g, float& b) {
    const uint32_t cc = static_cast<uint32_t>(argb);
    r = ((cc >> 16) & 0xFF) / 255.0f;
    g = ((cc >> 8) & 0xFF) / 255.0f;
    b = (cc & 0xFF) / 255.0f;
}

class TextRendererIOSImpl {
public:
    explicit TextRendererIOSImpl(MetalRenderer* owner)
        : owner(owner) {}

    MetalRenderer* owner = nullptr;

    std::unordered_map<std::string, TexInfo> baked;
    std::unordered_map<std::string, TexInfo> masks;

    void* quadPipeline = nullptr; // id<MTLRenderPipelineState>
    void* maskCompositePipeline = nullptr; // id<MTLRenderPipelineState>

    TexInfo effectRT;

    void releaseTexInfo(TexInfo& t) {
        if (t.tex) {
            id<MTLTexture> x = (__bridge_transfer id<MTLTexture>)t.tex;
            (void)x;
            t.tex = nullptr;
        }
        t.w = 0;
        t.h = 0;
    }

    void cleanup() {
        for (auto& kv : baked) {
            releaseTexInfo(kv.second);
        }
        baked.clear();

        for (auto& kv : masks) {
            releaseTexInfo(kv.second);
        }
        masks.clear();

        releaseTexInfo(effectRT);

        if (quadPipeline) {
            id<MTLRenderPipelineState> p = (__bridge_transfer id<MTLRenderPipelineState>)quadPipeline;
            (void)p;
            quadPipeline = nullptr;
        }
        if (maskCompositePipeline) {
            id<MTLRenderPipelineState> p = (__bridge_transfer id<MTLRenderPipelineState>)maskCompositePipeline;
            (void)p;
            maskCompositePipeline = nullptr;
        }
    }

    bool ensureQuadPipeline() {
        if (quadPipeline) return true;
        if (!owner) return false;

        id<MTLDevice> device = (__bridge id<MTLDevice>)owner->m_device;
        if (!device) return false;

        static NSString* const src =
            @"#include <metal_stdlib>\n"
            @"using namespace metal;\n"
            @"struct VOut { float4 position [[position]]; float2 uv; };\n"
            @"vertex VOut vmain(uint vid [[vertex_id]], const device float4* vb [[buffer(0)]]) {\n"
            @"  float4 v = vb[vid]; VOut o; o.position = float4(v.xy, 0.0, 1.0); o.uv = v.zw; return o;\n"
            @"}\n"
            @"struct U { float alpha; };\n"
            @"fragment float4 fmain(VOut in [[stage_in]], texture2d<float> tex [[texture(0)]], sampler samp [[sampler(0)]], constant U& u [[buffer(0)]]) {\n"
            @"  float a = clamp(u.alpha, 0.0, 1.0);\n"
            @"  float4 c = tex.sample(samp, in.uv);\n"
            @"  return float4(c.rgb * a, c.a * a);\n"
            @"}\n";

        NSError* err = nil;
        id<MTLLibrary> lib = [device newLibraryWithSource:src options:nil error:&err];
        if (err || !lib) return false;

        id<MTLFunction> vf = [lib newFunctionWithName:@"vmain"];
        id<MTLFunction> ff = [lib newFunctionWithName:@"fmain"];
        if (!vf || !ff) return false;

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
        if (err || !pso) return false;

        quadPipeline = (__bridge_retained void*)pso;
        return true;
    }

    bool ensureMaskCompositePipeline() {
        if (maskCompositePipeline) return true;
        if (!owner) return false;

        id<MTLDevice> device = (__bridge id<MTLDevice>)owner->m_device;
        if (!device) return false;

        static NSString* const src =
            @"#include <metal_stdlib>\n"
            @"using namespace metal;\n"
            @"struct VOut { float4 position [[position]]; float2 uv; };\n"
            @"vertex VOut vmain(uint vid [[vertex_id]], const device float4* vb [[buffer(0)]]) {\n"
            @"  float4 v = vb[vid]; VOut o; o.position = float4(v.xy, 0.0, 1.0); o.uv = v.zw; return o;\n"
            @"}\n"
            @"struct U { float alpha; };\n"
            @"fragment float4 fmain(VOut in [[stage_in]], texture2d<float> eff [[texture(0)]], texture2d<float> mask [[texture(1)]], sampler samp [[sampler(0)]], constant U& u [[buffer(0)]]) {\n"
            @"  float a = clamp(u.alpha, 0.0, 1.0);\n"
            @"  float3 col = eff.sample(samp, in.uv).rgb;\n"
            @"  float m = mask.sample(samp, in.uv).a;\n"
            @"  float am = a * m;\n"
            @"  return float4(col * am, am);\n"
            @"}\n";

        NSError* err = nil;
        id<MTLLibrary> lib = [device newLibraryWithSource:src options:nil error:&err];
        if (err || !lib) return false;

        id<MTLFunction> vf = [lib newFunctionWithName:@"vmain"];
        id<MTLFunction> ff = [lib newFunctionWithName:@"fmain"];
        if (!vf || !ff) return false;

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
        if (err || !pso) return false;

        maskCompositePipeline = (__bridge_retained void*)pso;
        return true;
    }

    id<MTLTexture> makeTextureBgra(const std::vector<uint8_t>& bgra, int32_t w, int32_t h) {
        if (!owner) return nil;
        if (bgra.empty() || w <= 0 || h <= 0) return nil;
        id<MTLDevice> device = (__bridge id<MTLDevice>)owner->m_device;
        if (!device) return nil;

        MTLTextureDescriptor* td = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:(NSUInteger)w height:(NSUInteger)h mipmapped:NO];
        td.usage = MTLTextureUsageShaderRead;
        td.storageMode = MTLStorageModeShared;
        id<MTLTexture> tex = [device newTextureWithDescriptor:td];
        if (!tex) return nil;
        MTLRegion rgn = { {0, 0, 0}, {(NSUInteger)w, (NSUInteger)h, 1} };
        [tex replaceRegion:rgn mipmapLevel:0 withBytes:bgra.data() bytesPerRow:(NSUInteger)w * 4];
        return tex;
    }

    bool ensureEffectRT(int32_t w, int32_t h) {
        if (!owner) return false;
        if (w <= 0 || h <= 0) return false;

        if (effectRT.tex && effectRT.w == w && effectRT.h == h) {
            return true;
        }
        releaseTexInfo(effectRT);

        id<MTLDevice> device = (__bridge id<MTLDevice>)owner->m_device;
        if (!device) return false;

        MTLTextureDescriptor* d = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:(NSUInteger)w height:(NSUInteger)h mipmapped:NO];
        d.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
        d.storageMode = MTLStorageModePrivate;
        id<MTLTexture> t = [device newTextureWithDescriptor:d];
        if (!t) return false;

        effectRT.tex = (__bridge_retained void*)t;
        effectRT.w = w;
        effectRT.h = h;
        return true;
    }

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
    ) {
        if (!owner) return;
        if (!owner->m_renderEncoder) return;
        if (!pipelinePtr) return;
        if (!tex0) return;

        id<MTLRenderCommandEncoder> enc = (__bridge id<MTLRenderCommandEncoder>)owner->m_renderEncoder;
        if (!enc) return;

        id<MTLRenderPipelineState> pso = (__bridge id<MTLRenderPipelineState>)pipelinePtr;
        if (!pso) return;

        if (!owner->ensureVideoPipeline()) {
            return;
        }
        id<MTLSamplerState> samp = (__bridge id<MTLSamplerState>)owner->m_videoSampler;
        if (!samp) return;

        const float cxPx = xPx + quadW * 0.5f;
        const float cyPx = yPx + quadH * 0.5f;
        const float hx = 0.5f * quadW;
        const float hy = 0.5f * quadH;

        const float rad = rotDeg * 3.1415926535f / 180.0f;
        const float cs = std::cos(rad);
        const float sn = std::sin(rad);

        auto rot = [&](float x, float y, float& ox, float& oy) {
            const float xx = x * sx;
            const float yy = y * sy;
            ox = xx * cs - yy * sn;
            oy = xx * sn + yy * cs;
        };

        auto pxToNdcX = [&](float x) -> float {
            return (x / std::max(1.0f, static_cast<float>(owner->m_width))) * 2.0f - 1.0f;
        };
        auto pxToNdcY = [&](float y) -> float {
            return 1.0f - (y / std::max(1.0f, static_cast<float>(owner->m_height))) * 2.0f;
        };

        float x0p, y0p, x1p, y1p, x2p, y2p, x3p, y3p;
        rot(-hx, -hy, x0p, y0p);
        rot( hx, -hy, x1p, y1p);
        rot(-hx,  hy, x2p, y2p);
        rot( hx,  hy, x3p, y3p);

        const float x0 = pxToNdcX(cxPx + x0p);
        const float y0 = pxToNdcY(cyPx + y0p);
        const float x1 = pxToNdcX(cxPx + x1p);
        const float y1 = pxToNdcY(cyPx + y1p);
        const float x2 = pxToNdcX(cxPx + x2p);
        const float y2 = pxToNdcY(cyPx + y2p);
        const float x3 = pxToNdcX(cxPx + x3p);
        const float y3 = pxToNdcY(cyPx + y3p);

        const float4 verts[4] = {
            {(float)x0, (float)y0, 0.0f, 1.0f},
            {(float)x1, (float)y1, uMax, 1.0f},
            {(float)x2, (float)y2, 0.0f, 0.0f},
            {(float)x3, (float)y3, uMax, 0.0f},
        };

        struct U { float alpha; };
        U u;
        u.alpha = vvClamp01(alpha);

        [enc setRenderPipelineState:pso];
        [enc setVertexBytes:verts length:sizeof(verts) atIndex:0];
        [enc setFragmentSamplerState:samp atIndex:0];
        [enc setFragmentTexture:tex0 atIndex:0];
        if (tex1) {
            [enc setFragmentTexture:tex1 atIndex:1];
        }
        [enc setFragmentBytes:&u length:sizeof(u) atIndex:0];
        [enc drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
    }

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
    ) {
        if (!owner) return;
        if (!owner->m_commandBuffer) return;
        if (!ensureEffectRT(w, h)) return;

        id<MTLCommandBuffer> cb = (__bridge id<MTLCommandBuffer>)owner->m_commandBuffer;
        id<MTLTexture> dst = (__bridge id<MTLTexture>)effectRT.tex;
        if (!cb || !dst) return;

        if (owner->m_renderEncoder) {
            id<MTLRenderCommandEncoder> encPrev = (__bridge id<MTLRenderCommandEncoder>)owner->m_renderEncoder;
            [encPrev endEncoding];
            owner->m_renderEncoder = nullptr;
            owner->m_exportSession.setCurrentEncoder(nullptr);
        }

        MTLRenderPassDescriptor* pass = [MTLRenderPassDescriptor renderPassDescriptor];
        pass.colorAttachments[0].texture = dst;
        pass.colorAttachments[0].loadAction = MTLLoadActionClear;
        pass.colorAttachments[0].storeAction = MTLStoreActionStore;
        pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0);

        id<MTLRenderCommandEncoder> enc = [cb renderCommandEncoderWithDescriptor:pass];
        if (!enc) return;

        MTLViewport vp;
        vp.originX = 0;
        vp.originY = 0;
        vp.width = (double)std::max(1, w);
        vp.height = (double)std::max(1, h);
        vp.znear = 0.0;
        vp.zfar = 1.0;
        [enc setViewport:vp];

        owner->m_renderEncoder = (__bridge void*)enc;
        owner->m_exportSession.setCurrentEncoder(owner->m_renderEncoder);

        owner->bindShader(shaderId);
        owner->setUniform("uResolution", (float)w, (float)h);
        owner->setUniform("iResolution", (float)w, (float)h);
        owner->setUniform("uTime", timeSec);
        owner->setUniform("iTime", timeSec);
        owner->setUniform("uIntensity", vvClamp01(intensity));
        owner->setUniform("uSpeed", vvClamp(speed, 0.01f, 5.0f));
        owner->setUniform("uAngle", angle);
        owner->setUniform("uThickness", vvClamp(thickness, 0.0f, 5.0f));

        float r = 1.0f, g = 1.0f, b = 1.0f;
        vvArgbToRgb01(colorA, r, g, b);
        owner->setUniform("uColorA", r, g, b);
        vvArgbToRgb01(colorB, r, g, b);
        owner->setUniform("uColorB", r, g, b);

        struct V { float pos[2]; float uv[2]; };
        const V verts[4] = {
            {{-1.0f, -1.0f}, {0.0f, 1.0f}},
            {{ 1.0f, -1.0f}, {1.0f, 1.0f}},
            {{-1.0f,  1.0f}, {0.0f, 0.0f}},
            {{ 1.0f,  1.0f}, {1.0f, 0.0f}},
        };

        [enc setVertexBytes:verts length:sizeof(verts) atIndex:0];
        if (!owner->m_uniformStaging.empty()) {
            [enc setFragmentBytes:owner->m_uniformStaging.data() length:owner->m_uniformStaging.size() atIndex:0];
        }
        id<MTLSamplerState> samp = (__bridge id<MTLSamplerState>)owner->m_videoSampler;
        if (samp) {
            [enc setFragmentSamplerState:samp atIndex:0];
        }
        for (const auto& kv : owner->m_boundTextures) {
            const int unit = kv.first;
            id<MTLTexture> t = (__bridge id<MTLTexture>)kv.second;
            if (t) {
                [enc setFragmentTexture:t atIndex:unit];
            }
        }
        [enc drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];

        [enc endEncoding];
        owner->m_renderEncoder = nullptr;
        owner->m_exportSession.setCurrentEncoder(nullptr);
    }

    void restoreSceneEncoderWithLoad() {
        if (!owner) return;
        if (!owner->m_commandBuffer) return;

        id<MTLCommandBuffer> cb = (__bridge id<MTLCommandBuffer>)owner->m_commandBuffer;
        if (!cb) return;

        id<MTLTexture> target = nil;
        if (owner->m_hasEncoderSurface) {
            target = (__bridge id<MTLTexture>)owner->currentPostProcessSrcTexture();
        } else {
            id<CAMetalDrawable> drawable = (__bridge id<CAMetalDrawable>)owner->m_currentDrawable;
            if (drawable) target = drawable.texture;
        }
        if (!target) return;

        MTLRenderPassDescriptor* pass = [MTLRenderPassDescriptor renderPassDescriptor];
        pass.colorAttachments[0].texture = target;
        pass.colorAttachments[0].loadAction = MTLLoadActionLoad;
        pass.colorAttachments[0].storeAction = MTLStoreActionStore;

        id<MTLRenderCommandEncoder> enc = [cb renderCommandEncoderWithDescriptor:pass];
        if (!enc) return;

        MTLViewport vp;
        vp.originX = 0;
        vp.originY = 0;
        vp.width = (double)std::max(1, owner->m_width);
        vp.height = (double)std::max(1, owner->m_height);
        vp.znear = 0.0;
        vp.zfar = 1.0;
        [enc setViewport:vp];

        owner->m_renderEncoder = (__bridge void*)enc;
        owner->m_exportSession.setCurrentEncoder(owner->m_renderEncoder);

        owner->m_boundShaderId.clear();
        owner->m_uniformStaging.clear();
        owner->m_boundTextures.clear();
    }
};

TextRendererIOS::TextRendererIOS(MetalRenderer* owner)
    : m_owner(owner) {
    m_owner->m_textRenderer = this;
}

TextRendererIOS::~TextRendererIOS() {
    cleanup();
}

static TextRendererIOSImpl* vvGetImpl(MetalRenderer* owner) {
    static std::unordered_map<MetalRenderer*, TextRendererIOSImpl*> s;
    auto it = s.find(owner);
    if (it != s.end()) return it->second;
    auto* p = new TextRendererIOSImpl(owner);
    s[owner] = p;
    return p;
}

static void vvFreeImpl(MetalRenderer* owner) {
    static std::unordered_map<MetalRenderer*, TextRendererIOSImpl*> s;
    auto it = s.find(owner);
    if (it != s.end()) {
        delete it->second;
        s.erase(it);
    }
}

void TextRendererIOS::cleanup() {
    if (!m_owner) return;
    TextRendererIOSImpl* impl = vvGetImpl(m_owner);
    if (impl) impl->cleanup();
    vvFreeImpl(m_owner);
    m_owner = nullptr;
}

void TextRendererIOS::render(const Asset& asset, TimeMs localTime) {
    if (!m_owner) return;
    if (!m_owner->m_renderEncoder) return;
    if (m_owner->m_width <= 0 || m_owner->m_height <= 0) return;

    TextRendererIOSImpl* impl = vvGetImpl(m_owner);
    if (!impl) return;

    ParsedTextParams p;
    if (!parseTextParams(asset.dataJson, p)) return;
    if (p.title.empty()) return;

    p.alpha = vvClamp01(p.alpha);
    const float timeSec = static_cast<float>(localTime) / 1000.0f;

    float gAlpha = p.alpha;
    if (p.animType == "fade_in") {
        float spd = vvClamp(p.animSpeed, 0.2f, 2.0f);
        const float prog = std::fmod(std::max(0.0f, timeSec * spd), 1.0f);
        gAlpha = gAlpha * prog;
    } else if (p.animType == "blink") {
        float spd = vvClamp(p.animSpeed, 0.2f, 2.0f);
        float ph = std::isfinite(p.animPhase) ? p.animPhase : 0.0f;
        const float f = 0.5f + 0.5f * std::sin(timeSec * spd * 6.0f + ph);
        gAlpha = gAlpha * f;
    }
    gAlpha = vvClamp01(gAlpha);

    const TextAnimTransform xform = computeTextAnimTransform(p, timeSec, 0.0f, 0.0f);

    ParsedTextParams cacheP = p;
    applyTextDecorAnimQuantized(cacheP, timeSec);

    auto computeTextPadPx = [&](const ParsedTextParams& q) -> float {
        if (q.padPx >= 0.0f && std::isfinite(q.padPx)) {
            float pad = q.padPx;
            if (pad < 0.0f) pad = 0.0f;
            if (pad > 200.0f) pad = 200.0f;
            return pad;
        }
        float bleed = 0.0f;
        bleed = std::max(bleed, std::max(0.0f, q.glowRadius) * 2.0f);
        bleed = std::max(bleed, std::max(0.0f, q.shadowBlur) * 2.0f + (std::fabs(q.shadowX) + std::fabs(q.shadowY)));
        bleed = std::max(bleed, std::max(0.0f, q.borderW));
        if (q.box) {
            bleed = std::max(bleed, std::max(0.0f, q.boxBorderW) * 0.5f);
        }
        if (!std::isfinite(bleed)) bleed = 0.0f;
        if (bleed < 0.0f) bleed = 0.0f;
        if (bleed > 80.0f) bleed = 80.0f;
        return std::ceil(bleed) + 6.0f;
    };

    float padAfterScalePx = computeTextPadPx(cacheP);

    bool hasUiMetrics = false;
    float sxUi = 0.0f;
    float syUi = 0.0f;
    float uiDpr = 0.0f;
    {
        const float uiW = (m_owner->m_uiPlayerWidth > 0.0f) ? m_owner->m_uiPlayerWidth : 0.0f;
        const float uiH = (m_owner->m_uiPlayerHeight > 0.0f) ? m_owner->m_uiPlayerHeight : 0.0f;
        if (uiW > 0.0f && uiH > 0.0f) {
            hasUiMetrics = true;
            sxUi = static_cast<float>(m_owner->m_width) / uiW;
            syUi = static_cast<float>(m_owner->m_height) / uiH;
            uiDpr = (m_owner->m_uiDevicePixelRatio > 0.0f) ? m_owner->m_uiDevicePixelRatio : 0.0f;

            const float s = 0.5f * (sxUi + syUi);
            const float sStroke = std::max(sxUi, syUi);
            auto scaleDecor = [&](ParsedTextParams& q) {
                q.borderW *= s;
                q.glowRadius *= s;
                q.shadowBlur *= s;
                q.boxBorderW *= sStroke;
                q.boxPad *= s;
                q.boxRadius *= s;
                q.shadowX *= sxUi;
                q.shadowY *= syUi;
            };

            if (!p.decorAlreadyScaled) {
                scaleDecor(cacheP);
                padAfterScalePx = computeTextPadPx(cacheP);
            } else {
                if (cacheP.animType == "shadow_swing") {
                    cacheP.shadowX *= sxUi;
                    cacheP.shadowY *= syUi;
                }
            }
        }
    }

    int blurInStep = -1;
    if (p.animType == "blur_in") {
        float spd = vvClamp(p.animSpeed, 0.2f, 2.0f);
        const float prog = std::fmod(std::max(0.0f, timeSec * spd), 1.0f);
        blurInStep = static_cast<int>(std::round(prog * 30.0f));
        if (blurInStep < 0) blurInStep = 0;
        if (blurInStep > 30) blurInStep = 30;
    }

    float clipU = 1.0f;
    if (p.animType == "typing" || p.animType == "type_delete") {
        float spd = vvClamp(p.animSpeed, 0.2f, 2.0f);
        float t = timeSec * spd;
        float prog = 0.0f;
        if (p.animType == "typing") {
            prog = std::fmod(std::max(0.0f, t), 1.0f);
        } else {
            const float x = std::fmod(std::max(0.0f, t), 2.0f);
            prog = (x < 1.0f) ? x : (2.0f - x);
        }
        prog = vvClamp01(prog);
        clipU = prog;
    }

    const bool hasShaderEffect =
        !p.effectType.empty() &&
        p.effectType != "none" &&
        p.effectType != "inner_glow" &&
        p.effectType != "inner_shadow";

    const bool bakeDecorOnly = hasShaderEffect;

    float fontPx = p.fontSizeN * static_cast<float>(m_owner->m_width);
    if (!std::isfinite(fontPx) || fontPx < 1.0f) fontPx = 16.0f;
    if (fontPx > 2048.0f) fontPx = 2048.0f;

    std::string key;
    key.reserve(asset.id.size() + p.title.size() + p.font.size() + 256);
    key += asset.id;
    key += "|";
    key += std::to_string(m_owner->m_width);
    key += "x";
    key += std::to_string(m_owner->m_height);
    key += "|";
    key += p.title;
    key += "|";
    key += p.font;
    key += "|";
    key += std::to_string(static_cast<int>(fontPx));
    key += "|";
    key += std::to_string(static_cast<int64_t>(p.fontColor));
    key += "|";
    key += std::to_string(static_cast<int>(cacheP.borderW * 1000.0f));
    key += "|";
    key += std::to_string(static_cast<int64_t>(p.borderColor));
    key += "|";
    key += std::to_string(static_cast<int64_t>(p.shadowColor));
    key += "|";
    key += std::to_string(static_cast<int>(cacheP.shadowX * 1000.0f));
    key += "|";
    key += std::to_string(static_cast<int>(cacheP.shadowY * 1000.0f));
    key += "|";
    key += std::to_string(static_cast<int>(cacheP.shadowBlur * 1000.0f));
    key += "|";
    key += (p.box ? "1" : "0");
    key += "|";
    key += std::to_string(static_cast<int>(cacheP.boxBorderW * 1000.0f));
    key += "|";
    key += std::to_string(static_cast<int64_t>(p.boxColor));
    key += "|";
    key += std::to_string(static_cast<int>(cacheP.boxPad * 1000.0f));
    key += "|";
    key += std::to_string(static_cast<int>(cacheP.boxRadius * 1000.0f));
    key += "|";
    key += std::to_string(static_cast<int>(cacheP.glowRadius * 1000.0f));
    key += "|";
    key += std::to_string(static_cast<int64_t>(p.glowColor));
    key += "|";
    key += p.effectType;
    key += "|";
    key += std::to_string(static_cast<int>(p.effectIntensity * 1000.0f));
    key += "|";
    key += std::to_string(static_cast<int64_t>(p.effectColorA));
    key += "|";
    key += std::to_string(static_cast<int64_t>(p.effectColorB));
    key += "|";
    key += std::to_string(static_cast<int>(p.effectSpeed * 1000.0f));
    key += "|";
    key += std::to_string(static_cast<int>(p.effectThickness * 1000.0f));
    key += "|";
    key += std::to_string(static_cast<int>(p.effectAngle * 1000.0f));
    key += "|";
    key += p.animType;
    key += "|";
    key += std::to_string(static_cast<int>(p.animSpeed * 1000.0f));
    key += "|";
    key += std::to_string(static_cast<int>(p.animAmplitude * 1000.0f));
    key += "|";
    key += std::to_string(static_cast<int>(p.animPhase * 1000.0f));
    key += "|";
    key += (bakeDecorOnly ? "decorOnly" : "full");
    key += "|textAlignV2";

    if (!hasShaderEffect && blurInStep >= 0) {
        key += "|blurIn=";
        key += std::to_string(blurInStep);
    }

    auto getOrCreate = [&](std::unordered_map<std::string, TexInfo>& map, const std::string& k, bool maskOnly, bool decorOnly) -> TexInfo* {
        auto it = map.find(k);
        if (it != map.end() && it->second.tex) {
            return &it->second;
        }

        ParsedTextParams rp = cacheP;
        rp.alpha = 1.0f;

        std::vector<uint8_t> bgra;
        int32_t tw = 0;
        int32_t th = 0;
        if (!rasterizeTextBitmap(rp, fontPx, timeSec, maskOnly, decorOnly, bgra, tw, th)) {
            return nullptr;
        }

        id<MTLTexture> tex = impl->makeTextureBgra(bgra, tw, th);
        if (!tex) return nullptr;

        TexInfo ti;
        ti.tex = (__bridge_retained void*)tex;
        ti.w = tw;
        ti.h = th;
        map[k] = ti;
        return &map[k];
    };

    if (!impl->ensureQuadPipeline()) return;

    // Position calc
    float xPx = p.x * static_cast<float>(m_owner->m_width) + xform.dxPx;
    float yPx = p.y * static_cast<float>(m_owner->m_height) + xform.dyPx;

    const bool hasExplicitPadPx = (p.padPx >= 0.0f && std::isfinite(p.padPx));
    if (hasExplicitPadPx) {
        xPx -= padAfterScalePx * xform.scaleX;
        yPx -= padAfterScalePx * xform.scaleY;
    }
    xPx += computeTextBiasXPx(p);

    auto snapPos = [&](float& xx, float& yy, float qw, float qh) {
        if (std::fabs(xform.rotationDeg) < 0.0001f) {
            const float tlx = xx + 0.5f * qw * (1.0f - xform.scaleX);
            const float tly = yy + 0.5f * qh * (1.0f - xform.scaleY);
            if (hasUiMetrics && uiDpr > 0.5f && sxUi > 0.0f && syUi > 0.0f) {
                const float tlxUi = tlx / sxUi;
                const float tlyUi = tly / syUi;
                const float tlxUiPhys = tlxUi * uiDpr;
                const float tlyUiPhys = tlyUi * uiDpr;
                const float stlxUiPhys = std::round(tlxUiPhys);
                const float stlyUiPhys = std::round(tlyUiPhys);
                const float stlx = (stlxUiPhys / uiDpr) * sxUi;
                const float stly = (stlyUiPhys / uiDpr) * syUi;
                xx = stlx - 0.5f * qw * (1.0f - xform.scaleX);
                yy = stly - 0.5f * qh * (1.0f - xform.scaleY);
            } else if (!hasUiMetrics) {
                const float stlx = std::round(tlx);
                const float stly = std::round(tly);
                xx = stlx - 0.5f * qw * (1.0f - xform.scaleX);
                yy = stly - 0.5f * qh * (1.0f - xform.scaleY);
            }
        }
    };

    // Baked path
    if (!hasShaderEffect) {
        TexInfo* t = getOrCreate(impl->baked, key, false, false);
        if (!t || !t->tex || t->w <= 0 || t->h <= 0) return;

        float quadW = static_cast<float>(t->w);
        float uMax = 1.0f;
        if (clipU < 0.9999f) {
            uMax = clipU;
            quadW = std::max(1.0f, quadW * uMax);
        }

        snapPos(xPx, yPx, quadW, static_cast<float>(t->h));

        id<MTLTexture> tex = (__bridge id<MTLTexture>)t->tex;
        impl->drawTexturedQuad(impl->quadPipeline, tex, nil, xPx, yPx, quadW, (float)t->h, xform.rotationDeg, xform.scaleX, xform.scaleY, gAlpha, uMax);
        return;
    }

    // Shader effect path
    TexInfo* decor = getOrCreate(impl->baked, key, false, true);
    if (decor && decor->tex && decor->w > 0 && decor->h > 0) {
        float quadW = static_cast<float>(decor->w);
        float uMax = 1.0f;
        if (clipU < 0.9999f) {
            uMax = clipU;
            quadW = std::max(1.0f, quadW * uMax);
        }
        float dx = xPx;
        float dy = yPx;
        snapPos(dx, dy, quadW, static_cast<float>(decor->h));
        id<MTLTexture> t0 = (__bridge id<MTLTexture>)decor->tex;
        impl->drawTexturedQuad(impl->quadPipeline, t0, nil, dx, dy, quadW, (float)decor->h, xform.rotationDeg, xform.scaleX, xform.scaleY, gAlpha, uMax);
    }

    std::string maskKey = key;
    maskKey += "|mask";
    if (blurInStep >= 0) {
        maskKey += "|blurIn=";
        maskKey += std::to_string(blurInStep);
    }

    TexInfo* mask = getOrCreate(impl->masks, maskKey, true, false);
    if (!mask || !mask->tex || mask->w <= 0 || mask->h <= 0) return;

    // Render effect shader into offscreen (mask-sized) RT
    impl->renderToEffectRT(
        p.effectType,
        mask->w,
        mask->h,
        timeSec,
        p.effectIntensity,
        p.effectSpeed,
        p.effectAngle,
        p.effectThickness,
        p.effectColorA,
        p.effectColorB
    );

    // Restore scene encoder and composite (effect * mask)
    impl->restoreSceneEncoderWithLoad();

    if (!impl->ensureMaskCompositePipeline()) return;

    float quadW = static_cast<float>(mask->w);
    float uMax = 1.0f;
    if (clipU < 0.9999f) {
        uMax = clipU;
        quadW = std::max(1.0f, quadW * uMax);
    }

    float mx = xPx;
    float my = yPx;
    snapPos(mx, my, quadW, static_cast<float>(mask->h));

    id<MTLTexture> effTex = (__bridge id<MTLTexture>)impl->effectRT.tex;
    id<MTLTexture> maskTex = (__bridge id<MTLTexture>)mask->tex;
    impl->drawTexturedQuad(impl->maskCompositePipeline, effTex, maskTex, mx, my, quadW, (float)mask->h, xform.rotationDeg, xform.scaleX, xform.scaleY, gAlpha, uMax);
}

} // namespace text
} // namespace ios
} // namespace vidviz
