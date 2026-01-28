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
    float uFlakeSize;
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
float hash21(thread float2& p)
{
    p = fract(p * float2(123.339996337890625, 456.209991455078125));
    p += float2(dot(p, p + float2(45.31999969482421875)));
    return fract(p.x * p.y);
}

static inline __attribute__((always_inline))
float SnowLayer(thread const float2& uv, thread const float& depth, constant VVUniforms& _63)
{
    float t = _63.uTime * _63.uSpeed;
    float scale = (4.0 + (depth * 5.0)) / fast::clamp(_63.uFlakeSize, 0.5, 2.0);
    float2 gridUV = uv * scale;
    float2 id = floor(gridUV);
    float2 st = fract(gridUV) - float2(0.5);
    float layerSnow = 0.0;
    for (int y = -1; y <= 1; y++)
    {
        for (int x = -1; x <= 1; x++)
        {
            float2 offset = float2(float(x), float(y));
            float2 neighborID = id + offset;
            float2 param = neighborID;
            float _131 = hash21(param);
            float n = _131;
            if (n > _63.uDensity)
            {
                continue;
            }
            float fallSpeed = 0.800000011920928955078125 + (n * 0.4000000059604644775390625);
            float yPos = ((-t) * fallSpeed) * (0.5 + (1.5 / (depth + 1.0)));
            float wiggle = sin((t * 1.5) + (n * 10.0)) * 0.20000000298023223876953125;
            wiggle += (cos((t * 4.0) + (n * 30.0)) * 0.0500000007450580596923828125);
            float2 p = offset + (float2(sin(n * 90.0), cos(n * 50.0)) * 0.4000000059604644775390625);
            p.y -= ((fract(yPos + (n * 10.0)) * 2.5) - 1.25);
            p.x += wiggle;
            float d = length(st - p);
            float sizeBase = (0.100000001490116119384765625 + (n * 0.20000000298023223876953125)) * (1.5 / ((depth * 0.800000011920928955078125) + 1.0));
            float sparkle = 0.800000011920928955078125 + (0.4000000059604644775390625 * sin((t * 10.0) + (n * 100.0)));
            float mask = smoothstep(sizeBase, 0.0, d);
            mask = powr(mask, 3.0);
            layerSnow += (mask * sparkle);
        }
    }
    return layerSnow;
}

fragment vv_fmain_out fmain(constant VVUniforms& _63 [[buffer(0)]], texture2d<float> uTexture [[texture(0)]], sampler uTextureSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float2 fragCoord = FlutterFragCoord(gl_FragCoord).xy;
    float2 uv = fragCoord / _63.uResolution;
    float2 adjUV = uv;
    adjUV.x *= (_63.uResolution.x / _63.uResolution.y);
    float4 baseColor = uTexture.sample(uTextureSmplr, uv);
    float snowAcc = 0.0;
    float2 param = adjUV;
    float param_1 = 5.0;
    snowAcc += (SnowLayer(param, param_1, _63) * 0.4000000059604644775390625);
    float2 param_2 = adjUV + float2(1.2000000476837158203125, 3.400000095367431640625);
    float param_3 = 2.5;
    snowAcc += (SnowLayer(param_2, param_3, _63) * 0.699999988079071044921875);
    float2 param_4 = adjUV - float2(2.099999904632568359375, 1.2000000476837158203125);
    float param_5 = 0.800000011920928955078125;
    snowAcc += SnowLayer(param_4, param_5, _63);
    snowAcc = fast::clamp(snowAcc, 0.0, 1.0);
    float3 snowColor = float3(0.949999988079071044921875, 0.980000019073486328125, 1.0);
    float3 finalRGB = mix(baseColor.xyz, snowColor, float3(snowAcc * _63.uIntensity));
    finalRGB = mix(finalRGB, finalRGB * float3(0.949999988079071044921875, 0.949999988079071044921875, 1.0499999523162841796875), float3(snowAcc * 0.20000000298023223876953125));
    out.fragColor = float4(finalRGB, baseColor.w);
    return out;
}
