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
float _vidvizSample8(thread float& x, constant VVUniforms& _64)
{
    x = fast::clamp(x, 0.0, 1.0);
    float fi = x * 7.0;
    float i0 = floor(fi);
    float i1 = fast::min(i0 + 1.0, 7.0);
    float t = fract(fi);
    float _58;
    if (i0 < 0.5)
    {
        _58 = _64.uFreq0;
    }
    else
    {
        float _74;
        if (i0 < 1.5)
        {
            _74 = _64.uFreq1;
        }
        else
        {
            float _84;
            if (i0 < 2.5)
            {
                _84 = _64.uFreq2;
            }
            else
            {
                float _94;
                if (i0 < 3.5)
                {
                    _94 = _64.uFreq3;
                }
                else
                {
                    float _104;
                    if (i0 < 4.5)
                    {
                        _104 = _64.uFreq4;
                    }
                    else
                    {
                        float _114;
                        if (i0 < 5.5)
                        {
                            _114 = _64.uFreq5;
                        }
                        else
                        {
                            float _124;
                            if (i0 < 6.5)
                            {
                                _124 = _64.uFreq6;
                            }
                            else
                            {
                                _124 = _64.uFreq7;
                            }
                            _114 = _124;
                        }
                        _104 = _114;
                    }
                    _94 = _104;
                }
                _84 = _94;
            }
            _74 = _84;
        }
        _58 = _74;
    }
    float f0 = _58;
    float _144;
    if (i1 < 0.5)
    {
        _144 = _64.uFreq0;
    }
    else
    {
        float _152;
        if (i1 < 1.5)
        {
            _152 = _64.uFreq1;
        }
        else
        {
            float _160;
            if (i1 < 2.5)
            {
                _160 = _64.uFreq2;
            }
            else
            {
                float _168;
                if (i1 < 3.5)
                {
                    _168 = _64.uFreq3;
                }
                else
                {
                    float _176;
                    if (i1 < 4.5)
                    {
                        _176 = _64.uFreq4;
                    }
                    else
                    {
                        float _184;
                        if (i1 < 5.5)
                        {
                            _184 = _64.uFreq5;
                        }
                        else
                        {
                            float _192;
                            if (i1 < 6.5)
                            {
                                _192 = _64.uFreq6;
                            }
                            else
                            {
                                _192 = _64.uFreq7;
                            }
                            _184 = _192;
                        }
                        _176 = _184;
                    }
                    _168 = _176;
                }
                _160 = _168;
            }
            _152 = _160;
        }
        _144 = _152;
    }
    float f1 = _144;
    return mix(f0, f1, t);
}

static inline __attribute__((always_inline))
float4 _vidvizTexture(texture2d<float> s, sampler sSmplr, thread const float2& uv, constant VVUniforms& _64)
{
    float param = uv.x;
    float _219 = _vidvizSample8(param, _64);
    float v = _219;
    return float4(v, v, v, 1.0);
}

fragment vv_fmain_out fmain(constant VVUniforms& _64 [[buffer(0)]], texture2d<float> iChannel0 [[texture(0)]], sampler iChannel0Smplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float3 iResolution = float3(_64.uResolution, 1.0);
    float iTime = _64.uTime * _64.uSpeed;
    float2 fragCoord = FlutterFragCoord(gl_FragCoord).xy;
    float2 uv = float2(fragCoord.x, iResolution.y - fragCoord.y) / iResolution.xy;
    float sideMargin = 0.004999999888241291046142578125;
    uv.x = (uv.x - sideMargin) / (1.0 - (2.0 * sideMargin));
    bool _272 = uv.x < 0.0;
    bool _279;
    if (!_272)
    {
        _279 = uv.x > 1.0;
    }
    else
    {
        _279 = _272;
    }
    if (_279)
    {
        out.fragColor = float4(0.0);
        return out;
    }
    float2 nv = uv;
    nv.y = (nv.y - 0.004999999888241291046142578125) * 2.0;
    float barCount = fast::max(1.0, _64.uBars);
    float fillRatio = fast::clamp(_64.uBarFill, 0.0500000007450580596923828125, 0.949999988079071044921875);
    float barIndex = floor(uv.x * barCount);
    float localX = fract(uv.x * barCount);
    float2 param = float2(barIndex / barCount, 0.0);
    float h = _vidvizTexture(iChannel0, iChannel0Smplr, param, _64).x;
    h = fast::clamp(h * _64.uIntensity, 0.0, 1.0);
    float halfWidth = 0.5 * fillRatio;
    float dx = abs(localX - 0.5) - halfWidth;
    float dy = nv.y - h;
    float dxPx = dx * (iResolution.x / barCount);
    float dyPx = dy * (iResolution.y * 0.5);
    float dist = fast::max(dxPx, dyPx);
    float shapeAlpha = 1.0 - smoothstep(0.0, 1.5, dist);
    if (nv.y < 0.0)
    {
        shapeAlpha = 0.0;
    }
    float glowInput = fast::max(_64.uGlow, 0.0);
    float glowDist = fast::max(dist, 0.0);
    float glowAlpha = exp((-glowDist) * 0.20000000298023223876953125) * glowInput;
    float finalAlpha = fast::clamp(shapeAlpha + glowAlpha, 0.0, 1.0);
    float gy = fast::clamp(uv.y, 0.0, 1.0);
    float3 tint = mix(float3(_64.uColor), float3(_64.uColor2), float3(gy));
    if (finalAlpha <= 0.001000000047497451305389404296875)
    {
        out.fragColor = float4(0.0);
    }
    else
    {
        out.fragColor = float4(tint * finalAlpha, finalAlpha);
    }
    return out;
}
