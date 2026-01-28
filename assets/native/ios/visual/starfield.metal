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
float2x2 Rot(thread const float& a)
{
    float s = sin(a);
    float c = cos(a);
    return float2x2(float2(c, -s), float2(s, c));
}

static inline __attribute__((always_inline))
float Hash21(thread float2& p)
{
    p = fract(p * float2(123.339996337890625, 456.209991455078125));
    p += float2(dot(p, p + float2(45.31999969482421875)));
    return fract(p.x * p.y);
}

static inline __attribute__((always_inline))
float Star(thread float2& uv, thread const float& flare)
{
    float d = length(uv);
    float m = 0.0199999995529651641845703125 / d;
    float rays = fast::max(0.0, 1.0 - abs((uv.x * uv.y) * 1000.0));
    m += (rays * flare);
    float param = 0.78537499904632568359375;
    uv *= Rot(param);
    rays = fast::max(0.0, 1.0 - abs((uv.x * uv.y) * 1000.0));
    m += ((rays * 0.300000011920928955078125) * flare);
    m *= smoothstep(1.0, 0.20000000298023223876953125, d);
    return m;
}

static inline __attribute__((always_inline))
float3 StarLayer(thread const float2& uv, thread const float& audio)
{
    float3 col = float3(0.0);
    float2 gv = fract(uv) - float2(0.5);
    float2 id = floor(uv);
    for (int y = -1; y <= 1; y++)
    {
        for (int x = -1; x <= 1; x++)
        {
            float2 offset = float2(float(x), float(y));
            float2 param = id + offset;
            float _183 = Hash21(param);
            float n = _183;
            float size = fract(n * 345.32000732421875);
            size *= (1.0 + (audio * 0.5));
            float2 param_1 = ((gv - offset) - float2(n, fract(n * 34.0))) + float2(0.5);
            float param_2 = smoothstep(0.800000011920928955078125, 0.89999997615814208984375, size);
            float _213 = Star(param_1, param_2);
            float star = _213;
            float3 color = (sin((float3(0.20000000298023223876953125, 0.300000011920928955078125, 0.89999997615814208984375) * fract(n * 2345.199951171875)) * 123.1999969482421875) * 0.5) + float3(0.5);
            color *= float3(1.0, 0.5, 1.0 + size);
            col += (color * (star * size));
        }
    }
    return col;
}

fragment vv_fmain_out fmain(constant VVUniforms& _253 [[buffer(0)]], texture2d<float> uTexture [[texture(0)]], sampler uTextureSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float2 fragCoord = FlutterFragCoord(gl_FragCoord).xy;
    float2 uv = (fragCoord - (_253.uResolution * 0.5)) / float2(_253.uResolution.y);
    float t = (_253.uTime * fast::clamp(_253.uSpeed, 0.20000000298023223876953125, 2.0)) * 0.100000001490116119384765625;
    float lows = (_253.uFreq0 + _253.uFreq1) * 0.5;
    float mids = ((_253.uFreq2 + _253.uFreq3) + _253.uFreq4) / 3.0;
    float audio = fast::clamp((lows * 0.60000002384185791015625) + (mids * 0.4000000059604644775390625), 0.0, 1.0);
    float3 col = float3(0.0);
    for (float i = 0.0; i < 1.0; i += 0.25)
    {
        float depth = fract(i + t);
        float scale = mix(20.0, 0.5, depth);
        float fade = depth * smoothstep(1.0, 0.89999997615814208984375, depth);
        float param = audio * 0.100000001490116119384765625;
        float2 rotUv = uv * Rot(param);
        float2 param_1 = (rotUv * scale) + float2(i * 453.20001220703125);
        float param_2 = audio;
        col += (StarLayer(param_1, param_2) * fade);
    }
    float3 tint = mix(float3(_253.uColor), _253.uColor2, float3((uv.y * 0.5) + 0.5));
    tint = fast::normalize(tint + float3(0.001000000047497451305389404296875));
    col *= mix(float3(1.0), tint, float3(0.300000011920928955078125));
    col *= (1.0 + (audio * 0.5));
    float2 texUV = fragCoord / _253.uResolution;
    float3 tex = uTexture.sample(uTextureSmplr, texUV).xyz;
    float3 finalColor = mix(tex, col, float3(fast::clamp(_253.uIntensity, 0.0, 1.0)));
    out.fragColor = float4(finalColor, 1.0);
    return out;
}
