#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;   // 0,1
uniform float uTime;        // 2
uniform float uIntensity;   // 3
uniform float uSpeed;       // 4
uniform float uAngle;       // 5
uniform float uThickness;   // 6
uniform vec3 uColorA;       // 7,8,9
uniform vec3 uColorB;       // 10,11,12

out vec4 fragColor;

float hash(vec2 p){
    p = fract(p*vec2(23.34, 45.45));
    p += dot(p, p+34.45);
    return fract(p.x*p.y);
}

void main(){
    vec2 frag = FlutterFragCoord().xy;
    vec2 res = max(uResolution, vec2(1.0));
    vec2 uv = frag / res;

    float t = uTime * uSpeed;
    float ang = radians(uAngle);
    vec2 dir = vec2(cos(ang), sin(ang));
    vec3 base = mix(uColorA, uColorB, uv.x);

    // moving glint line
    float line = smoothstep(0.0, 1.0, 1.0 - abs(dot(uv-0.5, dir) - fract(t)) * (20.0 + 40.0*uThickness));
    float spark = 0.0;

    // scattered small sparkles
    for(int k=0; k<3; k++){
        // HATA DÜZELTİLDİ: 'k' yerine 'float(k)' yazıldı.
        // int ile float çarpılamaz, cast etmek gerekir.
        vec2 cell = floor((uv + float(k)*0.13) * (6.0 + 10.0*uThickness));

        float h = hash(cell + floor(t));
        vec2 p = fract(uv * (6.0 + 10.0*uThickness));
        float d = length(p - vec2(h, fract(h*7.0)));
        spark += smoothstep(0.2, 0.0, d) * 0.3;
    }

    float m = clamp(line*uIntensity + spark*uIntensity, 0.0, 1.0);
    vec3 col = base + vec3(m);
    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}