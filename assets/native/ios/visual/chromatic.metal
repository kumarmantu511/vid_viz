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

fragment vv_fmain_out fmain(constant VVUniforms& _32 [[buffer(0)]], texture2d<float> uTexture [[texture(0)]], sampler uTextureSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float2 frag = FlutterFragCoord(gl_FragCoord).xy;
    float2 uv = frag / _32.uResolution;
    float time = _32.uTime * _32.uSpeed;
    float env = fast::clamp((0.60000002384185791015625 * (_32.uFreq0 + _32.uFreq1)) + ((0.4000000059604644775390625 * ((_32.uFreq5 + _32.uFreq6) + _32.uFreq7)) / 3.0), 0.0, 1.0);
    float px = 1.5 + (2.0 * env);
    float2 dir = float2(sin(time * 0.699999988079071044921875), cos(time * 0.5));
    float2 off = dir * (float2(px) / fast::max(_32.uResolution, float2(1.0)));
    float r = uTexture.sample(uTextureSmplr, (uv + off)).x;
    float g = uTexture.sample(uTextureSmplr, uv).y;
    float b = uTexture.sample(uTextureSmplr, (uv - off)).z;
    float3 tex = float3(r, g, b);
    float3 grad = mix(float3(_32.uColor), _32.uColor2, float3(uv.y));
    float3 effect = mix(tex, grad, float3(0.1500000059604644775390625 + (0.25 * env)));
    float3 finalMix = mix(uTexture.sample(uTextureSmplr, uv).xyz, effect, float3(fast::clamp(_32.uIntensity, 0.0, 1.0)));
    out.fragColor = float4(finalMix, 1.0);
    return out;
}
