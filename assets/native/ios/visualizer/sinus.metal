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
float bandValue(thread const int& i, constant VVUniforms& _40)
{
    float _34;
    if (i == 0)
    {
        _34 = _40.uFreq0;
    }
    else
    {
        float _49;
        if (i == 1)
        {
            _49 = _40.uFreq1;
        }
        else
        {
            float _59;
            if (i == 2)
            {
                _59 = _40.uFreq2;
            }
            else
            {
                float _69;
                if (i == 3)
                {
                    _69 = _40.uFreq3;
                }
                else
                {
                    float _79;
                    if (i == 4)
                    {
                        _79 = _40.uFreq4;
                    }
                    else
                    {
                        float _89;
                        if (i == 5)
                        {
                            _89 = _40.uFreq5;
                        }
                        else
                        {
                            float _98;
                            if (i == 6)
                            {
                                _98 = _40.uFreq6;
                            }
                            else
                            {
                                _98 = _40.uFreq7;
                            }
                            _89 = _98;
                        }
                        _79 = _89;
                    }
                    _69 = _79;
                }
                _59 = _69;
            }
            _49 = _59;
        }
        _34 = _49;
    }
    return _34;
}

fragment vv_fmain_out fmain(constant VVUniforms& _40 [[buffer(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float2 fragCoord = FlutterFragCoord(gl_FragCoord).xy;
    float2 uv = ((fragCoord * 2.0) - _40.uResolution) / float2(_40.uResolution.y);
    float osc = 0.0;
    for (int i = 0; i < 8; i++)
    {
        int param = i;
        float amp = fast::clamp(bandValue(param, _40), 0.0, 1.0);
        float w = 1.0 - (float(i) / 10.0);
        float freq = float(i + 1);
        float phase = (0.60000002384185791015625 + (0.100000001490116119384765625 * float(i))) * _40.uSpeed;
        osc += ((w * amp) * sin(freq * ((uv.x * 4.0) + (_40.uTime * phase))));
    }
    osc /= 8.0;
    float targetY = osc * _40.uIntensity;
    float distY = abs(uv.y - targetY);
    float distInPixels = (distY * _40.uResolution.y) * 0.5;
    float avgAmp = (osc + 1.0) * 0.5;
    float baseThickness = fast::max(1.0, (_40.uStroke * _40.uResolution.y) * 0.00200000009499490261077880859375);
    float thickness = baseThickness * (0.800000011920928955078125 + ((0.4000000059604644775390625 * avgAmp) * _40.uIntensity));
    float lineAlpha = 1.0 - smoothstep(thickness * 0.5, (thickness * 0.5) + 1.5, distInPixels);
    float glowInput = fast::max(_40.uGlow, 0.0);
    float glowAlpha = exp((-distY) * 20.0) * glowInput;
    float gx = fast::clamp(fragCoord.x / _40.uResolution.x, 0.0, 1.0);
    float3 col = mix(float3(_40.uColor), float3(_40.uColor2), float3(gx));
    float totalAlpha = fast::clamp(lineAlpha + glowAlpha, 0.0, 1.0);
    if (totalAlpha <= 0.0)
    {
        out.fragColor = float4(0.0);
    }
    else
    {
        out.fragColor = float4(col * totalAlpha, totalAlpha);
    }
    return out;
}
