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

// Implementation of the GLSL mod() function, which is slightly different than Metal fmod()
template<typename Tx, typename Ty>
inline Tx mod(Tx x, Ty y)
{
    return x - y * floor(x / y);
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
    packed_float3 uColor2;
    float uAspect;
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
float2x2 rot(thread const float& a)
{
    float c = cos(a);
    float s = sin(a);
    return float2x2(float2(c, s), float2(-s, c));
}

static inline __attribute__((always_inline))
float2 moda(thread const float2& p, thread const float& per)
{
    float angle = precise::atan2(p.y, p.x);
    float l = length(p);
    angle = mod(angle - (per / 2.0), per) - (per / 2.0);
    return float2(cos(angle), sin(angle)) * l;
}

static inline __attribute__((always_inline))
float cylZ(thread const float3& p, thread const float& r)
{
    return length(p.xy) - r;
}

static inline __attribute__((always_inline))
float mapScene(thread float3& p)
{
    float param = -p.z;
    float3 _128 = p;
    float2 _130 = _128.xy * rot(param);
    p.x = _130.x;
    p.y = _130.y;
    float2 param_1 = p.xy;
    float param_2 = 1.2566368579864501953125;
    float2 _140 = moda(param_1, param_2);
    p.x = _140.x;
    p.y = _140.y;
    p.x -= 0.5;
    float3 param_3 = p;
    float param_4 = 0.300000011920928955078125;
    return cylZ(param_3, param_4);
}

static inline __attribute__((always_inline))
float3 palette(thread const float& t, thread const float3& a, thread const float3& b, thread const float3& c, thread const float3& d)
{
    return a + (b * cos(((c * t) + d) * 6.28318023681640625));
}

fragment vv_fmain_out fmain(constant VVUniforms& _163 [[buffer(0)]], texture2d<float> uTexture [[texture(0)]], sampler uTextureSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float2 frag = FlutterFragCoord(gl_FragCoord).xy;
    float2 res = _163.uResolution;
    float2 uv = ((frag / res) * 2.0) - float2(1.0);
    uv.x *= (res.x / fast::max(res.y, 1.0));
    float mid = (((_163.uFreq2 + _163.uFreq3) + _163.uFreq4) + _163.uFreq5) * 0.25;
    float bass = (_163.uFreq0 + _163.uFreq1) * 0.5;
    float time = _163.uTime * _163.uSpeed;
    float shad = 1.0;
    float3 p = float3(0.001000000047497451305389404296875, 0.001000000047497451305389404296875, (-time) * (0.300000011920928955078125 + (0.4000000059604644775390625 * mid)));
    float3 dir = fast::normalize(float3(uv, 1.0));
    for (int i = 0; i < 60; i++)
    {
        float3 param = p;
        float _253 = mapScene(param);
        float d = _253;
        if (d < 0.001000000047497451305389404296875)
        {
            shad = float(i) / 60.0;
            break;
        }
        p += (dir * d);
    }
    float param_1 = p.z;
    float3 param_2 = float3(0.0, 0.5, 0.5);
    float3 param_3 = float3(0.5);
    float3 param_4 = float3(5.0);
    float3 param_5 = float3(0.0, 0.100000001490116119384765625, time * (0.20000000298023223876953125 + (0.4000000059604644775390625 * bass)));
    float3 pal = palette(param_1, param_2, param_3, param_4, param_5);
    float3 col = (pal * (1.0 - shad)) * 2.0;
    float audio = fast::clamp((0.60000002384185791015625 * bass) + (0.4000000059604644775390625 * mid), 0.0, 1.0);
    col *= (0.89999997615814208984375 + (1.39999997615814208984375 * audio));
    float2 uvStage = frag / res;
    float3 stage = uTexture.sample(uTextureSmplr, uvStage).xyz;
    float3 finalMix = mix(stage, col, float3(fast::clamp(_163.uIntensity, 0.0, 1.0)));
    out.fragColor = float4(finalMix, 1.0);
    return out;
}
