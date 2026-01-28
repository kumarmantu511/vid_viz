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

static inline __attribute__((always_inline))
float random(thread const float2& uv)
{
    return fract(sin(dot(uv, float2(12.98980045318603515625, 78.233001708984375))) * 43758.546875);
}

fragment vv_fmain_out fmain(constant VVUniforms& _44 [[buffer(0)]], texture2d<float> uTexture [[texture(0)]], sampler uTextureSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float2 uv = FlutterFragCoord(gl_FragCoord).xy / _44.uResolution;
    if (_44.uIntensity < 0.00999999977648258209228515625)
    {
        out.fragColor = float4(uTexture.sample(uTextureSmplr, uv).xyz, 1.0);
        return out;
    }
    float2 center = float2(0.5);
    float2 toCenter = center - uv;
    float2 param = uv;
    float offset = random(param);
    float3 acc = float3(0.0);
    float totalWeight = 0.0;
    float strength = _44.uIntensity * 0.300000011920928955078125;
    for (float t = 0.0; t <= 24.0; t += 1.0)
    {
        float percent = (t + offset) / 24.0;
        float weight = 4.0 * (1.0 - percent);
        float2 sampleUV = uv + ((toCenter * percent) * strength);
        sampleUV = fast::clamp(sampleUV, float2(0.0), float2(1.0));
        acc += (uTexture.sample(uTextureSmplr, sampleUV).xyz * weight);
        totalWeight += weight;
    }
    float3 finalColor = acc / float3(totalWeight);
    out.fragColor = float4(finalColor, 1.0);
    return out;
}
