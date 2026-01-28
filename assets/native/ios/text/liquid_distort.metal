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

fragment vv_fmain_out fmain(constant VVUniforms& _31 [[buffer(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float2 frag = FlutterFragCoord(gl_FragCoord).xy;
    float2 res = fast::max(_31.uResolution, float2(1.0));
    float2 uv = frag / res;
    float t = _31.uTime * _31.uSpeed;
    float ang = radians(_31.uAngle);
    float2 dir = float2(cos(ang), sin(ang));
    float amp = 0.02999999932944774627685546875 * _31.uIntensity;
    float freq = 8.0 + (10.0 * _31.uThickness);
    float2 wob = float2(sin(((uv.y * freq) + t) * 1.2000000476837158203125), cos(((uv.x * freq) - t) * 0.89999997615814208984375)) * amp;
    float2 uvd = (uv + wob) + ((dir * amp) * sin((((uv.x + uv.y) * freq) * 0.5) + t));
    float3 col = mix(_31.uColorA, _31.uColorB, float3(fast::clamp(uvd.x, 0.0, 1.0)));
    out.fragColor = float4(fast::clamp(col, float3(0.0), float3(1.0)), 1.0);
    return out;
}
