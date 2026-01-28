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

static inline __attribute__((always_inline))
float hash(thread const float& n)
{
    return fract(sin(n) * 43758.546875);
}

fragment vv_fmain_out fmain(constant VVUniforms& _43 [[buffer(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float2 frag = FlutterFragCoord(gl_FragCoord).xy;
    float2 res = fast::max(_43.uResolution, float2(1.0));
    float2 uv = frag / res;
    float t = _43.uTime * _43.uSpeed;
    float bands = 120.0 * (1.0 + _43.uThickness);
    float row = floor(uv.y * bands);
    float param = row + floor(t * 10.0);
    float jitter = ((hash(param) - 0.5) * 0.100000001490116119384765625) * _43.uIntensity;
    float offset = jitter;
    float param_1 = row * 13.30000019073486328125;
    float phase = (hash(param_1) * 6.283100128173828125) + t;
    float mixv = 0.5 + (0.5 * sin(((uv.x + offset) * 12.0) + phase));
    float3 base = mix(_43.uColorA, _43.uColorB, float3(mixv));
    float param_2 = row + floor(t * 7.0);
    float flick = step(0.980000019073486328125, hash(param_2));
    base = mix(base, float3(1.0), float3((flick * 0.20000000298023223876953125) * _43.uIntensity));
    out.fragColor = float4(base, 1.0);
    return out;
}
