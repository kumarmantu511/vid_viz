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
    float line = exp(-powr((uv.y - fract(t)) * 30.0, 2.0)) * _31.uIntensity;
    float3 base = mix(_31.uColorA, _31.uColorB, float3(uv.x));
    float3 col = base + (float3(0.100000001490116119384765625, 0.20000000298023223876953125, 0.300000011920928955078125) * line);
    col += ((float3(sin((uv.y * 200.0) + t), sin((uv.y * 160.0) + (t * 1.2000000476837158203125)), sin((uv.y * 120.0) + (t * 1.39999997615814208984375))) * 0.07999999821186065673828125) * _31.uIntensity);
    out.fragColor = float4(fast::clamp(col, float3(0.0), float3(1.0)), 1.0);
    return out;
}
