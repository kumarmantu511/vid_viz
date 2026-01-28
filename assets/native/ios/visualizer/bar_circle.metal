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
float _vidvizSample8(thread float& x, constant VVUniforms& _70)
{
    x = fast::clamp(x, 0.0, 1.0);
    float fi = x * 7.0;
    float i0 = floor(fi);
    float i1 = fast::min(i0 + 1.0, 7.0);
    float t = fract(fi);
    float _64;
    if (i0 < 0.5)
    {
        _64 = _70.uFreq0;
    }
    else
    {
        float _80;
        if (i0 < 1.5)
        {
            _80 = _70.uFreq1;
        }
        else
        {
            float _90;
            if (i0 < 2.5)
            {
                _90 = _70.uFreq2;
            }
            else
            {
                float _100;
                if (i0 < 3.5)
                {
                    _100 = _70.uFreq3;
                }
                else
                {
                    float _110;
                    if (i0 < 4.5)
                    {
                        _110 = _70.uFreq4;
                    }
                    else
                    {
                        float _120;
                        if (i0 < 5.5)
                        {
                            _120 = _70.uFreq5;
                        }
                        else
                        {
                            float _130;
                            if (i0 < 6.5)
                            {
                                _130 = _70.uFreq6;
                            }
                            else
                            {
                                _130 = _70.uFreq7;
                            }
                            _120 = _130;
                        }
                        _110 = _120;
                    }
                    _100 = _110;
                }
                _90 = _100;
            }
            _80 = _90;
        }
        _64 = _80;
    }
    float f0 = _64;
    float _150;
    if (i1 < 0.5)
    {
        _150 = _70.uFreq0;
    }
    else
    {
        float _158;
        if (i1 < 1.5)
        {
            _158 = _70.uFreq1;
        }
        else
        {
            float _166;
            if (i1 < 2.5)
            {
                _166 = _70.uFreq2;
            }
            else
            {
                float _174;
                if (i1 < 3.5)
                {
                    _174 = _70.uFreq3;
                }
                else
                {
                    float _182;
                    if (i1 < 4.5)
                    {
                        _182 = _70.uFreq4;
                    }
                    else
                    {
                        float _190;
                        if (i1 < 5.5)
                        {
                            _190 = _70.uFreq5;
                        }
                        else
                        {
                            float _198;
                            if (i1 < 6.5)
                            {
                                _198 = _70.uFreq6;
                            }
                            else
                            {
                                _198 = _70.uFreq7;
                            }
                            _190 = _198;
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
    float f1 = _150;
    return mix(f0, f1, t);
}

static inline __attribute__((always_inline))
float4 _vidvizTexture(texture2d<float> s, sampler sSmplr, thread const float2& uv, constant VVUniforms& _70)
{
    float param = uv.x;
    float _225 = _vidvizSample8(param, _70);
    float v = _225;
    return float4(v, v, v, 1.0);
}

static inline __attribute__((always_inline))
float distToLineSegment(thread const float2& p, thread const float2& a, thread const float2& b)
{
    float2 pa = p - a;
    float2 ba = b - a;
    float h = fast::clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - (ba * h));
}

fragment vv_fmain_out fmain(constant VVUniforms& _70 [[buffer(0)]], texture2d<float> iChannel0 [[texture(0)]], sampler iChannel0Smplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float3 iResolution = float3(_70.uResolution, 1.0);
    float iTime = _70.uTime * _70.uSpeed;
    float2 fragCoord = FlutterFragCoord(gl_FragCoord).xy;
    float2 uv = (fragCoord - (iResolution.xy * 0.5)) / float2(iResolution.y);
    float barCount = fast::max(1.0, _70.uBars);
    float innerRadius = 0.20000000298023223876953125;
    float maxBarLength = 0.2199999988079071044921875 * fast::clamp(_70.uIntensity, 0.5, 2.0);
    float _310;
    if (_70.uBarFill > 0.0)
    {
        _310 = _70.uBarFill;
    }
    else
    {
        _310 = 0.800000011920928955078125;
    }
    float barThickness = 0.008000000379979610443115234375 * mix(0.60000002384185791015625, 1.7999999523162841796875, fast::clamp(_310, 0.0, 1.0));
    float minBarLength = 0.00999999977648258209228515625;
    float angle = precise::atan2(uv.y, uv.x) + 1.57079637050628662109375;
    float normalizedAngle = fract(angle / 6.283185482025146484375);
    float currentBarIdx = floor(normalizedAngle * barCount);
    float minDist = 1000.0;
    for (int i = -1; i <= 1; i++)
    {
        float neighborIdx = currentBarIdx + float(i);
        float safeIdx = mod(neighborIdx, barCount);
        float t = safeIdx / barCount;
        float symmetryT = abs((2.0 * t) - 1.0);
        float freqIndex = 1.0 - symmetryT;
        float2 param = float2(freqIndex, 0.0);
        float intensity = _vidvizTexture(iChannel0, iChannel0Smplr, param, _70).x;
        intensity = powr(intensity, 0.85000002384185791015625);
        float barAngle = (((neighborIdx / barCount) * 2.0) * 3.1415927410125732421875) - 1.57079637050628662109375;
        float2 dir = float2(cos(barAngle), sin(barAngle));
        float2 startPos = dir * innerRadius;
        float2 endPos = dir * ((innerRadius + minBarLength) + (intensity * maxBarLength));
        float2 param_1 = uv;
        float2 param_2 = startPos;
        float2 param_3 = endPos;
        float dist = distToLineSegment(param_1, param_2, param_3);
        minDist = fast::min(minDist, dist);
    }
    float pixelSize = 1.0 / iResolution.y;
    float shapeAlpha = 1.0 - smoothstep(barThickness - pixelSize, barThickness + pixelSize, minDist);
    float distFromEdge = fast::max(minDist - barThickness, 0.0);
    float glowInput = fast::max(_70.uGlow, 0.0);
    float glowAlpha = exp((-distFromEdge) * 25.0) * glowInput;
    float totalAlpha = fast::clamp(shapeAlpha + glowAlpha, 0.0, 1.0);
    float gy = fast::clamp(fragCoord.y / fast::max(iResolution.y, 1.0), 0.0, 1.0);
    float3 col = mix(float3(_70.uColor), float3(_70.uColor2), float3(gy));
    if (totalAlpha <= 0.001000000047497451305389404296875)
    {
        out.fragColor = float4(0.0);
    }
    else
    {
        out.fragColor = float4(col * totalAlpha, totalAlpha);
    }
    return out;
}
