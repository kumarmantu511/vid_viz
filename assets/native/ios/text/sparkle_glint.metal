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

// Implementation of the GLSL radians() function
template<typename T>
inline T radians(T d)
{
    return d * T(0.01745329251);
}

struct VVUniforms
{
    float2 uResolution;
    float uTime;
    float uIntensity;
    float uSpeed;
    float uAngle;
    float uThickness;
    float3 uColorA;
    float3 uColorB;
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
    p = fract(p * float2(23.340000152587890625, 45.450000762939453125));
    p += float2(dot(p, p + float2(34.450000762939453125)));
    return fract(p.x * p.y);
}

fragment vv_fmain_out fmain(constant VVUniforms& _62 [[buffer(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float2 frag = FlutterFragCoord(gl_FragCoord).xy;
    float2 res = fast::max(_62.uResolution, float2(1.0));
    float2 uv = frag / res;
    float t = _62.uTime * _62.uSpeed;
    float ang = radians(_62.uAngle);
    float2 dir = float2(cos(ang), sin(ang));
    float3 base = mix(_62.uColorA, _62.uColorB, float3(uv.x));
    float line = smoothstep(0.0, 1.0, 1.0 - (abs(dot(uv - float2(0.5), dir) - fract(t)) * (20.0 + (40.0 * _62.uThickness))));
    float spark = 0.0;
    for (int k = 0; k < 3; k++)
    {
        float2 cell = floor((uv + float2(float(k) * 0.12999999523162841796875)) * (6.0 + (10.0 * _62.uThickness)));
        float2 param = cell + float2(floor(t));
        float _162 = hash(param);
        float h = _162;
        float2 p = fract(uv * (6.0 + (10.0 * _62.uThickness)));
        float d = length(p - float2(h, fract(h * 7.0)));
        spark += (smoothstep(0.20000000298023223876953125, 0.0, d) * 0.300000011920928955078125);
    }
    float m = fast::clamp((line * _62.uIntensity) + (spark * _62.uIntensity), 0.0, 1.0);
    float3 col = base + float3(m);
    out.fragColor = float4(fast::clamp(col, float3(0.0), float3(1.0)), 1.0);
    return out;
}
