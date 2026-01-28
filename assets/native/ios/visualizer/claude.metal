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
float sampleFreq(thread const float& x, constant VVUniforms& _62)
{
    float fi = fast::clamp(x, 0.0, 1.0) * 7.0;
    float i0 = floor(fi);
    float i1 = fast::min(i0 + 1.0, 7.0);
    float t = fract(fi);
    float _56;
    if (i0 < 0.5)
    {
        _56 = _62.uFreq0;
    }
    else
    {
        float _72;
        if (i0 < 1.5)
        {
            _72 = _62.uFreq1;
        }
        else
        {
            float _82;
            if (i0 < 2.5)
            {
                _82 = _62.uFreq2;
            }
            else
            {
                float _92;
                if (i0 < 3.5)
                {
                    _92 = _62.uFreq3;
                }
                else
                {
                    float _102;
                    if (i0 < 4.5)
                    {
                        _102 = _62.uFreq4;
                    }
                    else
                    {
                        float _112;
                        if (i0 < 5.5)
                        {
                            _112 = _62.uFreq5;
                        }
                        else
                        {
                            float _122;
                            if (i0 < 6.5)
                            {
                                _122 = _62.uFreq6;
                            }
                            else
                            {
                                _122 = _62.uFreq7;
                            }
                            _112 = _122;
                        }
                        _102 = _112;
                    }
                    _92 = _102;
                }
                _82 = _92;
            }
            _72 = _82;
        }
        _56 = _72;
    }
    float f0 = _56;
    float _142;
    if (i1 < 0.5)
    {
        _142 = _62.uFreq0;
    }
    else
    {
        float _150;
        if (i1 < 1.5)
        {
            _150 = _62.uFreq1;
        }
        else
        {
            float _158;
            if (i1 < 2.5)
            {
                _158 = _62.uFreq2;
            }
            else
            {
                float _166;
                if (i1 < 3.5)
                {
                    _166 = _62.uFreq3;
                }
                else
                {
                    float _174;
                    if (i1 < 4.5)
                    {
                        _174 = _62.uFreq4;
                    }
                    else
                    {
                        float _182;
                        if (i1 < 5.5)
                        {
                            _182 = _62.uFreq5;
                        }
                        else
                        {
                            float _190;
                            if (i1 < 6.5)
                            {
                                _190 = _62.uFreq6;
                            }
                            else
                            {
                                _190 = _62.uFreq7;
                            }
                            _182 = _190;
                        }
                        _174 = _182;
                    }
                    _166 = _174;
                }
                _158 = _166;
            }
            _150 = _158;
        }
        _142 = _150;
    }
    float f1 = _142;
    return mix(f0, f1, t);
}

static inline __attribute__((always_inline))
float capsuleDist(thread const float2& uv, thread const float2& center, thread const float& halfWidth, thread const float& halfHeight)
{
    float2 p = uv - center;
    float r = halfWidth;
    float lineHalf = fast::max(halfHeight - r, 0.0);
    float y = fast::clamp(p.y, -lineHalf, lineHalf);
    float2 q = p - float2(0.0, y);
    return length(q) - r;
}

fragment vv_fmain_out fmain(constant VVUniforms& _62 [[buffer(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float2 res = _62.uResolution;
    float2 uv = FlutterFragCoord(gl_FragCoord).xy / res;
    float bars = fast::clamp(_62.uBars, 4.0, 128.0);
    float totalWidth = 0.89999997615814208984375;
    float barW = totalWidth / bars;
    float _270;
    if (_62.uBarFill > 0.0)
    {
        _270 = _62.uBarFill;
    }
    else
    {
        _270 = 0.800000011920928955078125;
    }
    float fill = 1.0 - fast::clamp(_270, 0.0500000007450580596923828125, 1.0);
    float spacing = barW * fill;
    float halfWidth = (barW - spacing) * 0.5;
    halfWidth = fast::max(halfWidth, 9.9999997473787516355514526367188e-05);
    float idx = floor(uv.x * bars);
    float barStart = idx / bars;
    float barCenterX = barStart + (barW * 0.5);
    float sampleX = powr((idx + 0.5) / bars, 0.800000011920928955078125);
    float param = sampleX;
    float f = sampleFreq(param, _62);
    float height = fast::clamp(fast::max(f, 0.00999999977648258209228515625) * (0.800000011920928955078125 + (0.4000000059604644775390625 * _62.uIntensity)), 0.0199999995529651641845703125, 0.980000019073486328125);
    height *= (0.949999988079071044921875 + (0.100000001490116119384765625 * fast::clamp(_62.uSpeed, 0.0, 2.0)));
    float halfHeight = height * 0.4799999892711639404296875;
    float2 param_1 = uv;
    float2 param_2 = float2(barCenterX, 0.5);
    float param_3 = halfWidth;
    float param_4 = halfHeight;
    float dist = capsuleDist(param_1, param_2, param_3, param_4);
    float px = 1.0 / fast::min(res.x, res.y);
    float shapeAlpha = 1.0 - smoothstep(0.0, px * 2.0, dist);
    float glowInput = fast::max(_62.uGlow, 0.0);
    float glowDist = fast::max(dist, 0.0);
    float glowAlpha = exp((-glowDist) * 70.0) * glowInput;
    float gy = fast::clamp(uv.y, 0.0, 1.0);
    float3 grad = mix(float3(_62.uColor), float3(_62.uColor2), float3(gy));
    float finalAlpha = fast::clamp(shapeAlpha + glowAlpha, 0.0, 1.0);
    if (finalAlpha <= 0.001000000047497451305389404296875)
    {
        out.fragColor = float4(0.0);
    }
    else
    {
        out.fragColor = float4(grad * finalAlpha, finalAlpha);
    }
    return out;
}
