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
    float2 texel = float2(1.0) / _29.uResolution;
    float3 base = uTexture.sample(uTextureSmplr, uv).xyz;
    float3 blur = base * 0.25;
    blur += (uTexture.sample(uTextureSmplr, (uv + (texel * float2(-1.0)))).xyz * 0.0625);
    blur += (uTexture.sample(uTextureSmplr, (uv + (texel * float2(0.0, -1.0)))).xyz * 0.125);
    blur += (uTexture.sample(uTextureSmplr, (uv + (texel * float2(1.0, -1.0)))).xyz * 0.0625);
    blur += (uTexture.sample(uTextureSmplr, (uv + (texel * float2(-1.0, 0.0)))).xyz * 0.125);
    blur += (uTexture.sample(uTextureSmplr, (uv + (texel * float2(1.0, 0.0)))).xyz * 0.125);
    blur += (uTexture.sample(uTextureSmplr, (uv + (texel * float2(-1.0, 1.0)))).xyz * 0.0625);
    blur += (uTexture.sample(uTextureSmplr, (uv + (texel * float2(0.0, 1.0)))).xyz * 0.125);
    blur += (uTexture.sample(uTextureSmplr, (uv + (texel * float2(1.0)))).xyz * 0.0625);
    float3 detail = base - blur;
    float lumaDetail = dot(detail, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625));
    float mask = 1.0 - smoothstep(0.100000001490116119384765625, 0.5, abs(lumaDetail));
    float strength = _29.uIntensity * 2.0;
    float3 sharp = base + (detail * strength);
    if (_29.uIntensity > 0.5)
    {
        sharp = mix(sharp, (sharp * sharp) * (float3(3.0) - (sharp * 2.0)), float3(0.100000001490116119384765625 * _29.uIntensity));
    }
    out.fragColor = float4(fast::clamp(sharp, float3(0.0), float3(1.0)), 1.0);
    return out;
}
