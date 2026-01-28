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

template<typename T, size_t Num>
struct spvUnsafeArray
{
    T elements[Num ? Num : 1];
    
    thread T& operator [] (size_t pos) thread
    {
        return elements[pos];
    }
    constexpr const thread T& operator [] (size_t pos) const thread
    {
        return elements[pos];
    }
    
    device T& operator [] (size_t pos) device
    {
        return elements[pos];
    }
    constexpr const device T& operator [] (size_t pos) const device
    {
        return elements[pos];
    }
    
    constexpr const constant T& operator [] (size_t pos) const constant
    {
        return elements[pos];
    }
    
    threadgroup T& operator [] (size_t pos) threadgroup
    {
        return elements[pos];
    }
    constexpr const threadgroup T& operator [] (size_t pos) const threadgroup
    {
        return elements[pos];
    }
};

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
    float uGlow;
    float uStroke;
};

constant spvUnsafeArray<int, 5> _268 = spvUnsafeArray<int, 5>({ 1, 3, 0, 4, 2 });

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
float _vidvizSample8(thread float& x, constant VVUniforms& _101)
{
    x = fast::clamp(x, 0.0, 1.0);
    float fi = x * 7.0;
    float i0 = floor(fi);
    float i1 = fast::min(i0 + 1.0, 7.0);
    float t = fract(fi);
    float _95;
    if (i0 < 0.5)
    {
        _95 = _101.uFreq0;
    }
    else
    {
        float _110;
        if (i0 < 1.5)
        {
            _110 = _101.uFreq1;
        }
        else
        {
            float _120;
            if (i0 < 2.5)
            {
                _120 = _101.uFreq2;
            }
            else
            {
                float _130;
                if (i0 < 3.5)
                {
                    _130 = _101.uFreq3;
                }
                else
                {
                    float _140;
                    if (i0 < 4.5)
                    {
                        _140 = _101.uFreq4;
                    }
                    else
                    {
                        float _150;
                        if (i0 < 5.5)
                        {
                            _150 = _101.uFreq5;
                        }
                        else
                        {
                            float _160;
                            if (i0 < 6.5)
                            {
                                _160 = _101.uFreq6;
                            }
                            else
                            {
                                _160 = _101.uFreq7;
                            }
                            _150 = _160;
                        }
                        _140 = _150;
                    }
                    _130 = _140;
                }
                _120 = _130;
            }
            _110 = _120;
        }
        _95 = _110;
    }
    float f0 = _95;
    float _180;
    if (i1 < 0.5)
    {
        _180 = _101.uFreq0;
    }
    else
    {
        float _188;
        if (i1 < 1.5)
        {
            _188 = _101.uFreq1;
        }
        else
        {
            float _196;
            if (i1 < 2.5)
            {
                _196 = _101.uFreq2;
            }
            else
            {
                float _204;
                if (i1 < 3.5)
                {
                    _204 = _101.uFreq3;
                }
                else
                {
                    float _212;
                    if (i1 < 4.5)
                    {
                        _212 = _101.uFreq4;
                    }
                    else
                    {
                        float _220;
                        if (i1 < 5.5)
                        {
                            _220 = _101.uFreq5;
                        }
                        else
                        {
                            float _228;
                            if (i1 < 6.5)
                            {
                                _228 = _101.uFreq6;
                            }
                            else
                            {
                                _228 = _101.uFreq7;
                            }
                            _220 = _228;
                        }
                        _212 = _220;
                    }
                    _204 = _212;
                }
                _196 = _204;
            }
            _188 = _196;
        }
        _180 = _188;
    }
    float f1 = _180;
    return mix(f0, f1, t);
}

static inline __attribute__((always_inline))
float4 _vidvizTexture(texture2d<float> s, sampler sSmplr, thread const float2& uv, constant VVUniforms& _101)
{
    float param = uv.x;
    float _254 = _vidvizSample8(param, _101);
    float v = _254;
    return float4(v, v, v, 1.0);
}

static inline __attribute__((always_inline))
float getFreq(thread const int& channel, thread const int& i, constant VVUniforms& _101, texture2d<float> iChannel0, sampler iChannel0Smplr)
{
    int band = (2 * channel) + (_268[i] * 6);
    float normalizedBand = float(band) / 32.0;
    float2 param = float2(normalizedBand, 0.0);
    return _vidvizTexture(iChannel0, iChannel0Smplr, param, _101).x;
}

static inline __attribute__((always_inline))
float getScale(thread const int& i)
{
    float x = abs(2.0 - float(i));
    float s = 3.0 - x;
    return (s / 3.0) * 1.0;
}

static inline __attribute__((always_inline))
float smoothCubic(thread const float& t)
{
    return (t * t) * (3.0 - (2.0 * t));
}

static inline __attribute__((always_inline))
float getInversionFactor(thread const int& index)
{
    if ((index == 0) || (index == 4))
    {
        return -1.0;
    }
    else
    {
        return 1.0;
    }
}

static inline __attribute__((always_inline))
float sampleCurveY(thread float& t, thread const spvUnsafeArray<float, 5>& y, thread const bool& upper)
{
    t = fast::clamp(t, 0.0, 1.0);
    float extendedT = (t * 1.39999997615814208984375) - 0.20000000298023223876953125;
    if (extendedT <= 0.0)
    {
        float param = (extendedT + 0.20000000298023223876953125) / 0.20000000298023223876953125;
        float blend = smoothCubic(param);
        int param_1 = 0;
        float displacement = (y[0] - 0.5) * getInversionFactor(param_1);
        float result = 0.5 + (displacement * blend);
        float _356;
        if (upper)
        {
            _356 = result;
        }
        else
        {
            _356 = 1.0 - result;
        }
        return _356;
    }
    else
    {
        if (extendedT >= 1.0)
        {
            float param_2 = 1.0 - ((extendedT - 1.0) / 0.20000000298023223876953125);
            float blend_1 = smoothCubic(param_2);
            int param_3 = 4;
            float displacement_1 = (y[4] - 0.5) * getInversionFactor(param_3);
            float result_1 = 0.5 + (displacement_1 * blend_1);
            float _390;
            if (upper)
            {
                _390 = result_1;
            }
            else
            {
                _390 = 1.0 - result_1;
            }
            return _390;
        }
    }
    float scaledT = extendedT * 4.0;
    int index = int(scaledT);
    float frac = fract(scaledT);
    float param_4 = frac;
    frac = smoothCubic(param_4);
    float y1;
    float y2;
    float inv1;
    float inv2;
    if (index >= 4)
    {
        y2 = y[4];
        y1 = y[4];
        int param_5 = 4;
        float _423 = getInversionFactor(param_5);
        inv2 = _423;
        inv1 = _423;
    }
    else
    {
        y1 = y[index];
        y2 = y[min((index + 1), 4)];
        int param_6 = index;
        inv1 = getInversionFactor(param_6);
        int param_7 = min((index + 1), 4);
        inv2 = getInversionFactor(param_7);
    }
    float disp1 = (y1 - 0.5) * inv1;
    float disp2 = (y2 - 0.5) * inv2;
    float displacement_2 = mix(disp1, disp2, frac);
    float result_2 = 0.5 + displacement_2;
    if (!upper)
    {
        result_2 = 1.0 - result_2;
    }
    return result_2;
}

static inline __attribute__((always_inline))
float getFillIntensity(thread const float2& uv, thread const int& channel, constant VVUniforms& _101, texture2d<float> iChannel0, sampler iChannel0Smplr)
{
    float m = 0.5;
    float totalWidth = 0.60000002384185791015625;
    float offset = (1.0 - totalWidth) / 2.0;
    float channelShift = float(channel) * 0.07999999821186065673828125;
    float startX = offset + channelShift;
    float endX = (offset + channelShift) + totalWidth;
    bool _493 = uv.x < startX;
    bool _501;
    if (!_493)
    {
        _501 = uv.x > endX;
    }
    else
    {
        _501 = _493;
    }
    if (_501)
    {
        return 0.0;
    }
    spvUnsafeArray<float, 5> y;
    for (int i = 0; i < 5; i++)
    {
        int param = channel;
        int param_1 = i;
        float freq = getFreq(param, param_1, _101, iChannel0, iChannel0Smplr);
        int param_2 = i;
        float scaleFactor = getScale(param_2);
        y[i] = fast::max(0.0, m - ((scaleFactor * 0.20000000298023223876953125) * freq));
    }
    float t = (uv.x - startX) / (endX - startX);
    float param_3 = t;
    spvUnsafeArray<float, 5> param_4 = y;
    bool param_5 = true;
    float _552 = sampleCurveY(param_3, param_4, param_5);
    float upperY = _552;
    float param_6 = t;
    spvUnsafeArray<float, 5> param_7 = y;
    bool param_8 = false;
    float _560 = sampleCurveY(param_6, param_7, param_8);
    float lowerY = _560;
    float minY = fast::min(upperY, lowerY);
    float maxY = fast::max(upperY, lowerY);
    bool _573 = uv.y >= minY;
    bool _580;
    if (_573)
    {
        _580 = uv.y <= maxY;
    }
    else
    {
        _580 = _573;
    }
    if (_580)
    {
        return 1.0;
    }
    return 0.0;
}

static inline __attribute__((always_inline))
float getOutlineDistance(thread const float2& uv, thread const int& channel, constant VVUniforms& _101, texture2d<float> iChannel0, sampler iChannel0Smplr)
{
    float m = 0.5;
    float totalWidth = 0.60000002384185791015625;
    float offset = (1.0 - totalWidth) / 2.0;
    float channelShift = float(channel) * 0.07999999821186065673828125;
    float startX = offset + channelShift;
    float endX = (offset + channelShift) + totalWidth;
    spvUnsafeArray<float, 5> y;
    for (int i = 0; i < 5; i++)
    {
        int param = channel;
        int param_1 = i;
        float freq = getFreq(param, param_1, _101, iChannel0, iChannel0Smplr);
        int param_2 = i;
        float scaleFactor = getScale(param_2);
        y[i] = fast::max(0.0, m - ((scaleFactor * 0.20000000298023223876953125) * freq));
    }
    float minDist = 1000.0;
    bool _641 = uv.x >= startX;
    bool _648;
    if (_641)
    {
        _648 = uv.x <= endX;
    }
    else
    {
        _648 = _641;
    }
    if (_648)
    {
        float t = (uv.x - startX) / (endX - startX);
        float param_3 = t;
        spvUnsafeArray<float, 5> param_4 = y;
        bool param_5 = true;
        float _666 = sampleCurveY(param_3, param_4, param_5);
        float upperY = _666;
        float param_6 = t;
        spvUnsafeArray<float, 5> param_7 = y;
        bool param_8 = false;
        float _673 = sampleCurveY(param_6, param_7, param_8);
        float lowerY = _673;
        minDist = fast::min(minDist, abs(uv.y - upperY));
        minDist = fast::min(minDist, abs(uv.y - lowerY));
    }
    else
    {
        minDist = abs(uv.y - m);
    }
    return minDist;
}

fragment vv_fmain_out fmain(constant VVUniforms& _101 [[buffer(0)]], texture2d<float> iChannel0 [[texture(0)]], sampler iChannel0Smplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float3 iResolution = float3(_101.uResolution, 1.0);
    float iTime = _101.uTime * _101.uSpeed;
    float2 fragCoord = FlutterFragCoord(gl_FragCoord).xy;
    float2 uv = fragCoord / iResolution.xy;
    float3 finalColor = float3(0.0);
    float2 pixelSize = float2(1.0) / iResolution.xy;
    float baseStroke = fast::max(0.5, _101.uStroke);
    float lineThickness = baseStroke * length(pixelSize);
    float3 channelColor;
    for (int channel = 0; channel < 3; channel++)
    {
        if (channel == 0)
        {
            channelColor = float3(0.7960784435272216796875, 0.14117647707462310791015625, 0.501960813999176025390625);
        }
        else
        {
            if (channel == 1)
            {
                channelColor = float3(0.16078431904315948486328125, 0.784313738346099853515625, 0.752941191196441650390625);
            }
            else
            {
                channelColor = float3(0.094117648899555206298828125, 0.53725492954254150390625, 0.854901969432830810546875);
            }
        }
        if (true)
        {
            float2 param = uv;
            int param_1 = channel;
            float fillIntensity = getFillIntensity(param, param_1, _101, iChannel0, iChannel0Smplr);
            if (fillIntensity > 0.0)
            {
                float3 fillColor = (channelColor * 0.5) * fillIntensity;
                finalColor += fillColor;
            }
        }
        float2 param_2 = uv;
        int param_3 = channel;
        float dist = getOutlineDistance(param_2, param_3, _101, iChannel0, iChannel0Smplr);
        float stroke = 1.0 - smoothstep(0.0, lineThickness, dist);
        float glowInput = fast::max(_101.uGlow, 0.0);
        float glowEffect = exp((-dist) * 20.0) * glowInput;
        float intensity = stroke + glowEffect;
        float3 layerColor = channelColor * intensity;
        finalColor = (finalColor + layerColor) - (finalColor * layerColor);
    }
    float3 tint = mix(float3(_101.uColor), float3(_101.uColor2), float3(fast::clamp(uv.y, 0.0, 1.0)));
    finalColor *= tint;
    float a = fast::clamp(fast::max(finalColor.x, fast::max(finalColor.y, finalColor.z)), 0.0, 1.0);
    out.fragColor = float4(finalColor, a);
    return out;
}
