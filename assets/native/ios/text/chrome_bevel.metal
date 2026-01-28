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

static inline __attribute__((always_inline))
float bevel(thread float2& p, constant VVUniforms& _60)
{
    float f = 0.0;
    float w = 20.0 + (40.0 * fast::clamp(_60.uThickness, 0.0, 5.0));
    float2 param = p;
    float param_1 = radians(_60.uAngle);
    p = rotate(param, param_1);
    f += (abs(sin(p.x * w)) * 0.60000002384185791015625);
    f += (abs(sin((p.y * w) * 0.699999988079071044921875)) * 0.4000000059604644775390625);
    return fast::clamp(f, 0.0, 1.5);
}

fragment vv_fmain_out fmain(constant VVUniforms& _60 [[buffer(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float2 frag = FlutterFragCoord(gl_FragCoord).xy;
    float2 res = fast::max(_60.uResolution, float2(1.0));
    float2 uv = frag / res;
    float2 p = uv - float2(0.5);
    float t = _60.uTime * _60.uSpeed;
    p += (float2(sin(t), cos(t)) * 0.0199999995529651641845703125);
    float2 param = p;
    float _147 = bevel(param, _60);
    float b = _147;
    float3 base = mix(_60.uColorA, _60.uColorB, float3(smoothstep(0.20000000298023223876953125, 1.0, b)));
    float spec = powr(fast::max(0.0, sin(((p.x + p.y) * 12.0) + t)), 10.0);
    float3 col = base + float3(spec * (0.20000000298023223876953125 + (0.60000002384185791015625 * _60.uIntensity)));
    out.fragColor = float4(fast::clamp(col, float3(0.0), float3(1.0)), 1.0);
    return out;
}
