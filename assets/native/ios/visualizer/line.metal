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

constant spvUnsafeArray<int, 5> _250 = spvUnsafeArray<int, 5>({ 1, 3, 0, 4, 2 });

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
float _vidvizSample8(thread float& x, constant VVUniforms& _85)
{
    x = fast::clamp(x, 0.0, 1.0);
    float fi = x * 7.0;
    float i0 = floor(fi);
    float i1 = fast::min(i0 + 1.0, 7.0);
    float t = fract(fi);
    float _79;
    if (i0 < 0.5)
    {
        _79 = _85.uFreq0;
    }
    else
    {
        float _94;
        if (i0 < 1.5)
        {
            _94 = _85.uFreq1;
        }
        else
        {
            float _104;
            if (i0 < 2.5)
            {
                _104 = _85.uFreq2;
            }
            else
            {
                float _114;
                if (i0 < 3.5)
                {
                    _114 = _85.uFreq3;
                }
                else
                {
                    float _124;
                    if (i0 < 4.5)
                    {
                        _124 = _85.uFreq4;
                    }
                    else
                    {
                        float _134;
                        if (i0 < 5.5)
                        {
                            _134 = _85.uFreq5;
                        }
                        else
                        {
                            float _144;
                            if (i0 < 6.5)
                            {
                                _144 = _85.uFreq6;
                            }
                            else
                            {
                                _144 = _85.uFreq7;
                            }
                            _134 = _144;
                        }
                        _124 = _134;
                    }
                    _114 = _124;
                }
                _104 = _114;
            }
            _94 = _104;
        }
        _79 = _94;
    }
    float f0 = _79;
    float _164;
    if (i1 < 0.5)
    {
        _164 = _85.uFreq0;
    }
    else
    {
        float _172;
        if (i1 < 1.5)
        {
            _172 = _85.uFreq1;
        }
        else
        {
            float _180;
            if (i1 < 2.5)
            {
                _180 = _85.uFreq2;
            }
            else
            {
                float _188;
                if (i1 < 3.5)
                {
                    _188 = _85.uFreq3;
                }
                else
                {
                    float _196;
                    if (i1 < 4.5)
                    {
                        _196 = _85.uFreq4;
                    }
                    else
                    {
                        float _204;
                        if (i1 < 5.5)
                        {
                            _204 = _85.uFreq5;
                        }
                        else
                        {
                            float _212;
                            if (i1 < 6.5)
                            {
                                _212 = _85.uFreq6;
                            }
                            else
                            {
                                _212 = _85.uFreq7;
                            }
                            _204 = _212;
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
    float f1 = _164;
    return mix(f0, f1, t);
}

static inline __attribute__((always_inline))
float4 _vidvizTexture(texture2d<float> s, sampler sSmplr, thread const float2& uv, constant VVUniforms& _85)
{
    float param = uv.x;
    float _238 = _vidvizSample8(param, _85);
    float v = _238;
    return float4(v, v, v, 1.0);
}

static inline __attribute__((always_inline))
float getFreq(thread const int& i, constant VVUniforms& _85, texture2d<float> iChannel0, sampler iChannel0Smplr)
{
    int band = _250[i] * 6;
    float2 param = float2(float(band) / 32.0, 0.0);
    return _vidvizTexture(iChannel0, iChannel0Smplr, param, _85).x;
}

static inline __attribute__((always_inline))
float getScale(thread const int& i)
{
    float x = abs(2.0 - float(i));
    return ((3.0 - x) / 3.0) * 1.0;
}

static inline __attribute__((always_inline))
float smoothCubic(thread const float& t)
{
    return (t * t) * (3.0 - (2.0 * t));
}

static inline __attribute__((always_inline))
float sampleCurve(thread float& t, thread const spvUnsafeArray<float, 5>& y)
{
    t = fast::clamp(t, 0.0, 1.0);
    float st = t * 4.0;
    int i = int(st);
    float param = fract(st);
    float f = smoothCubic(param);
    float y1 = y[i];
    float y2 = y[min((i + 1), 4)];
    return mix(y1, y2, f);
}

fragment vv_fmain_out fmain(constant VVUniforms& _85 [[buffer(0)]], texture2d<float> iChannel0 [[texture(0)]], sampler iChannel0Smplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float3 iResolution = float3(_85.uResolution, 1.0);
    float iTime = _85.uTime * _85.uSpeed;
    float2 fragCoord = FlutterFragCoord(gl_FragCoord).xy;
    float2 uv = float2(fragCoord.x / iResolution.x, 1.0 - (fragCoord.y / iResolution.y));
    float sidePadding = 0.004999999888241291046142578125;
    uv.x = (uv.x - sidePadding) / (1.0 - (2.0 * sidePadding));
    bool _365 = uv.x < 0.0;
    bool _372;
    if (!_365)
    {
        _372 = uv.x > 1.0;
    }
    else
    {
        _372 = _365;
    }
    if (_372)
    {
        out.fragColor = float4(0.0);
        return out;
    }
    float2 pxSize = float2(1.0) / iResolution.xy;
    float thickness = (fast::max(0.5, _85.uStroke) * length(pxSize)) * 2.0;
    spvUnsafeArray<float, 5> y;
    for (int i = 0; i < 5; i++)
    {
        int param = i;
        float f = getFreq(param, _85, iChannel0, iChannel0Smplr);
        int param_1 = i;
        y[i] = fast::clamp(((f * getScale(param_1)) * 0.3499999940395355224609375) * _85.uIntensity, 0.0, 0.800000011920928955078125);
    }
    float param_2 = uv.x;
    spvUnsafeArray<float, 5> param_3 = y;
    float _429 = sampleCurve(param_2, param_3);
    float curveY = _429;
    float baseY = 0.0089999996125698089599609375;
    float lineY = baseY + curveY;
    float d = abs(uv.y - lineY);
    float fillAlpha = 0.0;
    bool _446 = uv.y >= baseY;
    bool _453;
    if (_446)
    {
        _453 = uv.y <= lineY;
    }
    else
    {
        _453 = _446;
    }
    if (_453)
    {
        fillAlpha = 0.449999988079071044921875;
    }
    float stroke = 1.0 - smoothstep(0.0, thickness, d);
    float glowInput = fast::max(_85.uGlow, 0.0);
    float glow = exp((-d) * 20.0) * glowInput;
    float3 grad = mix(float3(_85.uColor), float3(_85.uColor2), float3(fast::clamp(uv.y * 1.5, 0.0, 1.0)));
    float intensity = (fillAlpha + stroke) + glow;
    float3 finalColor = grad * intensity;
    float finalAlpha = fast::clamp(intensity, 0.0, 1.0);
    out.fragColor = float4(finalColor, finalAlpha);
    return out;
}
