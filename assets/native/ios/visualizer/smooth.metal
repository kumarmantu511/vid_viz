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
    float uStroke;
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
float sampleFreq(thread const float& x, constant VVUniforms& _54)
{
    float fi = fast::clamp(x, 0.0, 1.0) * 7.0;
    float i0 = floor(fi);
    float i1 = fast::min(i0 + 1.0, 7.0);
    float t = fract(fi);
    float _48;
    if (i0 < 0.5)
    {
        _48 = _54.uFreq0;
    }
    else
    {
        float _64;
        if (i0 < 1.5)
        {
            _64 = _54.uFreq1;
        }
        else
        {
            float _74;
            if (i0 < 2.5)
            {
                _74 = _54.uFreq2;
            }
            else
            {
                float _84;
                if (i0 < 3.5)
                {
                    _84 = _54.uFreq3;
                }
                else
                {
                    float _94;
                    if (i0 < 4.5)
                    {
                        _94 = _54.uFreq4;
                    }
                    else
                    {
                        float _104;
                        if (i0 < 5.5)
                        {
                            _104 = _54.uFreq5;
                        }
                        else
                        {
                            float _114;
                            if (i0 < 6.5)
                            {
                                _114 = _54.uFreq6;
                            }
                            else
                            {
                                _114 = _54.uFreq7;
                            }
                            _104 = _114;
                        }
                        _94 = _104;
                    }
                    _84 = _94;
                }
                _74 = _84;
            }
            _64 = _74;
        }
        _48 = _64;
    }
    float f0 = _48;
    float _134;
    if (i1 < 0.5)
    {
        _134 = _54.uFreq0;
    }
    else
    {
        float _142;
        if (i1 < 1.5)
        {
            _142 = _54.uFreq1;
        }
        else
        {
            float _150;
            if (i1 < 2.5)
            {
                _150 = _54.uFreq2;
            }
            else
            {
                float _158;
                if (i1 < 3.5)
                {
                    _158 = _54.uFreq3;
                }
                else
                {
                    float _166;
                    if (i1 < 4.5)
                    {
                        _166 = _54.uFreq4;
                    }
                    else
                    {
                        float _174;
                        if (i1 < 5.5)
                        {
                            _174 = _54.uFreq5;
                        }
                        else
                        {
                            float _182;
                            if (i1 < 6.5)
                            {
                                _182 = _54.uFreq6;
                            }
                            else
                            {
                                _182 = _54.uFreq7;
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
        _134 = _142;
    }
    float f1 = _134;
    return mix(f0, f1, t);
}

fragment vv_fmain_out fmain(constant VVUniforms& _54 [[buffer(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float2 res = _54.uResolution;
    float2 uv = FlutterFragCoord(gl_FragCoord).xy / res;
    uv.x = 1.0 - uv.x;
    float t = _54.uTime * (0.60000002384185791015625 * _54.uSpeed);
    float x = uv.x;
    float param = x;
    float f = sampleFreq(param, _54);
    float baseAmp = fast::clamp(f * _54.uIntensity, 0.0, 1.2000000476837158203125);
    float y0 = 0.5 + ((0.119999997317790985107421875 * baseAmp) * sin((10.0 * x) + t));
    float y1 = 0.5 + ((0.180000007152557373046875 * baseAmp) * sin(((10.0 * x) + t) + 1.7999999523162841796875));
    float y2 = 0.5 + ((0.23999999463558197021484375 * baseAmp) * sin(((10.0 * x) + t) + 3.599999904632568359375));
    float px = 1.0 / fast::min(res.x, res.y);
    float strokeVal = fast::max(0.100000001490116119384765625, _54.uStroke);
    float halfThickness = px * (strokeVal * 0.60000002384185791015625);
    float d0 = abs(uv.y - y0);
    float d1 = abs(uv.y - y1);
    float d2 = abs(uv.y - y2);
    float c0 = 1.0 - smoothstep(halfThickness, halfThickness + px, d0);
    float c1 = 1.0 - smoothstep(halfThickness, halfThickness + px, d1);
    float c2 = 1.0 - smoothstep(halfThickness, halfThickness + px, d2);
    float glowInput = fast::max(_54.uGlow, 0.0);
    float g0 = (exp((-d0) * 40.0) * glowInput) * 0.60000002384185791015625;
    float g1 = (exp((-d1) * 40.0) * glowInput) * 0.60000002384185791015625;
    float g2 = (exp((-d2) * 40.0) * glowInput) * 0.60000002384185791015625;
    float totalAlpha = ((c0 + g0) + (c1 + g1)) + (c2 + g2);
    if (totalAlpha < 0.001000000047497451305389404296875)
    {
        out.fragColor = float4(0.0);
        return out;
    }
    float gy = fast::clamp(uv.y, 0.0, 1.0);
    float3 baseColor = mix(float3(_54.uColor), float3(_54.uColor2), float3(gy));
    float finalAlpha = fast::clamp(totalAlpha, 0.0, 1.0);
    out.fragColor = float4(baseColor * finalAlpha, finalAlpha);
    return out;
}
