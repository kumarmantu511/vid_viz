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
    float uBlurRadius;
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
    float2 uv = fragCoord / _31.uResolution;
    bool _44 = _31.uIntensity < 0.00999999977648258209228515625;
    bool _53;
    if (!_44)
    {
        _53 = _31.uBlurRadius < 0.5;
    }
    else
    {
        _53 = _44;
    }
    if (_53)
    {
        out.fragColor = float4(uTexture.sample(uTextureSmplr, uv).xyz, 1.0);
        return out;
    }
    float4 sourceColor = uTexture.sample(uTextureSmplr, uv);
    float2 pixelSize = float2(1.0) / _31.uResolution;
    float radiusFactor = _31.uBlurRadius * 1.5;
    float3 acc = float3(0.0);
    float totalWeight = 0.0;
    for (float i = 0.0; i < 64.0; i += 1.0)
    {
        float progress = i / 64.0;
        float theta = i * 2.3999631404876708984375;
        float r = sqrt(progress);
        float2 offset = ((float2(cos(theta), sin(theta)) * r) * radiusFactor) * pixelSize;
        offset.x *= (_31.uResolution.y / _31.uResolution.x);
        float weight = exp(((-r) * r) * 2.5);
        float2 samplePos = fast::clamp(uv + offset, float2(0.0), float2(1.0));
        acc += (uTexture.sample(uTextureSmplr, samplePos).xyz * weight);
        totalWeight += weight;
    }
    float3 finalBlur = acc / float3(totalWeight);
    float3 result = mix(sourceColor.xyz, finalBlur, float3(fast::clamp(_31.uIntensity, 0.0, 1.0)));
    out.fragColor = float4(result, 1.0);
    return out;
}
