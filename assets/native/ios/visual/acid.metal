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
float3 palette(thread const float& t)
{
    float3 a = float3(0.5);
    float3 b = float3(0.5);
    float3 c = float3(1.0, 1.10000002384185791015625, 1.0);
    float3 d = float3(0.263000011444091796875, 0.41600000858306884765625, 0.556999981403350830078125);
    return a + (b * cos(((c * t) + d) * 6.28318023681640625));
}

fragment vv_fmain_out fmain(constant VVUniforms& _66 [[buffer(0)]], texture2d<float> uTexture [[texture(0)]], sampler uTextureSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float2 frag = FlutterFragCoord(gl_FragCoord).xy;
    float2 uv = ((frag * 2.0) - _66.uResolution) / float2(_66.uResolution.y);
    float2 uv0 = uv;
    float3 finalColor = float3(0.0);
    float time = _66.uTime * _66.uSpeed;
    float low = 0.5 * (_66.uFreq0 + _66.uFreq1);
    float mid = ((_66.uFreq2 + _66.uFreq3) + _66.uFreq4) / 3.0;
    float high = ((_66.uFreq5 + _66.uFreq6) + _66.uFreq7) / 3.0;
    float audio = fast::clamp(((0.60000002384185791015625 * low) + (0.300000011920928955078125 * mid)) + (0.100000001490116119384765625 * high), 0.0, 1.0);
    for (float i = 0.0; i < 5.0; i += 1.0)
    {
        uv = fract(uv * (1.60000002384185791015625 + (0.100000001490116119384765625 * audio))) - float2(0.5);
        float d = length(uv);
        float param = length(uv0) + time;
        float3 col = palette(param);
        d = sin((d * 8.0) + time) / 8.0;
        d = abs(d);
        d = powr(0.00999999977648258209228515625 / fast::max(d, 9.9999997473787516355514526367188e-05), 1.7999999523162841796875);
        finalColor += (col * d);
    }
    float gy = fast::clamp(frag.y / fast::max(_66.uResolution.y, 1.0), 0.0, 1.0);
    float3 grad = mix(float3(_66.uColor), _66.uColor2, float3(gy));
    float3 effect = finalColor * mix(float3(1.0), fast::normalize(grad + float3(0.001000000047497451305389404296875)), float3(0.25));
    float3 tex = uTexture.sample(uTextureSmplr, (frag / _66.uResolution)).xyz;
    float3 finalMix = mix(tex, effect, float3(fast::clamp(_66.uIntensity, 0.0, 1.0)));
    out.fragColor = float4(finalMix, 1.0);
    return out;
}
