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

static inline __attribute__((always_inline))
float hash(thread float2& p)
{
    p = fract(p * float2(123.339996337890625, 345.45001220703125));
    p += float2(dot(p, p + float2(34.345001220703125)));
    return fract(p.x * p.y);
}

fragment vv_fmain_out fmain(constant VVUniforms& _60 [[buffer(0)]], texture2d<float> uTexture [[texture(0)]], sampler uTextureSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float2 uv = FlutterFragCoord(gl_FragCoord).xy / _60.uResolution;
    float3 base = uTexture.sample(uTextureSmplr, uv).xyz;
    float t = floor(_60.uTime * 24.0);
    float2 param = (uv * _60.uResolution) + float2(t, t * 1.37000000476837158203125);
    float _98 = hash(param);
    float n = _98;
    n = (n * 2.0) - 1.0;
    float grain = mix(0.0, 0.20000000298023223876953125, fast::clamp(_60.uIntensity, 0.0, 1.0));
    float3 effect = fast::clamp(base + float3(n * grain), float3(0.0), float3(1.0));
    float3 finalColor = mix(base, effect, float3(fast::clamp(_60.uIntensity, 0.0, 1.0)));
    out.fragColor = float4(finalColor, 1.0);
    return out;
}
