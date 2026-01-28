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
    float uDropSize;
    float uDensity;
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
float3 N13(thread const float& p)
{
    float3 p3 = fract(float3(p) * float3(0.103100001811981201171875, 0.113689996302127838134765625, 0.13786999881267547607421875));
    p3 += float3(dot(p3, p3.yzx + float3(19.1900005340576171875)));
    return fract(float3((p3.x + p3.y) * p3.z, (p3.x + p3.z) * p3.y, (p3.y + p3.z) * p3.x));
}

static inline __attribute__((always_inline))
float StaticDrops(thread float2& uv, thread const float& t, thread const float& dSize)
{
    uv *= 30.0;
    float2 gridUV = uv + float2(1000.0);
    float2 id = floor(gridUV);
    uv = fract(gridUV) - float2(0.5);
    float param = (id.x * 107.4499969482421875) + (id.y * 3543.654052734375);
    float3 n = N13(param);
    float2 p = (n.xy - float2(0.5)) * 0.5;
    float d = length(uv - p);
    float fade = smoothstep(0.0, 0.02500000037252902984619140625, fract(t + n.z)) * smoothstep(1.0, 0.02500000037252902984619140625, fract(t + n.z));
    return (smoothstep(dSize * 0.20000000298023223876953125, 0.0, d) * fract(n.z * 10.0)) * fade;
}

static inline __attribute__((always_inline))
float N(thread const float& t)
{
    return fract(sin(t * 12345.564453125) * 7658.759765625);
}

static inline __attribute__((always_inline))
float2 Drops(thread float2& uv, thread const float& t, thread const float& dSize, thread const float& density)
{
    float2 UV = uv;
    uv.y = -uv.y;
    uv.y += (t * 0.800000011920928955078125);
    float2 a = float2(6.0, 1.0);
    float2 grid = a * 2.0;
    float2 gridUV = uv + float2(1000.0);
    float2 id = floor(gridUV * grid);
    float param = (id.x * 35.200000762939453125) + (id.y * 2376.10009765625);
    float randomID = N(param);
    float param_1 = (id.x * 35.200000762939453125) + (id.y * 2376.10009765625);
    float3 n = N13(param_1);
    if (n.x > density)
    {
        return float2(0.0);
    }
    float param_2 = id.x;
    float colShift = N(param_2);
    uv.y += colShift;
    float2 st = fract(gridUV * grid) - float2(0.5, 0.0);
    float x = n.x - 0.5;
    float y = UV.y * 20.0;
    float distort = sin(y + sin(y));
    x += ((distort * (0.5 - abs(x))) * (n.z - 0.5));
    x *= 0.699999988079071044921875;
    x = fast::clamp(x, -0.3499999940395355224609375, 0.3499999940395355224609375);
    float ti = fract(t + n.z);
    y = (((smoothstep(0.0, 0.85000002384185791015625, ti) * smoothstep(1.0, 0.85000002384185791015625, ti)) - 0.5) * 0.89999997615814208984375) + 0.5;
    float2 p = float2(x, y);
    float d = length((st - p) * a.yx);
    float currentDropSize = 0.20000000298023223876953125 * dSize;
    float Drop = smoothstep(currentDropSize, 0.0, d);
    float r = sqrt(smoothstep(1.0, y, st.y));
    float cd = abs(st.x - x);
    float trail = smoothstep(((currentDropSize * 0.5) + 0.02999999932944774627685546875) * r, ((currentDropSize * 0.5) - 0.0500000007450580596923828125) * r, cd);
    float trailFront = smoothstep(-0.0199999995529651641845703125, 0.0199999995529651641845703125, st.y - y);
    trail *= trailFront;
    y = UV.y;
    float param_3 = id.x;
    y += N(param_3);
    float trail2 = smoothstep(currentDropSize * r, 0.0, cd);
    float droplets = ((fast::max(0.0, sin((y * (1.0 - y)) * 120.0) - st.y) * trail2) * trailFront) * n.z;
    y = fract(y * 10.0) + (st.y - 0.5);
    float dd = length(st - float2(x, y));
    float param_4 = id.x;
    droplets = smoothstep(currentDropSize * N(param_4), 0.0, dd);
    float m = Drop + ((droplets * r) * trailFront);
    float borderMask = smoothstep(0.5, 0.3499999940395355224609375, abs(st.x));
    return float2(m * borderMask, trail * borderMask);
}

static inline __attribute__((always_inline))
float2 Rain(thread const float2& uv, thread const float& t, thread const float& dSize, thread const float& density)
{
    float2 param = uv;
    float param_1 = t;
    float param_2 = dSize;
    float _449 = StaticDrops(param, param_1, param_2);
    float s = _449;
    float2 param_3 = uv;
    float param_4 = t;
    float param_5 = dSize;
    float param_6 = density;
    float2 _459 = Drops(param_3, param_4, param_5, param_6);
    float2 r1 = _459;
    float2 param_7 = uv * 1.7999999523162841796875;
    float param_8 = t;
    float param_9 = dSize;
    float param_10 = density;
    float2 _471 = Drops(param_7, param_8, param_9, param_10);
    float2 r2 = _471;
    float c = (s + r1.x) + r2.x;
    c = smoothstep(0.300000011920928955078125, 1.0, c);
    return float2(c, fast::max(r1.y, r2.y));
}

fragment vv_fmain_out fmain(constant VVUniforms& _499 [[buffer(0)]], texture2d<float> uTexture [[texture(0)]], sampler uTextureSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float2 fragCoord = FlutterFragCoord(gl_FragCoord).xy;
    float2 uv = (fragCoord - (_499.uResolution * 0.5)) / float2(_499.uResolution.y);
    float2 UV = fragCoord / _499.uResolution;
    float4 baseColor = uTexture.sample(uTextureSmplr, UV);
    if (baseColor.w < 0.00999999977648258209228515625)
    {
        out.fragColor = float4(0.0);
        return out;
    }
    float T = _499.uTime * fast::clamp(_499.uSpeed, 0.20000000298023223876953125, 3.0);
    float t = T * 0.20000000298023223876953125;
    float dSize = fast::clamp(_499.uDropSize, 0.5, 2.0);
    float density = fast::clamp(_499.uDensity, 0.100000001490116119384765625, 1.0);
    UV = ((UV - float2(0.5)) * 0.980000019073486328125) + float2(0.5);
    float2 param = uv;
    float param_1 = t;
    float param_2 = dSize;
    float param_3 = density;
    float2 c = Rain(param, param_1, param_2, param_3);
    float2 e = float2(0.001000000047497451305389404296875, 0.0);
    float2 param_4 = uv + e;
    float param_5 = t;
    float param_6 = dSize;
    float param_7 = density;
    float cx = Rain(param_4, param_5, param_6, param_7).x;
    float2 param_8 = uv + e.yx;
    float param_9 = t;
    float param_10 = dSize;
    float param_11 = density;
    float cy = Rain(param_8, param_9, param_10, param_11).x;
    float2 n = float2(cx - c.x, cy - c.x);
    float3 blurredColor = float3(0.0);
    float blurSteps = 1.0;
    float blurRadius = 0.0040000001899898052215576171875;
    for (float i = -1.0; i <= 1.0; i += 1.0)
    {
        for (float j = -1.0; j <= 1.0; j += 1.0)
        {
            float2 offset = float2(i, j) * blurRadius;
            blurredColor += uTexture.sample(uTextureSmplr, (UV + offset)).xyz;
        }
    }
    blurredColor /= float3(9.0);
    float3 foggyBg = mix(blurredColor, float3(0.89999997615814208984375, 0.949999988079071044921875, 1.0), float3(0.25));
    float3 clearDrop = uTexture.sample(uTextureSmplr, (UV + n)).xyz;
    float trail = fast::clamp(c.y, 0.0, 1.0);
    float mask = fast::clamp(c.x + (trail * 0.699999988079071044921875), 0.0, 1.0);
    float3 finalRGB = mix(foggyBg, clearDrop, float3(mask));
    finalRGB += float3(trail * 0.1500000059604644775390625);
    finalRGB = mix(baseColor.xyz, finalRGB, float3(fast::clamp(_499.uIntensity, 0.0, 1.0)));
    out.fragColor = float4(finalRGB, baseColor.w);
    return out;
}
