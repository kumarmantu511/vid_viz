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
    float uAspect;
    float uHasCenter;
    float uHasBg;
    char _m18_pad[8];
    packed_float3 uRingColor;
    float uHasRingColor;
};

constant spvUnsafeArray<float3, 6> _588 = spvUnsafeArray<float3, 6>({ float3(0.0, 1.0, 1.0), float3(0.0, 0.5, 1.0), float3(0.5, 0.0, 1.0), float3(1.0, 0.0, 0.5), float3(1.0, 0.300000011920928955078125, 0.0), float3(1.0, 1.0, 0.0) });

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
float2 rotate(thread const float2& v, thread const float& a)
{
    float s = sin(a);
    float c = cos(a);
    return float2x2(float2(c, s), float2(-s, c)) * v;
}

static inline __attribute__((always_inline))
float3 hsv2rgb(thread const float3& c)
{
    float4 K = float4(1.0, 0.666666686534881591796875, 0.3333333432674407958984375, 3.0);
    float3 p = abs((fract(c.xxx + K.xyz) * 6.0) - K.www);
    return mix(K.xxx, fast::clamp(p - K.xxx, float3(0.0), float3(1.0)), float3(c.y)) * c.z;
}

static inline __attribute__((always_inline))
float hash12(thread const float2& p)
{
    float3 p3 = fract(p.xyx * 0.103100001811981201171875);
    p3 += float3(dot(p3, p3.yzx + float3(33.3300018310546875)));
    return fract((p3.x + p3.y) * p3.z);
}

static inline __attribute__((always_inline))
float sampleFFT(thread const float& t, constant VVUniforms& _139)
{
    spvUnsafeArray<float, 8> bands;
    bands[0] = _139.uFreq0;
    bands[1] = _139.uFreq1;
    bands[2] = _139.uFreq2;
    bands[3] = _139.uFreq3;
    bands[4] = _139.uFreq4;
    bands[5] = _139.uFreq5;
    bands[6] = _139.uFreq6;
    bands[7] = _139.uFreq7;
    float x = fast::clamp(t, 0.0, 1.0) * 7.0;
    int i0 = int(floor(x));
    int i1 = min(7, (i0 + 1));
    float f = fract(x);
    f = (f * f) * (3.0 - (2.0 * f));
    float raw = mix(bands[i0], bands[i1], f);
    return (smoothstep(0.0, 1.0, raw) * 0.699999988079071044921875) + (raw * 0.300000011920928955078125);
}

fragment vv_fmain_out fmain(constant VVUniforms& _139 [[buffer(0)]], texture2d<float> uBgImg [[texture(0)]], texture2d<float> uCenterImg [[texture(1)]], texture2d<float> uTexture [[texture(2)]], sampler uBgImgSmplr [[sampler(0)]], sampler uCenterImgSmplr [[sampler(1)]], sampler uTextureSmplr [[sampler(2)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float2 frag = FlutterFragCoord(gl_FragCoord).xy;
    float2 uv = frag / _139.uResolution;
    float2 p = (frag - (_139.uResolution * 0.5)) / float2(fast::max(_139.uResolution.y, 1.0));
    float2 param = p;
    float param_1 = 3.1415927410125732421875;
    p = rotate(param, param_1);
    uv = float2(1.0) - uv;
    float t = _139.uTime * (0.800000011920928955078125 + (0.60000002384185791015625 * _139.uSpeed));
    float bass = fast::clamp(((_139.uFreq0 + _139.uFreq1) + _139.uFreq2) / 3.0, 0.0, 1.0);
    float3 color;
    if (_139.uHasBg > 0.5)
    {
        float bgPulse = 1.0 + (bass * 0.02999999932944774627685546875);
        float2 bgUV = ((uv - float2(0.5)) / float2(bgPulse)) + float2(0.5);
        bgUV.y = 1.0 - bgUV.y;
        color = uBgImg.sample(uBgImgSmplr, fast::clamp(bgUV, float2(0.0), float2(1.0))).xyz * (1.0 + (bass * 0.1500000059604644775390625));
    }
    else
    {
        float dist = length(p);
        float hue1 = fract((_139.uTime * 0.014999999664723873138427734375) + 0.60000002384185791015625);
        float hue2 = fract((_139.uTime * 0.0199999995529651641845703125) + 0.300000011920928955078125);
        float3 param_2 = float3(hue1, 0.699999988079071044921875, 0.3499999940395355224609375 + (bass * 0.25));
        float3 c1 = hsv2rgb(param_2);
        float3 param_3 = float3(hue2, 0.800000011920928955078125, 0.100000001490116119384765625 + (bass * 0.100000001490116119384765625));
        float3 c2 = hsv2rgb(param_3);
        color = mix(c1, c2, float3(smoothstep(0.0, 0.699999988079071044921875, dist)));
        float2 param_4 = floor((uv * 35.0) + float2(_139.uTime * 0.20000000298023223876953125));
        float star = hash12(param_4);
        float starMask = smoothstep(0.949999988079071044921875, 0.980000019073486328125, star);
        color += float3((0.20000000298023223876953125 * starMask) * (0.5 + (0.5 * sin((_139.uTime * 4.0) + (star * 50.0)))));
    }
    float bassP = 0.5 + (bass * 0.5);
    for (int i = 0; i < 25; i++)
    {
        float fi = float(i);
        float2 param_5 = float2(fi, fi * 1.37000000476837158203125);
        float k = hash12(param_5);
        float z = fract(1.0 - ((t * 0.119999997317790985107421875) + k));
        float size = (1.0 - z) * 0.017999999225139617919921875;
        float2 base = float2(sin((fi * 12.8999996185302734375) + (k * 7.0)), cos((fi * 78.1999969482421875) + (k * 3.0))) * (0.5 + (0.699999988079071044921875 * k));
        float2 proj = base / float2(0.300000011920928955078125 + (1.5 * z));
        float3 param_6 = float3(fract(k + (_139.uTime * 0.07999999821186065673828125)), 0.5, 1.0);
        float3 pCol = hsv2rgb(param_6);
        float d1 = length(p - proj);
        float d2 = length(p + proj);
        float g1 = smoothstep(size, 0.0, d1);
        float g2 = smoothstep(size, 0.0, d2);
        color += (((pCol * (g1 + g2)) * bassP) * 0.60000002384185791015625);
    }
    float2 polar = float2((precise::atan2(p.x, p.y) / 6.283185482025146484375) + 0.5, length(p));
    float fftx = polar.x * 2.0;
    if (fftx > 1.0)
    {
        fftx = 2.0 - fftx;
    }
    fftx = 1.0 - fftx;
    float rGrow = bass * 0.039999999105930328369140625;
    float3 ringCol;
    for (int i_1 = 0; i_1 < 6; i_1++)
    {
        float fi_1 = float(i_1);
        float gain = 0.0599999986588954925537109375 * (1.0 - (fi_1 * 0.100000001490116119384765625));
        float thick = 0.014999999664723873138427734375 - (fi_1 * 0.001000000047497451305389404296875);
        float param_7 = fftx;
        float fftv = sampleFFT(param_7, _139);
        fftv = mix(fftv, smoothstep(0.0, 0.699999988079071044921875, fftv), 0.5);
        float radius = ((0.180000007152557373046875 + rGrow) + (fftv * gain)) - (fi_1 * 0.008000000379979610443115234375);
        if (_139.uHasRingColor > 0.5)
        {
            ringCol = float3(_139.uRingColor);
        }
        else
        {
            ringCol = _588[i_1];
        }
        float ring = smoothstep(thick, 0.0, abs(polar.y - radius));
        color = mix(color, ringCol, float3(ring * 0.85000002384185791015625));
    }
    float innerR = (0.180000007152557373046875 + rGrow) - 0.01200000010430812835693359375;
    float innerMask = smoothstep(innerR + 0.004999999888241291046142578125, innerR - 0.004999999888241291046142578125, polar.y);
    if ((_139.uHasCenter > 0.5) && (innerMask > 0.00999999977648258209228515625))
    {
        float pulse = 1.0 + (bass * 0.0500000007450580596923828125);
        float2 cUV = ((p / float2(fast::max(innerR * pulse, 9.9999997473787516355514526367188e-05))) * 0.5) + float2(0.5);
        cUV.y = 1.0 - cUV.y;
        float4 cTex = uCenterImg.sample(uCenterImgSmplr, fast::clamp(cUV, float2(0.0), float2(1.0)));
        color = mix(color, cTex.xyz * (1.0 + (bass * 0.20000000298023223876953125)), float3(innerMask * cTex.w));
    }
    else
    {
        float2 inner = p / float2(fast::max(innerR, 9.9999997473787516355514526367188e-05));
        float iDist = length(inner);
        float iAngle = precise::atan2(inner.y, inner.x);
        float hue = fract((_139.uTime * 0.039999999105930328369140625) + (sin((iAngle * 2.0) + _139.uTime) * 0.100000001490116119384765625));
        float val = mix(0.89999997615814208984375, 0.1500000059604644775390625, smoothstep(0.0, 1.0, iDist)) * (1.0 + (bass * 0.5));
        float3 param_8 = float3(hue, 0.60000002384185791015625, val);
        float3 iCol = hsv2rgb(param_8);
        iCol += float3(smoothstep(0.60000002384185791015625, 0.0, iDist) * (0.25 + (bass * 0.25)));
        color = mix(color, iCol, float3(innerMask));
    }
    color += float3(bass * 0.039999999105930328369140625);
    color *= smoothstep(0.0, 1.0, 1.7999999523162841796875 - length(p));
    float3 stage = uTexture.sample(uTextureSmplr, uv).xyz;
    out.fragColor = float4(mix(stage, color, float3(fast::clamp(_139.uIntensity, 0.0, 1.0))), 1.0);
    return out;
}
