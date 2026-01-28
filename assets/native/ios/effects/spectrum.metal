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
float sat(thread const float& x)
{
    return fast::clamp(x, 0.0, 1.0);
}

static inline __attribute__((always_inline))
float rnd(thread const float2& v)
{
    return fract(sin(dot(v, float2(12.98980045318603515625, 78.233001708984375))) * 43758.546875);
}

static inline __attribute__((always_inline))
float2 sat(thread const float2& v)
{
    return fast::clamp(v, float2(0.0), float2(1.0));
}

static inline __attribute__((always_inline))
float3 spectrum_weights(thread const float& t)
{
    float param = 1.0 - smoothstep(0.0, 0.60000002384185791015625, t);
    float r = sat(param);
    float param_1 = smoothstep(0.4000000059604644775390625, 1.0, t);
    float b = sat(param_1);
    float param_2 = 1.0 - (abs(t - 0.5) * 2.0);
    float g = sat(param_2);
    float3 w = float3(r, g, b);
    w = powr(w, float3(0.4545454680919647216796875));
    float s = fast::max(9.9999997473787516355514526367188e-05, (w.x + w.y) + w.z);
    return w / float3(s);
}

static inline __attribute__((always_inline))
void mainImage(thread float4& outCol, thread const float2& fragCoord, constant VVUniforms& _127, texture2d<float> uTexture, sampler uTextureSmplr)
{
    float2 uv = fragCoord / _127.uResolution;
    float3 base = uTexture.sample(uTextureSmplr, uv).xyz;
    float aspect = _127.uResolution.x / fast::max(_127.uResolution.y, 1.0);
    float2 dir = float2(1.0, 0.180000007152557373046875) * (1.0 / aspect);
    float timePhase = (sin(_127.uTime * 0.800000011920928955078125) * 0.5) + 0.5;
    float param = _127.uIntensity;
    float mag = (0.0199999995529651641845703125 * sat(param)) * (0.300000011920928955078125 + (0.699999988079071044921875 * timePhase));
    float2 param_1 = floor((uv * _127.uResolution) * 0.5);
    float pixelJitter = (rnd(param_1) - 0.5) * 0.00200000009499490261077880859375;
    float3 accum = float3(0.0);
    float3 wsum = float3(0.0);
    for (int i = 0; i < 7; i++)
    {
        float t = float(i) / 6.0;
        float edgeFactor = (t - 0.5) * 2.0;
        float curve = sign(edgeFactor) * powr(abs(edgeFactor), 1.2000000476837158203125);
        float2 sampleUV = uv + (dir * ((mag * curve) + pixelJitter));
        float2 param_2 = sampleUV;
        sampleUV = sat(param_2);
        float param_3 = t;
        float3 sWeights = spectrum_weights(param_3);
        float3 sColor = uTexture.sample(uTextureSmplr, sampleUV).xyz;
        accum += (sColor * sWeights);
        wsum += sWeights;
    }
    float3 result = accum / fast::max(float3(9.9999997473787516355514526367188e-06), wsum);
    outCol = float4(result, 1.0);
}

fragment vv_fmain_out fmain(constant VVUniforms& _127 [[buffer(0)]], texture2d<float> uTexture [[texture(0)]], sampler uTextureSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float2 fragCoord = FlutterFragCoord(gl_FragCoord).xy;
    float2 param_1 = fragCoord;
    float4 param;
    mainImage(param, param_1, _127, uTexture, uTextureSmplr);
    float4 outCol = param;
    float3 base = uTexture.sample(uTextureSmplr, (fragCoord / _127.uResolution)).xyz;
    float param_2 = _127.uIntensity;
    float blend = sat(param_2);
    float3 finalColor = mix(base, outCol.xyz, float3(blend));
    out.fragColor = float4(finalColor, 1.0);
    return out;
}
