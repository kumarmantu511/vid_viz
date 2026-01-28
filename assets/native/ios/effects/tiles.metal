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

static inline __attribute__((always_inline))
float2 fmod0(thread const float2& a, thread const float2& b)
{
    float2 c = fract(abs(a / b)) * abs(b);
    return abs(c);
}

static inline __attribute__((always_inline))
void mainImage(thread float4& color, thread const float2& fragCoord, thread float3& EdgeColor, thread float& NumTiles, thread float& Threshhold, constant VVUniforms& _62, texture2d<float> uTexture, sampler uTextureSmplr)
{
    float2 uv = fragCoord / _62.uResolution;
    float size = 1.0 / NumTiles;
    float2 param = uv;
    float2 param_1 = float2(size);
    float2 Pbase = uv - fmod0(param, param_1);
    float2 PCenter = Pbase + float2(size / 2.0);
    float2 st = (uv - Pbase) / float2(size);
    float4 c1 = float4(0.0);
    float4 c2 = float4(0.0);
    float4 invOff = float4(float3(1.0) - EdgeColor, 1.0);
    if (st.x > st.y)
    {
        c1 = invOff;
    }
    float threshholdB = 1.0 - Threshhold;
    if (st.x > threshholdB)
    {
        c2 = c1;
    }
    if (st.y > threshholdB)
    {
        c2 = c1;
    }
    float4 cBottom = c2;
    c1 = float4(0.0);
    c2 = float4(0.0);
    if (st.x > st.y)
    {
        c1 = invOff;
    }
    if (st.x < Threshhold)
    {
        c2 = c1;
    }
    if (st.y < Threshhold)
    {
        c2 = c1;
    }
    float4 cTop = c2;
    float4 tileColor = uTexture.sample(uTextureSmplr, PCenter);
    color = (tileColor + cTop) - cBottom;
}

fragment vv_fmain_out fmain(constant VVUniforms& _62 [[buffer(0)]], texture2d<float> uTexture [[texture(0)]], sampler uTextureSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float3 EdgeColor = float3(0.699999988079071044921875);
    float NumTiles = 40.0;
    float Threshhold = 0.1500000059604644775390625;
    float2 fragCoord = FlutterFragCoord(gl_FragCoord).xy;
    float2 param_1 = fragCoord;
    float4 param;
    mainImage(param, param_1, EdgeColor, NumTiles, Threshhold, _62, uTexture, uTextureSmplr);
    float4 outCol = param;
    float3 base = uTexture.sample(uTextureSmplr, (fragCoord / _62.uResolution)).xyz;
    float3 finalColor = mix(base, outCol.xyz, float3(fast::clamp(_62.uIntensity, 0.0, 1.0)));
    out.fragColor = float4(finalColor, 1.0);
    return out;
}
