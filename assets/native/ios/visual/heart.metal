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
    float3 uColor;
    packed_float3 uColor2;
    float uFreq0;
    float uFreq1;
    float uFreq2;
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
float pmin(thread const float& a, thread const float& b, thread const float& k)
{
    float h = fast::clamp(0.5 + ((0.5 * (b - a)) / k), 0.0, 1.0);
    return mix(b, a, h) - ((k * h) * (1.0 - h));
}

static inline __attribute__((always_inline))
float pabs(thread const float& a, thread const float& k)
{
    float param = a;
    float param_1 = -a;
    float param_2 = k;
    return -pmin(param, param_1, param_2);
}

static inline __attribute__((always_inline))
float dot2(thread const float2& p)
{
    return dot(p, p);
}

static inline __attribute__((always_inline))
float heart(thread float2& p)
{
    float param = p.x;
    float param_1 = 0.0500000007450580596923828125;
    p.x = pabs(param, param_1);
    if ((p.y + p.x) > 1.0)
    {
        float2 param_2 = p - float2(0.25, 0.75);
        return sqrt(dot2(param_2)) - 0.3535533845424652099609375;
    }
    float2 param_3 = p - float2(0.0, 1.0);
    float2 param_4 = p - float2(0.5 * fast::max(p.x + p.y, 0.0));
    return sqrt(fast::min(dot2(param_3), dot2(param_4))) * sign(p.x - p.y);
}

static inline __attribute__((always_inline))
float df(thread const float2& p)
{
    float2 hp = p;
    float hz = 1.0;
    hp /= float2(hz);
    hp.y -= (-0.60000002384185791015625);
    float2 param = hp;
    float _303 = heart(param);
    return _303 * hz;
}

static inline __attribute__((always_inline))
float tanh_approx(thread const float& x)
{
    float x2 = x * x;
    return fast::clamp((x * (27.0 + x2)) / (27.0 + (9.0 * x2)), -1.0, 1.0);
}

static inline __attribute__((always_inline))
float hf(thread const float2& p)
{
    float2 param = p;
    float d = df(param);
    float h = (-20.0) * d;
    float param_1 = h;
    h = tanh_approx(param_1);
    h -= (3.0 * length(p));
    float param_2 = h;
    float param_3 = 0.0;
    float param_4 = 1.0;
    h = pmin(param_2, param_3, param_4);
    h *= 0.25;
    return h;
}

static inline __attribute__((always_inline))
float3 nf(thread const float2& p, constant VVUniforms& _338)
{
    float2 e = float2(5.0 / _338.uResolution.y, 0.0);
    float2 param = p + e;
    float2 param_1 = p - e;
    float3 n;
    n.x = hf(param) - hf(param_1);
    float2 param_2 = p + e.yx;
    float2 param_3 = p - e.yx;
    n.y = hf(param_2) - hf(param_3);
    n.z = 2.0 * e.x;
    return fast::normalize(n);
}

static inline __attribute__((always_inline))
float3 hsv2rgb(thread const float3& c)
{
    float4 K = float4(1.0, 0.666666686534881591796875, 0.3333333432674407958984375, 3.0);
    float3 p = abs((fract(c.xxx + K.xyz) * 6.0) - K.www);
    return mix(K.xxx, fast::clamp(p - K.xxx, float3(0.0), float3(1.0)), float3(c.y)) * c.z;
}

static inline __attribute__((always_inline))
float2 hash(thread float2& p)
{
    p = float2(dot(p, float2(127.09999847412109375, 311.70001220703125)), dot(p, float2(269.5, 183.3000030517578125)));
    return float2(-1.0) + (fract(sin(p) * 43758.546875) * 2.0);
}

static inline __attribute__((always_inline))
float _noise(thread const float2& p)
{
    float2 i = floor(p + float2((p.x + p.y) * 0.3660254180431365966796875));
    float2 a = (p - i) + float2((i.x + i.y) * 0.211324870586395263671875);
    float2 o = step(a.yx, a);
    float2 b = (a - o) + float2(0.211324870586395263671875);
    float2 c = (a - float2(1.0)) + float2(0.42264974117279052734375);
    float3 h = fast::max(float3(0.5) - float3(dot(a, a), dot(b, b), dot(c, c)), float3(0.0));
    float2 param = i + float2(0.0);
    float2 _474 = hash(param);
    float2 param_1 = i + o;
    float2 _481 = hash(param_1);
    float2 param_2 = i + float2(1.0);
    float2 _488 = hash(param_2);
    float3 n = (((h * h) * h) * h) * float3(dot(a, _474), dot(b, _481), dot(c, _488));
    return dot(n, float3(70.0));
}

static inline __attribute__((always_inline))
float fbm(thread const float2& pos, thread const float& tm)
{
    float2 offset = float2(cos(tm), sin(tm * 0.707106769084930419921875));
    float aggr = 0.0;
    float2 param = pos;
    aggr += _noise(param);
    float2 param_1 = pos + offset;
    aggr += (_noise(param_1) * 0.5);
    float2 param_2 = pos + offset.yx;
    aggr += (_noise(param_2) * 0.25);
    float2 param_3 = pos - offset;
    aggr += (_noise(param_3) * 0.125);
    aggr /= 1.9375;
    return (aggr * 0.5) + 0.5;
}

static inline __attribute__((always_inline))
float divf(thread const float& offset, thread const float& f)
{
    float r = abs((0.20000000298023223876953125 + offset) - f);
    return fast::max(r, 0.001000000047497451305389404296875);
}

static inline __attribute__((always_inline))
float3 lightning(thread const float2& pos, thread const float2& pp, thread const float& offset, thread const float& beatIntensity, constant VVUniforms& _338)
{
    float3 sub = float3(0.0599999986588954925537109375, 0.02999999932944774627685546875, 0.0) * length(pp);
    float time = (_338.uTime * _338.uSpeed) + 123.40000152587890625;
    float stime = time / 200.0;
    float3 col = float3(0.0);
    float2 f = (cos(float2(0.707106769084930419921875, 1.0) * stime) * 10.0) + (float2(0.0, -11.0) * stime);
    float glow = 0.012500000186264514923095703125 + (beatIntensity * 0.0199999995529651641845703125);
    for (float i = 0.0; i < 2.0; i += 1.0)
    {
        float3 gcol0 = float3(1.0) + cos(((float3(0.0, 0.5, 1.0) + float3(time)) + float3(3.0 * pos.x)) - float3(0.3300000131130218505859375 * i));
        gcol0 = mix(gcol0, _338.uColor * 2.0, float3(0.5));
        float3 gcol1 = float3(1.0) + cos(((float3(0.0, 1.25, 2.5) + float3(2.0 * time)) + float3(pos.y)) + float3(0.25 * i));
        gcol1 = mix(gcol1, float3(_338.uColor2) * 2.0, float3(0.5));
        float btime = (stime * 85.0) + i;
        float rtime = (stime * 75.0) + i;
        float2 param = (pos + f) * 3.0;
        float param_1 = rtime;
        float param_2 = offset;
        float param_3 = fbm(param, param_1);
        float div1 = divf(param_2, param_3);
        float2 param_4 = (pos + f) * 2.0;
        float param_5 = btime;
        float param_6 = offset;
        float param_7 = fbm(param_4, param_5);
        float div2 = divf(param_6, param_7);
        float d1 = (offset * glow) / div1;
        float d2 = (offset * glow) / div2;
        col += ((gcol0 * d1) - sub);
        col += ((gcol1 * d2) - sub);
    }
    return col;
}

static inline __attribute__((always_inline))
float3 aces_approx(thread float3& v)
{
    v = fast::max(v, float3(0.0));
    v *= 0.60000002384185791015625;
    float a = 2.5099999904632568359375;
    float b = 0.02999999932944774627685546875;
    float c = 2.4300000667572021484375;
    float d = 0.589999973773956298828125;
    float e = 0.14000000059604644775390625;
    return fast::clamp((v * ((v * a) + float3(b))) / ((v * ((v * c) + float3(d))) + float3(e)), float3(0.0), float3(1.0));
}

static inline __attribute__((always_inline))
float3 effect(thread const float2& p, thread const float2& pp, thread const float& beat, constant VVUniforms& _338)
{
    float aa = 4.0 / _338.uResolution.y;
    float2 param = p;
    float d = df(param);
    float2 param_1 = p;
    float h = hf(param_1);
    float2 param_2 = p;
    float3 n = nf(param_2, _338);
    float3 p3 = float3(p, h);
    float3 rd = fast::normalize(p3 - float3(0.0, 0.0, 10.0));
    float3 ld = fast::normalize(float3(-4.0, -5.0, 3.0) - p3);
    float3 r = reflect(rd, n);
    float diff = fast::max(dot(ld, n), 0.0);
    float3 param_3 = float3(0.9900000095367431640625, 0.949999988079071044921875, 0.60000002384185791015625);
    float3 bloodRed = hsv2rgb(param_3);
    float3 param_4 = float3(0.0, 0.89999997615814208984375, 0.800000011920928955078125);
    float3 brightRed = hsv2rgb(param_4);
    float3 shadowCol = float3(0.100000001490116119384765625, 0.0, 0.0);
    float3 dcol = mix(shadowCol, bloodRed, float3(smoothstep(0.0, 0.5, diff)));
    dcol = mix(dcol, brightRed, float3(smoothstep(0.5, 1.0, diff)));
    float spe = powr(fast::max(dot(ld, r), 0.0), 12.0);
    float3 wetSpec = float3(0.800000011920928955078125, 0.63999998569488525390625, 0.63999998569488525390625);
    float3 scol = wetSpec * spe;
    float gd = d;
    float2 gp = p;
    float2 param_5 = gp;
    float2 param_6 = pp;
    float param_7 = gd;
    float param_8 = beat;
    float3 gcol = lightning(param_5, param_6, param_7, param_8, _338);
    float3 hcol = dcol + scol;
    float3 col = float3(0.0);
    float3 param_9 = float3(0.9900000095367431640625, 1.0, 0.004999999888241291046142578125);
    float3 gbcol = hsv2rgb(param_9) * (1.0 + (beat * 5.0));
    float2 param_10 = p;
    col += (gbcol / float3(fast::max(0.00999999977648258209228515625 * (dot2(param_10) - 0.100000001490116119384765625), 9.9999997473787516355514526367188e-05)));
    col += gcol;
    col = mix(col, hcol, float3(smoothstep(0.0, -aa, d)));
    float3 param_11 = float3(0.0199999995529651641845703125, 1.0, 2.0);
    float3 rimColor = hsv2rgb(param_11);
    float rimWidth = 0.014999999664723873138427734375;
    float rimMask = smoothstep(0.0, -aa, abs(d + rimWidth) - rimWidth);
    float fresnel = powr(1.0 - fast::max(dot(n, -rd), 0.0), 3.0);
    col = mix(col, rimColor, float3((rimMask * fresnel) * 0.800000011920928955078125));
    col *= smoothstep(1.7999999523162841796875, 0.5, length(pp));
    float3 param_12 = col;
    float3 _905 = aces_approx(param_12);
    col = _905;
    col = sqrt(col);
    return col;
}

fragment vv_fmain_out fmain(constant VVUniforms& _338 [[buffer(0)]], texture2d<float> uTexture [[texture(0)]], sampler uTextureSmplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float2 frag = FlutterFragCoord(gl_FragCoord).xy;
    float2 res = _338.uResolution;
    float bass = (_338.uFreq0 + _338.uFreq1) * 0.5;
    float beat = smoothstep(0.20000000298023223876953125, 0.800000011920928955078125, bass);
    float2 q = frag / res;
    float2 p = float2(-1.0) + (q * 2.0);
    p.y = -p.y;
    float2 pp = p;
    p.x *= (res.x / res.y);
    float zoom = 1.0 - (beat * 0.100000001490116119384765625);
    p *= zoom;
    float2 param = p;
    float2 param_1 = pp;
    float param_2 = beat;
    float3 col = effect(param, param_1, param_2, _338);
    float2 uv = frag / res;
    float3 stage = uTexture.sample(uTextureSmplr, uv).xyz;
    float3 finalMix = mix(stage, col, float3(fast::clamp(_338.uIntensity, 0.0, 1.0)));
    out.fragColor = float4(finalMix, 1.0);
    return out;
}
