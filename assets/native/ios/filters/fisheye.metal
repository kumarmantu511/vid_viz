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
    if (_31.uIntensity < 0.001000000047497451305389404296875)
    {
        out.fragColor = float4(uTexture.sample(uTextureSmplr, uv).xyz, 1.0);
        return out;
    }
    float2 p = uv - float2(0.5);
    float aspect = _31.uResolution.x / _31.uResolution.y;
    p.x *= aspect;
    float r2 = dot(p, p);
    float k = 1.0 * _31.uIntensity;
    float2 pd = p * (1.0 + (k * r2));
    pd.x /= aspect;
    float2 uvd = pd + float2(0.5);
    bool _111 = uvd.x >= 0.0;
    bool _117;
    if (_111)
    {
        _117 = uvd.x <= 1.0;
    }
    else
    {
        _117 = _111;
    }
    bool _123;
    if (_117)
    {
        _123 = uvd.y >= 0.0;
    }
    else
    {
        _123 = _117;
    }
    bool _129;
    if (_123)
    {
        _129 = uvd.y <= 1.0;
    }
    else
    {
        _129 = _123;
    }
    bool inBounds = _129;
    float3 color;
    if (inBounds)
    {
        color = uTexture.sample(uTextureSmplr, uvd).xyz;
    }
    else
    {
        color = float3(0.0);
    }
    out.fragColor = float4(color, 1.0);
    return out;
}
