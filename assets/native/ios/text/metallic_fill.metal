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
float band(thread const float2& p)
{
    float f = 0.0;
    f += (cos(p.x * 20.0) * 0.60000002384185791015625);
    f += (cos(p.x * 40.0) * 0.300000011920928955078125);
    f += (cos(p.x * 80.0) * 0.100000001490116119384765625);
    return (f * 0.5) + 0.5;
}

fragment vv_fmain_out fmain(constant VVUniforms& _96 [[buffer(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float2 frag = FlutterFragCoord(gl_FragCoord).xy;
    float2 res = fast::max(_96.uResolution, float2(1.0));
    float2 uv = frag / res;
    float2 p = uv - float2(0.5);
    float ang = radians(_96.uAngle);
    float2 param = p;
    float param_1 = ang;
    p = rotate(param, param_1);
    float t = _96.uTime * _96.uSpeed;
    p.x += (0.100000001490116119384765625 * t);
    float2 param_2 = p;
    float b = band(param_2);
    float3 base = mix(_96.uColorA, _96.uColorB, float3(b));
    float spec = powr(fast::max(0.0, sin(((p.x + p.y) * 6.283100128173828125) + t)), 8.0);
    float3 col = base + float3((_96.uIntensity * 0.60000002384185791015625) * spec);
    out.fragColor = float4(fast::clamp(col, float3(0.0), float3(1.0)), 1.0);
    return out;
}
