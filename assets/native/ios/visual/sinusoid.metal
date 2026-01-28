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
    float3 uColor2;
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
float getWaveHeight(thread const float2& uv, thread const float& time, thread const float& audioLow, thread const float& audioHigh)
{
    float x = uv.x * 6.0;
    float y = sin(x + time) * 0.4000000059604644775390625;
    y += (sin((x * 2.099999904632568359375) + (time * 1.5)) * 0.20000000298023223876953125);
    y += (sin((x * 4.30000019073486328125) - (time * 0.800000011920928955078125)) * 0.100000001490116119384765625);
    float amp = 0.5 + (1.5 * audioLow);
    float detail = 0.5 + (2.0 * audioHigh);
    float fade = smoothstep(0.0, 0.20000000298023223876953125, uv.x) * smoothstep(1.0, 0.800000011920928955078125, uv.x);
    return ((y * amp) * fade) * 0.5;
}

fragment vv_fmain_out fmain(constant VVUniforms& _104 [[buffer(0)]], texture2d<float> uTexture [[texture(0)]], sampler uTextureSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float2 frag = FlutterFragCoord(gl_FragCoord).xy;
    float2 uv = frag / _104.uResolution;
    float time = _104.uTime * _104.uSpeed;
    float bass = (_104.uFreq0 + _104.uFreq1) * 0.5;
    float mid = ((_104.uFreq2 + _104.uFreq3) + _104.uFreq4) * 0.3300000131130218505859375;
    float treble = ((_104.uFreq5 + _104.uFreq6) + _104.uFreq7) * 0.3300000131130218505859375;
    float totalAudio = (bass + mid) + treble;
    if (totalAudio < 0.00999999977648258209228515625)
    {
        bass = 0.20000000298023223876953125;
        treble = 0.100000001490116119384765625;
    }
    float2 p = uv;
    p.y = (p.y * 2.0) - 1.0;
    float3 waveColor = float3(0.0);
    float glowWidth = 0.0199999995529651641845703125 + (0.0500000007450580596923828125 * bass);
    for (float i = 0.0; i < 3.0; i += 1.0)
    {
        float offset = ((i - 1.0) * 0.008000000379979610443115234375) * (1.0 + bass);
        float2 param = float2(uv.x + offset, uv.y);
        float param_1 = time;
        float param_2 = bass;
        float param_3 = treble;
        float waveY = getWaveHeight(param, param_1, param_2, param_3);
        float dist = abs(p.y - waveY);
        float intensity = 0.008000000379979610443115234375 / (dist + 0.001000000047497451305389404296875);
        intensity = fast::clamp(intensity, 0.0, 50.0);
        if (i == 0.0)
        {
            waveColor.x += intensity;
        }
        if (i == 1.0)
        {
            waveColor.y += intensity;
        }
        if (i == 2.0)
        {
            waveColor.z += intensity;
        }
    }
    float3 gradientCol = mix(float3(_104.uColor), _104.uColor2, float3(uv.x + (sin(time * 0.5) * 0.20000000298023223876953125)));
    float3 finalGlow = waveColor * gradientCol;
    finalGlow += (float3(smoothstep(5.0, 10.0, waveColor.x)) * 0.5);
    float4 stageTex = uTexture.sample(uTextureSmplr, (frag / _104.uResolution));
    float3 bg = stageTex.xyz;
    float3 composited = bg + (finalGlow * _104.uIntensity);
    float vignette = 1.0 - (dot(uv - float2(0.5), uv - float2(0.5)) * 1.5);
    composited *= fast::clamp(vignette, 0.699999988079071044921875, 1.0);
    out.fragColor = float4(composited, 1.0);
    return out;
}
