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
    packed_float3 uColor2;
    float uAspect;
    float uProgress;
    float uStyle;
    float uThickness;
    float uTrackAlpha;
    float uCorner;
    float uGap;
    float uTheme;
    float uEffectAmount;
    packed_float3 uTrackColor;
    float uHeadAmount;
    float uHeadSize;
    float uHeadStyle;
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
float safeDiv(thread const float& a, thread const float& b)
{
    float _48;
    if (b == 0.0)
    {
        _48 = 0.0;
    }
    else
    {
        _48 = a / b;
    }
    return _48;
}

static inline __attribute__((always_inline))
float sdRoundedRect(thread const float2& p, thread const float2& b, thread const float& r)
{
    float2 d = (abs(p) - b) + float2(r);
    return length(fast::max(d, float2(0.0))) - r;
}

static inline __attribute__((always_inline))
float3 applyTheme(thread const float3& baseFill, thread const float& tx, thread const float& uvY, thread const float& centerY, constant VVUniforms& _77)
{
    float effect = fast::clamp(_77.uEffectAmount, 0.0, 1.0);
    float glow = fast::clamp(_77.uIntensity, 0.0, 1.0);
    float glowFactor = mix(1.0, 2.2000000476837158203125, glow);
    float3 fillColor = baseFill * glowFactor;
    float t = _77.uTime;
    float theme = _77.uTheme;
    if (theme < 0.5)
    {
    }
    else
    {
        if (theme < 1.5)
        {
            float time = t * (1.0 + ((0.800000011920928955078125 + (1.2000000476837158203125 * effect)) * _77.uSpeed));
            float flicker = 0.699999988079071044921875 + (mix(0.20000000298023223876953125, 1.0, effect) * fast::clamp((sin((18.0 * tx) + (time * 4.0)) * sin(time * 3.0)) + ((0.60000002384185791015625 * sin((40.0 * tx) + (time * 7.0))) * sin((8.0 * (uvY - centerY)) + (time * 5.0))), -1.0, 1.0));
            float heat = fast::clamp(tx + ((0.25 * effect) * sin(time + (tx * 6.0))), 0.0, 1.0);
            float3 fireColor = mix(float3(1.0, 0.25, 0.0), float3(1.0, 0.550000011920928955078125, 0.07999999821186065673828125), float3(heat));
            fireColor = mix(fireColor, float3(1.0, 0.980000019073486328125, 0.449999988079071044921875), float3(heat * heat));
            fillColor = mix(fillColor, (fireColor * glowFactor) * (0.800000011920928955078125 + ((0.89999997615814208984375 * flicker) * effect)), float3(effect));
        }
        else
        {
            if (theme < 2.5)
            {
                float time_1 = t * (1.2000000476837158203125 + ((0.800000011920928955078125 + (1.5 * effect)) * _77.uSpeed));
                float spark = 0.699999988079071044921875 + ((0.300000011920928955078125 + (0.699999988079071044921875 * effect)) * fast::max(0.5 + (0.5 * sin((24.0 * tx) + (time_1 * 6.0))), 1.0 - smoothstep(0.0, 0.25, abs(fract((tx * 6.0) - (time_1 * 1.39999997615814208984375)) - 0.5))));
                fillColor = mix(fillColor, (mix(float3(0.0, 0.64999997615814208984375, 1.0), float3(0.60000002384185791015625, 1.0, 1.0), float3(0.5 + (0.5 * sin((24.0 * tx) + (time_1 * 6.0))))) * ((1.2000000476837158203125 + (glow * 1.0)) + (0.800000011920928955078125 * effect))) * spark, float3(effect));
            }
            else
            {
                if (theme < 3.5)
                {
                    float time_2 = t * (0.800000011920928955078125 + ((0.699999988079071044921875 + (1.2000000476837158203125 * effect)) * _77.uSpeed));
                    float stripes = fast::clamp((0.5 * (0.5 + (0.5 * sin((36.0 * tx) - ((time_2 * 3.5) * (0.60000002384185791015625 + (0.800000011920928955078125 * effect))))))) + (0.5 * (0.5 + (0.5 * sin((120.0 * (uvY - centerY)) + ((time_2 * 4.0) * (0.60000002384185791015625 + (0.800000011920928955078125 * effect))))))), 0.0, 1.0);
                    fillColor = mix(fillColor, (mix(float3(0.949999988079071044921875, 0.20000000298023223876953125, 1.0), float3(0.100000001490116119384765625, 1.0, 0.89999997615814208984375), float3(stripes)) * ((1.2999999523162841796875 + (glow * 1.0)) + (0.699999988079071044921875 * effect))) * (1.0 + ((0.20000000298023223876953125 + (0.89999997615814208984375 * effect)) * sin(time_2 * 2.0))), float3(effect));
                }
                else
                {
                    if (theme < 4.5)
                    {
                        float time_3 = t * (0.5 + ((0.800000011920928955078125 + (1.2000000476837158203125 * effect)) * _77.uSpeed));
                        float phase = (tx * (4.0 + (4.0 * effect))) + time_3;
                        float3 rainbow = float3(0.5) + (float3(sin(phase), sin(phase + 2.0940001010894775390625), sin(phase + 4.188000202178955078125)) * 0.5);
                        fillColor = mix(fillColor, (rainbow * (0.800000011920928955078125 + ((1.39999997615814208984375 * glowFactor) * effect))) * (1.0 + ((0.60000002384185791015625 * effect) * sin(time_3 * 2.2000000476837158203125))), float3(effect));
                    }
                    else
                    {
                        if (theme < 5.5)
                        {
                            float time_4 = t * (0.800000011920928955078125 + ((1.0 + (2.0 * effect)) * _77.uSpeed));
                            float bandMask = step(0.75, fract(((uvY - centerY) * (8.0 + (8.0 * effect))) + (time_4 * 1.2999999523162841796875)));
                            float gx = fast::clamp(tx + (((fract(sin((tx + time_4) * 4373.0) * 10000.0) - 0.5) * 0.25) * effect), 0.0, 1.0);
                            float3 glitch = mix(float3(0.100000001490116119384765625, 0.89999997615814208984375, 1.0), float3(1.0, 0.100000001490116119384765625, 0.800000011920928955078125), float3(0.5 + (0.5 * sin((gx * 10.0) + (time_4 * 5.0)))));
                            glitch = float3(glitch.x, mix(glitch.y, glitch.x, 0.014999999664723873138427734375 * effect), mix(glitch.z, glitch.y, 0.014999999664723873138427734375 * effect));
                            fillColor = mix(fillColor, (glitch * ((1.0 + (glow * 1.2000000476837158203125)) + (0.800000011920928955078125 * effect))) * mix(0.300000011920928955078125, 1.0, bandMask * effect), float3(effect));
                        }
                        else
                        {
                            if (theme < 6.5)
                            {
                                float time_5 = t * (0.4000000059604644775390625 + ((0.4000000059604644775390625 + (0.800000011920928955078125 * effect)) * _77.uSpeed));
                                fillColor = mix(fillColor, (mix(mix(baseFill, float3(1.0), float3(0.25)), mix(baseFill, float3(1.0), float3(0.550000011920928955078125)), float3((0.5 + (0.5 * sin((tx * 3.0) + time_5))) * effect)) * (0.89999997615814208984375 + (0.4000000059604644775390625 * glow))) * (1.0 + ((0.25 * effect) * sin(time_5 * 0.800000011920928955078125))), float3(effect));
                            }
                            else
                            {
                                if (theme < 7.5)
                                {
                                    float time_6 = t * (0.5 + ((0.60000002384185791015625 + (0.800000011920928955078125 * effect)) * _77.uSpeed));
                                    float h = fast::clamp(uvY + (0.100000001490116119384765625 * sin((tx * 2.5) + (time_6 * 0.699999988079071044921875))), 0.0, 1.0);
                                    float3 sunset = mix(mix(float3(0.0599999986588954925537109375, 0.0199999995529651641845703125, 0.100000001490116119384765625), float3(0.85000002384185791015625, 0.3499999940395355224609375, 0.100000001490116119384765625), float3(h)), float3(1.0, 0.800000011920928955078125, 0.449999988079071044921875), float3(h * h));
                                    fillColor = mix(fillColor, mix(sunset, baseFill, float3(0.25)) * ((1.0 + ((0.4000000059604644775390625 * (0.5 + (0.5 * sin((tx * 5.0) - (time_6 * 1.5))))) * effect)) + (0.300000011920928955078125 * glow)), float3(effect));
                                }
                                else
                                {
                                    if (theme < 8.5)
                                    {
                                        float time_7 = t * (0.89999997615814208984375 + ((0.60000002384185791015625 + (1.0 * effect)) * _77.uSpeed));
                                        float frost = 0.449999988079071044921875 + (0.550000011920928955078125 * abs(sin((20.0 * tx) + (time_7 * 4.0)) * sin((10.0 * (uvY - centerY)) - (time_7 * 3.0))));
                                        fillColor = mix(fillColor, mix(float3(0.119999997317790985107421875, 0.60000002384185791015625, 1.0), float3(0.75, 1.0, 1.0), float3(frost)) * ((0.89999997615814208984375 + (0.5 * glow)) + ((0.5 * effect) * (0.60000002384185791015625 + (0.4000000059604644775390625 * sin((tx * 35.0) + (time_7 * 6.0)))))), float3(effect));
                                    }
                                    else
                                    {
                                        if (theme < 9.5)
                                        {
                                            float time_8 = t * (1.0 + ((0.800000011920928955078125 + (1.39999997615814208984375 * effect)) * _77.uSpeed));
                                            float colIndex = floor(tx * 40.0);
                                            float streak = smoothstep(0.0, 0.300000011920928955078125, 1.0 - fract(((uvY * 10.0) + (time_8 * 3.0)) + (colIndex * 13.0)));
                                            fillColor = mix(fillColor, mix(float3(0.0, 0.07999999821186065673828125, 0.0), float3(0.60000002384185791015625, 1.0, 0.60000002384185791015625), float3(fast::clamp((streak * (0.4000000059604644775390625 + (0.60000002384185791015625 * effect))) + ((0.4000000059604644775390625 + (0.60000002384185791015625 * sin((colIndex * 7.0) + (time_8 * 5.0)))) * 0.1500000059604644775390625), 0.0, 1.0))) * ((0.800000011920928955078125 + (0.4000000059604644775390625 * glow)) + (0.60000002384185791015625 * effect)), float3(effect));
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    return fillColor;
}

fragment vv_fmain_out fmain(constant VVUniforms& _77 [[buffer(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float2 frag = FlutterFragCoord(gl_FragCoord).xy;
    float2 res = fast::max(_77.uResolution, float2(1.0));
    float2 uv = frag / res;
    float p = fast::clamp(_77.uProgress, 0.0, 1.0);
    float style = _77.uStyle;
    float corner = fast::clamp(_77.uCorner, 0.0, 1.0);
    float effect = fast::clamp(_77.uEffectAmount, 0.0, 1.0);
    float glow = fast::clamp(_77.uIntensity, 0.0, 1.0);
    float marginX = 12.0 / res.x;
    float trackL = marginX;
    float trackR = 1.0 - marginX;
    float trackW = fast::max(trackR - trackL, 9.9999997473787516355514526367188e-05);
    float centerY = 0.5;
    float thicknessPx = fast::max(_77.uThickness, 1.0);
    float halfThick = (0.5 * thicknessPx) / res.y;
    float param = uv.x - trackL;
    float param_1 = trackW;
    float tx = fast::clamp(safeDiv(param, param_1), 0.0, 1.0);
    float aaDist = 1.0 / res.y;
    float softY = 1.0 - smoothstep(halfThick - aaDist, halfThick + aaDist, abs(uv.y - centerY));
    float insideTrackX = smoothstep(trackL - (1.0 / res.x), trackL, uv.x) * smoothstep(trackR + (1.0 / res.x), trackR, uv.x);
    float trackMask = softY * insideTrackX;
    float fillMask = 0.0;
    if (style < 0.5)
    {
        float trackWPx = fast::max((trackR - trackL) * res.x, 1.0);
        float outerWidthPx = p * trackWPx;
        if (outerWidthPx > 0.0)
        {
            float rPx = (halfThick * res.y) * ((corner * corner) * (3.0 - (2.0 * corner)));
            float2 param_2 = float2(frag.x - ((trackL * res.x) + (outerWidthPx * 0.5)), frag.y - (centerY * res.y));
            float2 param_3 = float2(outerWidthPx * 0.5, halfThick * res.y);
            float param_4 = rPx;
            float distPx = sdRoundedRect(param_2, param_3, param_4);
            fillMask = (1.0 - smoothstep(-0.5, 0.5, distPx)) * softY;
        }
    }
    else
    {
        bool _962 = style < 1.5;
        bool _971;
        if (!_962)
        {
            _971 = (style >= 1.5) && (style < 2.5);
        }
        else
        {
            _971 = _962;
        }
        if (_971)
        {
            float segCount = (style < 1.5) ? 16.0 : 8.0;
            float gap = mix(0.0, (style < 1.5) ? 0.89999997615814208984375 : 0.800000011920928955078125, _77.uGap * _77.uGap);
            float segT = fract(tx * segCount);
            float gapMask = smoothstep((gap * 0.5) - 0.00999999977648258209228515625, (gap * 0.5) + 0.00999999977648258209228515625, segT) * smoothstep((1.0 - (gap * 0.5)) + 0.00999999977648258209228515625, (1.0 - (gap * 0.5)) - 0.00999999977648258209228515625, segT);
            fillMask = (step(floor(tx * segCount), floor((p * segCount) + 0.001000000047497451305389404296875) - 1.0) * gapMask) * softY;
        }
        else
        {
            if (style < 3.5)
            {
                float dx = abs(uv.x - (0.5 * (trackL + trackR)));
                fillMask = (1.0 - smoothstep(((0.5 * p) * trackW) - (1.0 / res.x), ((0.5 * p) * trackW) + (1.0 / res.x), dx)) * softY;
            }
            else
            {
                if (style < 4.5)
                {
                    float trackWPx_1 = fast::max((trackR - trackL) * res.x, 1.0);
                    float outerWidthPx_1 = p * trackWPx_1;
                    if (outerWidthPx_1 > 0.0)
                    {
                        float2 pLocal = float2(frag.x - ((trackL * res.x) + (outerWidthPx_1 * 0.5)), frag.y - (centerY * res.y));
                        float rPx_1 = ((halfThick * res.y) * 0.699999988079071044921875) * ((corner * corner) * (3.0 - (2.0 * corner)));
                        float2 param_5 = pLocal;
                        float2 param_6 = float2(outerWidthPx_1 * 0.5, halfThick * res.y);
                        float param_7 = rPx_1;
                        float distOuter = sdRoundedRect(param_5, param_6, param_7);
                        float borderNpx = fast::max(1.5, (0.07999999821186065673828125 + (0.4000000059604644775390625 * corner)) * thicknessPx);
                        float2 param_8 = pLocal;
                        float2 param_9 = fast::max(float2(outerWidthPx_1 * 0.5, halfThick * res.y) - float2(borderNpx), float2(0.0));
                        float param_10 = fast::max(rPx_1 - borderNpx, 0.0);
                        float distInner = sdRoundedRect(param_8, param_9, param_10);
                        fillMask = fast::clamp((1.0 - smoothstep(-0.5, 0.5, distOuter)) - (1.0 - smoothstep(-0.5, 0.5, distInner)), 0.0, 1.0) * softY;
                    }
                }
                else
                {
                    fillMask = (((1.0 - smoothstep((((0.039999999105930328369140625 + (0.36000001430511474609375 * corner)) * thicknessPx) / res.y) - (0.5 / res.y), (((0.039999999105930328369140625 + (0.36000001430511474609375 * corner)) * thicknessPx) / res.y) + (0.5 / res.y), abs(uv.y - centerY))) * step(0.0, tx)) * step(tx, p)) * insideTrackX;
                }
            }
        }
    }
    fillMask = fast::clamp(fillMask, 0.0, 1.0);
    float3 baseFill = mix(float3(_77.uColor), float3(_77.uColor2), float3(tx));
    float3 param_11 = baseFill;
    float param_12 = tx;
    float param_13 = uv.y;
    float param_14 = centerY;
    float3 fillColor = applyTheme(param_11, param_12, param_13, param_14, _77);
    if (p > 0.0)
    {
        float headHighlight = smoothstep(mix(0.014999999664723873138427734375, 0.0599999986588954925537109375, effect), 0.0, abs(tx - p)) * fillMask;
        fillColor = mix(fillColor, fillColor * (1.0 + (1.5 * effect)), float3(headHighlight));
    }
    float breath = 1.0 + (mix(0.0, 0.119999997317790985107421875, glow) * sin(_77.uTime * (0.800000011920928955078125 + (0.4000000059604644775390625 * _77.uSpeed))));
    float finalFillMask = fillMask * breath;
    float tShaped = (corner * corner) * (3.0 - (2.0 * corner));
    float2 param_15 = float2(frag.x - ((0.5 * (trackL + trackR)) * res.x), frag.y - (centerY * res.y));
    float2 param_16 = float2((0.5 * (trackR - trackL)) * res.x, halfThick * res.y);
    float param_17 = (halfThick * res.y) * tShaped;
    float distTrack = sdRoundedRect(param_15, param_16, param_17);
    float trackShape = (1.0 - smoothstep(-0.5, 0.5, distTrack)) * insideTrackX;
    float finalTrackAlpha = _77.uTrackAlpha * trackShape;
    float3 trackBaseColor = mix(mix(float3(_77.uColor) * 0.180000007152557373046875, float3(_77.uColor2) * 0.180000007152557373046875, float3(tx)), float3(_77.uTrackColor), float3(step(0.001000000047497451305389404296875, fast::max(_77.uTrackColor[0u], fast::max(_77.uTrackColor[1u], _77.uTrackColor[2u])))));
    float3 trackLayer = trackBaseColor * finalTrackAlpha;
    float3 headLayer = float3(0.0);
    float headA = 0.0;
    bool _1374 = p > 0.0;
    bool _1381;
    if (_1374)
    {
        _1381 = _77.uHeadAmount > 0.001000000047497451305389404296875;
    }
    else
    {
        _1381 = _1374;
    }
    if (_1381)
    {
        float2 headLocal = float2(frag.x - mix(trackL * res.x, trackR * res.x, p), frag.y - (centerY * res.y));
        float hDist = length(float2(headLocal.x * 0.699999988079071044921875, headLocal.y));
        float baseR = ((halfThick * res.y) * mix(0.699999988079071044921875, 1.7999999523162841796875, _77.uHeadSize)) * (0.89999997615814208984375 + (0.4000000059604644775390625 * effect));
        float coreM = 1.0 - smoothstep(baseR * 0.300000011920928955078125, baseR * 0.550000011920928955078125, hDist);
        float haloM = 1.0 - smoothstep(baseR * 0.550000011920928955078125, baseR * (1.5 + (0.800000011920928955078125 * _77.uHeadAmount)), hDist);
        float _1454;
        if (_77.uHeadStyle < 0.5)
        {
            _1454 = 1.0;
        }
        else
        {
            float _1461;
            if (_77.uHeadStyle < 1.5)
            {
                _1461 = 0.800000011920928955078125 + (0.4000000059604644775390625 * sin(_77.uTime * 2.5));
            }
            else
            {
                _1461 = 0.699999988079071044921875 + (0.300000011920928955078125 * fast::max(sin((_77.uTime * 8.0) + (tx * 60.0)), sin((_77.uTime * 15.0) + (uv.y * 200.0))));
            }
            _1454 = _1461;
        }
        float twin = _1454;
        headA = ((_77.uHeadAmount * (0.60000002384185791015625 + (0.89999997615814208984375 * effect))) * ((coreM * 0.89999997615814208984375) + (haloM * 0.4000000059604644775390625))) * twin;
        headLayer = (fillColor * (1.2000000476837158203125 + (0.60000002384185791015625 * glow))) * headA;
    }
    float glowSize = mix(2.0, 12.0, glow);
    float glowShape = fast::clamp((1.0 - smoothstep(-0.5, glowSize, distTrack)) - trackShape, 0.0, 1.0);
    float _1531;
    if ((style < 2.5) || (style >= 4.5))
    {
        _1531 = smoothstep(p + 0.0199999995529651641845703125, p - 0.0199999995529651641845703125, tx);
    }
    else
    {
        _1531 = 1.0 - smoothstep(((0.5 * p) * trackW) - 0.00999999977648258209228515625, ((0.5 * p) * trackW) + 0.00999999977648258209228515625, abs(uv.x - (0.5 * (trackL + trackR))));
    }
    glowShape *= _1531;
    float finalGlowAlpha = (glow * (0.4000000059604644775390625 + (0.800000011920928955078125 * effect))) * glowShape;
    float3 glowLayer = (baseFill * (1.39999997615814208984375 + (0.60000002384185791015625 * glow))) * finalGlowAlpha;
    float3 fillLayer = fillColor * finalFillMask;
    float3 finalCol = ((trackLayer + fillLayer) + glowLayer) + headLayer;
    float finalAlpha = fast::clamp(((finalTrackAlpha + finalFillMask) + (finalGlowAlpha * 0.60000002384185791015625)) + headA, 0.0, 1.0);
    if (finalAlpha < 0.0030000000260770320892333984375)
    {
        out.fragColor = float4(0.0);
    }
    else
    {
        out.fragColor = float4(finalCol, finalAlpha);
    }
    return out;
}
