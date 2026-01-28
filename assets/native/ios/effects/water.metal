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
    float2 iResolution;
    float iTime;
    float uIntensity;
    float uSpeed;
    float uFrequency;
    float uAmplitude;
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

fragment vv_fmain_out fmain(constant VVUniforms& _31 [[buffer(0)]], texture2d<float> iChannel0 [[texture(0)]], sampler iChannel0Smplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float2 fragCoord = FlutterFragCoord(gl_FragCoord).xy;
    float2 uv = fragCoord / _31.iResolution;
    float2 posFromCenter = uv - float2(0.5);
    float _distance = length(posFromCenter);
    float delay = _distance / _31.uSpeed;
    float time = fast::max(0.0, _31.iTime - delay);
    float waveBase = sin(_31.uFrequency * time) * exp((-0.5) * time);
    float ampFactor = _31.uAmplitude * 0.0500000007450580596923828125;
    float rippleAmount = ampFactor * waveBase;
    float2 n = posFromCenter / float2(fast::max(_distance, 9.9999997473787516355514526367188e-05));
    float2 newPosition = uv + (n * rippleAmount);
    float3 color = iChannel0.sample(iChannel0Smplr, newPosition).xyz;
    color += float3((_31.uIntensity * 0.100000001490116119384765625) * waveBase);
    out.fragColor = float4(color, 1.0);
    return out;
}
