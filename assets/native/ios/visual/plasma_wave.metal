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

// Implementation of the GLSL mod() function, which is slightly different than Metal fmod()
template<typename Tx, typename Ty>
inline Tx mod(Tx x, Ty y)
{
    return x - y * floor(x / y);
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
    packed_float3 uColor2;
    float uAspect;
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
float random(thread const float& t)
{
    return ((cos(t) + cos((t * 1.2999999523162841796875) + 1.2999999523162841796875)) + cos((t * 1.39999997615814208984375) + 1.39999997615814208984375)) / 3.0;
}

static inline __attribute__((always_inline))
float getPlasmaY(thread const float& x, thread const float& horizontalFade, thread const float& offset, thread const float& time, thread const float& lineAmp)
{
    float param = (x * 0.20000000298023223876953125) + time;
    return ((random(param) * horizontalFade) * lineAmp) + offset;
}

fragment vv_fmain_out fmain(constant VVUniforms& _77 [[buffer(0)]], texture2d<float> uTexture [[texture(0)]], sampler uTextureSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float2 frag = FlutterFragCoord(gl_FragCoord).xy;
    float2 res = _77.uResolution;
    float2 uv = frag / res;
    float low = 0.5 * (_77.uFreq0 + _77.uFreq1);
    float mid = ((_77.uFreq2 + _77.uFreq3) + _77.uFreq4) / 3.0;
    float high = ((_77.uFreq5 + _77.uFreq6) + _77.uFreq7) / 3.0;
    float audio = fast::clamp(((0.5 * low) + (0.300000011920928955078125 * mid)) + (0.20000000298023223876953125 * high), 0.0, 1.0);
    float t = (_77.uTime * 0.20000000298023223876953125) * _77.uSpeed;
    float2 space = (((frag - (res / float2(2.0))) / float2(res.x)) * 2.0) * 5.0;
    float horizontalFade = 1.0 - ((cos(uv.x * 6.28318023681640625) * 0.5) + 0.5);
    float verticalFade = 1.0 - ((cos(uv.y * 6.28318023681640625) * 0.5) + 0.5);
    float warpAmp = 1.0 * (0.5 + audio);
    float param = (space.x * 0.5) + (t * 0.20000000298023223876953125);
    space.y += ((random(param) * warpAmp) * (0.5 + horizontalFade));
    float param_1 = ((space.y * 0.5) + (t * 0.20000000298023223876953125)) + 2.0;
    space.x += ((random(param_1) * warpAmp) * horizontalFade);
    float4 lines = float4(0.0);
    float lineAmp = 1.0 * (0.699999988079071044921875 + (0.800000011920928955078125 * audio));
    for (int l = 0; l < 16; l++)
    {
        float normalizedLineIndex = float(l) / 16.0;
        float offsetTime = t * 1.33000004291534423828125;
        float offsetPosition = float(l) + (space.x * 0.5);
        float param_2 = offsetPosition + offsetTime;
        float rand = (random(param_2) * 0.5) + 0.5;
        float halfWidth = mix(0.0199999995529651641845703125, 0.5, rand * horizontalFade) / 2.0;
        float offsetSpread = mix(0.60000002384185791015625, 2.0, horizontalFade);
        float param_3 = offsetPosition + (offsetTime * (1.0 + normalizedLineIndex));
        float offset = random(param_3) * offsetSpread;
        float param_4 = space.x;
        float param_5 = horizontalFade;
        float param_6 = offset;
        float param_7 = t;
        float param_8 = lineAmp;
        float linePos = getPlasmaY(param_4, param_5, param_6, param_7, param_8);
        float line = (smoothstep(halfWidth, 0.0, abs(linePos - space.y)) / 2.0) + smoothstep((halfWidth * 0.1500000059604644775390625) + 0.014999999664723873138427734375, halfWidth * 0.1500000059604644775390625, abs(linePos - space.y));
        float circleX = mod(float(l) + t, 25.0) - 12.0;
        float param_9 = circleX;
        float param_10 = horizontalFade;
        float param_11 = offset;
        float param_12 = t;
        float param_13 = lineAmp;
        float2 circlePos = float2(circleX, getPlasmaY(param_9, param_10, param_11, param_12, param_13));
        float circle = smoothstep(0.02500000037252902984619140625, 0.00999999977648258209228515625, length(space - circlePos)) * 4.0;
        line += circle;
        float4 lc = float4(0.25, 0.5, 1.0, 1.0);
        float4 _364 = lc;
        float3 _366 = _364.xyz * ((0.800000011920928955078125 + (rand * 0.60000002384185791015625)) + (audio * 0.60000002384185791015625));
        lc.x = _366.x;
        lc.y = _366.y;
        lc.z = _366.z;
        lines += ((lc * line) * rand);
    }
    float4 bg = mix(float4(0.125, 0.25, 0.5, 1.0), float4(0.0500000007450580596923828125, 0.300000011920928955078125, 0.300000011920928955078125, 1.0), float4(uv.x));
    float4 _393 = bg;
    float3 _395 = _393.xyz * verticalFade;
    bg.x = _395.x;
    bg.y = _395.y;
    bg.z = _395.z;
    float3 grad = mix(float3(_77.uColor), float3(_77.uColor2), float3(uv.y));
    float4 _415 = bg;
    float3 _423 = mix(_415.xyz, fast::normalize(grad + float3(0.001000000047497451305389404296875)), float3(0.25));
    bg.x = _423.x;
    bg.y = _423.y;
    bg.z = _423.z;
    float3 col = bg.xyz + lines.xyz;
    col *= (0.89999997615814208984375 + (0.800000011920928955078125 * audio));
    float3 stage = uTexture.sample(uTextureSmplr, (frag / res)).xyz;
    float3 finalMix = mix(stage, col, float3(fast::clamp(_77.uIntensity, 0.0, 1.0)));
    out.fragColor = float4(finalMix, 1.0);
    return out;
}
