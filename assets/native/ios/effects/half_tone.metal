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
    float uIntensity;
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

fragment vv_fmain_out fmain(constant VVUniforms& _29 [[buffer(0)]], texture2d<float> uTexture [[texture(0)]], sampler uTextureSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float2 uv = FlutterFragCoord(gl_FragCoord).xy / _29.uResolution;
    if (_29.uIntensity < 0.00999999977648258209228515625)
    {
        out.fragColor = float4(uTexture.sample(uTextureSmplr, uv).xyz, 1.0);
        return out;
    }
    float aspect = _29.uResolution.x / _29.uResolution.y;
    float2 st = uv;
    st.x *= aspect;
    st *= 80.0;
    st.x += (step(1.0, mod(st.y, 2.0)) * 0.5);
    float2 cellIndex = floor(st);
    float2 cellCenter = (cellIndex + float2(0.5)) / float2(80.0);
    cellCenter.x /= aspect;
    float3 centerColor = uTexture.sample(uTextureSmplr, cellCenter).xyz;
    float luminance = dot(centerColor, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625));
    float2 cellUV = fract(st) - float2(0.5);
    float dist = length(cellUV);
    float radius = sqrt(1.0 - luminance) * 0.5;
    float mask = smoothstep(radius, radius - 0.100000001490116119384765625, dist);
    float3 halftone = mix(float3(1.0), float3(0.0), float3(mask));
    float3 base = uTexture.sample(uTextureSmplr, uv).xyz;
    float3 finalColor = mix(base, halftone, float3(fast::clamp(_29.uIntensity, 0.0, 1.0)));
    out.fragColor = float4(finalColor, 1.0);
    return out;
}
