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
    char _m4_pad[12];
    packed_float3 uColor;
    float uBars;
    float uFreq0;
    float uFreq1;
    float uFreq2;
    float uFreq3;
    float uFreq4;
    float uFreq5;
    float uFreq6;
    float uFreq7;
    float3 uColor2;
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
float hash(thread float2& p)
{
    p = fract(p * float2(127.09999847412109375, 311.70001220703125));
    p += float2(dot(p, p + float2(34.5)));
    return fract(p.x * p.y);
}

static inline __attribute__((always_inline))
float _noise(thread const float2& p)
{
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = (f * f) * (float2(3.0) - (f * 2.0));
    float2 param = i + float2(0.0);
    float _82 = hash(param);
    float2 param_1 = i + float2(1.0, 0.0);
    float _87 = hash(param_1);
    float2 param_2 = i + float2(0.0, 1.0);
    float _95 = hash(param_2);
    float2 param_3 = i + float2(1.0);
    float _100 = hash(param_3);
    return mix(mix(_82, _87, u.x), mix(_95, _100, u.x), u.y);
}

static inline __attribute__((always_inline))
float fbm(thread float2& p)
{
    float f = 0.0;
    float w = 0.5;
    for (int i = 0; i < 4; i++)
    {
        float2 param = p;
        f += (w * _noise(param));
        p *= 2.2000000476837158203125;
        w *= 0.4799999892711639404296875;
    }
    return f;
}

fragment vv_fmain_out fmain(constant VVUniforms& _152 [[buffer(0)]], texture2d<float> uTexture [[texture(0)]], sampler uTextureSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float2 frag = FlutterFragCoord(gl_FragCoord).xy;
    float2 uv = frag / _152.uResolution;
    float2 p = (frag - (_152.uResolution * 0.5)) / float2(_152.uResolution.y);
    p.y *= (-1.0);
    float t = _152.uTime * (0.100000001490116119384765625 + (0.100000001490116119384765625 * _152.uSpeed));
    float2 sunPos = float2(0.0, 0.119999997317790985107421875);
    float3 skyNight = float3(0.0500000007450580596923828125, 0.100000001490116119384765625, 0.300000011920928955078125);
    float3 skySunset = float3(1.0, 0.4000000059604644775390625, 0.100000001490116119384765625);
    float3 skyHorizon = float3(0.800000011920928955078125, 0.20000000298023223876953125, 0.300000011920928955078125);
    float skyMix = smoothstep(-0.100000001490116119384765625, 0.60000002384185791015625, p.y);
    float3 skyCol = mix(skyHorizon, skyNight, float3(skyMix));
    float sunAtmosphere = 1.0 - length(p - sunPos);
    skyCol = mix(skyCol, skySunset, float3(smoothstep(0.5, 1.0, sunAtmosphere) * 0.800000011920928955078125));
    if (p.y > (-0.100000001490116119384765625))
    {
        float2 cloudUV = (p * float2(1.0, 3.0)) + float2(t * 0.1500000059604644775390625, 0.0);
        float2 param = cloudUV * 4.0;
        float _242 = fbm(param);
        float cl = _242;
        float cloudAlpha = smoothstep(0.4000000059604644775390625, 0.800000011920928955078125, cl) * 0.5;
        float3 cloudColor = float3(1.0, 0.800000011920928955078125, 0.800000011920928955078125);
        skyCol = mix(skyCol, cloudColor, float3(cloudAlpha));
    }
    float d = length(p - sunPos);
    float sun = smoothstep(0.0599999986588954925537109375, 0.0500000007450580596923828125, d);
    float glow = exp((-5.0) * d);
    skyCol += (float3(1.0, 0.800000011920928955078125, 0.4000000059604644775390625) * (sun + (glow * 0.60000002384185791015625)));
    float3 waterCol = float3(0.0);
    if (p.y < 0.0)
    {
        float z = 1.0 / abs(p.y);
        float2 planeUV = float2(p.x * z, z);
        float2 waveMov1 = (planeUV * 0.5) + float2(t, t * 0.800000011920928955078125);
        float2 waveMov2 = (planeUV * 0.699999988079071044921875) + float2((-t) * 0.5, t);
        float2 param_1 = waveMov1 * 4.0;
        float w1 = _noise(param_1);
        float2 param_2 = waveMov2 * 4.0;
        float w2 = _noise(param_2);
        float waves = (w1 + w2) * 0.5;
        float2 param_3 = waveMov1 * 4.099999904632568359375;
        float2 param_4 = waveMov2 * 4.099999904632568359375;
        float2 tilt = float2(_noise(param_3) - w1, _noise(param_4) - w2) * 1.5;
        float fresnel = powr(1.0 - abs(p.y), 4.0);
        float3 deepSeaBlue = float3(0.0, 0.20000000298023223876953125, 0.60000002384185791015625);
        float3 baseWaterColor = mix(float3(_152.uColor), deepSeaBlue, float3(0.60000002384185791015625));
        float3 waterBody = mix(baseWaterColor, float3(0.0, 0.4000000059604644775390625, 0.800000011920928955078125), float3(waves * 0.300000011920928955078125));
        float2 refUV = float2(p.x, -p.y) + ((tilt * 0.1500000059604644775390625) * (1.0 - abs(p.y)));
        float3 refSkyColor = mix(skyHorizon, skyNight, float3(smoothstep(0.0, 1.0, refUV.y)));
        float sunRefFactor = length(float2(p.x, p.y + (sunPos.y * 3.0)) + (tilt * 0.300000011920928955078125));
        float glitter = smoothstep(0.4000000059604644775390625, 0.0, sunRefFactor);
        glitter *= smoothstep(0.4000000059604644775390625, 1.0, waves);
        waterCol = mix(waterBody, refSkyColor, float3(fresnel * 0.5));
        waterCol += ((float3(1.0, 0.699999988079071044921875, 0.300000011920928955078125) * glitter) * 3.5);
        waterCol = mix(waterCol, skyHorizon, float3(smoothstep(-0.100000001490116119384765625, 0.0, p.y)));
    }
    else
    {
        waterCol = skyCol;
    }
    float vignette = 1.0 - (dot(uv - float2(0.5), uv - float2(0.5)) * 0.60000002384185791015625);
    waterCol *= vignette;
    waterCol = powr(waterCol, float3(0.89999997615814208984375));
    float _454;
    if (p.y < 0.0)
    {
        float2 param_5 = (uv * 15.0) + float2(t);
        _454 = _noise(param_5) * 0.00200000009499490261077880859375;
    }
    else
    {
        _454 = 0.0;
    }
    float distortion = _454;
    float4 texColor = uTexture.sample(uTextureSmplr, (uv + float2(distortion)));
    float4 sceneColor = float4(waterCol, 1.0);
    out.fragColor = mix(texColor, sceneColor, float4(fast::clamp(_152.uIntensity, 0.0, 1.0)));
    return out;
}
