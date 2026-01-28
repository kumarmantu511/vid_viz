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
    float uAspect;
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
void triangle_area(thread float& area, thread float& height, thread const float2& A, thread const float2& B, thread const float2& C)
{
    area = abs((((A.x * (B.y - C.y)) + (B.x * (C.y - A.y))) + (C.x * (A.y - B.y))) / 2.0);
    height = (2.0 * area) / length(B - C);
}

static inline __attribute__((always_inline))
void is_p_in_tri(thread bool& is_in, thread float& dist, thread const float2& P, thread const float& target_area, thread const float2& A, thread const float2& B, thread const float2& C)
{
    float area = 0.0;
    float new_area = 0.0;
    float min_dist = 1.0;
    float new_dist = 0.0;
    float2 param_2 = P;
    float2 param_3 = A;
    float2 param_4 = B;
    float param;
    float param_1;
    triangle_area(param, param_1, param_2, param_3, param_4);
    new_area = param;
    new_dist = param_1;
    min_dist = fast::min(min_dist, new_dist);
    area += new_area;
    float2 param_7 = P;
    float2 param_8 = B;
    float2 param_9 = C;
    float param_5;
    float param_6;
    triangle_area(param_5, param_6, param_7, param_8, param_9);
    new_area = param_5;
    new_dist = param_6;
    min_dist = fast::min(min_dist, new_dist);
    area += new_area;
    float2 param_12 = P;
    float2 param_13 = C;
    float2 param_14 = A;
    float param_10;
    float param_11;
    triangle_area(param_10, param_11, param_12, param_13, param_14);
    new_area = param_10;
    new_dist = param_11;
    min_dist = fast::min(min_dist, new_dist);
    area += new_area;
    dist = min_dist;
    float area_diff = abs(area - target_area);
    if (area_diff < 9.9999999747524270787835121154785e-07)
    {
        is_in = true;
    }
    else
    {
        is_in = false;
    }
}

static inline __attribute__((always_inline))
void project_p_to_line(thread float& rel_proj, thread const float2& P, thread const float2& A, thread const float2& B)
{
    float2 ab = B - A;
    float2 ap = P - A;
    float mag_ab = length(ab);
    rel_proj = dot(ap, ab) / (mag_ab * mag_ab);
}

static inline __attribute__((always_inline))
void kite_or_dart(thread float& tile, thread float& dist, thread const float& r, thread const float& phi, thread const float& steps)
{
    float new_phi = 0.6283185482025146484375 - abs(0.6283185482025146484375 - mod(phi, 1.256637096405029296875));
    float max_r = 1.0 / (cos(new_phi) - ((sin(new_phi) * (-0.19098301231861114501953125)) / 0.587785243988037109375));
    float new_r = max_r - abs(max_r - mod(r, 2.0 * max_r));
    float2 uv = float2(cos(new_phi), sin(new_phi)) * new_r;
    float target_dart_area = 0.2938926219940185546875;
    float target_kite_area = 0.0;
    bool is_kite_ceil = false;
    bool is_kite_floor = false;
    float floor_dist = 1.0;
    float ceil_dist = 1.0;
    float2 a = float2(0.0);
    float2 b = float2(1.0, 0.0);
    float2 c = float2(0.809017002582550048828125, 0.587785243988037109375);
    float2 cut_start = float2(0.0);
    float2 cut_stop = float2(0.0);
    float2 d = a + ((b - a) / float2(1.61803400516510009765625));
    float2 e = b + ((a - b) / float2(1.61803400516510009765625));
    float2 f = b + ((c - b) / float2(1.61803400516510009765625));
    bool is_in;
    bool param;
    float param_1;
    bool param_7;
    float param_8;
    bool param_14;
    float param_15;
    float param_21;
    float param_22;
    float param_26;
    float param_27;
    bool param_31;
    float param_32;
    bool param_38;
    float param_39;
    for (float i = 0.0; i < 20.0; i += 1.0)
    {
        if (i >= ceil(steps))
        {
            break;
        }
        target_kite_area = target_dart_area * 0.61803400516510009765625;
        target_dart_area *= 0.3819660246372222900390625;
        is_kite_floor = is_kite_ceil;
        floor_dist = ceil_dist;
        if (is_kite_floor)
        {
            float2 param_2 = uv;
            float param_3 = target_kite_area;
            float2 param_4 = f;
            float2 param_5 = c;
            float2 param_6 = a;
            is_p_in_tri(param, param_1, param_2, param_3, param_4, param_5, param_6);
            is_in = param;
            ceil_dist = param_1;
            cut_start = a;
            cut_stop = f;
            if (is_in)
            {
                b = c;
                c = a;
                a = f;
            }
            else
            {
                float2 param_9 = uv;
                float param_10 = target_kite_area;
                float2 param_11 = e;
                float2 param_12 = f;
                float2 param_13 = b;
                is_p_in_tri(param_7, param_8, param_9, param_10, param_11, param_12, param_13);
                is_in = param_7;
                ceil_dist = param_8;
                if (is_in)
                {
                    cut_start = e;
                    cut_stop = f;
                    c = b;
                    a = e;
                    b = f;
                }
                else
                {
                    float2 param_16 = uv;
                    float param_17 = target_dart_area;
                    float2 param_18 = f;
                    float2 param_19 = e;
                    float2 param_20 = a;
                    is_p_in_tri(param_14, param_15, param_16, param_17, param_18, param_19, param_20);
                    is_in = param_14;
                    ceil_dist = param_15;
                    float2 param_23 = uv;
                    float2 param_24 = a;
                    float2 param_25 = f;
                    triangle_area(param_21, param_22, param_23, param_24, param_25);
                    float a1 = param_21;
                    float h1 = param_22;
                    float2 param_28 = uv;
                    float2 param_29 = e;
                    float2 param_30 = f;
                    triangle_area(param_26, param_27, param_28, param_29, param_30);
                    float a2 = param_26;
                    float h2 = param_27;
                    if (h1 > h2)
                    {
                        cut_start = e;
                        cut_stop = f;
                    }
                    c = a;
                    a = f;
                    b = e;
                    is_kite_ceil = false;
                }
            }
        }
        else
        {
            float2 param_33 = uv;
            float param_34 = target_kite_area;
            float2 param_35 = d;
            float2 param_36 = c;
            float2 param_37 = a;
            is_p_in_tri(param_31, param_32, param_33, param_34, param_35, param_36, param_37);
            is_in = param_31;
            ceil_dist = param_32;
            cut_start = d;
            cut_stop = c;
            if (is_in)
            {
                b = c;
                c = a;
                a = d;
                is_kite_ceil = true;
            }
            else
            {
                float2 param_40 = uv;
                float param_41 = target_dart_area;
                float2 param_42 = c;
                float2 param_43 = d;
                float2 param_44 = b;
                is_p_in_tri(param_38, param_39, param_40, param_41, param_42, param_43, param_44);
                is_in = param_38;
                ceil_dist = param_39;
                a = c;
                c = b;
                b = d;
            }
        }
        d = a + ((b - a) / float2(1.61803400516510009765625));
        e = b + ((a - b) / float2(1.61803400516510009765625));
        f = b + ((c - b) / float2(1.61803400516510009765625));
    }
    float2 param_46 = uv;
    float2 param_47 = cut_start;
    float2 param_48 = cut_stop;
    float param_45;
    project_p_to_line(param_45, param_46, param_47, param_48);
    float p_proj = param_45;
    float dist_factor = 1.0 - smoothstep(fast::max(0.0, (steps - floor(steps)) - 0.0500000007450580596923828125), fast::min(1.0, (steps - floor(steps)) + 0.0500000007450580596923828125), p_proj);
    dist = (dist_factor * fast::min(floor_dist, ceil_dist)) + ((1.0 - dist_factor) * floor_dist);
    tile = (float(is_kite_floor) * ((1.0 - steps) + floor(steps))) + (float(is_kite_ceil) * ((1.0 - ceil(steps)) + steps));
}

static inline __attribute__((always_inline))
void mainImage(thread float4& fragColor, thread const float2& fragCoord, thread float2& iResolution, thread float& iTime)
{
    float2 uv = ((fragCoord * 2.0) - iResolution) / float2(iResolution.y);
    float r = length(uv);
    float phi = precise::atan2(uv.x, uv.y) + 3.1415927410125732421875;
    float max_steps = 4.0;
    float steps = 1.00010001659393310546875 + (((sin(iTime) + 1.0) / 2.0) * max_steps);
    float tile = 0.0;
    float d = 0.0;
    phi += (sin((iTime * 0.20000000298023223876953125) + 1.0) + (r * sin(iTime * 0.20000000298023223876953125)));
    float param_2 = r;
    float param_3 = phi;
    float param_4 = steps;
    float param;
    float param_1;
    kite_or_dart(param, param_1, param_2, param_3, param_4);
    tile = param;
    d = param_1;
    d = (steps * sqrt(d)) / sqrt(r);
    float3 color = float3((0.5 + (0.100000001490116119384765625 * tile)) / d, (0.300000011920928955078125 - (0.20000000298023223876953125 * tile)) / d, (0.4000000059604644775390625 + (0.100000001490116119384765625 * tile)) / d);
    fragColor = float4(color * 0.60000002384185791015625, 1.0);
}

fragment vv_fmain_out fmain(constant VVUniforms& _622 [[buffer(0)]], float4 gl_FragCoord [[position]])
{
    vv_fmain_out out = {};
    float2 frag = FlutterFragCoord(gl_FragCoord).xy;
    float2 fragCoord = frag;
    float2 iResolution = _622.uResolution;
    float iTime = _622.uTime * _622.uSpeed;
    float4 col = float4(0.0);
    float2 param_1 = fragCoord;
    float4 param;
    mainImage(param, param_1, iResolution, iTime);
    col = param;
    float4 _646 = col;
    float3 _648 = _646.xyz * _622.uIntensity;
    col.x = _648.x;
    col.y = _648.y;
    col.z = _648.z;
    out.fragColor = col;
    return out;
}
