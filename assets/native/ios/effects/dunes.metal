#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;

struct vv_vmain_out
{
    float2 vUV [[user(locn0)]];
    float4 gl_Position [[position]];
};

struct vv_vmain_in
{
    float2 aPos [[attribute(0)]];
    float2 aUV [[attribute(1)]];
};

vertex vv_vmain_out vmain(vv_vmain_in in [[stage_in]])
{
    vv_vmain_out out = {};
    out.vUV = in.aUV;
    out.gl_Position = float4(in.aPos, 0.0, 1.0);
    return out;
}

struct VVUniforms
{
    float2 uResolution;
    float uTime;
    float uIntensity;
};

struct vv_fmain_out
{
    float4 fragColor [[color(0)]];
};

static inline __attribute__((always_inline))
float4 FlutterFragCoord(thread float4& gl_FragCoord)
{
    return float4(gl_FragCoord.xy, 0.0, 1.0);
}

fragment vv_fmain_out fmain(constant VVUniforms& _31 [[buffer(0)]], texture2d<float> uTexture [[texture(0)]], sampler uTextureSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float2 pos = FlutterFragCoord(gl_FragCoord).xy;
    float2 uv = pos / _31.uResolution;
    float4 tex = uTexture.sample(uTextureSmplr, uv);
    float sh = 4.0;
    float di = 0.5;
    float3 effectColor = floor((tex.xyz * sh) + float3(di)) / float3(sh);
    effectColor *= fast::clamp(fast::min(pos.x, pos.y) - 1.0, 0.0, 1.0);
    float3 finalColor = mix(tex.xyz, effectColor, float3(fast::clamp(_31.uIntensity, 0.0, 1.0)));
    out.fragColor = float4(finalColor, 1.0);
    return out;
}
