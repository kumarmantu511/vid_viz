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
    float ramp = fast::clamp((0.5 + (0.5 * dot(uv - float2(0.5), dir))) + ((0.20000000298023223876953125 * sin(((uv.x + uv.y) * 6.28299999237060546875) + t)) * _31.uIntensity), 0.0, 1.0);
    float3 col = mix(_31.uColorA, _31.uColorB, float3(ramp));
    out.fragColor = float4(col, 1.0);
    return out;
}
