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
    float uGlow;
    float uBarFill;
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
float _vidvizSample8(thread float& x, constant VVUniforms& _75)
{
    x = fast::clamp(x, 0.0, 1.0);
    float fi = x * 7.0;
    float i0 = floor(fi);
    float i1 = fast::min(i0 + 1.0, 7.0);
    float t = fract(fi);
    float _70;
    if (i0 < 0.5)
    {
        _70 = _75.uFreq0;
    }
    else
    {
        float _85;
        if (i0 < 1.5)
        {
            _85 = _75.uFreq1;
        }
        else
        {
            float _95;
            if (i0 < 2.5)
            {
                _95 = _75.uFreq2;
            }
            else
            {
                float _105;
                if (i0 < 3.5)
                {
                    _105 = _75.uFreq3;
                }
                else
                {
                    float _115;
                    if (i0 < 4.5)
                    {
                        _115 = _75.uFreq4;
                    }
                    else
                    {
                        float _125;
                        if (i0 < 5.5)
                        {
                            _125 = _75.uFreq5;
                        }
                        else
                        {
                            float _135;
                            if (i0 < 6.5)
                            {
                                _135 = _75.uFreq6;
                            }
                            else
                            {
                                _135 = _75.uFreq7;
                            }
                            _125 = _135;
                        }
                        _115 = _125;
                    }
                    _105 = _115;
                }
                _95 = _105;
            }
            _85 = _95;
        }
        _70 = _85;
    }
    float f0 = _70;
    float _155;
    if (i1 < 0.5)
    {
        _155 = _75.uFreq0;
    }
    else
    {
        float _163;
        if (i1 < 1.5)
        {
            _163 = _75.uFreq1;
        }
        else
        {
            float _171;
            if (i1 < 2.5)
            {
                _171 = _75.uFreq2;
            }
            else
            {
                float _179;
                if (i1 < 3.5)
                {
                    _179 = _75.uFreq3;
                }
                else
                {
                    float _187;
                    if (i1 < 4.5)
                    {
                        _187 = _75.uFreq4;
                    }
                    else
                    {
                        float _195;
                        if (i1 < 5.5)
                        {
                            _195 = _75.uFreq5;
                        }
                        else
                        {
                            float _203;
                            if (i1 < 6.5)
                            {
                                _203 = _75.uFreq6;
                            }
                            else
                            {
                                _203 = _75.uFreq7;
                            }
                            _195 = _203;
                        }
                        _187 = _195;
                    }
                    _179 = _187;
                }
                _171 = _179;
            }
            _163 = _171;
        }
        _155 = _163;
    }
    float f1 = _155;
    return mix(f0, f1, t);
}

static inline __attribute__((always_inline))
float4 _vidvizTexture(texture2d<float> s, sampler sSmplr, thread const float2& uv, constant VVUniforms& _75)
{
    float param = uv.x;
    float _230 = _vidvizSample8(param, _75);
    float v = _230;
    return float4(v, v, v, 1.0);
}

static inline __attribute__((always_inline))
float3 bouncingBars(thread float2& p, thread float& alpha, constant VVUniforms& _75, thread float3& iResolution, texture2d<float> iChannel0, sampler iChannel0Smplr, thread float& iTime)
{
    float antiAlias = (1.41421353816986083984375 / iResolution.y) * 1.5;
    float aspectScale = (0.4000000059604644775390625 * iResolution.x) / iResolution.y;
    float3 color = float3(0.0);
    alpha = 0.0;
    p *= 0.550000011920928955078125;
    p.y += (-0.85000002384185791015625);
    p /= float2(aspectScale);
    p.y += (0.3300000131130218505859375 / aspectScale);
    p.y = -p.y;
    float2 normalizedPos = (float2(1.0) + p) * 0.5;
    float barCount = fast::max(_75.uBars, 1.0);
    float barStep = 1.0 / barCount;
    float _297;
    if (_75.uBarFill > 0.0)
    {
        _297 = _75.uBarFill;
    }
    else
    {
        _297 = 0.800000011920928955078125;
    }
    float fill = fast::clamp(_297, 0.0500000007450580596923828125, 1.0);
    float barWidth = barStep * fill;
    float barIndex = round(normalizedPos.x / barStep) * barStep;
    if ((barIndex >= 0.0) && (barIndex <= 1.0))
    {
        float2 localPos = float2(normalizedPos.x - barIndex, abs(normalizedPos.y - 0.5));
        float2 param = float2(barIndex, 0.25);
        float amplitude = _vidvizTexture(iChannel0, iChannel0Smplr, param, _75).x;
        amplitude = (((amplitude * sqrt(barIndex + 0.20000000298023223876953125)) * 2.5) / aspectScale) - 0.25;
        amplitude *= fast::clamp(_75.uIntensity, 0.5, 2.0);
        localPos.y -= (amplitude * 0.300000011920928955078125);
        if (normalizedPos.y < 0.5)
        {
            return color;
        }
        float _380;
        if (localPos.y > 0.0)
        {
            _380 = length(localPos);
        }
        else
        {
            _380 = abs(localPos.x);
        }
        float distanceToBar = aspectScale * (_380 - (barWidth * 0.4000000059604644775390625));
        float barMaskAA = smoothstep(antiAlias, -antiAlias, distanceToBar);
        color = mix(color, (float3(1.0) + sin(float3((abs(p.y) - iTime) + (2.0 * p.x)) + float3(0.0, 1.0, 2.0))) * (0.0500000007450580596923828125 + sign(p.y)), float3(smoothstep(antiAlias, -antiAlias, distanceToBar)));
        float3 tint = mix(float3(_75.uColor), float3(_75.uColor2), float3(fast::clamp(normalizedPos.y, 0.0, 1.0)));
        color *= tint;
        float glow = fast::clamp(_75.uGlow, 0.0, 1.0);
        float glowShaped = powr(glow, 0.60000002384185791015625);
        float inner = 0.0;
        if ((glowShaped > 0.001000000047497451305389404296875) && (barMaskAA > 0.001000000047497451305389404296875))
        {
            float w = antiAlias * mix(1.0, 14.0, glowShaped);
            float dIn = fast::max(-distanceToBar, 0.0);
            inner = exp((-dIn) / fast::max(w, 9.9999999747524270787835121154785e-07));
        }
        color *= (1.0 + ((glowShaped * 1.39999997615814208984375) * inner));
        alpha = barMaskAA;
    }
    return color;
}

static inline __attribute__((always_inline))
void mainImage(thread float4& O, thread const float2& C, constant VVUniforms& _75, thread float3& iResolution, texture2d<float> iChannel0, sampler iChannel0Smplr, thread float& iTime)
{
    float2 p = ((C + C) - iResolution.xy) / float2(iResolution.y);
    float2 param = p;
    float param_1;
    float3 _508 = bouncingBars(param, param_1, _75, iResolution, iChannel0, iChannel0Smplr, iTime);
    float alpha = param_1;
    float3 col = _508;
    O = float4(col * alpha, alpha);
}

fragment vv_fmain_out fmain(constant VVUniforms& _75 [[buffer(0)]], texture2d<float> iChannel0 [[texture(0)]], sampler iChannel0Smplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float3 iResolution = float3(_75.uResolution, 1.0);
    float iTime = _75.uTime * _75.uSpeed;
    float2 param_1 = FlutterFragCoord(gl_FragCoord).xy;
    float4 param;
    mainImage(param, param_1, _75, iResolution, iChannel0, iChannel0Smplr, iTime);
    out.fragColor = param;
    return out;
}
