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
float rand(thread const float2& p)
{
    return fract(sin(dot(p, float2(12.98980045318603515625, 78.233001708984375))) * 43758.546875);
}

fragment vv_fmain_out fmain(constant VVUniforms& _47 [[buffer(0)]], texture2d<float> uTexture [[texture(0)]], sampler uTextureSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float2 frag = FlutterFragCoord(gl_FragCoord).xy;
    float2 uv = frag / _47.uResolution;
    float time = _47.uTime * (0.699999988079071044921875 + (0.300000011920928955078125 * _47.uSpeed));
    float env = fast::clamp((_47.uFreq3 + _47.uFreq4) / 2.0, 0.0, 1.0);
    float3 tex = uTexture.sample(uTextureSmplr, uv).xyz;
    float scan = (0.039999999105930328369140625 * sin((uv.y * _47.uResolution.y) * 3.141590118408203125)) * (0.5 + (0.5 * env));
    float off = (1.0 + (2.0 * env)) / fast::max(_47.uResolution.x, 1.0);
    float3 split = float3(uTexture.sample(uTextureSmplr, (uv + float2(off, 0.0))).x, tex.y, uTexture.sample(uTextureSmplr, (uv - float2(off, 0.0))).z);
    float2 param = float2(uv.x * 123.40000152587890625, floor((uv.y + (time * 0.100000001490116119384765625)) * 200.0));
    float n = rand(param) * 0.02999999932944774627685546875;
    float3 effect = fast::clamp((split + float3(scan)) + float3(n), float3(0.0), float3(1.0));
    float3 mixc = mix(tex, effect, float3(fast::clamp(_47.uIntensity, 0.0, 1.0)));
    out.fragColor = float4(mixc, 1.0);
    return out;
}
