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

constant spvUnsafeArray<float4, 8> _706 = spvUnsafeArray<float4, 8>({ float4(1.0, 0.0, 0.0, 0.949999988079071044921875), float4(1.0, 0.5, 0.0, 0.930000007152557373046875), float4(1.0, 1.0, 0.0, 0.89999997615814208984375), float4(0.0, 1.0, 0.0, 0.87000000476837158203125), float4(0.0, 1.0, 1.0, 0.85000002384185791015625), float4(0.0, 0.0, 1.0, 0.819999992847442626953125), float4(0.800000011920928955078125, 0.0, 1.0, 0.800000011920928955078125), float4(1.0) });

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
void getBands(thread spvUnsafeArray<float, 8>& bands, constant VVUniforms& _153)
{
    bands[0] = _153.uFreq0;
    bands[1] = _153.uFreq1;
    bands[2] = _153.uFreq2;
    bands[3] = _153.uFreq3;
    bands[4] = _153.uFreq4;
    bands[5] = _153.uFreq5;
    bands[6] = _153.uFreq6;
    bands[7] = _153.uFreq7;
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
float2 uv_to_polar(thread const float2& uv)
{
    float2 polar = float2(precise::atan2(uv.x, uv.y), length(uv));
    polar.x = (polar.x / 6.283185482025146484375) + 0.5;
    return polar;
}

static inline __attribute__((always_inline))
float softFFT(thread const float& val)
{
    return (smoothstep(0.0, 1.0, val) * 0.64999997615814208984375) + (val * 0.3499999940395355224609375);
}

static inline __attribute__((always_inline))
float sampleFFT(thread const float& t, thread const spvUnsafeArray<float, 8>& b)
{
    float x = fast::clamp(t, 0.0, 1.0) * 7.0;
    float i0 = floor(x);
    float i1 = i0 + 1.0;
    if (i1 > 7.0)
    {
        i1 = 7.0;
    }
    float f = x - i0;
    f = (f * f) * (3.0 - (2.0 * f));
    float param = mix(b[int(i0)], b[int(i1)], f);
    return softFFT(param);
}

static inline __attribute__((always_inline))
float smooth_circle_polar(thread const float& len, thread const float& r, thread const float& smoothness)
{
    float dist = len - r;
    return 1.0 - smoothstep(r - (smoothness * 0.699999988079071044921875), r + (smoothness * 0.699999988079071044921875), dist);
}

fragment vv_fmain_out fmain(constant VVUniforms& _153 [[buffer(0)]], texture2d<float> uBgImg [[texture(0)]], texture2d<float> uCenterImg [[texture(1)]], texture2d<float> uTexture [[texture(2)]], sampler uBgImgSmplr [[sampler(0)]], sampler uCenterImgSmplr [[sampler(1)]], sampler uTextureSmplr [[sampler(2)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float2 frag = FlutterFragCoord(gl_FragCoord).xy;
    float2 uv = frag / _153.uResolution;
    float maxRes = fast::max(_153.uResolution.y, 1.0);
    float2 p = (frag - (_153.uResolution * 0.5)) / float2(maxRes);
    float2 gp = -p;
    float t = _153.uTime * (0.800000011920928955078125 + (0.60000002384185791015625 * _153.uSpeed));
    spvUnsafeArray<float, 8> param;
    getBands(param, _153);
    spvUnsafeArray<float, 8> bands = param;
    float bass = fast::clamp(((bands[0] + bands[1]) + bands[2]) * 0.333000004291534423828125, 0.0, 1.0);
    float3 color;
    if (_153.uHasBg > 0.5)
    {
        float bgPulse = 1.0 + (bass * 0.02999999932944774627685546875);
        float2 bgUV = ((uv - float2(0.5)) / float2(bgPulse)) + float2(0.5);
        color = uBgImg.sample(uBgImgSmplr, fast::clamp(bgUV, float2(0.0), float2(1.0))).xyz * (1.0 + (bass * 0.1500000059604644775390625));
    }
    else
    {
        float distSq = dot(gp, gp);
        float dist = sqrt(distSq);
        float hue1 = fract((_153.uTime * 0.0199999995529651641845703125) + 0.699999988079071044921875);
        float hue2 = fract((_153.uTime * 0.014999999664723873138427734375) + 0.5);
        float3 param_1 = float3(hue1, 0.60000002384185791015625, 0.4000000059604644775390625 + (bass * 0.300000011920928955078125));
        float3 centerCol = hsv2rgb(param_1);
        float3 param_2 = float3(hue2, 0.800000011920928955078125, 0.1500000059604644775390625 + (bass * 0.100000001490116119384765625));
        float3 edgeCol = hsv2rgb(param_2);
        color = mix(centerCol, edgeCol, float3(smoothstep(0.0, 0.60000002384185791015625, dist)));
        float2 param_3 = floor((uv * 40.0) + float2(_153.uTime * 0.300000011920928955078125));
        float starNoise = hash12(param_3);
        if (starNoise > 0.959999978542327880859375)
        {
            float twinkle = (sin((_153.uTime * 3.0) + (starNoise * 100.0)) * 0.5) + 0.5;
            color += float3((0.25 * twinkle) * (1.0 + bass));
        }
        color *= (1.0 + (bass * 0.20000000298023223876953125));
    }
    float bassParticle = 0.5 + (bass * 0.5);
    float tSpeed = t * 0.1500000059604644775390625;
    for (int i = 0; i < 20; i++)
    {
        float fi = float(i);
        float2 param_4 = float2(fi, fi * 1.37000000476837158203125);
        float k = hash12(param_4);
        float z = fract(1.0 - (tSpeed + k));
        float size = (1.0 - z) * 1.2000000476837158203125;
        float sizeFactor = size * 0.014999999664723873138427734375;
        float maxDist = sizeFactor * 2.5;
        float maxDistSq = maxDist * maxDist;
        float a1 = (fi * 12.98980045318603515625) + (k * 7.0);
        float a2 = (fi * 78.233001708984375) + (k * 3.0);
        float2 base = float2(sin(a1), cos(a2)) * (0.60000002384185791015625 + (0.800000011920928955078125 * k));
        float2 proj = base / float2(0.4000000059604644775390625 + (1.2000000476837158203125 * z));
        float2 diff1 = gp - proj;
        float dSq1 = dot(diff1, diff1);
        float2 diff2 = gp + proj;
        float dSq2 = dot(diff2, diff2);
        if ((dSq1 < maxDistSq) || (dSq2 < maxDistSq))
        {
            float3 param_5 = float3(fract(k + (_153.uTime * 0.100000001490116119384765625)), 0.60000002384185791015625, 1.0);
            float3 pColor = hsv2rgb(param_5);
            if (dSq1 < maxDistSq)
            {
                float dist_1 = sqrt(dSq1);
                float glow = smoothstep(sizeFactor, 0.0, dist_1);
                glow += (0.300000011920928955078125 * smoothstep(maxDist, 0.0, dist_1));
                color += ((pColor * glow) * bassParticle);
            }
            if (dSq2 < maxDistSq)
            {
                float dist_2 = sqrt(dSq2);
                float glow_1 = smoothstep(sizeFactor, 0.0, dist_2);
                glow_1 += (0.300000011920928955078125 * smoothstep(maxDist, 0.0, dist_2));
                color += ((pColor * glow_1) * bassParticle);
            }
        }
    }
    float2 pc = gp;
    float2 param_6 = pc;
    float2 polar = uv_to_polar(param_6);
    float fftx = polar.x;
    fftx *= 2.0;
    if (fftx > 1.0)
    {
        fftx = 2.0 - fftx;
    }
    fftx = 1.0 - fftx;
    float rGrow = bass * 0.02999999932944774627685546875;
    float3 ringCol;
    float ringAlpha;
    for (int i_1 = 0; i_1 < 8; i_1++)
    {
        float fi_1 = float(i_1);
        float w = 6.0 - fi_1;
        float gain = 0.054999999701976776123046875 * (0.5 + (0.5 * (w * 0.20000000298023223876953125)));
        float thick = 0.01200000010430812835693359375 - (0.006000000052154064178466796875 * (fi_1 * 0.20000000298023223876953125));
        float param_7 = fftx;
        spvUnsafeArray<float, 8> param_8 = bands;
        float fftv = sampleFFT(param_7, param_8);
        fftv = mix(fftv, smoothstep(0.0, 0.800000011920928955078125, fftv), 0.4000000059604644775390625);
        float radius = (0.119999997317790985107421875 + rGrow) + (fftv * gain);
        if (_153.uHasRingColor > 0.5)
        {
            ringCol = float3(_153.uRingColor);
            ringAlpha = 0.89999997615814208984375;
        }
        else
        {
            int colorIdx = i_1;
            float4 sc = _706[colorIdx];
            ringCol = sc.xyz;
            ringAlpha = sc.w;
        }
        float param_9 = polar.y;
        float param_10 = radius;
        float param_11 = thick;
        float ring = smooth_circle_polar(param_9, param_10, param_11);
        color += ((ringCol - color) * ((ring * ringAlpha) * 0.89999997615814208984375));
    }
    float innerRadius = (0.119999997317790985107421875 + rGrow) - 0.008000000379979610443115234375;
    float param_12 = polar.y;
    float param_13 = innerRadius;
    float param_14 = 0.0040000001899898052215576171875;
    float innerMask = smooth_circle_polar(param_12, param_13, param_14);
    if (innerMask > 0.00999999977648258209228515625)
    {
        if (_153.uHasCenter > 0.5)
        {
            float centerPulse = 1.0 + (bass * 0.0500000007450580596923828125);
            float2 centerUV = p / float2(fast::max((innerRadius * centerPulse) * 2.0, 9.9999997473787516355514526367188e-05));
            centerUV = (centerUV * 0.5) + float2(0.5);
            float4 centerTex = uCenterImg.sample(uCenterImgSmplr, fast::clamp(centerUV, float2(0.0), float2(1.0)));
            color = mix(color, centerTex.xyz * (1.0 + (bass * 0.20000000298023223876953125)), float3(innerMask * centerTex.w));
        }
        else
        {
            float2 inner = pc / float2(fast::max(innerRadius, 9.9999997473787516355514526367188e-05));
            float innerDist = length(inner);
            float innerAngle = precise::atan2(inner.y, inner.x);
            float hueBase = fract(_153.uTime * 0.0500000007450580596923828125);
            float hueVar = sin((innerAngle * 3.0) + (_153.uTime * 0.5)) * 0.100000001490116119384765625;
            float innerVal = (0.800000011920928955078125 - (0.60000002384185791015625 * smoothstep(0.0, 1.0, innerDist))) * (1.0 + (bass * 0.4000000059604644775390625));
            float3 param_15 = float3(hueBase + hueVar, 0.699999988079071044921875, innerVal);
            float3 innerCol = hsv2rgb(param_15);
            innerCol += float3(smoothstep(0.5, 0.0, innerDist) * (0.300000011920928955078125 + (bass * 0.300000011920928955078125)));
            float3 param_16 = float3(hueBase + 0.5, 0.800000011920928955078125, (smoothstep(0.699999988079071044921875, 1.0, innerDist) * smoothstep(1.2000000476837158203125, 0.89999997615814208984375, innerDist)) * 0.5);
            innerCol += hsv2rgb(param_16);
            color = mix(color, innerCol, float3(innerMask));
        }
    }
    color += float3(bass * 0.0500000007450580596923828125);
    color *= smoothstep(0.0, 1.0, 1.7000000476837158203125 - length(p));
    float3 stage = uTexture.sample(uTextureSmplr, uv).xyz;
    out.fragColor = float4(mix(stage, color, float3(fast::clamp(_153.uIntensity, 0.0, 1.0))), 1.0);
    return out;
}
