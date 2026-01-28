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
    float2 dir = (uv - float2(0.5)) * 2.0;
    float amount = 0.00999999977648258209228515625 + (0.039999999105930328369140625 * fast::clamp(_29.uIntensity, 0.0, 1.0));
    float2 off = dir * amount;
    float2 uvR = fast::clamp(uv + off, float2(0.0), float2(1.0));
    float2 uvG = uv;
    float2 uvB = fast::clamp(uv - off, float2(0.0), float2(1.0));
    float r = uTexture.sample(uTextureSmplr, uvR).x;
    float g = uTexture.sample(uTextureSmplr, uvG).y;
    float b = uTexture.sample(uTextureSmplr, uvB).z;
    float3 effect = float3(r, g, b);
    float3 base = uTexture.sample(uTextureSmplr, uv).xyz;
    float3 finalColor = mix(base, effect, float3(fast::clamp(_29.uIntensity, 0.0, 1.0)));
    out.fragColor = float4(finalColor, 1.0);
    return out;
}
