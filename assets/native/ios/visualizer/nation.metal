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
float _vidvizSample8(thread float& x, constant VVUniforms& _76)
{
    x = fast::clamp(x, 0.0, 1.0);
    float fi = x * 7.0;
    float i0 = floor(fi);
    float i1 = fast::min(i0 + 1.0, 7.0);
    float t = fract(fi);
    float _71;
    if (i0 < 0.5)
    {
        _71 = _76.uFreq0;
    }
    else
    {
        float _86;
        if (i0 < 1.5)
        {
            _86 = _76.uFreq1;
        }
        else
        {
            float _96;
            if (i0 < 2.5)
            {
                _96 = _76.uFreq2;
            }
            else
            {
                float _106;
                if (i0 < 3.5)
                {
                    _106 = _76.uFreq3;
                }
                else
                {
                    float _116;
                    if (i0 < 4.5)
                    {
                        _116 = _76.uFreq4;
                    }
                    else
                    {
                        float _126;
                        if (i0 < 5.5)
                        {
                            _126 = _76.uFreq5;
                        }
                        else
                        {
                            float _136;
                            if (i0 < 6.5)
                            {
                                _136 = _76.uFreq6;
                            }
                            else
                            {
                                _136 = _76.uFreq7;
                            }
                            _126 = _136;
                        }
                        _116 = _126;
                    }
                    _106 = _116;
                }
                _96 = _106;
            }
            _86 = _96;
        }
        _71 = _86;
    }
    float f0 = _71;
    float _156;
    if (i1 < 0.5)
    {
        _156 = _76.uFreq0;
    }
    else
    {
        float _164;
        if (i1 < 1.5)
        {
            _164 = _76.uFreq1;
        }
        else
        {
            float _172;
            if (i1 < 2.5)
            {
                _172 = _76.uFreq2;
            }
            else
            {
                float _180;
                if (i1 < 3.5)
                {
                    _180 = _76.uFreq3;
                }
                else
                {
                    float _188;
                    if (i1 < 4.5)
                    {
                        _188 = _76.uFreq4;
                    }
                    else
                    {
                        float _196;
                        if (i1 < 5.5)
                        {
                            _196 = _76.uFreq5;
                        }
                        else
                        {
                            float _204;
                            if (i1 < 6.5)
                            {
                                _204 = _76.uFreq6;
                            }
                            else
                            {
                                _204 = _76.uFreq7;
                            }
                            _196 = _204;
                        }
                        _188 = _196;
                    }
                    _180 = _188;
                }
                _172 = _180;
            }
            _164 = _172;
        }
        _156 = _164;
    }
    float f1 = _156;
    return mix(f0, f1, t);
}

static inline __attribute__((always_inline))
float normalizeAngle(thread float& a)
{
    if (a > 1.57079637050628662109375)
    {
        a = 3.1415927410125732421875 - a;
    }
    if (a < (-1.57079637050628662109375))
    {
        a = (-3.1415927410125732421875) - a;
    }
    return 1.0 - (((a / 1.57079637050628662109375) + 1.0) * 0.5);
}

static inline __attribute__((always_inline))
float4 _vidvizTexture(texture2d<float> s, sampler sSmplr, thread const float2& uv, constant VVUniforms& _76)
{
    float param = uv.x;
    float _231 = _vidvizSample8(param, _76);
    float v = _231;
    return float4(v, v, v, 1.0);
}

static inline __attribute__((always_inline))
float3 map(thread const float& v, thread const float& edge, thread const float3& c1, thread const float3& c2, thread const float& t, thread float3& iResolution)
{
    float m = t / iResolution.x;
    float d = v - edge;
    float a = abs(d);
    if (a <= m)
    {
        float b = ((d + m) * 0.5) / m;
        return mix(c1, c2, float3(smoothstep(0.0, 1.0, b)));
    }
    else
    {
        if (d < 0.0)
        {
            return c1;
        }
        else
        {
            return c2;
        }
    }
}

fragment vv_fmain_out fmain(constant VVUniforms& _76 [[buffer(0)]], texture2d<float> iChannel0 [[texture(0)]], sampler iChannel0Smplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float3 iResolution = float3(_76.uResolution, 1.0);
    float iTime = _76.uTime * _76.uSpeed;
    float2 fragCoord = FlutterFragCoord(gl_FragCoord).xy;
    float2 flippedCoord = float2(fragCoord.x, iResolution.y - fragCoord.y);
    float param = 0.0;
    float _334 = _vidvizSample8(param, _76);
    float param_1 = 0.100000001490116119384765625;
    float _337 = _vidvizSample8(param_1, _76);
    float bass = (_334 + _337) * 0.5;
    float s1 = fast::min((powr(bass * 0.800000011920928955078125, 4.0) * 5.0) * _76.uIntensity, 1.0);
    float wiggle = fast::max(0.0, bass - 0.699999988079071044921875) * 0.02999999932944774627685546875;
    float2 uv = (flippedCoord / iResolution.xy) + (float2(sin(iTime * 18.0), cos(iTime * 17.0)) * wiggle);
    float2 ar = float2(iResolution.x / iResolution.y, 1.0);
    float2 p = ((uv * ar) * 2.0) - ar;
    float angle = precise::atan2(p.y, p.x);
    float angle2 = angle - 0.785398185253143310546875;
    float param_2 = angle;
    float _404 = normalizeAngle(param_2);
    angle = _404;
    float param_3 = angle2;
    float _407 = normalizeAngle(param_3);
    angle2 = _407;
    float d = length(p);
    float3 bg = float3(0.0);
    float samplePos = abs(angle);
    float2 param_4 = float2(samplePos, 0.0);
    float so = _vidvizTexture(iChannel0, iChannel0Smplr, param_4, _76).x;
    so = smoothstep(0.20000000298023223876953125, 0.800000011920928955078125, so) * _76.uIntensity;
    float baseSize = 0.4000000059604644775390625;
    float ringSize = 0.02999999932944774627685546875;
    float outerGrowth = 0.100000001490116119384765625;
    float innerGrowth = 0.300000011920928955078125;
    float colorDistortion = 0.02500000037252902984619140625;
    float innerBorder = ((s1 * innerGrowth) * 0.20000000298023223876953125) + (baseSize * 0.300000011920928955078125);
    float outerBorder = ((s1 * innerGrowth) * 0.699999988079071044921875) + baseSize;
    float3 sub = float3((s1 * 0.20000000298023223876953125) * sqrt(d));
    float minCol = 0.0199999995529651641845703125;
    float maxCol = 0.20000000298023223876953125;
    float3 grad1 = (float3(0.00999999977648258209228515625) + ((float3(minCol + (fast::max(0.0, 0.5 - angle2) * maxCol)) * 2.0) * powr(d / fast::max(0.001000000047497451305389404296875, innerBorder), 2.0))) - sub;
    float3 grad2 = (float3(0.00999999977648258209228515625) + ((float3(minCol + (fast::max(0.0, angle2 - 0.5) * maxCol)) * 2.0) * (d / fast::max(0.001000000047497451305389404296875, outerBorder)))) - sub;
    float cds = 0.0199999995529651641845703125 * iResolution.x;
    float3 col1 = grad1;
    float ring = ringSize + (ringSize * sqrt(s1));
    float dynamicRadius = ((s1 * innerGrowth) + baseSize) + ring;
    float param_5 = d;
    float param_6 = innerBorder;
    float3 param_7 = col1;
    float3 param_8 = grad2;
    float param_9 = 0.0040000001899898052215576171875 * iResolution.x;
    col1 = map(param_5, param_6, param_7, param_8, param_9, iResolution);
    float param_10 = d;
    float param_11 = outerBorder;
    float3 param_12 = col1;
    float3 param_13 = float3(1.0);
    float param_14 = 0.0030000000260770320892333984375 * iResolution.x;
    col1 = map(param_10, param_11, param_12, param_13, param_14, iResolution);
    float3 cRed = mix(float3(1.0, 0.0, 0.0), float3(_76.uColor), float3(0.5));
    float3 cGreen = mix(float3(0.0, 1.0, 0.0), float3(_76.uColor), float3(0.300000011920928955078125));
    float3 cBlue = mix(float3(0.0, 0.0, 1.0), float3(_76.uColor2), float3(0.5));
    float param_15 = d;
    float param_16 = dynamicRadius + (so * outerGrowth);
    float3 param_17 = col1;
    float3 param_18 = float3(1.0, 1.0, 0.0);
    float param_19 = 2.0 + (so * cds);
    col1 = map(param_15, param_16, param_17, param_18, param_19, iResolution);
    float param_20 = d;
    float param_21 = dynamicRadius + (so * (outerGrowth + colorDistortion));
    float3 param_22 = col1;
    float3 param_23 = cRed;
    float param_24 = 2.0 + (so * cds);
    col1 = map(param_20, param_21, param_22, param_23, param_24, iResolution);
    float param_25 = d;
    float param_26 = dynamicRadius + (so * (outerGrowth + (colorDistortion * 2.0)));
    float3 param_27 = col1;
    float3 param_28 = cBlue;
    float param_29 = 2.0 + (so * cds);
    col1 = map(param_25, param_26, param_27, param_28, param_29, iResolution);
    float param_30 = d;
    float param_31 = dynamicRadius + (so * (outerGrowth + (colorDistortion * 3.0)));
    float3 param_32 = col1;
    float3 param_33 = cGreen;
    float param_34 = 2.0 + (so * cds);
    col1 = map(param_30, param_31, param_32, param_33, param_34, iResolution);
    float param_35 = d;
    float param_36 = (dynamicRadius - 0.00200000009499490261077880859375) + (so * (outerGrowth + (colorDistortion * 4.0)));
    float3 param_37 = col1;
    float3 param_38 = bg;
    float param_39 = 2.0 + (so * cds);
    col1 = map(param_35, param_36, param_37, param_38, param_39, iResolution);
    float m = fast::max(fast::max(col1.x, col1.y), col1.z);
    if (m > 1.0)
    {
        col1 /= float3(m);
    }
    col1 = mix(col1, col1 * float3(_76.uColor), float3(0.300000011920928955078125));
    float alpha = smoothstep(0.0500000007450580596923828125, 1.5, length(col1));
    out.fragColor = float4(col1 * alpha, alpha);
    return out;
}
