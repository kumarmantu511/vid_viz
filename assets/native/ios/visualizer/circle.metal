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
    float2 flippedCoord = float2(fragCoord.x, iResolution.y - fragCoord.y);
    float2 p = (flippedCoord - (iResolution.xy * 0.5)) / float2(iResolution.y);
    float r = length(p);
    float a = precise::atan2(p.y, p.x);
    float raysCount = fast::clamp(_64.uBars, 4.0, 128.0);
    float innerRadius = 0.20000000298023223876953125;
    float maxLen = 0.2800000011920928955078125 * fast::clamp(_64.uIntensity, 0.5, 2.0);
    float _296;
    if (_64.uBarFill > 0.0)
    {
        _296 = _64.uBarFill;
    }
    else
    {
        _296 = 0.5;
    }
    float fillRatio = fast::clamp(_296, 0.0500000007450580596923828125, 1.0);
    float thickness = ((3.1415927410125732421875 * innerRadius) / raysCount) * fillRatio;
    float t = fract((a + 3.1415927410125732421875) / 6.283185482025146484375);
    float idx = floor(t * raysCount);
    float ang = (((idx + 0.5) / raysCount) * 6.283185482025146484375) - 3.1415927410125732421875;
    float2 dir = float2(cos(ang), sin(ang));
    float sampleX = (idx + 0.5) / raysCount;
    float2 param = float2(sampleX, 0.0);
    float freq = _vidvizTexture(iChannel0, iChannel0Smplr, param, _64).x;
    freq = powr(fast::clamp(freq, 0.0, 1.0), 0.699999988079071044921875);
    float outerRadius = innerRadius + (maxLen * freq);
    float along = dot(p, dir);
    float2 perpV = p - (dir * along);
    float perp = length(perpV);
    float clampedAlong = fast::clamp(along, innerRadius, outerRadius);
    float dAlong = along - clampedAlong;
    float dist = length(float2(perp, dAlong)) - thickness;
    float px = 1.0 / fast::max(iResolution.y, 1.0);
    float aa = px * 1.75;
    float mask = 1.0 - smoothstep(0.0, aa, dist);
    float glowDist = fast::max(dist, 0.0);
    float glowAmt = exp((-glowDist) * 20.0) * fast::max(_64.uGlow, 0.0);
    float _420;
    if (outerRadius > innerRadius)
    {
        _420 = fast::clamp((along - innerRadius) / (outerRadius - innerRadius), 0.0, 1.0);
    }
    else
    {
        _420 = 0.0;
    }
    float gy = _420;
    float3 col = mix(float3(_64.uColor), float3(_64.uColor2), float3(gy));
    float finalAlpha = fast::clamp(mask + glowAmt, 0.0, 1.0);
    out.fragColor = float4(col * finalAlpha, finalAlpha);
    return out;
}
