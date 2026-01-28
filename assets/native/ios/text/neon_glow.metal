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
float2 rotate(thread const float2& p, thread const float& a)
{
    float c = cos(a);
    float s = sin(a);
    return float2x2(float2(c, -s), float2(s, c)) * p;
}

fragment vv_fmain_out fmain(constant VVUniforms& _56 [[buffer(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float2 frag = FlutterFragCoord(gl_FragCoord).xy;
    float2 res = fast::max(_56.uResolution, float2(1.0));
    float2 uv = frag / res;
    float2 p = uv - float2(0.5);
    float ang = radians(_56.uAngle);
    float2 param = p;
    float param_1 = ang;
    p = rotate(param, param_1);
    float t = _56.uTime * _56.uSpeed;
    float band = 0.5 + (0.5 * sin((p.x * (12.0 + (20.0 * _56.uThickness))) + (t * 2.0)));
    float3 base = mix(_56.uColorA, _56.uColorB, float3(band));
    float pulse = 0.699999988079071044921875 + (0.300000011920928955078125 * sin(t * 3.0));
    float glow = smoothstep(0.20000000298023223876953125, 1.0, band) * (0.60000002384185791015625 + (0.4000000059604644775390625 * sin(t + (p.y * 8.0))));
    float3 col = ((base * (1.0 + (_56.uIntensity * 0.800000011920928955078125))) * mix(1.0, 1.2999999523162841796875, glow)) * pulse;
    out.fragColor = float4(fast::min(col, float3(1.0)), 1.0);
    return out;
}
