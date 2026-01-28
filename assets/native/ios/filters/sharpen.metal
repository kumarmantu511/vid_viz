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

fragment vv_fmain_out fmain(constant VVUniforms& _29 [[buffer(0)]], texture2d<float> uTexture [[texture(0)]], sampler uTextureSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float2 uv = FlutterFragCoord(gl_FragCoord).xy / _29.uResolution;
    if (_29.uIntensity < 0.00999999977648258209228515625)
    {
        out.fragColor = float4(uTexture.sample(uTextureSmplr, uv).xyz, 1.0);
        return out;
    }
    float2 texel = float2(1.0) / _29.uResolution;
    float3 c = uTexture.sample(uTextureSmplr, uv).xyz;
    float3 l = uTexture.sample(uTextureSmplr, (uv - float2(texel.x, 0.0))).xyz;
    float3 r = uTexture.sample(uTextureSmplr, (uv + float2(texel.x, 0.0))).xyz;
    float3 t = uTexture.sample(uTextureSmplr, (uv - float2(0.0, texel.y))).xyz;
    float3 b = uTexture.sample(uTextureSmplr, (uv + float2(0.0, texel.y))).xyz;
    float3 detail = (c * 4.0) - (((l + r) + t) + b);
    float3 finalColor = c + (detail * _29.uIntensity);
    out.fragColor = float4(fast::clamp(finalColor, float3(0.0), float3(1.0)), 1.0);
    return out;
}
