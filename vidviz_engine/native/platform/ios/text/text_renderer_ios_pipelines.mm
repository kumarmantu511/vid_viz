#import "platform/ios/text/text_renderer_ios_internal.h"

namespace vidviz {
namespace ios {
namespace text {

void TextRendererIOSImpl::releaseTexInfo(VVTextTexInfo& t) {
    if (t.tex) {
        id<MTLTexture> x = (__bridge_transfer id<MTLTexture>)t.tex;
        (void)x;
        t.tex = nullptr;
    }
    t.w = 0;
    t.h = 0;
}

void TextRendererIOSImpl::cleanup() {
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

bool TextRendererIOSImpl::ensureQuadPipeline() {
    if (quadPipeline) return true;
    if (!owner) return false;

    id<MTLDevice> device = (__bridge id<MTLDevice>)owner->m_device;
    if (!device) return false;

    static NSString* const src =
        @"#include <metal_stdlib>\n"
        @"using namespace metal;\n"
        @"struct VOut { float4 position [[position]]; float2 uv; };\n"
        @"vertex VOut vmain(uint vid [[vertex_id]], const device float4* vb [[buffer(0)]]) {\n"
        @"  float4 v = vb[vid]; VOut o; o.position=float4(v.xy,0.0,1.0); o.uv=v.zw; return o;\n"
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

bool TextRendererIOSImpl::ensureMaskCompositePipeline() {
    if (maskCompositePipeline) return true;
    if (!owner) return false;

    id<MTLDevice> device = (__bridge id<MTLDevice>)owner->m_device;
    if (!device) return false;

    static NSString* const src =
        @"#include <metal_stdlib>\n"
        @"using namespace metal;\n"
        @"struct VOut { float4 position [[position]]; float2 uv; };\n"
        @"vertex VOut vmain(uint vid [[vertex_id]], const device float4* vb [[buffer(0)]]) {\n"
        @"  float4 v = vb[vid]; VOut o; o.position=float4(v.xy,0.0,1.0); o.uv=v.zw; return o;\n"
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

} // namespace text
} // namespace ios
} // namespace vidviz
