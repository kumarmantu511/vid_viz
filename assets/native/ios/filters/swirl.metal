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
    float uIntensity;
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

fragment vv_fmain_out fmain(constant VVUniforms& _29 [[buffer(0)]], texture2d<float> uTexture [[texture(0)]], sampler uTextureSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float2 uv = FlutterFragCoord(gl_FragCoord).xy / _29.uResolution;
    if (_29.uIntensity < 0.00999999977648258209228515625)
    {
        out.fragColor = float4(uTexture.sample(uTextureSmplr, uv).xyz, 1.0);
        return out;
    }
    float2 p = uv - float2(0.5);
    float aspect = _29.uResolution.x / _29.uResolution.y;
    p.x *= aspect;
    float r = length(p);
    float maxAngle = 4.7123851776123046875 * _29.uIntensity;
    float strength = 1.0 - smoothstep(0.0, 1.0, r * 2.0);
    float angle = strength * maxAngle;
    float s = sin(angle);
    float c = cos(angle);
    float2 pr = float2((p.x * c) - (p.y * s), (p.x * s) + (p.y * c));
    pr.x /= aspect;
    float2 finalUV = pr + float2(0.5);
    bool _138 = finalUV.x >= 0.0;
    bool _144;
    if (_138)
    {
        _144 = finalUV.x <= 1.0;
    }
    else
    {
        _144 = _138;
    }
    bool _150;
    if (_144)
    {
        _150 = finalUV.y >= 0.0;
    }
    else
    {
        _150 = _144;
    }
    bool _156;
    if (_150)
    {
        _156 = finalUV.y <= 1.0;
    }
    else
    {
        _156 = _150;
    }
    bool inBounds = _156;
    float3 color;
    if (inBounds)
    {
        color = uTexture.sample(uTextureSmplr, finalUV).xyz;
    }
    else
    {
        color = float3(0.0);
    }
    out.fragColor = float4(color, 1.0);
    return out;
}
