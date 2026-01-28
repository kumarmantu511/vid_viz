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

fragment vv_fmain_out fmain(constant VVUniforms& _31 [[buffer(0)]], texture2d<float> uTexture [[texture(0)]], sampler uTextureSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float2 fragCoord = FlutterFragCoord(gl_FragCoord).xy;
    float2 normUV = fragCoord / _31.uResolution;
    if (_31.uIntensity < 0.001000000047497451305389404296875)
    {
        out.fragColor = float4(uTexture.sample(uTextureSmplr, normUV).xyz, 1.0);
        return out;
    }
    float2 uv = normUV - float2(0.5);
    float aspect = _31.uResolution.x / _31.uResolution.y;
    uv.x *= aspect;
    float t = _31.uTime * 1.2000000476837158203125;
    float pulse = 0.100000001490116119384765625 + (0.100000001490116119384765625 * cos(t));
    float fishyness = (0.4000000059604644775390625 + pulse) * _31.uIntensity;
    float2 fishuv;
    fishuv.x = ((1.0 - (uv.y * uv.y)) * fishyness) * uv.x;
    fishuv.y = ((1.0 - (uv.x * uv.x)) * fishyness) * uv.y;
    float2 pos = uv;
    float2 uvR = pos - (fishuv * 0.920000016689300537109375);
    uvR.x /= aspect;
    uvR += float2(0.5);
    float2 uvGB = pos - fishuv;
    uvGB.x /= aspect;
    uvGB += float2(0.5);
    float cr = uTexture.sample(uTextureSmplr, uvR).x;
    float2 cgb = uTexture.sample(uTextureSmplr, uvGB).yz;
    float3 color = float3(cr, cgb);
    float uvMagSqrd = dot(uv, uv);
    float vignette = 1.0 - ((uvMagSqrd * fishyness) * 2.0);
    color *= fast::clamp(vignette, 0.0, 1.0);
    bool _189 = uvGB.x < 0.0;
    bool _196;
    if (!_189)
    {
        _196 = uvGB.x > 1.0;
    }
    else
    {
        _196 = _189;
    }
    bool _203;
    if (!_196)
    {
        _203 = uvGB.y < 0.0;
    }
    else
    {
        _203 = _196;
    }
    bool _210;
    if (!_203)
    {
        _210 = uvGB.y > 1.0;
    }
    else
    {
        _210 = _203;
    }
    if (_210)
    {
        color = float3(0.0);
    }
    out.fragColor = float4(color, 1.0);
    return out;
}
