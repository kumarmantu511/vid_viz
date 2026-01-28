#version 460 core

#include <flutter/runtime_effect.glsl>

precision highp float;

// Uniformları tek tek satırlara ayırarak tanımlıyoruz (Hata çözümü)
uniform vec2 uResolution;
uniform float uTime;
uniform float uIntensity;
uniform float uSpeed;
uniform vec3 uColor;
uniform float uBars;

// Frekanslar
uniform float uFreq0;
uniform float uFreq1;
uniform float uFreq2;
uniform float uFreq3;
uniform float uFreq4;
uniform float uFreq5;
uniform float uFreq6;
uniform float uFreq7;

uniform vec3 uColor2;
uniform sampler2D uTexture; // Resim/Video dokusu

out vec4 fragColor;

// Random fonksiyonu
float rand(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    // Koordinatları al
    vec2 frag = FlutterFragCoord().xy;
    vec2 uv = frag / uResolution;

    // Zaman hesabı
    float time = uTime * (0.7 + 0.3 * uSpeed);

    // Frekans etkisi (Environment)
    float env = clamp((uFreq3 + uFreq4) / 2.0, 0.0, 1.0);

    // Orijinal dokuyu oku
    vec3 tex = texture(uTexture, uv).rgb;

    // 1. Scanlines (Tarama çizgileri)
    float scan = 0.04 * sin(uv.y * uResolution.y * 3.14159) * (0.5 + 0.5 * env);

    // 2. Slight RGB Split (Renk kayması - Chromatic Aberration)
    float off = (1.0 + 2.0 * env) / max(uResolution.x, 1.0);
    vec3 split = vec3(
    texture(uTexture, uv + vec2(off, 0.0)).r,
    tex.g,
    texture(uTexture, uv - vec2(off, 0.0)).b
    );

    // 3. Noise (Gürültü)
    float n = rand(vec2(uv.x * 123.4, floor((uv.y + time * 0.1) * 200.0))) * 0.03;

    // Efektleri birleştir
    vec3 effect = clamp(split + scan + n, 0.0, 1.0);

    // Intensity ile orijinal ve efektli hali karıştır
    vec3 mixc = mix(tex, effect, clamp(uIntensity, 0.0, 1.0));

    // Çıktı
    fragColor = vec4(mixc, 1.0);
}