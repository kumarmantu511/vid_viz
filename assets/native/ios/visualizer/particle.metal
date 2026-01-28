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
float2 polar(thread const float2& dPoint)
{
    float r = length(dPoint);
    return float2(r, precise::atan2(dPoint.y, dPoint.x));
}

static inline __attribute__((always_inline))
float rand(thread const float2& co)
{
    return fract(sin(dot(co, float2(12.98980045318603515625, 78.233001708984375))) * 43758.546875);
}

static inline __attribute__((always_inline))
float2 decart(thread const float2& pPoint)
{
    float c = cos(pPoint.y);
    float s = sin(pPoint.y);
    return float2(c, s) * pPoint.x;
}

fragment vv_fmain_out fmain(constant VVUniforms& _83 [[buffer(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float3 iResolution = float3(_83.uResolution, 1.0);
    float iTime = _83.uTime * _83.uSpeed;
    float2 fragCoord = FlutterFragCoord(gl_FragCoord).xy;
    float2 flippedCoord = float2(fragCoord.x, iResolution.y - fragCoord.y);
    float2 center = iResolution.xy * 0.5;
    float2 frag = flippedCoord - center;
    float2 param = frag;
    float2 fragPolar = polar(param);
    float lenCenter = length(center);
    float globTime = iTime / 15.0;
    float timeDelta = 720.0;
    float polarRadiusDelta = 0.699999988079071044921875;
    float presence = 0.0;
    float2 pPoint;
    for (float i = 0.0; i < 150.0; i += 1.0)
    {
        float phase = i / 150.0;
        float localTime = (globTime + (timeDelta * ((2.0 * phase) - 1.0))) + phase;
        float particleTime = fract(localTime);
        float pt2 = particleTime * particleTime;
        float pt4 = pt2 * pt2;
        float spaceTransform = pt4 * pt4;
        pPoint.x = lenCenter * ((0.0500000007450580596923828125 + (polarRadiusDelta * phase)) + spaceTransform);
        float distCheck = abs(pPoint.x - fragPolar.x);
        if (distCheck > 25.0)
        {
            continue;
        }
        float seed = floor(localTime);
        float2 param_1 = float2(mod(seed, 10000.0), 1.0);
        pPoint.y = floor(particleTime + (720.0 * rand(param_1))) * 0.008714542724192142486572265625;
        float2 param_2 = pPoint;
        float2 dPoint = decart(param_2);
        float dist = length(dPoint - frag);
        float particleSize = 25.0 * spaceTransform;
        float localPresence = smoothstep(particleSize * 1.2000000476837158203125, 0.0, dist);
        presence += localPresence;
    }
    float centerMask = smoothstep(10.0, 50.0, fragPolar.x);
    presence *= centerMask;
    presence = fast::clamp(presence * 0.5, 0.0, 1.0);
    float alpha = presence;
    float tcol = fast::clamp(fragPolar.x / fast::max(lenCenter, 1.0), 0.0, 1.0);
    float3 tint = mix(float3(_83.uColor), float3(_83.uColor2), float3(tcol));
    float3 color = tint * alpha;
    out.fragColor = float4(color, alpha);
    return out;
}
