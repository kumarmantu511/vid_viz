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
float _vidvizSample8(thread float& x, constant VVUniforms& _73)
{
    x = fast::clamp(x, 0.0, 1.0);
    float fi = x * 7.0;
    float i0 = floor(fi);
    float i1 = fast::min(i0 + 1.0, 7.0);
    float t = fract(fi);
    float _67;
    if (i0 < 0.5)
    {
        _67 = _73.uFreq0;
    }
    else
    {
        float _83;
        if (i0 < 1.5)
        {
            _83 = _73.uFreq1;
        }
        else
        {
            float _93;
            if (i0 < 2.5)
            {
                _93 = _73.uFreq2;
            }
            else
            {
                float _103;
                if (i0 < 3.5)
                {
                    _103 = _73.uFreq3;
                }
                else
                {
                    float _113;
                    if (i0 < 4.5)
                    {
                        _113 = _73.uFreq4;
                    }
                    else
                    {
                        float _123;
                        if (i0 < 5.5)
                        {
                            _123 = _73.uFreq5;
                        }
                        else
                        {
                            float _133;
                            if (i0 < 6.5)
                            {
                                _133 = _73.uFreq6;
                            }
                            else
                            {
                                _133 = _73.uFreq7;
                            }
                            _123 = _133;
                        }
                        _113 = _123;
                    }
                    _103 = _113;
                }
                _93 = _103;
            }
            _83 = _93;
        }
        _67 = _83;
    }
    float f0 = _67;
    float _153;
    if (i1 < 0.5)
    {
        _153 = _73.uFreq0;
    }
    else
    {
        float _161;
        if (i1 < 1.5)
        {
            _161 = _73.uFreq1;
        }
        else
        {
            float _169;
            if (i1 < 2.5)
            {
                _169 = _73.uFreq2;
            }
            else
            {
                float _177;
                if (i1 < 3.5)
                {
                    _177 = _73.uFreq3;
                }
                else
                {
                    float _185;
                    if (i1 < 4.5)
                    {
                        _185 = _73.uFreq4;
                    }
                    else
                    {
                        float _193;
                        if (i1 < 5.5)
                        {
                            _193 = _73.uFreq5;
                        }
                        else
                        {
                            float _201;
                            if (i1 < 6.5)
                            {
                                _201 = _73.uFreq6;
                            }
                            else
                            {
                                _201 = _73.uFreq7;
                            }
                            _193 = _201;
                        }
                        _185 = _193;
                    }
                    _177 = _185;
                }
                _169 = _177;
            }
            _161 = _169;
        }
        _153 = _161;
    }
    float f1 = _153;
    return mix(f0, f1, t);
}

static inline __attribute__((always_inline))
float4 _vidvizTexture(texture2d<float> s, sampler sSmplr, thread const float2& uv, constant VVUniforms& _73)
{
    float param = uv.x;
    float _228 = _vidvizSample8(param, _73);
    float v = _228;
    return float4(v, v, v, 1.0);
}

static inline __attribute__((always_inline))
float getRealFFT(thread const float& x, constant VVUniforms& _73, texture2d<float> iChannel0, sampler iChannel0Smplr)
{
    float2 param = float2(fast::clamp(x, 0.0, 1.0), 0.25);
    return powr(_vidvizTexture(iChannel0, iChannel0Smplr, param, _73).x, 1.5);
}

static inline __attribute__((always_inline))
float cubicInterp(thread const float& t)
{
    return (t * t) * (3.0 - (2.0 * t));
}

static inline __attribute__((always_inline))
float lowResWave(thread const float& x, constant VVUniforms& _73, texture2d<float> iChannel0, sampler iChannel0Smplr)
{
    float seg = 0.0416666679084300994873046875;
    float i0 = floor(x / seg);
    float i1 = i0 + 1.0;
    float x0 = i0 * seg;
    float x1 = fast::min(i1 * seg, 1.0);
    float param = x0;
    float a0 = getRealFFT(param, _73, iChannel0, iChannel0Smplr);
    float param_1 = x1;
    float a1 = getRealFFT(param_1, _73, iChannel0, iChannel0Smplr);
    float t = (x - x0) / seg;
    float param_2 = t;
    return mix(a0, a1, cubicInterp(param_2));
}

fragment vv_fmain_out fmain(constant VVUniforms& _73 [[buffer(0)]], texture2d<float> iChannel0 [[texture(0)]], sampler iChannel0Smplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float3 iResolution = float3(_73.uResolution, 1.0);
    float iTime = _73.uTime * _73.uSpeed;
    float2 fragCoord = FlutterFragCoord(gl_FragCoord).xy;
    float2 uv = fragCoord / iResolution.xy;
    uv.y = 1.0 - uv.y;
    float centerY = 0.5;
    float param = uv.x;
    float amp = lowResWave(param, _73, iChannel0, iChannel0Smplr) * _73.uIntensity;
    float waveY = centerY + ((amp - 0.5) * 0.550000011920928955078125);
    float dist = abs(uv.y - waveY);
    float distInPixels = dist * iResolution.y;
    float thickness = fast::max(1.0, _73.uStroke * 2.0);
    float lineAlpha = 1.0 - smoothstep(thickness * 0.5, (thickness * 0.5) + 1.5, distInPixels);
    float glowInput = fast::max(_73.uGlow, 0.0);
    float glowAlpha = exp((-dist) * 50.0) * glowInput;
    float3 col = mix(float3(_73.uColor), float3(_73.uColor2), float3(uv.x));
    float totalAlpha = fast::clamp(lineAlpha + glowAlpha, 0.0, 1.0);
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
