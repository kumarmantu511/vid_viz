#import "platform/ios/text/text_renderer_ios_internal.h"

namespace vidviz {
namespace ios {
namespace text {

id<MTLTexture> TextRendererIOSImpl::makeTextureBgra(const std::vector<uint8_t>& bgra, int32_t w, int32_t h) {
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

bool TextRendererIOSImpl::ensureEffectRT(int32_t w, int32_t h) {
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

void TextRendererIOSImpl::renderToEffectRT(
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
    owner->setUniform("uIntensity", vvTextClamp01(intensity));
    owner->setUniform("uSpeed", vvTextClamp(speed, 0.01f, 5.0f));
    owner->setUniform("uAngle", angle);
    owner->setUniform("uThickness", vvTextClamp(thickness, 0.0f, 5.0f));

    float r = 1.0f, g = 1.0f, b = 1.0f;
    vvTextArgbToRgb01(colorA, r, g, b);
    owner->setUniform("uColorA", r, g, b);
    vvTextArgbToRgb01(colorB, r, g, b);
    owner->setUniform("uColorB", r, g, b);

    const VVTextQuadV verts[4] = {
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

void TextRendererIOSImpl::restoreSceneEncoderWithLoad() {
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

void TextRendererIOSImpl::drawTexturedQuad(
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

    if (!owner->ensureVideoPipeline()) return;

    id<MTLRenderCommandEncoder> enc = (__bridge id<MTLRenderCommandEncoder>)owner->m_renderEncoder;
    id<MTLRenderPipelineState> pso = (__bridge id<MTLRenderPipelineState>)pipelinePtr;
    id<MTLSamplerState> samp = (__bridge id<MTLSamplerState>)owner->m_videoSampler;
    if (!enc || !pso || !samp) return;

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

    const VVTextQuadV verts[4] = {
        {{x0, y0}, {0.0f, 1.0f}},
        {{x1, y1}, {uMax, 1.0f}},
        {{x2, y2}, {0.0f, 0.0f}},
        {{x3, y3}, {uMax, 0.0f}},
    };

    struct U { float alpha; };
    U u;
    u.alpha = vvTextClamp01(alpha);

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

} // namespace text
} // namespace ios
} // namespace vidviz
