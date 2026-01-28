#version 460 core

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uResolution;
uniform float uTime;
uniform float uIntensity;
uniform float uSpeed;
uniform vec3 uColor;
uniform float uBars;
uniform float uFreq0;
uniform float uFreq1;
uniform float uFreq2;
uniform float uFreq3;
uniform float uFreq4;
uniform float uFreq5;
uniform float uFreq6;
uniform float uFreq7;
uniform vec3 uColor2;
uniform sampler2D uTexture;
uniform float uAspect;

out vec4 fragColor;

// Global değişkenler
vec2 iResolution;
float iTime;

const float GR = (1.0 + sqrt(5.0)) / 2.0; // Golden ratio
const float GRI = (1.0 / GR); // Inverse of the golden ratio
const float PI = 3.14159265;
const float DG_72 = PI / 2.5;
const float DG_36 = PI / 5.0;
const float COS_DG_36 = cos(DG_36);
const float SIN_DG_36 = sin(DG_36);
const float DG_18 = PI / 10.0;

// Int-Float dönüşüm hatalarını önlemek için .0 eklendi
const vec2 SUN_TRI_A = vec2(0.0, 0.0);
const vec2 SUN_TRI_B = vec2(1.0, 0.0);
const vec2 SUN_TRI_C = vec2(cos(DG_36), sin(DG_36));
const float SUN_TRI_AREA = sin(DG_18) * cos(DG_18);

void triangle_area(out float area, out float height, in vec2 A, in vec2 B, in vec2 C)
{
    area = abs((A.x * (B.y - C.y) + B.x * (C.y - A.y) + C.x * (A.y - B.y)) / 2.0);
    height = 2.0 * area / length(B - C);
}

void project_p_to_line(out float rel_proj, in vec2 P, in vec2 A, in vec2 B)
{
    vec2 ab = B - A;
    vec2 ap = P - A;
    float mag_ab = length(ab);
    rel_proj = dot(ap, ab) / (mag_ab * mag_ab);
}

void is_p_in_tri(out bool is_in, out float dist, in vec2 P, in float target_area, in vec2 A, in vec2 B, in vec2 C)
{
    float area = 0.0;
    float new_area = 0.0;
    float min_dist = 1.0;
    float new_dist = 0.0;

    triangle_area(new_area, new_dist, P, A, B);
    min_dist = min(min_dist, new_dist);
    area += new_area;

    triangle_area(new_area, new_dist, P, B, C);
    min_dist = min(min_dist, new_dist);
    area += new_area;

    triangle_area(new_area, new_dist, P, C, A);
    min_dist = min(min_dist, new_dist);
    area += new_area;

    dist = min_dist;

    float area_diff = abs(area - target_area);
    if (area_diff < 1e-6) {
        is_in = true;
    } else {
        is_in = false;
    }
}

void kite_or_dart(out float tile, out float dist, in float r, in float phi, in float steps){
    float new_phi = DG_36 - abs(DG_36 - (mod(phi, DG_72)));
    float max_r = 1.0 / (cos(new_phi) - sin(new_phi) * (COS_DG_36 - 1.0) / SIN_DG_36);
    float new_r = max_r - abs(max_r - mod(r, 2.0 * max_r));

    vec2 uv = new_r * vec2(cos(new_phi), sin(new_phi));

    float target_dart_area = SUN_TRI_AREA;
    float target_kite_area = 0.0;

    bool is_kite_ceil = false;
    bool is_kite_floor = false;
    float floor_dist = 1.0;
    float ceil_dist = 1.0;
    vec2 a = SUN_TRI_A;
    vec2 b = SUN_TRI_B;
    vec2 c = SUN_TRI_C;

    vec2 d, e, f;
    vec2 cut_start = vec2(0.0);
    vec2 cut_stop = vec2(0.0);
    float a1, a2, h1, h2;

    d = a + (b - a) / GR;
    e = b + (a - b) / GR;
    f = b + (c - b) / GR;

    bool is_in;

    // DÜZELTME: while yerine for döngüsü kullanıldı (Shader uyumluluğu için)
    // Penrose iterasyon limiti genellikle düşüktür, 20 adım güvenlidir.
    for (float i = 0.0; i < 20.0; i += 1.0) {
        if (i >= ceil(steps)) break;

        target_kite_area = target_dart_area * GRI;
        target_dart_area = target_dart_area * (1.0 - GRI);
        is_kite_floor = is_kite_ceil;
        floor_dist = ceil_dist;

        if (is_kite_floor){
            is_p_in_tri(is_in, ceil_dist, uv, target_kite_area, f, c, a);
            cut_start = a;
            cut_stop = f;
            if(is_in){
                b = c;
                c = a;
                a = f;
            } else {
                is_p_in_tri(is_in, ceil_dist, uv, target_kite_area, e, f, b);
                if(is_in){
                    cut_start = e;
                    cut_stop = f;
                    c = b;
                    a = e;
                    b = f;
                } else {
                    is_p_in_tri(is_in, ceil_dist, uv, target_dart_area, f, e, a);
                    triangle_area(a1, h1, uv, a, f);
                    triangle_area(a2, h2, uv, e, f);
                    if(h1 > h2){
                        cut_start = e;
                        cut_stop = f;
                    }
                    c = a;
                    a = f;
                    b = e;
                    is_kite_ceil = false;
                }
            }
        } else {
            is_p_in_tri(is_in, ceil_dist, uv, target_kite_area, d, c, a);
            cut_start = d;
            cut_stop = c;
            if(is_in){
                b = c;
                c = a;
                a = d;
                is_kite_ceil = true;
            } else {
                is_p_in_tri(is_in, ceil_dist, uv, target_dart_area, c, d, b);
                a = c;
                c = b;
                b = d;
            }
        }

        d = a + (b - a) / GR;
        e = b + (a - b) / GR;
        f = b + (c - b) / GR;
    }

    float p_proj;
    project_p_to_line(p_proj, uv, cut_start, cut_stop);

    float dist_factor = 1.0 - smoothstep(max(0.0, steps - floor(steps) - 0.05), min(1.0, steps - floor(steps) + 0.05), p_proj);
    dist = dist_factor * min(floor_dist, ceil_dist) + (1.0 - dist_factor) * floor_dist;
    tile = float(is_kite_floor) * (1.0 - steps + floor(steps)) + float(is_kite_ceil) * (1.0 - ceil(steps) + steps);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord * 2.0 - iResolution.xy) / iResolution.y;

    float r = length(uv);
    float phi = atan(uv.x, uv.y) + PI;

    float max_steps = 4.000;
    float steps = 1.0001 + ((sin(iTime) + 1.0) / 2.0) * max_steps;

    float tile = 0.0;
    float d = 0.0;

    phi += sin(iTime * 0.2 + 1.0) + r * sin(iTime * 0.2);

    kite_or_dart(tile, d, r, phi, steps);

    d = steps * sqrt(d) / sqrt(r);

    vec3 color = vec3((0.5 + 0.1 * tile) / d, (0.3 - 0.2 * tile) / d, (0.4 + 0.1 * tile) / d);

    fragColor = vec4(0.6 * color, 1.0);
}

void main() {
    vec2 frag = FlutterFragCoord().xy;
    vec2 fragCoord = frag;
    iResolution = uResolution;
    iTime = uTime * uSpeed;

    // Değişkeni başlatıyoruz (Hata önleyici)
    vec4 col = vec4(0.0);

    mainImage(col, fragCoord);

    col.rgb *= uIntensity;
    fragColor = col;
}