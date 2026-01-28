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
float colFn(thread const float2& coord, thread const float& time)
{
    float delta_theta = 0.89759790897369384765625;
    float acc = 0.0;
    float t_speed = time * 0.20000000298023223876953125;
    float t_speed_x = time * 0.300000011920928955078125;
    float t_speed_y = time * 0.300000011920928955078125;
    for (int i = 0; i < 8; i++)
    {
        float theta = delta_theta * float(i);
        float ct = cos(theta);
        float st = sin(theta);
        float ax = (coord.x + (ct * t_speed)) + t_speed_x;
        float ay = (coord.y - (st * t_speed)) - t_speed_y;
        acc += (cos(((ax * ct) - (ay * st)) * 6.0) * 2.400000095367431640625);
    }
    return cos(acc);
}

fragment vv_fmain_out fmain(constant VVUniforms& _117 [[buffer(0)]], texture2d<float> uTexture [[texture(0)]], sampler uTextureSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float2 frag = FlutterFragCoord(gl_FragCoord).xy;
    float2 p = frag / _117.uResolution;
    if (_117.uIntensity < 0.001000000047497451305389404296875)
    {
        out.fragColor = float4(uTexture.sample(uTextureSmplr, p).xyz, 1.0);
        return out;
    }
    float time = _117.uTime * 1.2999999523162841796875;
    float2 param = p;
    float param_1 = time;
    float cc1 = colFn(param, param_1);
    float2 off = float2(1.0 / _117.uResolution.x, 1.0 / _117.uResolution.y) * 60.0;
    float2 param_2 = p + float2(off.x, 0.0);
    float param_3 = time;
    float cc2_x = colFn(param_2, param_3);
    float dx = (0.5 * (cc1 - cc2_x)) / 60.0;
    float2 param_4 = p + float2(0.0, off.y);
    float param_5 = time;
    float cc2_y = colFn(param_4, param_5);
    float dy = (0.5 * (cc1 - cc2_y)) / 60.0;
    float2 c1 = p + float2(dx * 2.0, (-dy) * 2.0);
    c1 = fast::clamp(c1, float2(0.0), float2(1.0));
    float alpha = 1.0 + ((dx * dy) * 700.0);
    float ddx = dx - 0.01200000010430812835693359375;
    float ddy = dy - 0.01200000010430812835693359375;
    if ((ddx > 0.0) && (ddy > 0.0))
    {
        alpha = powr(alpha, (ddx * ddy) * 200000.0);
    }
    alpha = fast::clamp(alpha, 0.0, 2.0);
    float3 base = uTexture.sample(uTextureSmplr, p).xyz;
    float3 warped = uTexture.sample(uTextureSmplr, c1).xyz * alpha;
    float3 finalColor = mix(base, warped, float3(fast::clamp(_117.uIntensity, 0.0, 1.0)));
    out.fragColor = float4(finalColor, 1.0);
    return out;
}
