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
    float aspect = _31.uResolution.x / _31.uResolution.y;
    centered.x *= aspect;
    float r2 = dot(centered, centered);
    float distAmount = 0.20000000298023223876953125 * _31.uIntensity;
    float2 distorted = centered * (1.0 + (distAmount * r2));
    distorted.x /= aspect;
    float2 uvd = distorted + float2(0.5);
    float inBounds = ((step(0.0, uvd.x) * step(uvd.x, 1.0)) * step(0.0, uvd.y)) * step(uvd.y, 1.0);
    float scanLineIntensity = 0.1500000059604644775390625 * _31.uIntensity;
    float scan = 1.0 - (scanLineIntensity * (1.0 + cos((uvd.y * _31.uResolution.y) * 3.1415927410125732421875)));
    float mask = 1.0 - (scanLineIntensity * (1.0 + sin(((uvd.x * _31.uResolution.x) * 3.1415927410125732421875) * 0.5)));
    float distVig = dot(distorted, distorted);
    float vignette = smoothstep(0.60000002384185791015625, 0.20000000298023223876953125, (distVig * _31.uIntensity) * 1.5);
    float3 color = uTexture.sample(uTextureSmplr, uvd).xyz;
    color *= (scan * mask);
    color *= vignette;
    color *= inBounds;
    out.fragColor = float4(color, 1.0);
    return out;
}
