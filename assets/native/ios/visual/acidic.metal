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
float2x2 rotate(thread const float& angle)
{
    float s = sin(angle);
    float c = cos(angle);
    return float2x2(float2(c, -s), float2(s, c));
}

static inline __attribute__((always_inline))
float3 palette2(thread const float& t, thread const float& u)
{
    float mu = u / 1.0;
    float3 a = float3(0.53799998760223388671875 - mu, 0.3580000102519989013671875, 1.3580000400543212890625 + mu);
    float3 b = float3(0.1879999935626983642578125 + mu, 0.097999997437000274658203125, 0.301999986171722412109375);
    float3 c = float3(3.138000011444091796875 - mu, 1.427999973297119140625, 0.13799999654293060302734375);
    float3 d = float3(0.100000001490116119384765625, 0.60000002384185791015625, 0.9179999828338623046875);
    return a + (b * cos(((c * t) + d) * 7.28318023681640625));
}

fragment vv_fmain_out fmain(constant VVUniforms& _107 [[buffer(0)]], texture2d<float> uTexture [[texture(0)]], sampler uTextureSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float2 frag = FlutterFragCoord(gl_FragCoord).xy;
    float2 uv = ((frag * 2.0) - _107.uResolution) / float2(_107.uResolution.y);
    float2 uv0 = uv;
    float3 finalColor = float3(0.0);
    float time = _107.uTime * _107.uSpeed;
    float bass = (0.699999988079071044921875 * _107.uFreq0) + (0.300000011920928955078125 * _107.uFreq1);
    float mid = ((_107.uFreq2 + _107.uFreq3) + _107.uFreq4) / 3.0;
    float high = ((_107.uFreq5 + _107.uFreq6) + _107.uFreq7) / 3.0;
    float audioLevel = fast::clamp((bass + mid) + high, 0.0, 1.0);
    float colorVariance = sin((time * 3.141590118408203125) / 4.0);
    float direction = sin((time * 3.141590118408203125) / 4.0);
    float rotationAngle = (direction * smoothstep(0.0, 1.0, bass)) * 1.10000002384185791015625;
    float baseBrightness = 0.1500000059604644775390625;
    float boostBrightness = 5.0 + (1.0 * high);
    for (float i = 0.0; i < 4.0; i += 1.0)
    {
        uv = fract(uv * (1.2000000476837158203125 + (direction / 8.0))) - float2(0.5);
        float param = rotationAngle;
        uv = rotate(param) * uv;
        float d = length(uv) * 1.2999999523162841796875;
        float param_1 = (length(uv0) + time) + direction;
        float param_2 = colorVariance;
        float3 col = palette2(param_1, param_2);
        d = sin(((d * 8.0) + time) + (bass / 10.0));
        d = abs(d);
        d = exp(((-12.0) + (bass / 0.5)) * d);
        float brightness = baseBrightness + (boostBrightness * audioLevel);
        finalColor += ((col * d) * brightness);
    }
    float gy = fast::clamp(frag.y / fast::max(_107.uResolution.y, 1.0), 0.0, 1.0);
    float3 grad = mix(float3(_107.uColor), _107.uColor2, float3(gy));
    float3 effect = finalColor * mix(float3(1.0), fast::normalize(grad + float3(0.001000000047497451305389404296875)), float3(0.25));
    float3 tex = uTexture.sample(uTextureSmplr, (frag / _107.uResolution)).xyz;
    float3 finalMix = mix(tex, effect, float3(fast::clamp(_107.uIntensity, 0.0, 1.0)));
    out.fragColor = float4(finalMix, 1.0);
    return out;
}
