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
float aurora(thread const float2& uv, thread const float& time)
{
    float2 p = uv * 2.0;
    float color = 0.0;
    for (float i = 1.0; i < 4.0; i += 1.0)
    {
        p.x += (sin(p.y + (time * 0.5)) * 0.5);
        float w = abs(1.0 / (sin(p.x + (time * 0.20000000298023223876953125)) + (2.0 * i)));
        color += w;
    }
    return color * 0.20000000298023223876953125;
}

static inline __attribute__((always_inline))
float hash(thread const float2& p)
{
    return fract(sin(dot(p, float2(12.98980045318603515625, 78.233001708984375))) * 43758.546875);
}

static inline __attribute__((always_inline))
float2x2 rot(thread const float& a)
{
    float s = sin(a);
    float c = cos(a);
    return float2x2(float2(c, -s), float2(s, c));
}

static inline __attribute__((always_inline))
float sdRoundedBox(thread const float2& p, thread const float2& b, thread const float& r)
{
    float2 q = (abs(p) - b) + float2(r);
    return (length(fast::max(q, float2(0.0))) + fast::min(fast::max(q.x, q.y), 0.0)) - r;
}

static inline __attribute__((always_inline))
float sdSegment(thread const float2& p, thread const float2& a, thread const float2& b)
{
    float2 pa = p - a;
    float2 ba = b - a;
    float h = fast::clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - (ba * h));
}

static inline __attribute__((always_inline))
float charV(thread const float2& p)
{
    float2 param = p;
    float2 param_1 = float2(-0.070000000298023223876953125, 0.100000001490116119384765625);
    float2 param_2 = float2(0.0, -0.100000001490116119384765625);
    float2 param_3 = p;
    float2 param_4 = float2(0.0, -0.100000001490116119384765625);
    float2 param_5 = float2(0.070000000298023223876953125, 0.100000001490116119384765625);
    return fast::min(sdSegment(param, param_1, param_2), sdSegment(param_3, param_4, param_5));
}

static inline __attribute__((always_inline))
float charI(thread const float2& p)
{
    float2 param = p;
    float2 param_1 = float2(0.0, 0.100000001490116119384765625);
    float2 param_2 = float2(0.0, -0.100000001490116119384765625);
    return sdSegment(param, param_1, param_2);
}

static inline __attribute__((always_inline))
float charD(thread const float2& p)
{
    float2 param = p;
    float2 param_1 = float2(-0.0599999986588954925537109375, 0.100000001490116119384765625);
    float2 param_2 = float2(-0.0599999986588954925537109375, -0.100000001490116119384765625);
    float d = sdSegment(param, param_1, param_2);
    float2 param_3 = p;
    float2 param_4 = float2(-0.0599999986588954925537109375, 0.100000001490116119384765625);
    float2 param_5 = float2(0.0199999995529651641845703125, 0.070000000298023223876953125);
    d = fast::min(d, sdSegment(param_3, param_4, param_5));
    float2 param_6 = p;
    float2 param_7 = float2(0.0199999995529651641845703125, 0.070000000298023223876953125);
    float2 param_8 = float2(0.0199999995529651641845703125, -0.070000000298023223876953125);
    d = fast::min(d, sdSegment(param_6, param_7, param_8));
    float2 param_9 = p;
    float2 param_10 = float2(0.0199999995529651641845703125, -0.070000000298023223876953125);
    float2 param_11 = float2(-0.0599999986588954925537109375, -0.100000001490116119384765625);
    d = fast::min(d, sdSegment(param_9, param_10, param_11));
    return d;
}

static inline __attribute__((always_inline))
float charZ(thread const float2& p)
{
    float2 param = p;
    float2 param_1 = float2(-0.0599999986588954925537109375, 0.100000001490116119384765625);
    float2 param_2 = float2(0.0599999986588954925537109375, 0.100000001490116119384765625);
    float d = sdSegment(param, param_1, param_2);
    float2 param_3 = p;
    float2 param_4 = float2(0.0599999986588954925537109375, 0.100000001490116119384765625);
    float2 param_5 = float2(-0.0599999986588954925537109375, -0.100000001490116119384765625);
    d = fast::min(d, sdSegment(param_3, param_4, param_5));
    float2 param_6 = p;
    float2 param_7 = float2(-0.0599999986588954925537109375, -0.100000001490116119384765625);
    float2 param_8 = float2(0.0599999986588954925537109375, -0.100000001490116119384765625);
    d = fast::min(d, sdSegment(param_6, param_7, param_8));
    return d;
}

static inline __attribute__((always_inline))
float getText(thread float2& p)
{
    float d = 100.0;
    p.y += 0.64999997615814208984375;
    p.x += 0.5;
    float spacing = 0.20000000298023223876953125;
    float2 param = p;
    d = fast::min(d, charV(param));
    p.x -= spacing;
    float2 param_1 = p;
    d = fast::min(d, charI(param_1));
    p.x -= spacing;
    float2 param_2 = p;
    d = fast::min(d, charD(param_2));
    p.x -= spacing;
    float2 param_3 = p;
    d = fast::min(d, charV(param_3));
    p.x -= spacing;
    float2 param_4 = p;
    d = fast::min(d, charI(param_4));
    p.x -= spacing;
    float2 param_5 = p;
    d = fast::min(d, charZ(param_5));
    return d;
}

fragment vv_fmain_out fmain(constant VVUniforms& _358 [[buffer(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float2 uv = (FlutterFragCoord(gl_FragCoord).xy - (_358.uResolution * 0.5)) / float2(_358.uResolution.y);
    uv.y *= (-1.0);
    uv *= 3.0;
    float2 bgUV = uv;
    float3 bgCol = float3(0.00999999977648258209228515625, 0.0, 0.0500000007450580596923828125);
    float2 param = bgUV + float2(0.0, _358.uTime * 0.100000001490116119384765625);
    float param_1 = _358.uTime;
    float aur = aurora(param, param_1);
    bgCol += (float3(0.20000000298023223876953125, 0.0, 0.800000011920928955078125) * aur);
    bgCol += ((float3(0.0, 0.5, 1.0) * aur) * 0.5);
    float particles = 0.0;
    for (float i = 0.0; i < 5.0; i += 1.0)
    {
        float size = 4.0 + (i * 2.0);
        float2 pPos = bgUV;
        pPos.y += (_358.uTime * (0.0500000007450580596923828125 + (i * 0.0199999995529651641845703125)));
        pPos.x += (sin((_358.uTime * 0.20000000298023223876953125) + i) * 0.20000000298023223876953125);
        float2 id = floor(pPos * size);
        float2 gv = fract(pPos * size) - float2(0.5);
        float2 param_2 = id;
        float n = hash(param_2);
        if (n > 0.89999997615814208984375)
        {
            float dP = length(gv);
            float spark = 0.0199999995529651641845703125 / (dP + 0.001000000047497451305389404296875);
            spark *= (0.5 + (0.5 * sin((_358.uTime * 4.0) + (n * 10.0))));
            particles += (spark * 0.300000011920928955078125);
        }
    }
    bgCol += (float3(0.60000002384185791015625, 0.800000011920928955078125, 1.0) * particles);
    float2 logoUV = uv;
    logoUV.y -= 0.300000011920928955078125;
    logoUV.y *= (-1.0);
    float hover = sin(_358.uTime * 1.0) * 0.0500000007450580596923828125;
    logoUV.y += hover;
    float pulse = 1.0 + (sin(_358.uTime * 3.0) * 0.0199999995529651641845703125);
    float2 p = logoUV / float2(pulse);
    float2 pL = p;
    pL.x += 0.1500000059604644775390625;
    pL.y -= 0.0199999995529651641845703125;
    float param_3 = 0.449999988079071044921875;
    pL *= rot(param_3);
    float2 param_4 = pL;
    float2 param_5 = float2(0.10999999940395355224609375, 0.449999988079071044921875);
    float param_6 = 0.100000001490116119384765625;
    float dLeft = sdRoundedBox(param_4, param_5, param_6);
    float2 pR = p;
    pR.x -= 0.1500000059604644775390625;
    pR.y -= 0.0199999995529651641845703125;
    float param_7 = -0.449999988079071044921875;
    pR *= rot(param_7);
    float2 param_8 = pR;
    float2 param_9 = float2(0.10999999940395355224609375, 0.449999988079071044921875);
    float param_10 = 0.100000001490116119384765625;
    float dRight = sdRoundedBox(param_8, param_9, param_10);
    float3 colL = mix(float3(0.60000002384185791015625, 0.0, 1.0), float3(0.300000011920928955078125, 0.0, 0.800000011920928955078125), float3((-p.y) + 0.5));
    float3 colR = mix(float3(0.0, 0.800000011920928955078125, 1.0), float3(0.0, 0.4000000059604644775390625, 0.89999997615814208984375), float3((-p.y) + 0.5));
    float3 finalColor = float3(0.0);
    float maskL = smoothstep(0.004999999888241291046142578125, 0.0, dLeft);
    float maskR = smoothstep(0.004999999888241291046142578125, 0.0, dRight);
    finalColor += (colL * maskL);
    float3 blendColor = mix(finalColor, colR, float3(0.800000011920928955078125));
    finalColor = mix(finalColor, blendColor, float3(maskR));
    float intersection = maskL * maskR;
    finalColor += ((float3(0.5, 0.800000011920928955078125, 1.0) * intersection) * 0.4000000059604644775390625);
    float2 wUV = p;
    wUV.y += 0.25;
    float waveY = (sin((wUV.x * 18.0) + (_358.uTime * 8.0)) * 0.0599999986588954925537109375) * ((sin(_358.uTime) * 0.300000011920928955078125) + 0.800000011920928955078125);
    float dWave = abs(wUV.y - waveY);
    float waveLine = smoothstep(0.0199999995529651641845703125, 0.004999999888241291046142578125, dWave);
    float logoMask = fast::max(maskL, maskR);
    float fadeSides = smoothstep(0.449999988079071044921875, 0.0, abs(wUV.x));
    finalColor += ((((float3(0.699999988079071044921875, 0.949999988079071044921875, 1.0) * waveLine) * logoMask) * fadeSides) * 2.0);
    float dist = fast::min(dLeft, dRight);
    float glowIntensity = 0.014999999664723873138427734375 / (abs(dist) + 0.00200000009499490261077880859375);
    float3 glowColor = mix(float3(0.5, 0.0, 1.0), float3(0.0, 0.800000011920928955078125, 1.0), float3(0.5 + (0.5 * sin(_358.uTime))));
    float outerGlow = glowIntensity * (1.0 - (logoMask * 0.800000011920928955078125));
    finalColor += (glowColor * outerGlow);
    float2 textUV = uv;
    float2 param_11 = textUV;
    float _725 = getText(param_11);
    float dText = _725;
    float textAlpha = smoothstep(0.00999999977648258209228515625, 0.001000000047497451305389404296875, dText);
    float textGlow = 0.008000000379979610443115234375 / (abs(dText) + 0.001000000047497451305389404296875);
    float3 textColor = float3(1.0);
    float3 textGlowCol = float3(0.0, 0.800000011920928955078125, 1.0);
    float3 finalTextElement = (textColor * textAlpha) + ((textGlowCol * textGlow) * 0.800000011920928955078125);
    float shineSpeed = _358.uTime * 2.5;
    float shineBand = (textUV.x * 1.5) + (textUV.y * 0.5);
    float shineVal = smoothstep(-0.20000000298023223876953125, 0.20000000298023223876953125, sin(shineBand - shineSpeed));
    shineVal = powr(shineVal, 30.0);
    float3 shineColor = float3(1.60000002384185791015625, 0.800000011920928955078125, 2.0);
    finalTextElement += ((shineColor * shineVal) * textAlpha);
    float3 foreground = finalColor + finalTextElement;
    float alpha = fast::clamp((((maskL + maskR) + outerGlow) + textAlpha) + textGlow, 0.0, 1.0);
    float3 pixel = mix(bgCol, foreground, float3(alpha));
    pixel += (finalTextElement * 0.5);
    pixel *= (1.0 - dot(uv * 0.3499999940395355224609375, uv * 0.3499999940395355224609375));
    out.fragColor = float4(pixel, 1.0);
    return out;
}
