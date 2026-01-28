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
    float uSpeed;
    char _m4_pad[12];
    packed_float3 uColor;
    float uBars;
    float uFreq0;
    float uFreq1;
    float uFreq2;
    float uFreq3;
    float uFreq4;
    float uFreq5;
    float uFreq6;
    float uFreq7;
    float3 uColor2;
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
float2 fluid(thread float2& uv, thread const float& t)
{
    float turbulence = 4.0;
    for (float i = 1.0; i < 8.0; i += 1.0)
    {
        uv.x += (cos((uv.y * i) + t) / turbulence);
        uv.y += (sin(uv.x * i) / turbulence);
        uv = uv.yx;
    }
    return uv;
}

fragment vv_fmain_out fmain(constant VVUniforms& _84 [[buffer(0)]], texture2d<float> uTexture [[texture(0)]], sampler uTextureSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float2 frag = FlutterFragCoord(gl_FragCoord).xy;
    float2 uv = frag / _84.uResolution;
    float2 p = (frag / float2(fast::max(_84.uResolution.y, 1.0))) * 10.0;
    float env = fast::clamp(((_84.uFreq2 + _84.uFreq3) + _84.uFreq4) / 3.0, 0.0, 1.0);
    float t = _84.uTime * (0.60000002384185791015625 + (0.800000011920928955078125 * _84.uSpeed));
    float2 param = p;
    float param_1 = t;
    float2 _133 = fluid(param, param_1);
    float2 f = _133;
    float r = abs(sin(f.x)) + 0.5;
    float g = abs(sin((f.x + 2.0) + (t * 0.20000000298023223876953125))) - 0.20000000298023223876953125;
    float b = abs(sin(f.x + 4.0));
    float3 col = fast::clamp(float3(r, g, b), float3(0.0), float3(1.0));
    float3 grad = mix(float3(_84.uColor), _84.uColor2, float3(0.5 + (0.5 * sin(f.y * 0.20000000298023223876953125))));
    float3 effect = mix(col, grad, float3(0.300000011920928955078125 + (0.4000000059604644775390625 * env)));
    float3 tex = uTexture.sample(uTextureSmplr, uv).xyz;
    float3 finalMix = mix(tex, effect, float3(fast::clamp(_84.uIntensity, 0.0, 1.0)));
    out.fragColor = float4(finalMix, 1.0);
    return out;
}
