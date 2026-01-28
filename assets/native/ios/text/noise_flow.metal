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
    p = fract(p * float2(123.339996337890625, 345.45001220703125));
    p += float2(dot(p, p + float2(34.450000762939453125)));
    return fract(p.x * p.y);
}

static inline __attribute__((always_inline))
float _noise(thread const float2& p)
{
    float2 i = floor(p);
    float2 f = fract(p);
    float2 param = i;
    float _67 = hash(param);
    float a = _67;
    float2 param_1 = i + float2(1.0, 0.0);
    float _73 = hash(param_1);
    float b = _73;
    float2 param_2 = i + float2(0.0, 1.0);
    float _79 = hash(param_2);
    float c = _79;
    float2 param_3 = i + float2(1.0);
    float _85 = hash(param_3);
    float d = _85;
    float2 u = (f * f) * (float2(3.0) - (f * 2.0));
    return (mix(a, b, u.x) + (((c - a) * u.y) * (1.0 - u.x))) + (((d - b) * u.x) * u.y);
}

fragment vv_fmain_out fmain(constant VVUniforms& _132 [[buffer(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float2 frag = FlutterFragCoord(gl_FragCoord).xy;
    float2 res = fast::max(_132.uResolution, float2(1.0));
    float2 uv = frag / res;
    float t = _132.uTime * _132.uSpeed;
    float ang = radians(_132.uAngle);
    float2 dir = float2(cos(ang), sin(ang));
    float2 param = (uv * float2(6.0 + (8.0 * _132.uThickness))) + (dir * t);
    float n = _noise(param);
    float3 base = mix(_132.uColorA, _132.uColorB, float3(uv.x));
    float3 col = mix(base, base * 1.39999997615814208984375, float3(n * _132.uIntensity));
    out.fragColor = float4(fast::clamp(col, float3(0.0), float3(1.0)), 1.0);
    return out;
}
