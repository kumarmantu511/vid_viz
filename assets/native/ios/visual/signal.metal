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
float grid(thread float2& uv, thread const float& t)
{
    float2 size = float2(10.0);
    uv += float2(t * 0.20000000298023223876953125, t * 0.100000001490116119384765625);
    float2 grid_1 = abs(fract(uv * size) - float2(0.5));
    float lines = smoothstep(0.4799999892711639404296875, 0.5, fast::max(grid_1.x, grid_1.y));
    return lines * 0.100000001490116119384765625;
}

static inline __attribute__((always_inline))
float hash(thread const float2& p)
{
    return fract(sin(dot(p, float2(12.98980045318603515625, 78.233001708984375))) * 43758.546875);
}

static inline __attribute__((always_inline))
float _noise(thread const float2& p)
{
    float2 i = floor(p);
    float2 f = fract(p);
    f = (f * f) * (float2(3.0) - (f * 2.0));
    float2 param = i + float2(0.0);
    float2 param_1 = i + float2(1.0, 0.0);
    float2 param_2 = i + float2(0.0, 1.0);
    float2 param_3 = i + float2(1.0);
    return mix(mix(hash(param), hash(param_1), f.x), mix(hash(param_2), hash(param_3), f.x), f.y);
}

static inline __attribute__((always_inline))
float signalWave(thread const float2& uv, thread const float& time, thread const float& freqAvg)
{
    float wave = sin((uv.x * 10.0) + (time * 2.0));
    wave += (sin((uv.x * 20.0) - (time * 5.0)) * 0.5);
    wave += (sin((uv.x * 50.0) + (time * 8.0)) * 0.20000000298023223876953125);
    float2 param = float2(uv.x * 20.0, time * 10.0);
    float n = _noise(param);
    wave += ((n - 0.5) * (0.5 + (freqAvg * 2.0)));
    return wave * 0.1500000059604644775390625;
}

fragment vv_fmain_out fmain(constant VVUniforms& _199 [[buffer(0)]], texture2d<float> uTexture [[texture(0)]], sampler uTextureSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float2 frag = FlutterFragCoord(gl_FragCoord).xy;
    float2 uv = (frag - (_199.uResolution * 0.5)) / float2(_199.uResolution.y);
    float t = _199.uTime * (0.5 + (0.5 * _199.uSpeed));
    float bass = (_199.uFreq0 + _199.uFreq1) / 2.0;
    float mid = ((_199.uFreq2 + _199.uFreq3) + _199.uFreq4) / 3.0;
    float treble = ((_199.uFreq5 + _199.uFreq6) + _199.uFreq7) / 3.0;
    float totalAudio = ((bass + mid) + treble) / 3.0;
    float3 bgCol = float3(0.0500000007450580596923828125, 0.0500000007450580596923828125, 0.07999999821186065673828125);
    float2 param = uv;
    float param_1 = t;
    float _274 = grid(param, param_1);
    float g = _274;
    bgCol += ((_199.uColor2 * g) * (0.5 + bass));
    float3 signalCol = float3(0.0);
    for (float i = 0.0; i < 3.0; i += 1.0)
    {
        float offset = (i * 0.004999999888241291046142578125) * (1.0 + (bass * 2.0));
        float2 param_2 = uv + float2(0.0, offset);
        float param_3 = t;
        float param_4 = totalAudio;
        float waveY = signalWave(param_2, param_3, param_4);
        float amplitude = (1.0 - abs(uv.x * 1.5)) * (0.5 + (totalAudio * 1.5));
        amplitude = fast::clamp(amplitude, 0.0, 1.5);
        float dist = abs(uv.y - (waveY * amplitude));
        float glow = 0.008000000379979610443115234375 / (dist + 0.001000000047497451305389404296875);
        float core = smoothstep(0.0199999995529651641845703125, 0.0, dist);
        float3 col = mix(float3(_199.uColor), _199.uColor2, float3(i * 0.5));
        signalCol += ((col * ((glow * 0.60000002384185791015625) + core)) * fast::clamp(_199.uIntensity, 0.0, 1.5));
    }
    float2 param_5 = float2(uv.y * 10.0, t * 20.0);
    float glitchX = ((_noise(param_5) * 0.00999999977648258209228515625) * bass) * _199.uIntensity;
    float4 texColor = uTexture.sample(uTextureSmplr, ((frag / _199.uResolution) + float2(glitchX, 0.0)));
    float scanline = (sin((frag.y * 0.5) + (t * 10.0)) * 0.5) + 0.5;
    float4 _418 = texColor;
    float3 _420 = _418.xyz * (0.800000011920928955078125 + (0.20000000298023223876953125 * scanline));
    texColor.x = _420.x;
    texColor.y = _420.y;
    texColor.z = _420.z;
    float3 scene = bgCol + signalCol;
    float3 finalRGB = mix(texColor.xyz, scene, float3(0.5 * _199.uIntensity));
    finalRGB += (signalCol * texColor.w);
    float vignette = 1.0 - (length(uv) * 0.5);
    finalRGB *= vignette;
    out.fragColor = float4(finalRGB, texColor.w);
    return out;
}
