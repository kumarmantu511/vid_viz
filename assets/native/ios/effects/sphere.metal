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
    float2 uv = fragCoord / _31.uResolution;
    if (_31.uIntensity < 0.00999999977648258209228515625)
    {
        out.fragColor = float4(uTexture.sample(uTextureSmplr, uv).xyz, 1.0);
        return out;
    }
    float2 centered = uv - float2(0.5);
    float distSq = dot(centered, centered);
    float2 warp = centered * (1.0 + ((0.4000000059604644775390625 * distSq) * _31.uIntensity));
    float2 warpedUV = warp + float2(0.5);
    float2 bounds = step(float2(0.0), warpedUV) * step(warpedUV, float2(1.0));
    float mask = bounds.x * bounds.y;
    float scanParams = (warpedUV.y * _31.uResolution.y) * 0.5;
    float scanline = sin((scanParams * 3.1415927410125732421875) * 2.0);
    float scanMask = 1.0 - ((((0.5 * scanline) + 0.5) * 0.100000001490116119384765625) * _31.uIntensity);
    float vig = (((16.0 * warpedUV.x) * warpedUV.y) * (1.0 - warpedUV.x)) * (1.0 - warpedUV.y);
    vig = powr(vig, 0.1500000059604644775390625);
    float3 color = float3(0.0);
    if (mask > 0.0)
    {
        color = uTexture.sample(uTextureSmplr, warpedUV).xyz;
        color *= scanMask;
        color *= vig;
    }
    out.fragColor = float4(color * mask, 1.0);
    return out;
}
