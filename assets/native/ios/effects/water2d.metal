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
    float2 fragCoord = FlutterFragCoord(gl_FragCoord).xy;
    float2 r = fragCoord / _31.uResolution;
    if (_31.uIntensity <= 0.001000000047497451305389404296875)
    {
        out.fragColor = float4(uTexture.sample(uTextureSmplr, r).xyz, 1.0);
        return out;
    }
    float timeVal = _31.uTime * 0.20000000298023223876953125;
    float2 f1 = (r + float2(timeVal)) * 8.0;
    float2 f2 = f1 + float2(8.0);
    float2 p = cos(float2(cos(f1.x - f1.y) * cos(f1.y), sin(f1.x + f1.y) * sin(f1.y)));
    float2 q = cos(float2(cos(f2.x - f2.y) * cos(f2.y), sin(f2.x + f2.y) * sin(f2.y)));
    float amplitude = 2.0 / _31.uResolution.x;
    float2 s = r + ((p - q) * amplitude);
    s = fast::clamp(s, float2(0.0), float2(1.0));
    float3 base = uTexture.sample(uTextureSmplr, r).xyz;
    float3 warped = uTexture.sample(uTextureSmplr, s).xyz;
    float3 finalColor = mix(base, warped, float3(fast::clamp(_31.uIntensity, 0.0, 1.0)));
    out.fragColor = float4(finalColor, 1.0);
    return out;
}
