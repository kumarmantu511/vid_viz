#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform sampler2D uTexture;
uniform float uIntensity;

out vec4 fragColor;

// --- OPTIMIZASYON: Array Yerine Matematiksel Renk Donusumu ---
// Bu fonksiyon diziden veri okumak yerine rengi islemci uzerinde hesaplar.
// Cok daha hizlidir ve piksellesmeyi (banding) onler.
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution.xy;

    vec3 base = texture(uTexture, uv).rgb;

    // Parlaklık hesabı (Luma)
    float luma = dot(base, vec3(0.299, 0.587, 0.114));

    // --- RENK MANTIGI ---
    // Termal kameralarda sicak (1.0) Kirmizi, soguk (0.0) Mor/Mavidir.
    // HSV Renk uzayinda:
    // 0.0 = Kirmizi
    // 0.15 = Sari
    // 0.33 = Yesil
    // 0.66 = Mavi
    // 0.75 = Mor

    // Parlakligi (0..1) tersten Hue degerine (0.75..0) ceviriyoruz.
    // Boylece:
    // Parlak (1.0) -> (1.0 - 1.0)*0.75 = 0.0 Hue (KIRMIZI)
    // Karanlik (0.0) -> (1.0 - 0.0)*0.75 = 0.75 Hue (MOR/MAVI)
    float hue = (1.0 - luma) * 0.75;

    // Renkleri biraz daha canli gostermek icin Saturation 1.0, Value 1.0 kullaniyoruz.
    // Eğer soğuk kısımların (mor) daha karanlık olmasını istersen
    // vec3(hue, 1.0, 0.5 + 0.5 * luma) yapabilirsin.
    vec3 effect = hsv2rgb(vec3(hue, 1.0, 1.0));

    // Intensity ile karistirma
    vec3 finalColor = mix(base, effect, clamp(uIntensity, 0.0, 1.0));
    fragColor = vec4(finalColor, 1.0);
}